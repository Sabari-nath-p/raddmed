import 'package:flutter/material.dart';
import 'package:raddmed/Screens/ActiveAblationScreen/ActiveAblationScreen.dart';
import 'package:raddmed/Models/PatientModel.dart';
import 'package:raddmed/Repositories/PatientRepository.dart';
import 'package:raddmed/Models/Enums/InstrumentAccess.dart';
import 'package:raddmed/Models/Enums/InstrumentMode.dart';
import 'package:raddmed/Models/Enums/AntennaType.dart';

import 'package:raddmed/Models/ProcedureModel.dart';
import 'package:raddmed/Repositories/ProcedureRepository.dart';
import 'package:raddmed/Models/UserModel.dart';
import 'package:raddmed/Widgets/UnifiedHeader.dart';

// --- Main Screen ---
class NewProcedureScreen extends StatefulWidget {
  final UserModel currentUser;

  const NewProcedureScreen({super.key, required this.currentUser});

  @override
  State<NewProcedureScreen> createState() => _NewProcedureScreenState();
}

class _NewProcedureScreenState extends State<NewProcedureScreen> {
  // Selection States
  InstrumentAccess? _selectedCategory;
  InstrumentMode? _selectedMode;
  AntennaType? _selectedAntenna;
  final _antennaSerialController = TextEditingController();
  final _cycleCountController = TextEditingController();
  PatientModel? _selectedPatient;

