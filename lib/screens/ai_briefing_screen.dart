import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/errors/app_error_handler.dart';
import '../models/health_models.dart';
import '../services/chatbot_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_animations.dart';

class AIBriefingScreen extends StatefulWidget {
  final String? patientId;
  final String? initialPrompt;

  const AIBriefingScreen({
    super.key,
    this.patientId,
    this.initialPrompt,
  });

  @override
  State<AIBriefingScreen> createState() => _AIBriefingScreenState();
}

class _AIBriefingScreenState extends State<AIBriefingScreen> {
  final ChatbotService _chatbotService = ChatbotService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  bool _isGeneratingDaily = false;
  bool _isGeneratingPatient = false;
  bool _isGeneratingCustom = false;

  String _dailyBriefing = '';
  String _patientBriefing = '';
  String _customBriefing = '';

  List<ProviderPatientRecord> _allPatients = [];
  bool _isLoadingPatients = true;

  final TextEditingController _customPromptController = TextEditingController();
  final FocusNode _customPromptFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadPatients();
    if (widget.initialPrompt != null) {
      _customPromptController.text = widget.initialPrompt!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateCustomBriefing();
      });
    }
  }

  @override
  void dispose() {
    _customPromptController.dispose();
    _customPromptFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    final doctorId = _authService.currentUser?.uid;
    if (doctorId == null || doctorId.isEmpty) {
      setState(() => _isLoadingPatients = false);
      return;
    }

    try {
      final patients = await _firestoreService.getDoctorPatients(doctorId);
      if (mounted) {
        setState(() {
          _allPatients = patients;
          _isLoadingPatients = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPatients = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _generateDailyBriefing() async {
    setState(() => _isGeneratingDaily = true);

    try {
      final doctorName = _authService.currentUser?.displayName ?? 'Doctor';
      final currentDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

      final prompt = '''
Create a comprehensive daily clinical briefing for Dr. $doctorName on $currentDate.

**Patient Roster:** ${_allPatients.length} patients currently under care
${_allPatients.isNotEmpty ? _allPatients.map((p) => '- ${p.fullName}, Age ${p.age}${p.medicalHistory.isNotEmpty ? ' (${p.medicalHistory.join(', ')})' : ''}').join('\n') : 'No patients currently assigned'}

Please provide a structured daily briefing including:

## MORNING OVERVIEW
- Key priorities for today
- Critical patients requiring immediate attention
- Scheduled procedures or rounds

## CLINICAL ALERTS
- High-risk patients to monitor closely
- Potential safety concerns or drug interactions
- Follow-up actions from yesterday

## ADMINISTRATIVE TASKS
- Documentation gaps that need completion
- Quality metrics to review
- Communication needed with colleagues/families

## TODAY'S FOCUS AREAS
- Primary clinical goals
- Educational opportunities
- Quality improvement initiatives

## AI RECOMMENDATIONS
- Evidence-based care suggestions
- Efficiency tips for today's workflow
- New clinical guidelines or updates to consider

Format with clear sections and actionable bullet points. Keep tone professional but supportive.
''';

      final response = await _chatbotService.getGeminiResponse(prompt);

      if (mounted) {
        setState(() {
          _dailyBriefing = response;
          _isGeneratingDaily = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingDaily = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _generatePatientBriefing() async {
    if (_allPatients.isEmpty) {
      AppErrorHandler.showSnackBar(
        context,
        'No patients available for briefing. Add patients to generate insights.',
      );
      return;
    }

    setState(() => _isGeneratingPatient = true);

    try {
      final prompt = '''
As a clinical decision support AI, analyze the current patient roster and provide key insights:

**Current Patients:**
${_allPatients.map((p) => '''
Patient: ${p.fullName}, Age ${p.age}
Medical History: ${p.medicalHistory.isEmpty ? 'No significant history' : p.medicalHistory.join(', ')}
''').join('\n')}

Please provide:

## PATIENT POPULATION ANALYSIS
- Demographics overview (age ranges, common conditions)
- Risk stratification of current patients
- Notable patterns in medical histories

## HIGH-PRIORITY PATIENTS
- Patients requiring extra monitoring today
- Complex cases needing multidisciplinary approach
- Discharge planning considerations

## CLINICAL TRENDS
- Common diagnoses in current roster
- Medication management considerations
- Potential care coordination needs

## QUALITY OPPORTUNITIES
- Preventive care gaps to address
- Clinical documentation improvements
- Patient safety considerations

## ACTION ITEMS
- Specific follow-ups needed
- Recommended assessments or tests
- Care planning priorities

Focus on actionable insights that improve patient care and clinical efficiency.
''';

      final response = await _chatbotService.getGeminiResponse(prompt);

      if (mounted) {
        setState(() {
          _patientBriefing = response;
          _isGeneratingPatient = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingPatient = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _generateCustomBriefing() async {
    if (_customPromptController.text.trim().isEmpty) {
      AppErrorHandler.showSnackBar(
        context,
        'Please enter a question or prompt for AI analysis.',
      );
      _customPromptFocus.requestFocus();
      return;
    }

    setState(() => _isGeneratingCustom = true);

    try {
      final contextualPrompt = '''
As an AI clinical assistant, please analyze and respond to this request:

${_customPromptController.text.trim()}

${_allPatients.isNotEmpty ? '''
**Current Patient Context:**
- Total patients under care: ${_allPatients.length}
- Patient demographics: ${_allPatients.map((p) => '${p.fullName} (Age ${p.age})').join(', ')}
''' : ''}

**Current Date/Time:** ${DateFormat('EEEE, MMMM d, yyyy - h:mm a').format(DateTime.now())}
**Doctor:** ${_authService.currentUser?.displayName ?? 'Unknown'}

Provide a comprehensive, evidence-based response that addresses the request while considering the clinical context. Format with clear sections and actionable recommendations.
''';

      final response = await _chatbotService.getGeminiResponse(contextualPrompt);

      if (mounted) {
        setState(() {
          _customBriefing = response;
          _isGeneratingCustom = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingCustom = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  void _clearBriefings() {
    setState(() {
      _dailyBriefing = '';
      _patientBriefing = '';
      _customBriefing = '';
      _customPromptController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoadingPatients
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Status Dashboard Card
                        SlideUpAnimation(
                          child: _buildStatusDashboard(),
                        ),

                        const SizedBox(height: AppTheme.lg),

                        // Quick Action Cards
                        SlideUpAnimation(
                          delay: const Duration(milliseconds: 100),
                          child: _buildQuickActions(),
                        ),

                        const SizedBox(height: AppTheme.lg),

                        // Custom Prompt Section
                        SlideUpAnimation(
                          delay: const Duration(milliseconds: 200),
                          child: _buildCustomPromptCard(),
                        ),

                        // Briefing Results
                        if (_dailyBriefing.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.xl),
                          FadeInAnimation(
                            child: _buildBriefingCard(
                              title: 'Daily Clinical Briefing',
                              content: _dailyBriefing,
                              icon: Icons.today,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],

                        if (_patientBriefing.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.lg),
                          FadeInAnimation(
                            child: _buildBriefingCard(
                              title: 'Patient Roster Analysis',
                              content: _patientBriefing,
                              icon: Icons.groups,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],

                        if (_customBriefing.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.lg),
                          FadeInAnimation(
                            child: _buildBriefingCard(
                              title: 'Custom AI Analysis',
                              content: _customBriefing,
                              icon: Icons.psychology,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],

                        const SizedBox(height: AppTheme.xl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.blue.shade300,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: Colors.blue.shade300,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg, AppTheme.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.psychology,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI Clinical Briefing',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE, MMM d').format(DateTime.now()),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (_dailyBriefing.isNotEmpty || _patientBriefing.isNotEmpty || _customBriefing.isNotEmpty)
          IconButton(
            onPressed: _clearBriefings,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Clear All',
          ),
      ],
    );
  }

  Widget _buildStatusDashboard() {
    final doctorName = _authService.currentUser?.displayName ?? 'Doctor';

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.1),
            const Color(0xFF7C3AED).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF7C3AED),
                child: Text(
                  doctorName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${_getTimeOfDay()}, Dr. $doctorName',
                      style: AppTheme.labelLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          Row(
            children: [
              _buildStatusTile(
                icon: Icons.people,
                label: 'Patients',
                value: '${_allPatients.length}',
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: AppTheme.md),
              _buildStatusTile(
                icon: Icons.pending_actions,
                label: 'Tasks',
                value: '${_allPatients.isEmpty ? 0 : _allPatients.length + 2}',
                color: AppTheme.warningColor,
              ),
              const SizedBox(width: AppTheme.md),
              _buildStatusTile(
                icon: Icons.check_circle,
                label: 'Status',
                value: 'Ready',
                color: AppTheme.successColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.md),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTheme.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: AppTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            title: 'Daily Briefing',
            subtitle: 'Get overview',
            icon: Icons.today,
            gradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            isLoading: _isGeneratingDaily,
            onTap: _generateDailyBriefing,
          ),
        ),
        const SizedBox(width: AppTheme.md),
        Expanded(
          child: _buildActionCard(
            title: 'Patient Analysis',
            subtitle: 'Analyze roster',
            icon: Icons.groups,
            gradient: const [Color(0xFF059669), Color(0xFF047857)],
            isLoading: _isGeneratingPatient,
            onTap: _generatePatientBriefing,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTheme.largeRadius,
        gradient: LinearGradient(colors: gradient),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: AppTheme.largeRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.lg),
            child: Column(
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 32),
                const SizedBox(height: AppTheme.sm),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomPromptCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: AppTheme.md),
              Text('Ask AI Anything', style: AppTheme.headingSmall),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          TextField(
            controller: _customPromptController,
            focusNode: _customPromptFocus,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ask about protocols, drug interactions, clinical guidelines, or any medical question...',
              hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
              filled: true,
              fillColor: AppTheme.backgroundColor,
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
                borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.md),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: AppTheme.mediumRadius,
              gradient: _isGeneratingCustom
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                    ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isGeneratingCustom ? null : _generateCustomBriefing,
                borderRadius: AppTheme.mediumRadius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isGeneratingCustom) ...[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: AppTheme.sm),
                        const Text(
                          'Analyzing...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        const Icon(Icons.send, color: Colors.white, size: 20),
                        const SizedBox(width: AppTheme.sm),
                        const Text(
                          'Get AI Response',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBriefingCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.headingSmall.copyWith(color: color),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Briefing copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Copy to clipboard',
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(AppTheme.lg),
            child: SelectableText(
              content,
              style: AppTheme.bodyMedium.copyWith(height: 1.6),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, y • h:mm a').format(DateTime.now()),
                  style: AppTheme.bodySmall,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'AI Generated',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
