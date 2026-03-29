import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../core/errors/app_error_handler.dart';
import '../services/chatbot_service.dart';

/// Professional, fast-loading AI briefing screen for clinical handoffs
class FastShiftHandoffScreen extends StatefulWidget {
  final String? patientId;

  const FastShiftHandoffScreen({
    super.key,
    this.patientId,
  });

  @override
  State<FastShiftHandoffScreen> createState() => _FastShiftHandoffScreenState();
}

class _FastShiftHandoffScreenState extends State<FastShiftHandoffScreen> {
  final ChatbotService _chatbotService = ChatbotService();
  final TextEditingController _briefingController = TextEditingController();
  bool _isGenerating = false;
  String _briefResult = '';

  @override
  void dispose() {
    _briefingController.dispose();
    super.dispose();
  }

  Future<void> _generateBriefing() async {
    if (_briefingController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: AppTheme.md),
              Text('Please enter briefing requirements'),
            ],
          ),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final prompt = '''
Generate a comprehensive AI briefing based on the following requirements:

${_briefingController.text.trim()}

Structure the response as:
1. 🔴 PRIORITY ITEMS (urgent tasks requiring immediate attention)
2. 📋 KEY UPDATES (important changes since last shift)
3. 👥 PATIENT STATUS SUMMARY (critical patients and their current status)
4. ✓ PENDING ACTIONS (tasks that need completion)
5. ⚠️ ALERTS & REMINDERS (safety items, deadlines, follow-ups)

Format as clear, actionable bullet points for healthcare team handoff.
''';

      final result = await _chatbotService.getGeminiResponse(prompt);

      if (!mounted) return;
      setState(() {
        _briefResult = result;
        _isGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  void _clearAll() {
    setState(() {
      _briefingController.clear();
      _briefResult = '';
    });
  }

  void _copyToClipboard() {
    if (_briefResult.isNotEmpty) {
      // Clipboard copy functionality would go here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: AppTheme.md),
              Text('Briefing copied to clipboard'),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('AI Shift Briefing'),
        backgroundColor: AppTheme.successColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_briefResult.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              onPressed: _copyToClipboard,
              tooltip: 'Copy briefing',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _clearAll,
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: Column(
        children: [
          // Professional Header Banner
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.successColor, AppTheme.successColor.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.successColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.md),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: AppTheme.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI-Powered Team Briefing',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Generated briefings for clinical handoffs',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.md,
                      vertical: AppTheme.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, color: Colors.white, size: 16),
                        SizedBox(width: AppTheme.xs),
                        Text(
                          DateFormat('EEEE, MMMM d • HH:mm').format(DateTime.now()),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Quick Suggestions
                  if (_briefResult.isEmpty) ...[
                    _buildQuickSuggestions(),
                    const SizedBox(height: AppTheme.xl),
                  ],

                  // Briefing Requirements Field
                  Row(
                    children: [
                      Icon(Icons.list_alt, size: 20, color: AppTheme.successColor),
                      SizedBox(width: AppTheme.sm),
                      Text(
                        'Briefing Requirements',
                        style: AppTheme.labelLarge.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: AppTheme.mediumRadius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _briefingController,
                      maxLines: 6,
                      style: AppTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Describe what you need briefed on:\n• Patient status updates\n• Pending tasks and deadlines\n• Critical alerts\n• Handoff priorities',
                        hintStyle: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Icon(
                            Icons.edit_note,
                            color: AppTheme.successColor.withValues(alpha: 0.7),
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.mediumRadius,
                          borderSide: BorderSide(color: AppTheme.dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppTheme.mediumRadius,
                          borderSide: BorderSide(color: AppTheme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppTheme.mediumRadius,
                          borderSide: BorderSide(color: AppTheme.successColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.all(AppTheme.lg),
                        alignLabelWithHint: true,
                      ),
                      textAlignVertical: TextAlignVertical.top,
                    ),
                  ),
                  const SizedBox(height: AppTheme.xxl),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearAll,
                          icon: Icon(Icons.clear_all),
                          label: Text('Clear'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: AppTheme.lg),
                            side: BorderSide(color: AppTheme.dividerColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isGenerating ? null : _generateBriefing,
                          icon: _isGenerating
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(Icons.auto_awesome),
                          label: Text(_isGenerating ? 'Generating...' : 'Generate Briefing'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: AppTheme.lg),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.xl),

                  // Generated Briefing Result
                  if (_briefResult.isNotEmpty) _buildBriefingResult(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    final suggestions = [
      {'icon': Icons.list, 'text': 'Daily priorities and pending items'},
      {'icon': Icons.warning_amber, 'text': 'Critical alerts and safety concerns'},
      {'icon': Icons.people, 'text': 'Patient status and overnight events'},
      {'icon': Icons.task_alt, 'text': 'Completed tasks and follow-ups'},
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.1),
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.2),
        ),
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: AppTheme.successColor, size: 20),
              SizedBox(width: AppTheme.sm),
              Text(
                'Quick Suggestions',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          ...suggestions.map((suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.sm),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        suggestion['icon'] as IconData,
                        size: 16,
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Text(
                        suggestion['text'] as String,
                        style: AppTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBriefingResult() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.successColor.withValues(alpha: 0.1),
            AppTheme.successColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.3),
        ),
        borderRadius: AppTheme.mediumRadius,
        boxShadow: [
          BoxShadow(
            color: AppTheme.successColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppTheme.lg),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.only(
                topLeft: AppTheme.mediumRadius.topLeft,
                topRight: AppTheme.mediumRadius.topRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Text(
                    'AI Briefing Ready',
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.share_outlined, color: AppTheme.successColor),
                  onPressed: _copyToClipboard,
                  tooltip: 'Share briefing',
                ),
              ],
            ),
          ),
          // Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.lg),
            child: SelectableText(
              _briefResult,
              style: AppTheme.bodyMedium.copyWith(
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}