import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../core/config/firebase_config.dart';
import '../core/providers/enhanced_connection_provider.dart';
import '../widgets/ios_responsive_components.dart';
import '../theme/ios_app_theme.dart';

/// Firebase testing and diagnostics screen
class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  Map<String, String> _firebaseInfo = {};
  bool _isLoading = false;
  String _testStatus = 'Ready to test';
  List<String> _testResults = [];

  @override
  void initState() {
    super.initState();
    _loadFirebaseInfo();
  }

  void _loadFirebaseInfo() {
    setState(() {
      _firebaseInfo = FirebaseConfig.getProjectInfo();
    });
  }

  Future<void> _runFirebaseTests() async {
    setState(() {
      _isLoading = true;
      _testResults.clear();
      _testStatus = 'Running Firebase tests...';
    });

    try {
      // Test 1: Firebase initialization
      _addTestResult('🔄 Testing Firebase initialization...');
      await Future.delayed(const Duration(milliseconds: 500));

      if (FirebaseConfig.isInitialized) {
        _addTestResult('✅ Firebase is initialized');
      } else {
        _addTestResult('❌ Firebase not initialized');
        await FirebaseConfig.initialize();
        _addTestResult('🔄 Attempting to initialize Firebase...');

        if (FirebaseConfig.isInitialized) {
          _addTestResult('✅ Firebase initialized successfully');
        } else {
          _addTestResult('❌ Firebase initialization failed');
        }
      }

      // Test 2: Connection validation
      _addTestResult('🔄 Validating Firebase connection...');
      await Future.delayed(const Duration(milliseconds: 500));

      final isConnected = await FirebaseConfig.validateConnection();
      if (isConnected) {
        _addTestResult('✅ Firebase connection validated');
      } else {
        _addTestResult('❌ Firebase connection validation failed');
      }

      // Test 3: Project info
      _addTestResult('🔄 Retrieving project information...');
      await Future.delayed(const Duration(milliseconds: 500));

      final info = FirebaseConfig.getProjectInfo();
      if (info['status'] == 'Connected') {
        _addTestResult('✅ Project info retrieved successfully');
        _addTestResult('   Project ID: ${info['projectId']}');
        _addTestResult('   App ID: ${info['appId']}');
      } else {
        _addTestResult('❌ Failed to get project info: ${info['status']}');
      }

      // Test 4: Network connectivity
      if (mounted) {
        final connectionProvider = context.read<EnhancedConnectionProvider>();
        _addTestResult('🔄 Checking network connectivity...');
        await Future.delayed(const Duration(milliseconds: 500));

        if (connectionProvider.isOnline) {
          _addTestResult('✅ Network connection available');
        } else {
          _addTestResult('⚠️ No network connection (offline mode)');
        }
      }

      setState(() {
        _testStatus = 'Tests completed';
        _isLoading = false;
      });

      _loadFirebaseInfo(); // Refresh info

    } catch (e) {
      _addTestResult('❌ Test error: $e');
      setState(() {
        _testStatus = 'Tests failed with error';
        _isLoading = false;
      });
    }
  }

  void _addTestResult(String result) {
    setState(() {
      _testResults.add(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: IosAppTheme.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: IosAppTheme.systemBackground,
        border: const Border(),
        middle: ResponsiveText(
          'Firebase Test',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          children: [
            // Test controls
            IosSection(
              title: 'Firebase Testing',
              subtitle: 'Run comprehensive Firebase connection tests',
              children: [
                IosListTile(
                  title: ResponsiveText(
                    _testStatus,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w400,
                      color: _isLoading
                          ? IosAppTheme.primaryBlue
                          : CupertinoColors.label,
                    ),
                  ),
                  trailing: _isLoading
                      ? SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: const CupertinoActivityIndicator(),
                        )
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _runFirebaseTests,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: IosAppTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: ResponsiveText(
                              'Quick Test',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                ),
                const IosDivider(margin: EdgeInsets.symmetric(vertical: 8)),
                IosListTile(
                  title: ResponsiveText(
                    'Healthcare Firebase Test',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                      color: IosAppTheme.systemGreen,
                    ),
                  ),
                  subtitle: ResponsiveText(
                    'Comprehensive healthcare data flow validation',
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _navigateToComprehensiveTest(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: IosAppTheme.systemGreen,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: ResponsiveText(
                        'Full Test',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20.h),

            // Firebase project info
            IosSection(
              title: 'Project Information',
              subtitle: 'Current Firebase project configuration',
              children: _firebaseInfo.entries.map((entry) {
                return IosListTile(
                  title: ResponsiveText(
                    _formatKey(entry.key),
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  trailing: Expanded(
                    child: ResponsiveText(
                      entry.value,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: CupertinoColors.secondaryLabel,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 2,
                    ),
                  ),
                );
              }).toList(),
            ),

            if (_testResults.isNotEmpty) ...[
              SizedBox(height: 20.h),

              // Test results
              IosSection(
                title: 'Test Results',
                subtitle: 'Detailed Firebase test output',
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: CupertinoColors.tertiarySystemFill,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _testResults.map((result) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          child: ResponsiveText(
                            result,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontFamily: 'monospace',
                              color: _getResultColor(result),
                            ),
                            maxLines: 3,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: 20.h),

            // Connection status
            Consumer<EnhancedConnectionProvider>(
              builder: (context, connectionProvider, child) {
                return IosSection(
                  title: 'Network Status',
                  subtitle: 'Current connection and sync information',
                  children: [
                    IosListTile(
                      leading: Icon(
                        connectionProvider.isOnline
                            ? CupertinoIcons.wifi
                            : CupertinoIcons.wifi_slash,
                        color: connectionProvider.isOnline
                            ? IosAppTheme.systemGreen
                            : IosAppTheme.systemRed,
                        size: 24.sp,
                      ),
                      title: ResponsiveText(
                        connectionProvider.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: ResponsiveText(
                        connectionProvider.isOnline
                            ? 'Connected to internet'
                            : 'No internet connection',
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ),
                    if (connectionProvider.pendingSyncCount > 0) ...[
                      const IosDivider(),
                      IosListTile(
                        leading: Icon(
                          CupertinoIcons.clock,
                          color: IosAppTheme.systemOrange,
                          size: 24.sp,
                        ),
                        title: ResponsiveText(
                          'Pending Sync',
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        trailing: ResponsiveText(
                          '${connectionProvider.pendingSyncCount} items',
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: IosAppTheme.systemOrange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

            SizedBox(height: 40.h),

            // Actions
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  IosButton(
                    text: 'Refresh Information',
                    onPressed: () {
                      _loadFirebaseInfo();
                      setState(() {
                        _testResults.clear();
                        _testStatus = 'Information refreshed';
                      });
                    },
                    backgroundColor: IosAppTheme.primaryBlue,
                    width: double.infinity,
                  ),
                  SizedBox(height: 12.h),
                  IosButton(
                    text: 'Clear Test Results',
                    onPressed: _testResults.isNotEmpty
                        ? () {
                            setState(() {
                              _testResults.clear();
                              _testStatus = 'Ready to test';
                            });
                          }
                        : null,
                    backgroundColor: IosAppTheme.systemGray,
                    textColor: Colors.white,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAll(RegExp(r'([A-Z])'), ' \$1')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ')
        .trim();
  }

  Color _getResultColor(String result) {
    if (result.contains('✅')) {
      return IosAppTheme.systemGreen;
    } else if (result.contains('❌')) {
      return IosAppTheme.systemRed;
    } else if (result.contains('⚠️')) {
      return IosAppTheme.systemOrange;
    } else if (result.contains('🔄')) {
      return IosAppTheme.primaryBlue;
    }
    return CupertinoColors.label;
  }

  void _navigateToComprehensiveTest(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Comprehensive Tests'),
        content: const Text('Detailed Firebase test suite coming soon'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}