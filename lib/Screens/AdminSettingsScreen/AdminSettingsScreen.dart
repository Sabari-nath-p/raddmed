import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:raddmed/Models/UserModel.dart';
import 'package:raddmed/Models/HospitalModel.dart';
import 'package:raddmed/Models/Enums/UserType.dart';
import 'package:raddmed/Models/Enums/InstrumentAccess.dart';
import 'package:raddmed/Repositories/UserRepository.dart';
import 'package:raddmed/Repositories/HospitalRepository.dart';
import 'package:raddmed/Widgets/UnifiedHeader.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
const _kNavy = Color(0xFF0D1B2A);
const _kRed = Color(0xFFE3192B);
const _kBg = Color(0xFFF0F4F8);
const _kCard = Colors.white;
const _kBorder = Color(0xFFE4E8EF);
const _kSubText = Color(0xFF8A96A8);
const _kBlue = Color(0xFF3B82F6);
const _kGreen = Color(0xFF10B981);

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class AdminSettingsScreen extends StatefulWidget {
  final UserModel currentUser;
  const AdminSettingsScreen({super.key, required this.currentUser});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  // 0 = Hospital Profile,  1 = User Manager
  int _tab = 0;

  // ── Hospital fields ────────────────────────────────────────────────────────
  final _hospitalNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  Uint8List? _hospitalLogo;
  bool _isSaving = false;

  // ── Staff list ─────────────────────────────────────────────────────────────
  List<UserModel> _staffList = [];
  bool _loadingStaff = true;

  @override
  void initState() {
    super.initState();
    _loadHospital();
    _loadStaff();
  }

  @override
  void dispose() {
    _hospitalNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA
  // ─────────────────────────────────────────────────────────────────────────
  void _loadHospital() {
    final h = HospitalRepository.getHospital(
      'hospital_${widget.currentUser.userid}',
    );
    if (h != null) {
      _hospitalNameCtrl.text = h.name;
      _addressCtrl.text = h.address;
      _phoneCtrl.text = h.phone;
      _websiteCtrl.text = h.website;
      _hospitalLogo = h.logo;
    }
  }

  Future<void> _loadStaff() async {
    final all = await UserRepository.getAllUsers();
    if (!mounted) return;
    setState(() {
      _staffList = all
          .where(
            (u) =>
                u.userType == UserType.staff &&
                u.data.contains(widget.currentUser.userid),
          )
          .toList();
      _loadingStaff = false;
    });
  }

  Future<void> _saveHospital() async {
    setState(() => _isSaving = true);
    await HospitalRepository.saveHospital(
      HospitalModel(
        id: 'hospital_${widget.currentUser.userid}',
        name: _hospitalNameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
        logo: _hospitalLogo,
      ),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNavRail(),
                Expanded(
                  child: _tab == 0
                      ? _buildHospitalPage()
                      : _buildUserManagerPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() => UnifiedHeader(
    title: 'Admin Settings',
    subtitle: 'Hospital profile & user management',
    currentUser: widget.currentUser,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: _kNavy),
      onPressed: () => Navigator.pop(context),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // NAV RAIL
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNavRail() {
    return Container(
      width: 220,
      color: _kNavy,
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _navSection('SETTINGS'),
          _navItem(Icons.business_rounded, 'Hospital Profile', 0),
          _navItem(Icons.manage_accounts_rounded, 'User Manager', 1),
          const SizedBox(height: 16),
          _navDivider(),
          const SizedBox(height: 16),
          _navSection('SESSION'),
          _navItemInfo(
            Icons.person_outline_rounded,
            'Logged in as',
            subtitle: widget.currentUser.name,
          ),
        ],
      ),
    );
  }

  Widget _navSection(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF4A6080),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _navItem(IconData icon, String label, int idx) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: active ? _kRed.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(
            icon,
            size: 18,
            color: active ? _kRed : const Color(0xFF6B8CAE),
          ),
          title: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF8AABCC),
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          minLeadingWidth: 20,
        ),
      ),
    );
  }

  Widget _navItemInfo(IconData icon, String label, {String? subtitle}) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: ListTile(
          dense: true,
          leading: Icon(icon, size: 18, color: const Color(0xFF6B8CAE)),
          title: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8AABCC),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF4A6080),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          minLeadingWidth: 20,
        ),
      );

  Widget _navDivider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 0 — HOSPITAL PROFILE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHospitalPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle(
            Icons.business_rounded,
            'Hospital Profile',
            'Manage your hospital identity and contact details',
          ),
          const SizedBox(height: 24),
          _SectionCard(
            icon: Icons.domain_rounded,
            title: 'Institution Details',
            subtitle: 'Primary information about your hospital',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Hospital Name',
                        hint: 'Enter full institution name',
                        controller: _hospitalNameCtrl,
                        icon: Icons.business_outlined,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _Field(
                        label: 'Contact Phone',
                        hint: '+1 (000) 000-0000',
                        controller: _phoneCtrl,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _Field(
                  label: 'Address',
                  hint: 'Street, City, State, Postal Code',
                  controller: _addressCtrl,
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                _Field(
                  label: 'Website',
                  hint: 'https://hospital.example.com',
                  controller: _websiteCtrl,
                  icon: Icons.language_outlined,
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kNavy,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 15,
                  ),
                  side: const BorderSide(color: _kBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveHospital,
                icon: _isSaving
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.save_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Changes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  disabledBackgroundColor: _kRed.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 15,
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1 — USER MANAGER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUserManagerPage() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pageTitle(
                Icons.manage_accounts_rounded,
                'User Manager',
                'Create and manage staff accounts for this hospital',
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showStaffDialog(null),
                icon: const Icon(
                  Icons.add_rounded,
                  size: 17,
                  color: Colors.white,
                ),
                label: const Text(
                  'Add Staff',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildStaffTable()),
        ],
      ),
    );
  }

  Widget _buildStaffTable() {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 36),
                SizedBox(width: 12),
                Expanded(flex: 3, child: _TH('NAME')),
                Expanded(flex: 2, child: _TH('USER ID')),
                Expanded(flex: 4, child: _TH('ACCESS AREAS')),
                SizedBox(width: 90),
              ],
            ),
          ),
          // Table body
          Expanded(
            child: _loadingStaff
                ? const Center(child: CircularProgressIndicator(color: _kRed))
                : _staffList.isEmpty
                ? _emptyState()
                : ListView.builder(
                    itemCount: _staffList.length,
                    itemBuilder: (_, i) => _StaffRow(
                      staff: _staffList[i],
                      isEven: i.isEven,
                      onEdit: () => _showStaffDialog(_staffList[i]),
                      onDelete: () => _deleteStaff(_staffList[i]),
                    ),
                  ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(
              children: [
                Text(
                  '${_staffList.length} staff member${_staffList.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: _kSubText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: _kBg, shape: BoxShape.circle),
          child: const Icon(
            Icons.people_outline_rounded,
            size: 40,
            color: _kSubText,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No staff members yet',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kNavy,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Click "Add Staff" to create the first account.',
          style: TextStyle(fontSize: 12, color: _kSubText),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────────────────────────────────────
  void _showStaffDialog(UserModel? existing) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StaffDialog(
        existing: existing,
        adminUser: widget.currentUser,
        onSaved: () {
          Navigator.pop(context);
          _loadStaff();
        },
      ),
    );
  }

  Future<void> _deleteStaff(UserModel staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _kRed),
            SizedBox(width: 8),
            Text(
              'Delete Staff',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Text(
          'Remove "${staff.name}" (${staff.userid})? This cannot be undone.',
          style: const TextStyle(fontSize: 13, color: _kSubText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _kSubText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await UserRepository.deleteUser(staff.userid);
      if (mounted) _loadStaff();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _pageTitle(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _kRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _kRed, size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: _kSubText),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staff Table Row
// ─────────────────────────────────────────────────────────────────────────────
class _StaffRow extends StatelessWidget {
  final UserModel staff;
  final bool isEven;
  final VoidCallback onEdit, onDelete;
  const _StaffRow({
    required this.staff,
    required this.isEven,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : _kBg.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: _kBorder.withOpacity(0.6))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _kBlue.withOpacity(0.12),
            child: Text(
              staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: _kBlue,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              staff.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _kNavy,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              staff.userid,
              style: const TextStyle(
                color: _kSubText,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: staff.accessInstruments
                  .map((a) => _AccessBadge(a))
                  .toList(),
            ),
          ),
          SizedBox(
            width: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _IconBtn(
                  icon: Icons.edit_outlined,
                  color: _kBlue,
                  tooltip: 'Edit',
                  onTap: onEdit,
                ),
                const SizedBox(width: 4),
                _IconBtn(
                  icon: Icons.delete_outline_rounded,
                  color: _kRed,
                  tooltip: 'Delete',
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessBadge extends StatelessWidget {
  final InstrumentAccess access;
  const _AccessBadge(this.access);

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (access) {
      case InstrumentAccess.liver:
        color = _kGreen;
        label = 'Liver';
        break;
      case InstrumentAccess.lung:
        color = _kRed;
        label = 'Lung';
        break;
      case InstrumentAccess.kidney:
        color = _kBlue;
        label = 'Kidney';
        break;
      case InstrumentAccess.bone:
        color = Colors.grey;
        label = 'Bone';
        break;
      case InstrumentAccess.thyroid:
        color = Colors.purple;
        label = 'Thyroid';
        break;
      case InstrumentAccess.endovenuos:
        color = Colors.teal;
        label = 'Endovenuos';
        break;
      case InstrumentAccess.breast:
        color = Colors.pink;
        label = 'Breast';
        break;
      case InstrumentAccess.uterus:
        color = Colors.deepPurple;
        label = 'Uterus';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Staff Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _StaffDialog extends StatefulWidget {
  final UserModel? existing;
  final UserModel adminUser;
  final VoidCallback onSaved;
  const _StaffDialog({
    this.existing,
    required this.adminUser,
    required this.onSaved,
  });

  @override
  State<_StaffDialog> createState() => _StaffDialogState();
}

class _StaffDialogState extends State<_StaffDialog> {
  final _nameCtrl = TextEditingController();
  final _useridCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final List<InstrumentAccess> _selectedAccess = [];
  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.existing!.name;
      _useridCtrl.text = widget.existing!.userid;
      _passwordCtrl.text = widget.existing!.password;
      _selectedAccess.addAll(widget.existing!.accessInstruments);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _useridCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final userid = _useridCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (name.isEmpty || userid.isEmpty || password.isEmpty) {
      setState(() => _error = 'Name, User ID and Password are required.');
      return;
    }
    if (_selectedAccess.isEmpty) {
      setState(() => _error = 'Select at least one access area.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await UserRepository.updateUser(
          UserModel(
            id: widget.existing!.id,
            name: name,
            userid: userid,
            password: password,
            userType: UserType.staff,
            accessInstruments: List.from(_selectedAccess),
            data: widget.existing!.data,
          ),
        );
      } else {
        await UserRepository.addUser(
          UserModel(
            id: 'staff_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            userid: userid,
            password: password,
            userType: UserType.staff,
            accessInstruments: List.from(_selectedAccess),
            data: 'admin:${widget.adminUser.userid}',
          ),
        );
      }
      widget.onSaved();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Failed to save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 100, vertical: 40),
      child: Container(
        width: 560,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _kBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                      color: _kRed,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? 'Edit Staff Account' : 'Add New Staff',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _kNavy,
                        ),
                      ),
                      Text(
                        _isEdit
                            ? 'Update account details'
                            : 'Create a new staff account',
                        style: const TextStyle(fontSize: 11, color: _kSubText),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _kSubText),
                  ),
                ],
              ),
            ),
            // Form body
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          label: 'Full Name',
                          hint: 'e.g. Dr. Jane Smith',
                          controller: _nameCtrl,
                          icon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _Field(
                          label: 'User ID (Login)',
                          hint: 'e.g. jsmith',
                          controller: _useridCtrl,
                          icon: Icons.badge_outlined,
                          enabled: !_isEdit,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Password
                  const Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontSize: 14, color: _kNavy),
                    decoration: InputDecoration(
                      hintText: _isEdit
                          ? 'Enter new password to change'
                          : 'Set a secure password',
                      hintStyle: TextStyle(
                        color: _kSubText.withOpacity(0.6),
                        fontSize: 13,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: _kSubText,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 44),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: _kSubText,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFBFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kBlue, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Access areas
                  const Text(
                    'Access Areas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select which areas this staff member can access.',
                    style: TextStyle(fontSize: 11, color: _kSubText),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.adminUser.accessInstruments.map((inst) {
                      final isSelected = _selectedAccess.contains(inst);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selectedAccess.remove(inst);
                          } else {
                            _selectedAccess.add(inst);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _kRed.withOpacity(0.08)
                                : const Color(0xFFFAFBFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? _kRed.withOpacity(0.5)
                                  : _kBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 16,
                                color: isSelected ? _kRed : _kSubText,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                _accessLabel(inst),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected ? _kRed : _kNavy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kRed.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kRed.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 14,
                            color: _kRed,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _kBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kNavy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 13,
                      ),
                      side: const BorderSide(color: _kBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isEdit
                                ? Icons.save_rounded
                                : Icons.person_add_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                    label: Text(
                      _saving
                          ? 'Saving...'
                          : (_isEdit ? 'Update Staff' : 'Create Staff'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRed,
                      disabledBackgroundColor: _kRed.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _accessLabel(InstrumentAccess a) {
    switch (a) {
      case InstrumentAccess.liver:
        return 'Liver';
      case InstrumentAccess.lung:
        return 'Lung';
      case InstrumentAccess.kidney:
        return 'Kidney';
      case InstrumentAccess.bone:
        return 'Bone';
      case InstrumentAccess.thyroid:
        return 'Thyroid';
      case InstrumentAccess.endovenuos:
        return 'Endovenuos';
      case InstrumentAccess.breast:
        return 'Breast';
      case InstrumentAccess.uterus:
        return 'Uterus';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Table Header Cell
// ─────────────────────────────────────────────────────────────────────────────
class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: _kSubText,
      letterSpacing: 0.8,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Card
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: _kBlue),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: _kSubText),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(24), child: child),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Labelled Input Field
// ─────────────────────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final bool enabled;
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          enabled: enabled,
          style: const TextStyle(fontSize: 14, color: _kNavy),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: _kSubText.withOpacity(0.6),
              fontSize: 13,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(icon, size: 16, color: _kSubText),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            filled: true,
            fillColor: enabled ? const Color(0xFFFAFBFC) : _kBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _kBorder.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
