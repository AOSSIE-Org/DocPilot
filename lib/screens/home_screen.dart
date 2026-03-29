import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../core/providers/enhanced_connection_provider.dart';
import '../services/firebase/auth_service.dart';
import '../theme/ios_app_theme.dart';
import 'perfect_ios_patients_screen.dart';
import 'firebase_test_screen.dart';

/// Main home screen with iOS tab bar navigation
class DocPilotHomeScreen extends StatefulWidget {
  const DocPilotHomeScreen({super.key});

  @override
  State<DocPilotHomeScreen> createState() => _DocPilotHomeScreenState();
}

class _DocPilotHomeScreenState extends State<DocPilotHomeScreen> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();

  // Get doctor ID from authenticated user
  String? get _doctorId => _authService.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final doctorId = _doctorId;

    // If not authenticated, show sign-in prompt
    if (doctorId == null) {
      return CupertinoPageScaffold(
        backgroundColor: IosAppTheme.systemGroupedBackground,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.person_crop_circle_badge_exclam,
                   size: 64.sp, color: IosAppTheme.systemGray),
              SizedBox(height: 16.h),
              Text('Please sign in to continue',
                   style: TextStyle(fontSize: 17.sp, color: IosAppTheme.systemGray)),
            ],
          ),
        ),
      );
    }

    return CupertinoTabScaffold(
      backgroundColor: IosAppTheme.systemGroupedBackground,
      tabBar: CupertinoTabBar(
        backgroundColor: IosAppTheme.systemBackground,
        border: Border(
          top: BorderSide(
            color: IosAppTheme.systemGray4.withOpacity(0.4),
            width: 0.5.h,
          ),
        ),
        activeColor: IosAppTheme.primaryBlue,
        inactiveColor: IosAppTheme.systemGray,
        iconSize: 24.sp,
        height: 49.h + MediaQuery.of(context).padding.bottom,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.person_2),
            activeIcon: const Icon(CupertinoIcons.person_2_fill),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.doc_text),
            activeIcon: const Icon(CupertinoIcons.doc_text_fill),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.mic),
            activeIcon: const Icon(CupertinoIcons.mic_fill),
            label: 'Voice',
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.cloud),
            activeIcon: const Icon(CupertinoIcons.cloud_fill),
            label: 'Firebase',
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.settings),
            activeIcon: const Icon(CupertinoIcons.settings_solid),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            // Patients screen with perfect iOS design
            return CupertinoTabView(
              defaultTitle: 'Patients',
              builder: (context) => PerfectiOSPatientsScreen(
                doctorId: doctorId,
              ),
            );

          case 1:
            // Clinical notes screen (to be implemented)
            return CupertinoTabView(
              defaultTitle: 'Clinical Notes',
              builder: (context) => _buildPlaceholderScreen(
                'Clinical Notes',
                'Patient notes and reports will appear here',
                CupertinoIcons.doc_text_fill,
              ),
            );

          case 2:
            // Voice assistant screen (to be implemented)
            return CupertinoTabView(
              defaultTitle: 'Voice Assistant',
              builder: (context) => _buildPlaceholderScreen(
                'Voice Assistant',
                'Record and transcribe patient consultations',
                CupertinoIcons.mic_fill,
              ),
            );

          case 3:
            // Firebase test screen
            return CupertinoTabView(
              defaultTitle: 'Firebase Test',
              builder: (context) => const FirebaseTestScreen(),
            );

          case 4:
            // Settings screen (to be implemented)
            return CupertinoTabView(
              defaultTitle: 'Settings',
              builder: (context) => _buildSettingsScreen(),
            );

          default:
            return Container();
        }
      },
    );
  }

  /// Build placeholder screen for unimplemented tabs
  Widget _buildPlaceholderScreen(String title, String subtitle, IconData icon) {
    return CupertinoPageScaffold(
      backgroundColor: IosAppTheme.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: IosAppTheme.systemBackground,
        border: const Border(),
        middle: Text(
          title,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Container(
            padding: EdgeInsets.all(32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100.w,
                  height: 100.h,
                  decoration: BoxDecoration(
                    color: IosAppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Icon(
                    icon,
                    size: 50.sp,
                    color: IosAppTheme.primaryBlue,
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: CupertinoColors.secondaryLabel,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: IosAppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build settings screen with connection info
  Widget _buildSettingsScreen() {
    return CupertinoPageScaffold(
      backgroundColor: IosAppTheme.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: IosAppTheme.systemBackground,
        border: const Border(),
        middle: Text(
          'Settings',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: Consumer<EnhancedConnectionProvider>(
          builder: (context, connectionProvider, child) {
            return ListView(
              padding: EdgeInsets.symmetric(vertical: 20.h),
              children: [
                // Connection status section
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        child: Text(
                          'CONNECTION STATUS',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: IosAppTheme.secondarySystemGroupedBackground,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                connectionProvider.isOnline
                                    ? CupertinoIcons.wifi
                                    : CupertinoIcons.wifi_slash,
                                color: connectionProvider.isOnline
                                    ? IosAppTheme.systemGreen
                                    : IosAppTheme.systemRed,
                              ),
                              title: Text(
                                connectionProvider.isOnline ? 'Online' : 'Offline',
                                style: TextStyle(fontSize: 17.sp),
                              ),
                              subtitle: Text(
                                connectionProvider.isOnline
                                    ? 'Connected to server'
                                    : 'No internet connection',
                                style: TextStyle(fontSize: 15.sp),
                              ),
                            ),
                            if (connectionProvider.pendingSyncCount > 0) ...[
                              const Divider(height: 1),
                              ListTile(
                                leading: Icon(
                                  CupertinoIcons.clock,
                                  color: IosAppTheme.systemOrange,
                                ),
                                title: Text(
                                  'Pending Sync',
                                  style: TextStyle(fontSize: 17.sp),
                                ),
                                subtitle: Text(
                                  '${connectionProvider.pendingSyncCount} items waiting',
                                  style: TextStyle(fontSize: 15.sp),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 32.h),

                // App info section
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        child: Text(
                          'APP INFORMATION',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: IosAppTheme.secondarySystemGroupedBackground,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                CupertinoIcons.info_circle,
                                color: IosAppTheme.primaryBlue,
                              ),
                              title: Text(
                                'Version',
                                style: TextStyle(fontSize: 17.sp),
                              ),
                              trailing: Text(
                                '1.0.0',
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(
                                CupertinoIcons.device_phone_portrait,
                                color: IosAppTheme.primaryBlue,
                              ),
                              title: Text(
                                'Screen Size',
                                style: TextStyle(fontSize: 17.sp),
                              ),
                              trailing: Text(
                                '${ScreenUtil().screenWidth.toInt()} × ${ScreenUtil().screenHeight.toInt()}',
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
