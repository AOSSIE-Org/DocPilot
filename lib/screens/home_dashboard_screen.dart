import 'package:flutter/material.dart';
import '../core/errors/app_error_handler.dart';
import '../core/utils/logout_utils.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import 'doctor_patients_screen.dart';
import 'clinical_notes_screen.dart';
import 'medication_safety_screen.dart';
import 'shift_handoff_screen.dart';
import 'emergency_triage_screen.dart';
import 'ward_rounds_screen.dart';
import 'voice_assistant_screen.dart';
import 'doctor_profile_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _showWelcomeBanner = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final doctorId = _authService.currentUser?.uid;
    if (doctorId == null || doctorId.isEmpty) {
      return;
    }

    try {
      await _firestoreService.getDoctorPatients(doctorId);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
  }

  void _signOut() async {
    await LogoutUtils.performSafeLogout(
      context: context,
      onLogout: () => _authService.signOut(),
      onError: (error) {
        AppErrorHandler.showSnackBar(context, error);
      },
      // AuthGateScreen listens to Firebase auth changes and will switch to
      // SignInScreen automatically after successful sign out.
      onSuccess: () {},
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final userName = _authService.currentUser?.displayName ?? 'Doctor';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final workflowCardAspectRatio = screenWidth <= 390 ? 1.28 : 1.36;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with greeting and actions
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Hello, $userName',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Profile Icon
                          GestureDetector(
                            onTap: () => _navigateTo(const DoctorProfileScreen()),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.person, color: Colors.grey[800], size: 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Logout Icon
                          GestureDetector(
                            onTap: _signOut,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.exit_to_app, color: Colors.grey[800], size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Welcome Banner
              if (_showWelcomeBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.handshake, color: Colors.white, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Welcome to DocPilot!',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() => _showWelcomeBanner = false);
                              },
                              child: const Icon(Icons.close, color: Colors.white, size: 24),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All features work right away! Add patients later to link notes and consultations to their records.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _navigateTo(DoctorPatientsScreen()),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_circle, color: Colors.blue, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add Patient (Optional)',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              // Advanced Workflows Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Advanced Workflows',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      padding: EdgeInsets.zero,
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: workflowCardAspectRatio,
                      children: [
                        _WorkflowCard(
                          icon: Icons.mic_none,
                          color: Colors.blue,
                          title: 'Consultation AI',
                          description: 'Voice to text with Deepgram and AI summaries',
                          onTap: () => _navigateTo(InteractiveVoiceAssistantScreen(patientId: 'new')),
                        ),
                        _WorkflowCard(
                          icon: Icons.local_pharmacy,
                          color: Colors.orange,
                          title: 'Medication Safety',
                          description: 'Check drug interactions and contraindications',
                          onTap: () => _navigateTo(MedicationSafetyScreen()),
                        ),
                        _WorkflowCard(
                          icon: Icons.assignment,
                          color: Colors.teal,
                          title: 'Shift Handoff',
                          description: 'Generate concise handoff summaries quickly',
                          onTap: () => _navigateTo(ShiftHandoffScreen()),
                        ),
                        _WorkflowCard(
                          icon: Icons.note,
                          color: Colors.purple,
                          title: 'Clinical Notes',
                          description: 'Record and manage patient documentation',
                          onTap: () => _navigateTo(
                            ClinicalNotesScreen(patientId: 'new'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Quick Actions Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _ActionButton(
                      icon: Icons.group,
                      color: Colors.cyan,
                      title: 'My Patients',
                      description: 'View patient records and history',
                      onTap: () => _navigateTo(DoctorPatientsScreen()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Hospital Operations Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hospital Operations',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _ActionButton(
                      icon: Icons.emergency_share,
                      color: Colors.red,
                      title: 'Emergency Triage',
                      description: 'Quickly prioritize urgent cases',
                      onTap: () => _navigateTo(EmergencyTriageScreen()),
                    ),
                    const SizedBox(height: 6),
                    _ActionButton(
                      icon: Icons.local_hospital,
                      color: Colors.teal,
                      title: 'Ward Rounds',
                      description: 'Generate rounds summary and plans',
                      onTap: () => _navigateTo(WardRoundsScreen()),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _WorkflowCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }
}
