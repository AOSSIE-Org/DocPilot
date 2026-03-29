import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

// Core services
import 'core/cache/cache_manager.dart';
import 'core/storage/local_storage_service.dart';
import 'core/providers/enhanced_connection_provider.dart';
import 'core/providers/patient_provider.dart';
import 'core/providers/clinical_notes_provider.dart';

// Firebase services
import 'services/firebase/firebase_bootstrap_service.dart';
import 'services/firebase/notification_service.dart';

// Theme and UI
import 'theme/app_theme.dart';
import 'screens/auth/auth_gate_screen.dart';

/// Main entry point with complete app initialization
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Load environment variables
  try {
    await dotenv.load();
  } catch (_) {
    debugPrint('[Main] No .env file found, using defaults');
  }

  // Initialize core services
  await _initializeCoreServices();

  // Initialize Firebase services
  await _initializeFirebaseServices();

  // Run the app
  runApp(const DocPilotApp());
}

/// Initialize core app services
Future<void> _initializeCoreServices() async {
  try {
    // Initialize cache manager
    await CacheManager().initialize();
    debugPrint('[Main] Cache manager initialized');

    // Initialize local storage
    await LocalStorageService().initialize();
    debugPrint('[Main] Local storage initialized');
  } catch (e) {
    debugPrint('[Main] Core services initialization failed: $e');
  }
}

/// Initialize Firebase services with enhanced configuration
Future<void> _initializeFirebaseServices() async {
  try {
    // Initialize Firebase using the bootstrap service for consistency
    await FirebaseBootstrapService.initialize();

    if (FirebaseBootstrapService.isInitialized) {
      debugPrint('[Main] ✅ Firebase initialized successfully');

      // Initialize notifications if Firebase is available
      await NotificationService().initialize();
      debugPrint('[Main] ✅ Notification service initialized');
    } else {
      debugPrint('[Main] ⚠️ Firebase not available - running in offline mode');
    }
  } catch (e) {
    debugPrint('[Main] ❌ Firebase services initialization failed: $e');
    // App continues in offline mode
  }
}

/// Main DocPilot application with Material Design
class DocPilotApp extends StatelessWidget {
  const DocPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      useInheritedMediaQuery: true,
      builder: (context, child) {
        return MultiProvider(
          providers: [
            // Connection and sync management
            ChangeNotifierProvider<EnhancedConnectionProvider>(
              create: (_) => EnhancedConnectionProvider()..initialize(),
              lazy: false,
            ),
            // Data providers
            ChangeNotifierProvider<PatientProvider>(
              create: (_) => PatientProvider(),
            ),
            ChangeNotifierProvider<ClinicalNotesProvider>(
              create: (_) => ClinicalNotesProvider(),
            ),
          ],
          child: ScaffoldMessenger(
            child: MaterialApp(
              title: 'DocPilot',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppTheme.primaryColor,
                  brightness: Brightness.light,
                ),
                scaffoldBackgroundColor: AppTheme.backgroundColor,
              ),
              home: const AuthGateScreen(),
              builder: (context, widget) {
                ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
                  return Scaffold(
                    backgroundColor: AppTheme.backgroundColor,
                    body: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64.sp,
                              color: Colors.red,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'Something went wrong',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'We\'re working to fix this issue. Please restart the app.',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                };
                return widget ?? Container();
              },
              supportedLocales: const [
                Locale('en', 'US'),
              ],
            ),
          ),
        );
      },
    );
  }
}
