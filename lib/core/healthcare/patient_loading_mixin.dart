import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/health_models.dart';
import 'healthcare_services_manager.dart';

/// Mixin that provides shared patient loading functionality
/// Eliminates duplicate patient loading patterns across healthcare screens
mixin PatientLoadingMixin<T extends StatefulWidget> on State<T> {
  ProviderPatientRecord? _patient;
  List<ProviderPatientRecord> _patientsCache = const [];
  StreamSubscription<List<ProviderPatientRecord>>? _patientsSubscription;

  final HealthcareServicesManager _services = HealthcareServicesManager();

  /// Current loaded patient
  ProviderPatientRecord? get patient => _patient;

  /// Cached list of all patients for the current doctor
  List<ProviderPatientRecord> get patientsCache => _patientsCache;

  /// Load patient data by ID
  Future<void> loadPatientData(String patientId) async {
    final loadedPatient = await _services.loadPatient(patientId);
    if (mounted) {
      setState(() => _patient = loadedPatient);
    }
  }

  /// Set patient directly (useful for patient selection)
  void setPatient(ProviderPatientRecord? patient) {
    if (mounted) {
      setState(() => _patient = patient);
    }
  }

  /// Start watching all patients for the current doctor
  /// Useful for patient selection lists and real-time updates
  void startWatchingPatients() {
    final doctorId = _services.currentDoctorId;
    if (doctorId.isEmpty) return;

    _patientsSubscription?.cancel();
    _patientsSubscription = _services.firestore
        .watchDoctorPatients(doctorId)
        .listen(
      (patients) {
        if (!mounted) return;
        setState(() {
          _patientsCache = patients;

          // Auto-select first patient if none selected and patients available
          if (_patient == null && patients.isNotEmpty) {
            _patient = patients.first;
          }
        });
      },
      onError: (error) {
        // Handle error silently or log it
        debugPrint('Error watching patients: $error');
      },
    );
  }

  /// Stop watching patients (call in dispose)
  void stopWatchingPatients() {
    _patientsSubscription?.cancel();
    _patientsSubscription = null;
  }

  /// Find patient by ID from cache
  ProviderPatientRecord? findPatientById(String patientId) {
    if (patientId.isEmpty) return null;

    try {
      return _patientsCache.firstWhere((p) => p.id == patientId);
    } catch (e) {
      return null;
    }
  }

  /// Show patient selection bottom sheet
  Future<ProviderPatientRecord?> showPatientSelector({
    String title = 'Select Patient',
    String searchHint = 'Search patient by name',
  }) async {
    if (_patientsCache.isEmpty) {
      return null;
    }

    return showModalBottomSheet<ProviderPatientRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PatientSelectorSheet(
        patients: _patientsCache,
        title: title,
        searchHint: searchHint,
      ),
    );
  }

  /// Build patient context widget for display
  Widget buildPatientContextWidget({
    VoidCallback? onTap,
    VoidCallback? onAdd,
    String emptyText = 'No patient selected',
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(
            _patientsCache.isEmpty ? Icons.info_outline : Icons.person_search,
            color: _patientsCache.isEmpty ? Colors.grey : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: _patientsCache.isNotEmpty ? onTap : null,
              child: Text(
                _patient?.fullName ??
                (_patientsCache.isEmpty ? emptyText : 'Select patient (optional)'),
                style: TextStyle(
                  color: _patientsCache.isEmpty ? Colors.grey : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (_patientsCache.isNotEmpty)
            const Icon(Icons.expand_more),
          if (onAdd != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Add patient',
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    stopWatchingPatients();
    super.dispose();
  }
}

/// Internal widget for patient selection sheet
class _PatientSelectorSheet extends StatefulWidget {
  final List<ProviderPatientRecord> patients;
  final String title;
  final String searchHint;

  const _PatientSelectorSheet({
    required this.patients,
    required this.title,
    required this.searchHint,
  });

  @override
  State<_PatientSelectorSheet> createState() => _PatientSelectorSheetState();
}

class _PatientSelectorSheetState extends State<_PatientSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<ProviderPatientRecord> _filteredPatients = [];

  @override
  void initState() {
    super.initState();
    _filteredPatients = widget.patients;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterPatients(String query) {
    final normalized = query.trim().toLowerCase();
    setState(() {
      _filteredPatients = widget.patients
          .where((patient) =>
              patient.fullName.toLowerCase().contains(normalized))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _filterPatients,
            ),
            const SizedBox(height: 16),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _filteredPatients.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final patient = _filteredPatients[index];
                  return ListTile(
                    title: Text(patient.fullName),
                    subtitle: Text(
                      patient.lastVisitSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(context, patient),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}