  List<PatientModel> _allPatients = [];
  List<PatientModel> _filteredPatients = [];
  String _searchQuery = '';

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
  }

  void _showAddPatientDialog() async {
    final bool? added = await showDialog<bool>(
      context: context,
      builder: (context) => const _AddPatientDialog(),
    );
    if (added == true) {
      _loadPatients();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          UnifiedHeader(
            title: 'New Ablation Procedure',
            subtitle: 'Follow the steps below to start a new procedure.',
            currentUser: widget.currentUser,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1B2332)),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Main 4-Column Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCategoryColumn()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildModeColumn()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildAntennaColumn()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildPatientColumn()),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          _buildBottomActionBar(),

          // Footer
          const _Footer(),
        ],
      ),
    );
  }

  // --- Column 1: Procedure Category ---
  Widget _buildCategoryColumn() {
    final availableCategories = InstrumentAccess.values.where((cat) {
      return widget.currentUser.accessInstruments.contains(cat);
    }).toList();

    return _BaseColumnContainer(
      title: '1. Procedure Category',
      subtitle: 'Select the target area for ablation.',
      child: availableCategories.isEmpty
          ? const Center(
              child: Text(
                'No categories assigned',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(top: 16),
              itemCount: availableCategories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final cat = availableCategories[index];
                final isSelected = _selectedCategory == cat;
                return _SelectionCard(
                  title: cat.name.toUpperCase(),
                  icon: Icons.monitor_heart_outlined,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                      _selectedMode = null; // Reset mode when category changes
                    });
                  },
                );
              },
            ),
    );
  }

  // --- Column 2: Mode Selection (FIXED) ---
  Widget _buildModeColumn() {
    return _BaseColumnContainer(
      title: '2. Mode Selection',
      subtitle: 'Choose how the ablation will be delivered.',
      child: _selectedCategory == null
          ? const Center(
              child: Text(
                'Select a category first',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(top: 16),
                    itemCount: _selectedCategory!.supportedModes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final mode = _selectedCategory!.supportedModes[index];
                      final isSelected = _selectedMode == mode;
                      return _SelectionCard(
                        title: mode.name.toUpperCase(),
                        iconData: Icons.hardware,
                        isSelected: isSelected,
                        isLarge: true,
                        onTap: () => setState(() {
                          _selectedMode = mode;
                          if (mode != InstrumentMode.continuous) {
                            _cycleCountController.clear();
                          }
                        }),
                      );
                    },
                  ),
                ),
                // if (_selectedMode == InstrumentMode.continuous) ...[
                //   const SizedBox(height: 16),
                //   TextField(
                //     controller: _cycleCountController,
                //     keyboardType: TextInputType.number,
                //     decoration: InputDecoration(
                //       labelText: 'Number of Cycles (Optional)',
                //       hintText: 'Enter cycles',
                //       hintStyle: TextStyle(
                //         color: Colors.grey.shade400,
                //         fontSize: 13,
                //       ),
                //       labelStyle: const TextStyle(
                //         fontWeight: FontWeight.w600,
                //         fontSize: 13,
                //       ),
                //       contentPadding: const EdgeInsets.symmetric(
                //         horizontal: 16,
                //         vertical: 14,
                //       ),
                //       border: OutlineInputBorder(
                //         borderRadius: BorderRadius.circular(8),
                //         borderSide: BorderSide(color: Colors.grey.shade300),
                //       ),
                //       enabledBorder: OutlineInputBorder(
                //         borderRadius: BorderRadius.circular(8),
                //         borderSide: BorderSide(color: Colors.grey.shade300),
                //       ),
                //       focusedBorder: OutlineInputBorder(
                //         borderRadius: BorderRadius.circular(8),
                //         borderSide: const BorderSide(color: Color(0xFFE31820)),
                //       ),
                //     ),
                //   ),
                // ],
              ],
            ),
    );
  }

  // --- Column 3: Antenna Selection ---
  Widget _buildAntennaColumn() {
    return _BaseColumnContainer(
      title: '3. Antenna Selection',
      subtitle: 'Select the antenna to be used.',
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: AntennaType.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final antenna = AntennaType.values[index];
                final isSelected = _selectedAntenna == antenna;
                return _SelectionCard(
                  title: antenna.displayName,
                  isSelected: isSelected,
                  hideIcon: true,
                  onTap: () => setState(() => _selectedAntenna = antenna),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _antennaSerialController,
            decoration: InputDecoration(
              labelText: 'Antenna Serial Number (Optional)',
              hintText: 'Enter serial number',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
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
      ),
    );
  }

  // --- Column 4: Patient Selection ---
  Widget _buildPatientColumn() {
    return _BaseColumnContainer(
      title: '4. Patient Selection',
      subtitle: 'Select a patient for this procedure.',
      child: Column(
        children: [
          const SizedBox(height: 16),
          TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _filterPatients();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by name or ID...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 20, color: Colors.grey.shade300),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.filter_alt_outlined,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
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
          const SizedBox(height: 16),
          Expanded(
            child: _filteredPatients.isEmpty
                ? const Center(
                    child: Text(
                      'No patients found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredPatients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final patient = _filteredPatients[index];
                      final isSelected = _selectedPatient?.id == patient.id;
                      return _SelectionCard(
                        title: patient.name,
                        subtitle: '${patient.gender}, ${patient.contactNumber}',
                        prefixText: patient.patientId,
                        isSelected: isSelected,
                        hideIcon: true,
                        onTap: () => setState(() => _selectedPatient = patient),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddPatientDialog,
              icon: const Icon(Icons.add, color: Color(0xFFE31820), size: 20),
              label: const Text(
                'Add New Patient',
                style: TextStyle(
                  color: Color(0xFFE31820),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Bottom Action Bar ---
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF1B2332),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  if (_selectedCategory == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a Procedure Category'),
                      ),
                    );
                    return;
                  }
                  if (_selectedMode == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a Mode')),
                    );
                    return;
                  }
                  if (_selectedAntenna == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select an Antenna')),
                    );
                    return;
                  }
                  if (_selectedPatient == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a Patient')),
                    );
                    return;
                  }

                  final procedureId = DateTime.now().millisecondsSinceEpoch
                      .toString();
                  final procedure = ProcedureModel(
                    id: procedureId,
                    patientId: _selectedPatient!.patientId,
                    patientName: _selectedPatient!.name,
                    category: _selectedCategory!.name,
                    mode: _selectedMode!.name,
                    antenna: _selectedAntenna!.name,
                    antennaSerialNumber: _antennaSerialController.text.trim(),
                    startTime: DateTime.now().toIso8601String(),
                    status: 'In Progress',
                    initiatedByUserId: widget.currentUser.userid,
                    initiatedByUserName: widget.currentUser.name,
                    numberCycle: _cycleCountController.text.trim().isEmpty
                        ? null
                        : _cycleCountController.text.trim(),
                  );

                  await ProcedureRepository.addProcedure(procedure);

                  if (mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) =>
                            ActiveAblationScreen(procedure: procedure),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE31820),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  children: [
                    Text(
                      'Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Reusable Components ---
class _BaseColumnContainer extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _BaseColumnContainer({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE31820),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? prefixText;
  final IconData? icon;
  final IconData? iconData;
  final bool isSelected;
  final bool hideIcon;
  final bool isLarge;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    this.subtitle,
    this.prefixText,
    this.icon,
    this.iconData,
    required this.isSelected,
    this.hideIcon = false,
    this.isLarge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isLarge ? 24 : 16,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE31820).withOpacity(0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFE31820) : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: subtitle != null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (!hideIcon && icon != null) ...[
              Icon(
                icon,
                color: isSelected
                    ? const Color(0xFFE31820)
                    : Colors.grey.shade600,
                size: 28,
              ),
              const SizedBox(width: 16),
            ],
            if (!hideIcon && iconData != null) ...[
              Icon(
                iconData,
                color: isSelected
                    ? const Color(0xFFE31820)
                    : Colors.grey.shade600,
                size: 28,
              ),
              const SizedBox(width: 16),
            ],
            if (prefixText != null) ...[
              SizedBox(
                width: 60,
                child: Text(
                  prefixText!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.replaceAll("ENDOVASCULAR", "FOOTSWITCH"),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? Colors.black : Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? const Color(0xFFE31820)
                  : Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Add Patient Dialog Form ---
class _AddPatientDialog extends StatefulWidget {
  const _AddPatientDialog();

  @override
  State<_AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends State<_AddPatientDialog> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _doctorController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _ageController = TextEditingController();

  String _selectedGender = 'Male';
  InstrumentAccess _selectedDiagnosisArea = InstrumentAccess.liver;
  bool _isSaving = false;

  void _savePatient() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient Name is required.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final patientId = PatientRepository.generateNextPatientId();

    final patient = PatientModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patientId,
      name: name,
      contactNumber: _contactController.text.trim(),
      consultingDoctor: _doctorController.text.trim(),
      diagnosisArea: _selectedDiagnosisArea.name.toUpperCase(),
      gender: _selectedGender,
      age: _ageController.text.trim(),
      address: _addressController.text.trim(),
      note: _notesController.text.trim(),
    );

    await PatientRepository.addPatient(patient);

    if (mounted) {
      Navigator.pop(context, true);
    }
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
                  const Text(
                    'Add New Patient',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
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
              Row(
                children: [
                  Expanded(
                    child: _buildTextField('Age', 'Enter age', _ageController),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gender',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedGender,
                              isExpanded: true,
                              items: ['Male', 'Female', 'Other']
                                  .map(
                                    (g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(g),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _selectedGender = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Procedure Category / Diagnosis Area',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<InstrumentAccess>(
                        value: _selectedDiagnosisArea,
                        isExpanded: true,
                        items: InstrumentAccess.values
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat.name.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null)
                            setState(() => _selectedDiagnosisArea = val);
                        },
                      ),
                    ),
                  ),
                ],
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
                _notesController,
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _savePatient,
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
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Patient',
                            style: TextStyle(
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
                'Device Connected',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Container(width: 1, height: 12, color: Colors.grey.shade300),
              const SizedBox(width: 16),
              Text(
                'RAAD-2000',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(width: 16),
              Container(width: 1, height: 12, color: Colors.grey.shade300),
              const SizedBox(width: 16),
              Text(
                'Firmware v1.0.1',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Removed _BrandLogo
