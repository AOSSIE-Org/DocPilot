import 'package:flutter/material.dart';
import 'dart:async';

import '../core/errors/app_error_handler.dart';
import '../theme/app_theme.dart';
import '../models/health_models.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/chatbot_service.dart';

class ClinicalNotesScreen extends StatefulWidget {
  final String patientId;

  const ClinicalNotesScreen({
    super.key,
    required this.patientId,
  });

  @override
  State<ClinicalNotesScreen> createState() => _ClinicalNotesScreenState();
}

class _ClinicalNotesScreenState extends State<ClinicalNotesScreen> {
  final List<ClinicalNote> _notes = [];
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final ChatbotService _chatbotService = ChatbotService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _searchQuery = '';
  bool _isSyncingCloud = false;
  StreamSubscription<List<ClinicalNote>>? _cloudSubscription;

  @override
  void initState() {
    super.initState();
    // Load data asynchronously without blocking UI render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialNotes();
      _listenToCloudReports();
    });
  }

  Future<void> _loadInitialNotes() async {
    setState(() => _isSyncingCloud = true);
    final notes = await _firestoreService.getClinicalReports(widget.patientId);
    if (!mounted) return;
    setState(() {
      _notes
        ..clear()
        ..addAll(notes);
      _isSyncingCloud = false;
    });
  }

  @override
  void dispose() {
    _cloudSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToCloudReports() {
    if (!_firestoreService.isFirebaseAvailable) {
      setState(() => _isSyncingCloud = false);
      return;
    }

    _isSyncingCloud = true;
    _cloudSubscription =
        _firestoreService.watchClinicalReports(widget.patientId).listen(
      (cloudNotes) {
        if (!mounted) return;
        setState(() {
          _notes
            ..clear()
            ..addAll(cloudNotes);
          _isSyncingCloud = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isSyncingCloud = false;
        });
      },
    );
  }

  Future<void> _createClinicalReport() async {
    final result = await showModalBottomSheet<Map<String, String>?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _CreateNoteDialog(
        patientId: widget.patientId,
        chatbotService: _chatbotService,
      ),
    );

    if (result == null) return;

    final note = ClinicalNote(
      patientId: widget.patientId,
      title: result['title']!,
      content: result['content']!,
      diagnosis: result['diagnosis']?.isEmpty == true ? null : result['diagnosis'],
      treatments: result['treatments']?.split('\n').where((t) => t.trim().isNotEmpty).toList() ?? [],
      followUpItems: result['followUpItems']?.split('\n').where((f) => f.trim().isNotEmpty).toList() ?? [],
      createdBy: _authService.currentUser?.displayName ?? 'Clinician',
    );

    setState(() {
      _notes.insert(0, note);
    });

    try {
      await _firestoreService.saveClinicalReport(note);
    } catch (error) {
      if (mounted) {
        AppErrorHandler.showSnackBar(context, error);
      }
    }
  }

  Future<void> _editNote(ClinicalNote note) async {
    final result = await showModalBottomSheet<Map<String, String>?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _CreateNoteDialog(
        patientId: widget.patientId,
        chatbotService: _chatbotService,
        existingNote: note,
      ),
    );

    if (result == null) return;

    final updatedNote = note.copyWith(
      title: result['title']!,
      content: result['content']!,
      diagnosis: result['diagnosis']?.isEmpty == true ? null : result['diagnosis'],
      treatments: result['treatments']?.split('\n').where((t) => t.trim().isNotEmpty).toList() ?? [],
      followUpItems: result['followUpItems']?.split('\n').where((f) => f.trim().isNotEmpty).toList() ?? [],
    );

    setState(() {
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = updatedNote;
      }
    });

    try {
      await _firestoreService.updateClinicalReport(updatedNote);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note updated successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        AppErrorHandler.showSnackBar(context, error);
      }
    }
  }

  Future<void> _deleteNote(ClinicalNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _notes.removeWhere((n) => n.id == note.id);
    });

    try {
      await _firestoreService.deleteClinicalReport(note.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note deleted successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        AppErrorHandler.showSnackBar(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = _filterNotes();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Clinical Notes'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          if (_isSyncingCloud)
            const Padding(
              padding: EdgeInsets.only(right: AppTheme.lg),
              child: Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.md, AppTheme.lg, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes, diagnosis, treatment...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  _buildFilterChip('This Month', 'month'),
                  _buildFilterChip('This Year', 'year'),
                  _buildFilterChip('Archival', 'archive'),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.lg),

          // Notes List
          if (filteredNotes.isEmpty)
            Expanded(
              child: _buildEmptyState(),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
                itemCount: filteredNotes.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.lg),
                    child: _buildNoteCard(filteredNotes[index]),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createClinicalReport,
        icon: const Icon(Icons.add_chart),
        label: const Text('New Report'),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.md),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedFilter = value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.lg,
            vertical: AppTheme.md,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            border: isSelected
                ? null
                : Border.all(color: AppTheme.dividerColor),
            borderRadius: AppTheme.mediumRadius,
          ),
          child: Text(
            label,
            style: AppTheme.labelMedium.copyWith(
              color: isSelected ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteCard(ClinicalNote note) {
    return GlossyCard(
      onTap: () => _showNoteDetails(note),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: AppTheme.headingSmall,
                    ),
                    const SizedBox(height: AppTheme.xs),
                    Text(
                      'Dr. ${note.createdBy.split(' ').last}',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.md,
                        vertical: AppTheme.xs,
                      ),
                      decoration: BoxDecoration(
                        color: _getDiagnosisColor(note.diagnosis)
                            .withValues(alpha: 0.1),
                        borderRadius: AppTheme.mediumRadius,
                      ),
                      child: Text(
                        _diagnosisText(note),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.labelSmall.copyWith(
                          color: _getDiagnosisColor(note.diagnosis),
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editNote(note);
                      } else if (value == 'delete') {
                        _deleteNote(note);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    icon: Icon(Icons.more_vert, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          Text(
            note.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: AppTheme.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(note.createdAt),
                style: AppTheme.labelSmall,
              ),
              if (note.treatments.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.medication,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: AppTheme.xs),
                    Text(
                      '${note.treatments.length} treatments',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNoteDetails(ClinicalNote note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppTheme.lg,
            right: AppTheme.lg,
            top: AppTheme.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.headingMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.md),
                
                // Date and Doctor Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date', style: AppTheme.labelSmall),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          _formatDate(note.createdAt),
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Provider', style: AppTheme.labelSmall),
                        const SizedBox(height: AppTheme.xs),
                        Text(
                          note.createdBy,
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.xl),

                // Diagnosis
                Container(
                  padding: const EdgeInsets.all(AppTheme.md),
                  decoration: BoxDecoration(
                      color: _getDiagnosisColor(note.diagnosis)
                        .withValues(alpha: 0.1),
                    borderRadius: AppTheme.mediumRadius,
                    border: Border.all(
                        color: _getDiagnosisColor(note.diagnosis)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.find_in_page,
                        color:
                              _getDiagnosisColor(note.diagnosis),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diagnosis',
                              style: AppTheme.labelSmall,
                            ),
                            const SizedBox(height: AppTheme.xs),
                            Text(
                              _diagnosisText(note),
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.xl),

                // Clinical Notes
                Text('Clinical Notes', style: AppTheme.labelLarge),
                const SizedBox(height: AppTheme.md),
                Text(
                  note.content,
                  style: AppTheme.bodySmall,
                ),
                const SizedBox(height: AppTheme.xl),

                // Treatments
                if (note.treatments.isNotEmpty) ...[
                  Text('Treatments', style: AppTheme.labelLarge),
                  const SizedBox(height: AppTheme.md),
                  Column(
                    children: note.treatments
                        .map(
                          (treatment) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppTheme.md),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.md),
                                Expanded(
                                  child: Text(
                                    treatment,
                                    style: AppTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppTheme.xl),
                ],

                // Follow-up Items
                if (note.followUpItems.isNotEmpty) ...[
                  Text('Follow-up Items', style: AppTheme.labelLarge),
                  const SizedBox(height: AppTheme.md),
                  Column(
                    children: note.followUpItems
                        .map(
                          (item) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppTheme.md),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.schedule,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.md),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: AppTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<ClinicalNote> _filterNotes() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'month':
        return _applySearch(
          _notes
            .where((note) =>
                note.createdAt.month == now.month &&
                note.createdAt.year == now.year)
            .toList(),
        );
      case 'year':
        return _applySearch(
          _notes
            .where((note) => note.createdAt.year == now.year)
            .toList(),
        );
      case 'archive':
        return _applySearch(
          _notes
            .where(
                (note) => note.createdAt.isBefore(DateTime(now.year - 1)))
            .toList(),
        );
      default:
        return _applySearch(_notes);
    }
  }

  List<ClinicalNote> _applySearch(List<ClinicalNote> notes) {
    if (_searchQuery.isEmpty) return notes;
    return notes.where((note) {
      final treatmentsText = note.treatments.join(' ').toLowerCase();
      final followUpText = note.followUpItems.join(' ').toLowerCase();
      return note.title.toLowerCase().contains(_searchQuery) ||
          note.content.toLowerCase().contains(_searchQuery) ||
          (note.diagnosis?.toLowerCase().contains(_searchQuery) ?? false) ||
          treatmentsText.contains(_searchQuery) ||
          followUpText.contains(_searchQuery);
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_outlined,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppTheme.md),
          Text(
            'No Clinical Notes',
            style: AppTheme.headingMedium.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            'Notes will appear here',
            style: AppTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Color _getDiagnosisColor(String? diagnosis) {
    if (diagnosis == null || diagnosis.trim().isEmpty) {
      return AppTheme.textSecondary;
    }

    final lower = diagnosis.toLowerCase();
    if (lower.contains('healthy') || lower.contains('normal')) {
      return AppTheme.successColor;
    } else if (lower.contains('severe') ||
        lower.contains('urgent') ||
        lower.contains('critical')) {
      return AppTheme.dangerColor;
    } else if (lower.contains('moderate') || lower.contains('warning')) {
      return AppTheme.warningColor;
    }
    return AppTheme.primaryColor;
  }

  String _diagnosisText(ClinicalNote note) {
    final diagnosis = note.diagnosis;
    if (diagnosis == null || diagnosis.trim().isEmpty) {
      return 'Not specified';
    }
    return diagnosis;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// AI-Assisted Clinical Note Creation Dialog
class _CreateNoteDialog extends StatefulWidget {
  final String patientId;
  final ChatbotService chatbotService;
  final ClinicalNote? existingNote;

  const _CreateNoteDialog({
    required this.patientId,
    required this.chatbotService,
    this.existingNote,
  });

  @override
  State<_CreateNoteDialog> createState() => _CreateNoteDialogState();
}

class _CreateNoteDialogState extends State<_CreateNoteDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _treatmentsController = TextEditingController();
  final TextEditingController _followUpController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();

  bool _isGenerating = false;
  bool _showAIAssistance = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingNote != null) {
      final note = widget.existingNote!;
      _titleController.text = note.title;
      _contentController.text = note.content;
      _diagnosisController.text = note.diagnosis ?? '';
      _treatmentsController.text = note.treatments.join('\n');
      _followUpController.text = note.followUpItems.join('\n');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _diagnosisController.dispose();
    _treatmentsController.dispose();
    _followUpController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generateAIContent() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe what you want to document')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final aiPrompt = '''
Generate a clinical note based on the following information:

**Request:** $prompt

Please provide a structured clinical note with:

1. **Suggested Title:** Brief, professional title for the note
2. **Clinical Content:** Detailed clinical documentation
3. **Diagnosis/Assessment:** Primary clinical assessment or diagnosis
4. **Treatment Plan:** Recommended treatments or interventions (one per line)
5. **Follow-up Items:** Next steps or monitoring needed (one per line)

Format the response clearly with each section labeled.
''';

      final result = await widget.chatbotService.getGeminiResponse(aiPrompt);

      if (mounted) {
        _parseAIResponse(result);
        setState(() => _isGenerating = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI generation failed: $e')),
        );
      }
    }
  }

  void _parseAIResponse(String response) {
    final lines = response.split('\n');
    String currentSection = '';
    String title = '';
    String content = '';
    String diagnosis = '';
    List<String> treatments = [];
    List<String> followUps = [];

    for (String line in lines) {
      final lowerLine = line.toLowerCase();

      if (lowerLine.contains('suggested title') || lowerLine.contains('title:')) {
        currentSection = 'title';
      } else if (lowerLine.contains('clinical content') || lowerLine.contains('content:')) {
        currentSection = 'content';
      } else if (lowerLine.contains('diagnosis') || lowerLine.contains('assessment')) {
        currentSection = 'diagnosis';
      } else if (lowerLine.contains('treatment')) {
        currentSection = 'treatments';
      } else if (lowerLine.contains('follow-up') || lowerLine.contains('follow up')) {
        currentSection = 'followup';
      } else if (line.trim().isNotEmpty && !line.startsWith('#')) {
        switch (currentSection) {
          case 'title':
            if (title.isEmpty) title = line.trim().replaceAll(RegExp(r'^[\*\-\d\.]\s*'), '');
            break;
          case 'content':
            if (content.isNotEmpty) content += '\n';
            content += line.trim();
            break;
          case 'diagnosis':
            if (diagnosis.isEmpty) diagnosis = line.trim().replaceAll(RegExp(r'^[\*\-\d\.]\s*'), '');
            break;
          case 'treatments':
            final treatment = line.trim().replaceAll(RegExp(r'^[\*\-\d\.]\s*'), '');
            if (treatment.isNotEmpty) treatments.add(treatment);
            break;
          case 'followup':
            final followUp = line.trim().replaceAll(RegExp(r'^[\*\-\d\.]\s*'), '');
            if (followUp.isNotEmpty) followUps.add(followUp);
            break;
        }
      }
    }

    // Update the controllers
    if (title.isNotEmpty) _titleController.text = title;
    if (content.isNotEmpty) _contentController.text = content;
    if (diagnosis.isNotEmpty) _diagnosisController.text = diagnosis;
    if (treatments.isNotEmpty) _treatmentsController.text = treatments.join('\n');
    if (followUps.isNotEmpty) _followUpController.text = followUps.join('\n');

    _promptController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.lg,
        right: AppTheme.lg,
        top: AppTheme.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  widget.existingNote == null ? 'New Clinical Note' : 'Edit Clinical Note',
                  style: AppTheme.headingMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showAIAssistance = !_showAIAssistance;
                    });
                  },
                  icon: Icon(
                    _showAIAssistance ? Icons.psychology : Icons.psychology_outlined,
                    color: AppTheme.primaryColor,
                  ),
                  tooltip: 'AI Assistance',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // AI Assistance Section
            if (_showAIAssistance) ...[
              const SizedBox(height: AppTheme.md),
              Container(
                padding: const EdgeInsets.all(AppTheme.md),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.mediumRadius,
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: AppTheme.sm),
                        Text(
                          'AI Assistant',
                          style: AppTheme.labelLarge.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.sm),
                    TextField(
                      controller: _promptController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Describe what you want to document (e.g., "Patient visit for diabetes follow-up, blood sugar well controlled")',
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.mediumRadius,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: AppTheme.sm),
                    ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _generateAIContent,
                      icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(_isGenerating ? 'Generating...' : 'Generate Note'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppTheme.lg),

            // Manual Input Fields
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g., Routine Checkup, Post-op Follow-up',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.md),

            TextField(
              controller: _diagnosisController,
              decoration: const InputDecoration(
                labelText: 'Diagnosis/Assessment',
                hintText: 'Primary diagnosis or assessment',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.md),

            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Clinical Notes *',
                hintText: 'Detailed clinical documentation...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.md),

            TextField(
              controller: _treatmentsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Treatment Plan (one per line)',
                hintText: 'Continue current medications\nFollow up in 2 weeks',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.md),

            TextField(
              controller: _followUpController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Follow-up Items (one per line)',
                hintText: 'Lab work in 1 month\nSchedule imaging',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.xl),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppTheme.md),
                ElevatedButton(
                  onPressed: () {
                    if (_titleController.text.trim().isEmpty ||
                        _contentController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Title and clinical notes are required'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context, {
                      'title': _titleController.text.trim(),
                      'content': _contentController.text.trim(),
                      'diagnosis': _diagnosisController.text.trim(),
                      'treatments': _treatmentsController.text.trim(),
                      'followUpItems': _followUpController.text.trim(),
                    });
                  },
                  child: Text(widget.existingNote == null ? 'Create Note' : 'Update Note'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
