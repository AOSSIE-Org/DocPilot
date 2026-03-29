import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import '../core/errors/app_error_handler.dart';
import '../theme/app_theme.dart';
import '../models/health_models.dart';
import '../services/chatbot_service.dart';
import '../services/firebase/firestore_service.dart';

class DocumentScannerScreen extends StatefulWidget {
  final String patientId;

  const DocumentScannerScreen({
    super.key,
    required this.patientId,
  });

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final ChatbotService _chatbotService = ChatbotService();
  final FirestoreService _firestoreService = FirestoreService();
  
  final List<DocumentScan> _scans = [];
  bool _isAnalyzing = false;
  String _selectedDocType = 'lab_report';
  File? _selectedImage;
  StreamSubscription<List<DocumentScan>>? _cloudSubscription;

  @override
  void initState() {
    super.initState();
    _listenToCloudScans();
  }

  @override
  void dispose() {
    _cloudSubscription?.cancel();
    super.dispose();
  }

  void _listenToCloudScans() {
    if (!_firestoreService.isFirebaseAvailable) return;

    _cloudSubscription =
        _firestoreService.watchDocumentScans(widget.patientId).listen(
      (cloudScans) {
        if (!mounted) return;
        setState(() {
          _scans
            ..clear()
            ..addAll(cloudScans);
        });
      },
      onError: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Medical Documents'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Upload Section
            _buildUploadSection(),
            const SizedBox(height: AppTheme.lg),
            
            // Recent Scans
            if (_scans.isNotEmpty) ...[
              SectionHeader(
                title: 'Recent Scans',
                subtitle: '${_scans.length} document${_scans.length > 1 ? 's' : ''}',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _scans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppTheme.md),
                  itemBuilder: (context, index) {
                    return _buildScanCard(_scans[index]);
                  },
                ),
              ),
            ] else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.lg),
      child: GlossyCard(
        child: Column(
          children: [
            if (_selectedImage != null)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: AppTheme.mediumRadius,
                    child: Image.file(
                      _selectedImage!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: AppTheme.lg),
                ],
              ),
            
            // Document Type Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Document Type', style: AppTheme.labelLarge),
                const SizedBox(height: AppTheme.sm),
                Wrap(
                  spacing: AppTheme.sm,
                  runSpacing: AppTheme.sm,
                  children: [
                    _buildDocTypeChip('lab_report', 'Lab Report', Icons.biotech),
                    _buildDocTypeChip('xray', 'X-Ray', Icons.image),
                    _buildDocTypeChip('scan', 'Scan', Icons.document_scanner),
                    _buildDocTypeChip('prescription', 'Prescription', Icons.medication),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.lg),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.lg,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: AppTheme.mediumRadius,
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.camera_alt,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                          const SizedBox(height: AppTheme.xs),
                          const Text(
                            'Camera',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.lg,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                        borderRadius: AppTheme.mediumRadius,
                        border: Border.all(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.image,
                            color: AppTheme.secondaryColor,
                            size: 28,
                          ),
                          const SizedBox(height: AppTheme.xs),
                          const Text(
                            'Gallery',
                            style: TextStyle(
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            if (_selectedImage != null) ...[
              const SizedBox(height: AppTheme.lg),
              IosButton(
                label: _isAnalyzing ? 'Analyzing...' : 'Analyze Document',
                isLoading: _isAnalyzing,
                onPressed: _analyzeDocument,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(DocumentScan scan) {
    return GlossyCard(
      onTap: () => _showScanDetails(scan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getDocTypeColor(scan.documentType).withValues(alpha: 0.1),
                  borderRadius: AppTheme.mediumRadius,
                ),
                child: Center(
                  child: Icon(
                    _getDocTypeIcon(scan.documentType),
                    color: _getDocTypeColor(scan.documentType),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      _formatDocType(scan.documentType),
                      style: AppTheme.labelLarge,
                    ),
                    const SizedBox(height: AppTheme.xs),
                    Text(
                      _formatDate(scan.dateScanned),
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (scan.isProcessed)
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 20,
                ),
            ],
          ),
          if (scan.analysis != null) ...[
            const SizedBox(height: AppTheme.md),
            const Divider(color: AppTheme.dividerColor, height: 1),
            const SizedBox(height: AppTheme.md),
            Text(
              'Analysis',
              style: AppTheme.labelMedium,
            ),
            const SizedBox(height: AppTheme.xs),
            Text(
              scan.analysis!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.xl),
      child: Column(
        children: [
          Icon(
            Icons.document_scanner,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppTheme.md),
          Text(
            'No Documents Yet',
            style: AppTheme.headingMedium.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: AppTheme.xs),
          Text(
            'Scan your medical documents to analyze them',
            style: AppTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (!mounted) return;
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  Future<void> _analyzeDocument() async {
    if (_selectedImage == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // Create analysis prompt
      final prompt = '''Analyze this medical document image and provide:
1. Document Type Confirmation
2. Key Health Metrics/Values
3. Important Findings
4. Recommended Actions
5. Risk Assessment

Provide the analysis in a structured format.''';

      final analysis = await _chatbotService.getGeminiVisionResponse(
        prompt: prompt,
        imagePath: _selectedImage!.path,
      );

      if (!mounted) return;

      final scan = DocumentScan(
        patientId: widget.patientId,
        imagePath: _selectedImage!.path,
        documentType: _selectedDocType,
        analysis: analysis,
        isProcessed: true,
      );

      setState(() {
        _scans.insert(0, scan);
        _selectedImage = null;
        _isAnalyzing = false;
      });

      try {
        await _firestoreService.saveDocumentScan(scan);
      } catch (error) {
        if (!mounted) return;
        AppErrorHandler.showSnackBar(context, error);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document analyzed successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  Future<void> _showScanDetails(DocumentScan scan) async {
    final imageFile = File(scan.imagePath);
    final imageExists = await imageFile.exists();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppTheme.lg),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _formatDocType(scan.documentType),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.headingSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.md),
                ClipRRect(
                  borderRadius: AppTheme.mediumRadius,
                  child: imageExists
                      ? Image.file(
                          imageFile,
                          height: 300,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 180,
                          width: double.infinity,
                          color: AppTheme.backgroundColor,
                          alignment: Alignment.center,
                          child: Text(
                            'Image preview unavailable on this device.',
                            style: AppTheme.bodySmall,
                          ),
                        ),
                ),
                if (!imageExists) ...[
                  const SizedBox(height: AppTheme.sm),
                  Text(
                    'The scan record was synced from cloud, but local image file path is not present here.',
                    style: AppTheme.labelSmall,
                  ),
                ],
                const SizedBox(height: AppTheme.lg),
                if (scan.extractedText != null) ...[
                  Text('Extracted Text', style: AppTheme.labelLarge),
                  const SizedBox(height: AppTheme.md),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.md),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: AppTheme.mediumRadius,
                    ),
                    child: Text(
                      scan.extractedText!,
                      style: AppTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: AppTheme.lg),
                ],
                if (scan.analysis != null) ...[
                  Text('AI Analysis', style: AppTheme.labelLarge),
                  const SizedBox(height: AppTheme.md),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.md),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: AppTheme.mediumRadius,
                      border: Border.all(
                        color: AppTheme.successColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      scan.analysis!,
                      style: AppTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getDocTypeColor(String type) {
    switch (type) {
      case 'lab_report':
        return AppTheme.primaryColor;
      case 'xray':
        return AppTheme.secondaryColor;
      case 'scan':
        return AppTheme.warningColor;
      case 'prescription':
        return AppTheme.successColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getDocTypeIcon(String type) {
    switch (type) {
      case 'lab_report':
        return Icons.biotech;
      case 'xray':
        return Icons.image;
      case 'scan':
        return Icons.document_scanner;
      case 'prescription':
        return Icons.medication;
      default:
        return Icons.description;
    }
  }

  Widget _buildDocTypeChip(String value, String label, IconData icon) {
    final isSelected = _selectedDocType == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.primaryColor),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedDocType = value;
        });
      },
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
      ),
    );
  }

  String _formatDocType(String type) {
    switch (type) {
      case 'lab_report':
        return 'Lab Report';
      case 'xray':
        return 'X-Ray';
      case 'scan':
        return 'Medical Scan';
      case 'prescription':
        return 'Prescription';
      default:
        return 'Document';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
