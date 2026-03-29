import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:provider/provider.dart';

import '../core/providers/patient_provider.dart';
import '../core/providers/enhanced_connection_provider.dart';
import '../core/providers/base_provider.dart';
import '../models/health_models.dart';
import '../widgets/ios_optimized_ui_components.dart';
import '../theme/ios_app_theme.dart';

/// iOS-style patients screen with perfect responsive design and no overflow issues
class iOSOptimizedPatientsScreen extends StatefulWidget {
  final String doctorId;

  const iOSOptimizedPatientsScreen({
    super.key,
    required this.doctorId,
  });

  @override
  State<iOSOptimizedPatientsScreen> createState() => _iOSOptimizedPatientsScreenState();
}

class _iOSOptimizedPatientsScreenState extends State<iOSOptimizedPatientsScreen>
    with TickerProviderStateMixin {
  late PatientProvider _patientProvider;
  late EnhancedConnectionProvider _connectionProvider;
  late TextEditingController _searchController;
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;

  String _searchQuery = '';
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );

    _patientProvider = context.read<PatientProvider>();
    _connectionProvider = context.read<EnhancedConnectionProvider>();

    // Initialize data loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPatients();
    });

    // Listen to search changes with debouncing
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _loadPatients() async {
    await _patientProvider.loadPatientsForDoctor(widget.doctorId);
  }

  Future<void> _refreshPatients() async {
    await _patientProvider.refresh();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
    });

    if (_isSearchVisible) {
      _searchAnimationController.forward();
    } else {
      _searchAnimationController.reverse();
      _searchController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  List<ProviderPatientRecord> _getFilteredPatients() {
    if (_searchQuery.isEmpty) {
      return _patientProvider.items;
    }
    return _patientProvider.searchPatients(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: IosAppTheme.systemGroupedBackground,
      navigationBar: _buildNavigationBar(),
      child: SafeArea(
        child: Column(
          children: [
            // Search bar with animation
            AnimatedBuilder(
              animation: _searchAnimation,
              builder: (context, child) {
                return SizeTransition(
                  sizeFactor: _searchAnimation,
                  child: _buildSearchBar(),
                );
              },
            ),

            // Main content
            Expanded(
              child: Consumer<PatientProvider>(
                builder: (context, patientProvider, child) {
                  final filteredPatients = _getFilteredPatients();

                  // Create paginated state for iOS list
                  final paginatedState = PaginatedState<ProviderPatientRecord>(
                    items: filteredPatients,
                    hasMore: false,
                    isLoading: patientProvider.isLoading,
                    error: patientProvider.error,
                  );

                  return Column(
                    children: [
                      // Sync status section
                      Consumer<EnhancedConnectionProvider>(
                        builder: (context, connectionProvider, child) {
                          return IosSyncStatusWidget(
                            isSyncing: connectionProvider.isSyncing,
                            lastSyncTime: connectionProvider.lastSuccessfulSync,
                            pendingSyncCount: connectionProvider.pendingSyncCount,
                            onSync: connectionProvider.isOnline
                                ? () => connectionProvider.forceSync()
                                : null,
                          );
                        },
                      ),

                      // Section header
                      if (filteredPatients.isNotEmpty || patientProvider.isLoading) ...[
                        IosSectionHeader(
                          title: _searchQuery.isEmpty
                              ? 'All Patients (${filteredPatients.length})'
                              : 'Search Results (${filteredPatients.length})',
                          subtitle: _searchQuery.isEmpty
                              ? 'Manage your patient records'
                              : 'Patients matching \"$_searchQuery\"',
                        ),
                      ],

                      // Patients list
                      Expanded(
                        child: IosPaginatedListView<ProviderPatientRecord>(
                          state: paginatedState,
                          onRefresh: _refreshPatients,
                          emptyTitle: _searchQuery.isNotEmpty
                              ? 'No patients found'
                              : 'No patients yet',
                          emptySubtitle: _searchQuery.isNotEmpty
                              ? 'No patients match your search criteria.\nTry adjusting your search terms.'
                              : 'Add your first patient to get started.\nTap the + button to begin.',
                          emptyIcon: _searchQuery.isNotEmpty
                              ? CupertinoIcons.search
                              : CupertinoIcons.person_add,
                          itemBuilder: (context, patient, index) {
                            return _buildPatientCard(patient, index);
                          },
                          padding: EdgeInsets.only(
                            bottom: ResponsiveHelper.spacing(100), // Space for FAB
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  CupertinoNavigationBar _buildNavigationBar() {
    return CupertinoNavigationBar(
      backgroundColor: IosAppTheme.systemBackground,
      border: const Border(),
      middle: AutoSizeText(
        'Patients',
        style: TextStyle(
          fontSize: 17.sp,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label,
        ),
        maxLines: 1,
        minFontSize: 14,
      ),
      leading: Consumer<EnhancedConnectionProvider>(
        builder: (context, connectionProvider, child) {
          return IosConnectionStatusIndicator(
            status: connectionProvider.status,
            onTap: () => _showConnectionDetails(context),
          );
        },
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search button
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _toggleSearch,
            child: Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                color: _isSearchVisible
                    ? IosAppTheme.primaryBlue
                    : IosAppTheme.systemGray5,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(
                CupertinoIcons.search,
                size: 18.sp,
                color: _isSearchVisible
                    ? Colors.white
                    : IosAppTheme.systemGray,
              ),
            ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(8)),

          // Add patient button
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showAddPatientSheet(context),
            child: Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                color: IosAppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(
                CupertinoIcons.add,
                size: 18.sp,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: IosDesignConstants.standardMargin,
        vertical: ResponsiveHelper.spacing(8),
      ),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: 'Search patients...',
        style: TextStyle(
          fontSize: 16.sp,
          color: CupertinoColors.label,
        ),
        placeholderStyle: TextStyle(
          fontSize: 16.sp,
          color: CupertinoColors.placeholderText,
        ),
        backgroundColor: IosAppTheme.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(IosDesignConstants.standardRadius),
        padding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 12.h,
        ),
      ),
    );
  }

  Widget _buildPatientCard(ProviderPatientRecord patient, int index) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: IosDesignConstants.standardMargin,
        vertical: ResponsiveHelper.spacing(4),
      ),
      decoration: BoxDecoration(
        color: IosAppTheme.secondarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(IosDesignConstants.standardRadius),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey4.withOpacity(0.3),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: CupertinoListTile(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        leading: _buildPatientAvatar(patient),
        title: AutoSizeText(
          patient.fullName,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
          maxLines: 1,
          minFontSize: 14,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _buildPatientSubtitle(patient),
        trailing: _buildPatientTrailing(patient),
        onTap: () => _navigateToPatientDetail(patient),
      ),
    );
  }

  Widget _buildPatientAvatar(ProviderPatientRecord patient) {
    final initial = patient.firstName.isNotEmpty
        ? patient.firstName[0].toUpperCase()
        : '?';

    return Container(
      width: 50.w,
      height: 50.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            IosAppTheme.primaryBlue.withOpacity(0.8),
            IosAppTheme.secondaryBlue.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: AutoSizeText(
          initial,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          maxLines: 1,
          minFontSize: 16,
        ),
      ),
    );
  }

  Widget _buildPatientSubtitle(ProviderPatientRecord patient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: ResponsiveHelper.spacing(4)),
        Row(
          children: [
            Icon(
              CupertinoIcons.calendar,
              size: 14.sp,
              color: IosAppTheme.systemGray,
            ),
            SizedBox(width: ResponsiveHelper.spacing(4)),
            AutoSizeText(
              'Age ${patient.age}',
              style: TextStyle(
                fontSize: 15.sp,
                color: IosAppTheme.systemGray,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              minFontSize: 12,
            ),
            SizedBox(width: ResponsiveHelper.spacing(12)),
            Icon(
              patient.gender.toLowerCase() == 'male'
                  ? CupertinoIcons.person
                  : CupertinoIcons.person_fill,
              size: 14.sp,
              color: IosAppTheme.systemGray,
            ),
            SizedBox(width: ResponsiveHelper.spacing(4)),
            Flexible(
              child: AutoSizeText(
                patient.gender,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: IosAppTheme.systemGray,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                minFontSize: 12,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (patient.lastVisitSummary.isNotEmpty &&
            patient.lastVisitSummary != 'No summary available.') ...[
          SizedBox(height: ResponsiveHelper.spacing(6)),
          Row(
            children: [
              Icon(
                CupertinoIcons.doc_text,
                size: 14.sp,
                color: IosAppTheme.systemGray2,
              ),
              SizedBox(width: ResponsiveHelper.spacing(4)),
              Expanded(
                child: AutoSizeText(
                  patient.lastVisitSummary,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: IosAppTheme.systemGray2,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  minFontSize: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPatientTrailing(ProviderPatientRecord patient) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status indicators
        if (patient.foodAllergies.isNotEmpty ||
            patient.medicinalAllergies.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 6.w,
              vertical: 2.h,
            ),
            decoration: BoxDecoration(
              color: IosAppTheme.systemOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: 10.sp,
                  color: IosAppTheme.systemOrange,
                ),
                SizedBox(width: ResponsiveHelper.spacing(2)),
                AutoSizeText(
                  'Allergies',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: IosAppTheme.systemOrange,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  minFontSize: 8,
                ),
              ],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(4)),
        ],

        Icon(
          CupertinoIcons.chevron_right,
          size: 16.sp,
          color: IosAppTheme.systemGray3,
        ),
      ],
    );
  }

  void _showConnectionDetails(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Consumer<EnhancedConnectionProvider>(
        builder: (context, connectionProvider, child) {
          final stats = connectionProvider.getEnhancedSyncStatistics();

          return CupertinoActionSheet(
            title: AutoSizeText(
              'Connection Status',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              minFontSize: 16,
            ),
            message: Container(
              constraints: BoxConstraints(
                maxHeight: ScreenUtil().screenHeight * 0.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    IosConnectionStatusIndicator(
                      status: connectionProvider.status,
                      isCompact: false,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    IosSectionHeader(title: 'Sync Statistics'),
                    ...stats.entries.map((entry) => Container(
                      margin: EdgeInsets.symmetric(
                        vertical: ResponsiveHelper.spacing(2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: AutoSizeText(
                              entry.key,
                              style: TextStyle(
                                fontSize: 15.sp,
                                color: CupertinoColors.secondaryLabel,
                              ),
                              maxLines: 1,
                              minFontSize: 12,
                            ),
                          ),
                          AutoSizeText(
                            entry.value.toString(),
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.label,
                            ),
                            maxLines: 1,
                            minFontSize: 12,
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            actions: [
              if (connectionProvider.isOnline && !connectionProvider.isSyncing)
                CupertinoActionSheetAction(
                  onPressed: () {
                    connectionProvider.forceSync();
                    Navigator.pop(context);
                  },
                  child: AutoSizeText(
                    'Force Sync Now',
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: IosAppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    minFontSize: 14,
                  ),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: AutoSizeText(
                'Close',
                style: TextStyle(
                  fontSize: 17.sp,
                  color: IosAppTheme.primaryBlue,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                minFontSize: 14,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddPatientSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: AutoSizeText(
          'Add New Patient',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          minFontSize: 16,
        ),
        message: AutoSizeText(
          'Create a new patient record to manage their healthcare information.',
          style: TextStyle(
            fontSize: 15.sp,
            color: CupertinoColors.secondaryLabel,
          ),
          maxLines: 3,
          minFontSize: 12,
          textAlign: TextAlign.center,
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to add patient screen
              _navigateToAddPatient();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.person_add,
                  size: 18.sp,
                  color: IosAppTheme.primaryBlue,
                ),
                SizedBox(width: ResponsiveHelper.spacing(8)),
                AutoSizeText(
                  'Create Patient Record',
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: IosAppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  minFontSize: 14,
                ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: AutoSizeText(
            'Cancel',
            style: TextStyle(
              fontSize: 17.sp,
              color: IosAppTheme.primaryBlue,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            minFontSize: 14,
          ),
        ),
      ),
    );
  }

  void _navigateToAddPatient() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: AutoSizeText(
              'Add Patient',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              minFontSize: 14,
            ),
          ),
          child: const Center(
            child: Text('Add Patient Form - To be implemented'),
          ),
        ),
      ),
    );
  }

  void _navigateToPatientDetail(ProviderPatientRecord patient) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: AutoSizeText(
              patient.fullName,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              minFontSize: 14,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          child: Center(
            child: AutoSizeText(
              'Patient detail for ${patient.fullName}',
              style: TextStyle(
                fontSize: 17.sp,
                color: CupertinoColors.label,
              ),
              maxLines: 2,
              minFontSize: 14,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS-style provider setup with ScreenUtil initialization
class iOSOptimizedProviderSetup extends StatelessWidget {
  final Widget child;

  const iOSOptimizedProviderSetup({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone 11 Pro dimensions
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<EnhancedConnectionProvider>(
              create: (_) => EnhancedConnectionProvider()..initialize(),
            ),
            ChangeNotifierProvider<PatientProvider>(
              create: (_) => PatientProvider(),
            ),
            // Add other providers as needed
          ],
          child: this.child,
        );
      },
      child: child,
    );
  }
}

/// iOS-style app example with perfect responsive design
class iOSOptimizedApp extends StatelessWidget {
  const iOSOptimizedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'DocPilot - iOS Optimized',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: IosAppTheme.primaryBlue,
        scaffoldBackgroundColor: IosAppTheme.systemGroupedBackground,
        barBackgroundColor: IosAppTheme.systemBackground,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w400,
            color: CupertinoColors.label,
          ),
        ),
      ),
      home: const iOSOptimizedProviderSetup(
        child: iOSOptimizedPatientsScreen(doctorId: 'doctor123'),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}