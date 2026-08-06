import 'package:flutter/material.dart';
import 'package:raddmed/Models/PatientModel.dart';
import 'package:raddmed/Repositories/PatientRepository.dart';
import 'package:raddmed/Models/Enums/InstrumentAccess.dart';

import 'package:raddmed/Models/ProcedureModel.dart';
import 'package:raddmed/Repositories/ProcedureRepository.dart';
import 'package:raddmed/Screens/ProcedureHistoryScreen/ProcedureHistoryScreen.dart';
import 'package:raddmed/Widgets/UnifiedHeader.dart';

// --- Main App Entry (For testing) ---
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RADDMED Patients',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        primaryColor: const Color(0xFFE31820),
        fontFamily: 'Segoe UI',
      ),
      home: const PatientsScreen(),
    );
  }
}

// --- Main Screen ---

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  List<PatientModel> _allPatients = [];
  List<PatientModel> _filteredPatients = [];
  String _searchQuery = '';

  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  void _loadPatients() {
    setState(() {
      _allPatients = PatientRepository.getAllPatients();
      _filterPatients();
    });
  }

  void _filterPatients() {
    if (_searchQuery.isEmpty) {
      _filteredPatients = List.from(_allPatients);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredPatients = _allPatients.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.patientId.toLowerCase().contains(q);
      }).toList();
    }
    _currentPage = 1; // Reset to page 1 on filter change
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _filterPatients();
    });
  }

  List<ProcedureModel> _patientProcedures = [];

  // Nullable state: Starts unselected to demonstrate conditional right panel
  PatientModel? _selectedPatient;

  void _showAddPatientDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddPatientDialog(
        onSaved: () {
          _loadPatients();
        },
      ),
    );
  }

  void _onPatientSelected(PatientModel patient) {
    setState(() {
      _selectedPatient = patient;
      _patientProcedures = ProcedureRepository.getProceduresForPatient(
        patient.patientId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          UnifiedHeader(
            title: 'Patients',
            subtitle: 'Manage and view patient information',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1B2332)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Patient List
                  Expanded(
                    flex: 11,
                    child: PatientListPanel(
                      patients: _filteredPatients,
                      selectedPatient: _selectedPatient,
                      onPatientSelected: _onPatientSelected,
                      onAddPatient: _showAddPatientDialog,
                      onSearchChanged: _onSearchChanged,
                      currentPage: _currentPage,
                      itemsPerPage: _itemsPerPage,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right Side: Details View (Conditional rendering)
                  Expanded(
                    flex: 13,
                    child: _selectedPatient == null
                        ? const _EmptySelectionPlaceholder()
                        : PatientDetailPanel(
                            patient: _selectedPatient!,
                            logs: _patientProcedures,
                            onEditPatient: () {
                              showDialog(
                                context: context,
                                builder: (context) => _AddPatientDialog(
                                  patient: _selectedPatient,
                                  onSaved: () {
                                    _loadPatients();
                                    // Refresh selected patient
                                    setState(() {
                                      _selectedPatient =
                                          PatientRepository.getAllPatients()
                                              .firstWhere(
                                                (p) =>
                                                    p.id ==
                                                    _selectedPatient!.id,
                                              );
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const _Footer(),
        ],
      ),
    );
  }
}

// --- Separated Components for Professional Structure ---

class PatientListPanel extends StatelessWidget {
  final List<PatientModel> patients;
  final PatientModel? selectedPatient;
  final ValueChanged<PatientModel> onPatientSelected;
  final VoidCallback onAddPatient;
  final ValueChanged<String> onSearchChanged;
  final int currentPage;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;

  const PatientListPanel({
    super.key,
    required this.patients,
    required this.selectedPatient,
    required this.onPatientSelected,
    required this.onAddPatient,
    required this.onSearchChanged,
    required this.currentPage,
    required this.itemsPerPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // List Header & Controls
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Patient List',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search patients by name or ID...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: onAddPatient,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add Patient',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE31820),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Patient ID',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Patient Name',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Age / Gender',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Phone',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Last Procedure',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 24), // Chevron space
              ],
            ),
          ),

          // List Data
          Expanded(
            child: Builder(
              builder: (context) {
                final startIndex = (currentPage - 1) * itemsPerPage;
                final endIndex = (startIndex + itemsPerPage > patients.length)
                    ? patients.length
                    : startIndex + itemsPerPage;
                final currentPatients = patients.sublist(startIndex, endIndex);

                return ListView.builder(
                  itemCount: currentPatients.length,
                  itemBuilder: (context, index) {
                    final patient = currentPatients[index];
                    final isSelected = selectedPatient?.id == patient.id;

                    return InkWell(
                      onTap: () => onPatientSelected(patient),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE31820).withOpacity(0.05)
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade100),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                patient.patientId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                patient.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${patient.age} / ${patient.gender}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                patient.contactNumber,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                patient.lastProcedureDate.isEmpty
                                    ? 'N/A'
                                    : patient.lastProcedureDate,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: isSelected
                                  ? const Color(0xFFE31820)
                                  : Colors.grey.shade400,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Pagination Footer
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Builder(
              builder: (context) {
                final int totalPages = (patients.length / itemsPerPage).ceil();
                final int displayStart = patients.isEmpty
                    ? 0
                    : ((currentPage - 1) * itemsPerPage) + 1;
                final int displayEnd =
                    (currentPage * itemsPerPage > patients.length)
                    ? patients.length
                    : currentPage * itemsPerPage;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing $displayStart to $displayEnd of ${patients.length} patients',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                    Row(
                      children: [
                        if (currentPage > 1)
                          InkWell(
                            onTap: () => onPageChanged(currentPage - 1),
                            child: _buildPageButton(
                              '<',
                              isIcon: true,
                              icon: Icons.chevron_left,
                            ),
                          ),
                        const SizedBox(width: 8),
                        ...List.generate(totalPages, (i) {
                          int pageNum = i + 1;
                          // simple pagination logic to show max 5 buttons could be added, showing all for now
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () => onPageChanged(pageNum),
                              child: _buildPageButton(
                                pageNum.toString(),
                                isActive: pageNum == currentPage,
                              ),
                            ),
                          );
                        }),
                        if (currentPage < totalPages)
                          InkWell(
                            onTap: () => onPageChanged(currentPage + 1),
                            child: _buildPageButton(
                              '>',
                              isIcon: true,
                              icon: Icons.chevron_right,
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton(
    String text, {
    bool isActive = false,
    bool isIcon = false,
    IconData icon = Icons.chevron_right,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFE31820).withOpacity(0.1)
            : Colors.white,
        border: Border.all(
          color: isActive ? const Color(0xFFE31820) : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: isIcon
          ? Icon(icon, size: 16, color: Colors.grey.shade600)
          : Text(
              text,
              style: TextStyle(
                color: isActive
                    ? const Color(0xFFE31820)
                    : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
    );
  }
}

class PatientDetailPanel extends StatelessWidget {
  final PatientModel patient;
  final List<ProcedureModel> logs;
  final VoidCallback onEditPatient;

  const PatientDetailPanel({
    super.key,
    required this.patient,
    required this.logs,
    required this.onEditPatient,
  });

  @override
  Widget build(BuildContext context) {
    // Wrapped entirely in a SingleChildScrollView to make it fully scrollable
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary Details Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header Section
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.blueGrey.shade100,
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  patient.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    patient.patientId,
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${patient.age} / ${patient.gender}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 16,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  patient.contactNumber,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: onEditPatient,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE31820)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Edit Patient',
                          style: TextStyle(color: Color(0xFFE31820)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider replacing the tabs
                Divider(height: 1, color: Colors.grey.shade200),

                // Detailed Information Grid
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildDetailRow('Patient ID', patient.patientId),
                            const SizedBox(height: 20),
                            _buildDetailRow('Age', patient.age),
                            const SizedBox(height: 20),
                            _buildDetailRow('Gender', patient.gender),
                            const SizedBox(height: 20),
                            _buildDetailRow('Address', patient.address),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _buildDetailRow(
                              'Primary Doctor',
                              patient.consultingDoctor,
                            ),
                            const SizedBox(height: 20),
                            _buildDetailRow('Diagnosis', patient.diagnosisArea),
                            const SizedBox(height: 20),
                            _buildDetailRow('Notes', patient.note),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Ablation History Logs Card (Now scrolls with the rest of the view)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Ablation History Logs',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Procedure Date',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Ablation Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Time',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Staff Attended',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // Expanded(
                      //   flex: 1,
                      //   child: Text(
                      //     'Status',
                      //     style: TextStyle(
                      //       fontWeight: FontWeight.bold,
                      //       fontSize: 12,
                      //     ),
                      //   ),
                      // ),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Text(
                            'Action',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Render list directly in column instead of expanding a ListView to allow parent scrolling
                ...logs.map((log) => _buildLogRow(log, context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogRow(ProcedureModel log, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              log.startTime.split('T')[0], // Just date if ISO string
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              log.category,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              log.startTime.contains('T')
                  ? log.startTime.split('T')[1].substring(0, 5)
                  : '-',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              log.numberCycle != null
                  ? '${log.mode} (${log.numberCycle} cycles)'
                  : log.mode,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              log.initiatedByUserName,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          // Expanded(
          //   flex: 1,
          //   child: Text(
          //     log.status,
          //     style: TextStyle(
          //       color: log.status == 'Completed' ? Colors.green : Colors.orange,
          //       fontWeight: FontWeight.w600,
          //     ),
          //   ),
          // ),
          Expanded(
            flex: 1,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                color: Colors.blue.shade600,
                tooltip: 'View Details',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProcedureDetailScreen(procedure: log),
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySelectionPlaceholder extends StatelessWidget {
  const _EmptySelectionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Patient Selected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a patient from the list to view details',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Add Patient Dialog Form ---
class _AddPatientDialog extends StatefulWidget {
  final PatientModel? patient;
  final VoidCallback onSaved;

  const _AddPatientDialog({this.patient, required this.onSaved});

  @override
  State<_AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends State<_AddPatientDialog> {
  final _nameController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _contactController = TextEditingController();
  final _doctorController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  final _ageController = TextEditingController();

  String _selectedGender = 'Male';
  String _selectedDiagnosis = 'Liver';

  @override
  void initState() {
    super.initState();
    if (widget.patient != null) {
      _nameController.text = widget.patient!.name;
      _patientIdController.text = widget.patient!.patientId;
      _contactController.text = widget.patient!.contactNumber;
      _doctorController.text = widget.patient!.consultingDoctor;

      _selectedDiagnosis = widget.patient!.diagnosisArea;

      _addressController.text = widget.patient!.address;
      _noteController.text = widget.patient!.note;

      final validGenders = ['Male', 'Female', 'Other'];
      _selectedGender = validGenders.contains(widget.patient!.gender)
          ? widget.patient!.gender
          : 'Male';

      _ageController.text = widget.patient!.age;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patientIdController.dispose();
    _contactController.dispose();
    _doctorController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _save() {
    final patientId =
        widget.patient?.patientId ?? PatientRepository.generateNextPatientId();
    final patient = PatientModel(
      id:
          widget.patient?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patientId,
      name: _nameController.text.trim(),
      contactNumber: _contactController.text.trim(),
      consultingDoctor: _doctorController.text.trim(),
      diagnosisArea: _selectedDiagnosis,
      gender: _selectedGender,
      age: _ageController.text.trim(),
      address: _addressController.text.trim(),
      note: _noteController.text.trim(),
      lastProcedureDate: widget.patient?.lastProcedureDate ?? 'N/A',
    );

    if (widget.patient != null) {
      PatientRepository.updatePatient(patient);
    } else {
      PatientRepository.addPatient(patient);
    }

    widget.onSaved();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.patient == null ? 'Add New Patient' : 'Edit Patient',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Patient Name',
                      'Enter full name',
                      _nameController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField('Age', 'Enter age', _ageController),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownField(
                      'Gender',
                      _selectedGender,
                      ['Male', 'Female', 'Other'],
                      (val) {
                        setState(() => _selectedGender = val!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Contact Number',
                      'Enter phone number',
                      _contactController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      'Consulting Doctor',
                      'Enter doctor name',
                      _doctorController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                'Access Area (Instrument)',
                _selectedDiagnosis,
                ['Liver', 'Heart', 'Kidney', 'Basic Staff Access'],
                (val) {
                  setState(() => _selectedDiagnosis = val!);
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Address',
                'Enter full address',
                _addressController,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Other Notes',
                'Any additional medical notes',
                _noteController,
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE31820),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      widget.patient == null
                          ? 'Save Patient'
                          : 'Update Patient',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE31820)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE31820)),
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// Removed _Header as it's replaced by UnifiedHeader

// --- Footer ---
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'System Ready',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            'RADDMED Ablation System v1.0.0',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Removed _BrandLogo
