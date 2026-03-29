import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/patient_provider.dart';
import '../core/providers/enhanced_connection_provider.dart';
import '../core/providers/base_provider.dart';
import '../models/health_models.dart';
import '../widgets/optimized_ui_components.dart';

/// Example screen demonstrating optimized dataflow with all new components
class OptimizedPatientsScreen extends StatefulWidget {
  final String doctorId;

  const OptimizedPatientsScreen({
    super.key,
    required this.doctorId,
  });

  @override
  State<OptimizedPatientsScreen> createState() => _OptimizedPatientsScreenState();
}

class _OptimizedPatientsScreenState extends State<OptimizedPatientsScreen> {
  late PatientProvider _patientProvider;
  late EnhancedConnectionProvider _connectionProvider;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _patientProvider = context.read<PatientProvider>();
    _connectionProvider = context.read<EnhancedConnectionProvider>();

    // Initialize data loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPatients();
    });

    // Listen to search changes
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    await _patientProvider.loadPatientsForDoctor(widget.doctorId);
  }

  Future<void> _refreshPatients() async {
    await _patientProvider.refresh();
  }

  List<ProviderPatientRecord> _getFilteredPatients() {
    if (_searchQuery.isEmpty) {
      return _patientProvider.items;
    }
    return _patientProvider.searchPatients(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Patients'),
        actions: [
          // Connection status indicator
          Consumer<EnhancedConnectionProvider>(
            builder: (context, connectionProvider, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ConnectionStatusIndicator(
                  status: connectionProvider.status,
                  onTap: () => _showConnectionDetails(context),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patients...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
      ),
      body: Consumer<PatientProvider>(
        builder: (context, patientProvider, child) {
          // Get filtered patients based on search
          final filteredPatients = _getFilteredPatients();

          // Create a mock paginated state for demonstration
          final paginatedState = PaginatedState<ProviderPatientRecord>(
            items: filteredPatients,
            hasMore: false, // For this example, no pagination
            isLoading: patientProvider.isLoading,
            error: patientProvider.error,
          );

          return Column(
            children: [
              // Sync status header
              Consumer<EnhancedConnectionProvider>(
                builder: (context, connectionProvider, child) {
                  return SyncStatusWidget(
                    isSyncing: connectionProvider.isSyncing,
                    lastSyncTime: connectionProvider.lastSuccessfulSync,
                    pendingSyncCount: connectionProvider.pendingSyncCount,
                    onSync: connectionProvider.isOnline
                        ? () => connectionProvider.forceSync()
                        : null,
                  );
                },
              ),

              // Patients list
              Expanded(
                child: PaginatedListView<ProviderPatientRecord>(
                  state: paginatedState,
                  onRefresh: _refreshPatients,
                  emptyTitle: _searchQuery.isNotEmpty
                      ? 'No patients found'
                      : 'No patients yet',
                  emptySubtitle: _searchQuery.isNotEmpty
                      ? 'No patients match your search criteria.'
                      : 'Add your first patient to get started.',
                  itemBuilder: (context, patient, index) {
                    return _buildPatientCard(patient);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPatientDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPatientCard(ProviderPatientRecord patient) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(
            patient.firstName.isNotEmpty ? patient.firstName[0].toUpperCase() : '?',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          patient.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Age: ${patient.age} • ${patient.gender}'),
            if (patient.lastVisitSummary.isNotEmpty &&
                patient.lastVisitSummary != 'No summary available.') ...[
              const SizedBox(height: 4),
              Text(
                patient.lastVisitSummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicators
            if (patient.foodAllergies.isNotEmpty || patient.medicinalAllergies.isNotEmpty)
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 16,
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _navigateToPatientDetail(patient),
      ),
    );
  }

  void _showConnectionDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer<EnhancedConnectionProvider>(
        builder: (context, connectionProvider, child) {
          final stats = connectionProvider.getEnhancedSyncStatistics();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ConnectionStatusIndicator(
                  status: connectionProvider.status,
                  isCompact: false,
                ),
                const Divider(),
                Text(
                  'Sync Statistics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...stats.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: connectionProvider.isOnline && !connectionProvider.isSyncing
                        ? () {
                            connectionProvider.forceSync();
                            Navigator.pop(context);
                          }
                        : null,
                    child: Text(
                      connectionProvider.isSyncing
                          ? 'Syncing...'
                          : connectionProvider.isOnline
                              ? 'Force Sync Now'
                              : 'Offline - Cannot Sync',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddPatientDialog(BuildContext context) {
    // Implement add patient dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Patient'),
        content: const Text('Patient creation form would go here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement patient creation
              Navigator.pop(context);
            },
            child: const Text('Add Patient'),
          ),
        ],
      ),
    );
  }

  void _navigateToPatientDetail(ProviderPatientRecord patient) {
    // Implement navigation to patient detail
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(patient.fullName),
          ),
          body: Center(
            child: Text('Patient detail for ${patient.fullName}'),
          ),
        ),
      ),
    );
  }
}

/// Provider setup example for the app
class OptimizedProviderSetup extends StatelessWidget {
  final Widget child;

  const OptimizedProviderSetup({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
      child: child,
    );
  }
}

/// Example of how to use the optimized screen
class ExampleUsage extends StatelessWidget {
  const ExampleUsage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocPilot - Optimized',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const OptimizedProviderSetup(
        child: OptimizedPatientsScreen(doctorId: 'doctor123'),
      ),
    );
  }
}