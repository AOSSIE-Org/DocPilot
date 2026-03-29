import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../core/providers/patient_provider.dart';
import '../core/providers/enhanced_connection_provider.dart';
import '../core/providers/base_provider.dart';
import '../models/health_models.dart';
import '../widgets/ios_optimized_ui_components.dart';
import '../widgets/ios_responsive_components.dart';
import '../theme/ios_app_theme.dart';

/// Perfect iOS-style patients screen with no overflow issues
class PerfectiOSPatientsScreen extends StatefulWidget {
  final String doctorId;

  const PerfectiOSPatientsScreen({
    super.key,
    required this.doctorId,
  });

  @override
  State<PerfectiOSPatientsScreen> createState() => _PerfectiOSPatientsScreenState();
}

class _PerfectiOSPatientsScreenState extends State<PerfectiOSPatientsScreen>
    with TickerProviderStateMixin {
  late PatientProvider _patientProvider;
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

    // Initialize data loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPatients();
    });

    // Listen to search changes
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
                        IosSection(
                          title: _searchQuery.isEmpty
                              ? 'All Patients (${filteredPatients.length})'
                              : 'Search Results (${filteredPatients.length})',
                          subtitle: _searchQuery.isEmpty
                              ? 'Manage your patient records'
                              : 'Patients matching \"$_searchQuery\"',
                          children: const [],
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
                            bottom: ResponsiveHelper.spacing(20),
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
      middle: ResponsiveText(
        'Patients',
        style: TextStyle(
          fontSize: 17.sp,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label,
        ),
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
          SizedBox(width: 8.w),

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
      margin: EdgeInsets.all(16.w),
      child: IosSearchTextField(
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
        borderRadius: BorderRadius.circular(10.r),
        padding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 12.h,
        ),
      ),
    );
  }

  Widget _buildPatientCard(ProviderPatientRecord patient, int index) {
    return IosCard(
      margin: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 4.h,
      ),
      onTap: () => _navigateToPatientDetail(patient),
      child: IosListTile(
        leading: _buildPatientAvatar(patient),
        title: ResponsiveText(
          patient.fullName,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
          maxWidth: ResponsiveLayout.getMaxTextWidth(context, containerWidth: 200.w),
        ),
        subtitle: _buildPatientSubtitle(patient),
        trailing: _buildPatientTrailing(patient),
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
            IosAppTheme.primaryBlue.withValues(alpha: 0.8),
            IosAppTheme.secondaryBlue.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: ResponsiveText(
          initial,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildPatientSubtitle(ProviderPatientRecord patient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 4.h),
        Row(
          children: [
            Icon(
              CupertinoIcons.calendar,
              size: 14.sp,
              color: IosAppTheme.systemGray,
            ),
            SizedBox(width: 4.w),
            ResponsiveText(
              'Age ${patient.age}',
              style: TextStyle(
                fontSize: 15.sp,
                color: IosAppTheme.systemGray,
                fontWeight: FontWeight.w400,
              ),
              maxWidth: 60.w,
            ),
            SizedBox(width: 12.w),
            Icon(
              patient.gender.toLowerCase() == 'male'
                  ? CupertinoIcons.person
                  : CupertinoIcons.person_fill,
              size: 14.sp,
              color: IosAppTheme.systemGray,
            ),
            SizedBox(width: 4.w),
            Flexible(
              child: ResponsiveText(
                patient.gender,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: IosAppTheme.systemGray,
                  fontWeight: FontWeight.w400,
                ),
                maxWidth: 80.w,
              ),
            ),
          ],
        ),
        if (patient.lastVisitSummary.isNotEmpty &&
            patient.lastVisitSummary != 'No summary available.') ...[
          SizedBox(height: 6.h),
          Row(
            children: [
              Icon(
                CupertinoIcons.doc_text,
                size: 14.sp,
                color: IosAppTheme.systemGray2,
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: ResponsiveText(
                  patient.lastVisitSummary,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: IosAppTheme.systemGray2,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  minFontSize: 10,
                  maxWidth: ResponsiveLayout.getMaxTextWidth(context),
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
          IosBadge(
            text: 'Allergies',
            backgroundColor: IosAppTheme.systemOrange.withValues(alpha: 0.1),
            textColor: IosAppTheme.systemOrange,
            fontSize: 10.sp,
          ),
          SizedBox(height: 4.h),
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
    final connectionProvider = context.read<EnhancedConnectionProvider>();
    final stats = connectionProvider.getEnhancedSyncStatistics();

    IosUtils.showActionSheet(
      context,
      title: 'Connection Status',
      message: 'View detailed connection and sync information',
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            _showDetailedStats(context, stats);
          },
          child: ResponsiveText(
            'View Sync Statistics',
            style: TextStyle(
              fontSize: 17.sp,
              color: IosAppTheme.primaryBlue,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        if (connectionProvider.isOnline && !connectionProvider.isSyncing)
          CupertinoActionSheetAction(
            onPressed: () {
              connectionProvider.forceSync();
              Navigator.pop(context);
            },
            child: ResponsiveText(
              'Force Sync Now',
              style: TextStyle(
                fontSize: 17.sp,
                color: IosAppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: ResponsiveText(
          'Close',
          style: TextStyle(
            fontSize: 17.sp,
            color: IosAppTheme.primaryBlue,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _showDetailedStats(BuildContext context, Map<String, dynamic> stats) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: ScreenUtil().screenHeight * 0.7,
        decoration: BoxDecoration(
          color: IosAppTheme.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: IosAppTheme.systemGray4,
                      width: 0.5.h,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ResponsiveText(
                        'Sync Statistics',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: ResponsiveText(
                        'Done',
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: IosAppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Stats list
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  children: stats.entries.map((entry) {
                    return Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 2.h,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 2,
                            child: ResponsiveText(
                              _formatStatKey(entry.key),
                              style: TextStyle(
                                fontSize: 15.sp,
                                color: CupertinoColors.secondaryLabel,
                              ),
                              maxLines: 2,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: ResponsiveText(
                              entry.value.toString(),
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w500,
                                color: CupertinoColors.label,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatStatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  void _showAddPatientSheet(BuildContext context) {
    IosUtils.showActionSheet(
      context,
      title: 'Add New Patient',
      message: 'Create a new patient record to manage their healthcare information.',
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
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
              SizedBox(width: 8.w),
              ResponsiveText(
                'Create Patient Record',
                style: TextStyle(
                  fontSize: 17.sp,
                  color: IosAppTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: ResponsiveText(
          'Cancel',
          style: TextStyle(
            fontSize: 17.sp,
            color: IosAppTheme.primaryBlue,
            fontWeight: FontWeight.w400,
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
            middle: ResponsiveText(
              'Add Patient',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
              ),
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
            middle: ResponsiveText(
              patient.fullName,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
              ),
              maxWidth: 200.w,
            ),
          ),
          child: Center(
            child: ResponsiveText(
              'Patient detail for ${patient.fullName}',
              style: TextStyle(
                fontSize: 17.sp,
                color: CupertinoColors.label,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// Main app with perfect iOS styling and responsive design
class PerfectiOSApp extends StatelessWidget {
  const PerfectiOSApp({super.key});

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
          ],
          child: CupertinoApp(
            title: 'DocPilot - Perfect iOS',
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
            home: const PerfectiOSPatientsScreen(doctorId: 'doctor123'),
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}