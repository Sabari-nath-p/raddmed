import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raddmed/Models/Enums/InstrumentAccess.dart';
import 'package:raddmed/Models/Enums/UserType.dart';
import 'package:raddmed/Models/UserModel.dart';
import 'package:raddmed/Repositories/UserRepository.dart';
import 'package:raddmed/Repositories/HospitalRepository.dart';
import 'package:raddmed/Repositories/PatientRepository.dart';
import 'package:raddmed/Repositories/ProcedureRepository.dart';
import 'package:raddmed/Widgets/UnifiedHeader.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
const _kNavy = Color(0xFF0D1B2A);
const _kRed = Color(0xFFE3192B);
const _kGreen = Color(0xFF10B981);
const _kBlue = Color(0xFF3B82F6);
const _kAmber = Color(0xFFF59E0B);
const _kPurple = Color(0xFF8B5CF6);
const _kBg = Color(0xFFF0F4F8);
const _kCard = Colors.white;
const _kBorder = Color(0xFFE4E8EF);
const _kSub = Color(0xFF8A96A8);

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class RootAdminScreen extends StatefulWidget {
  const RootAdminScreen({super.key});

  @override
  State<RootAdminScreen> createState() => _RootAdminScreenState();
}

class _RootAdminScreenState extends State<RootAdminScreen> {
  // ── Form state ─────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _hospitalNameCtrl = TextEditingController();
  final _adminUserIdCtrl = TextEditingController();
  final _adminPwdCtrl = TextEditingController();
  DateTime? _expiryDate;
  bool _obscurePwd = true;
  bool _saving = false;

  final Map<InstrumentAccess, bool> _access = {
    InstrumentAccess.liver: false,
    InstrumentAccess.lung: false,
    InstrumentAccess.kidney: false,
    InstrumentAccess.bone: false,
    InstrumentAccess.thyroid: false,
    InstrumentAccess.endovenuos: false,
    InstrumentAccess.breast: false,
    InstrumentAccess.uterus: false,
  };

  // ── Registry state ─────────────────────────────────────────────────────────
  List<UserModel> _allUsers = [];
  List<UserModel> _filtered = [];
  bool _loadingUsers = true;
  String _roleFilter = 'All';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _hospitalNameCtrl.dispose();
    _adminUserIdCtrl.dispose();
    _adminPwdCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _loadUsers() async {
    final users = await UserRepository.getAllUsers();
    if (!mounted) return;
    setState(() {
      _allUsers = users;
      _loadingUsers = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    _filtered = _allUsers.where((u) {
      final matchRole =
          _roleFilter == 'All' ||
          u.userType.name.toLowerCase() == _roleFilter.toLowerCase();
      final matchQ =
          q.isEmpty ||
          u.name.toLowerCase().contains(q) ||
          u.userid.toLowerCase().contains(q) ||
          u.data.toLowerCase().contains(q);
      return matchRole && matchQ;
    }).toList()..sort((a, b) => a.userType.index.compareTo(b.userType.index));
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      _snack('Please select a software expiry date.', isError: true);
      return;
    }
    if (!_access.values.any((v) => v)) {
      _snack('Select at least one access area.', isError: true);
      return;
    }
    setState(() => _saving = true);

    final selected = _access.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    await UserRepository.addUser(
      UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _hospitalNameCtrl.text.trim(),
        userid: _adminUserIdCtrl.text.trim(),
        password: _adminPwdCtrl.text,
        userType: UserType.admin,
        accessInstruments: selected,
        data: 'Hospital Account',
        expiryDate: _expiryDate,
      ),
    );

    _formKey.currentState!.reset();
    _hospitalNameCtrl.clear();
    _adminUserIdCtrl.clear();
    _adminPwdCtrl.clear();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _expiryDate = null;
      _obscurePwd = true;
      _access.updateAll((k, _) => false);
    });
    _snack('Hospital account created successfully!');
    await _loadUsers();
  }

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Factory Reset'),
        content: const Text(
          'Are you sure you want to delete ALL data (Users, Hospitals, Patients, Procedures)?\n\n'
          'This action cannot be undone and will only leave the default root account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await UserRepository.clearAllUsers();
    await HospitalRepository.clearAllHospitals();
    await PatientRepository.clearAllPatients();
    await ProcedureRepository.clearAllProcedures();

    await _loadUsers();
    if (mounted) _snack('All data cleared successfully.');
  }

  Future<void> _deleteUser(UserModel u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(user: u),
    );
    if (ok != true || !mounted) return;
    await UserRepository.deleteUser(u.userid);
    await _loadUsers();
    if (mounted) _snack('User "${u.userid}" deleted.');
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _kRed : _kNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _instLabel(InstrumentAccess inst) {
    final s = inst.name.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    return s[0].toUpperCase() + s.substring(1);
  }

  Color _roleColor(UserType t) => t == UserType.rootUser
      ? _kRed
      : t == UserType.admin
      ? _kBlue
      : _kGreen;
  String _roleLabel(UserType t) => t == UserType.rootUser
      ? 'Root'
      : t == UserType.admin
      ? 'Hospital Admin'
      : 'Staff';
  IconData _roleIcon(UserType t) => t == UserType.rootUser
      ? Icons.verified_user_rounded
      : t == UserType.admin
      ? Icons.local_hospital_rounded
      : Icons.badge_rounded;

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          UnifiedHeader(
            title: 'Root Admin Console',
            subtitle: 'Provision hospital accounts and manage system users',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Clear All Data (Factory Reset)',
                  child: GestureDetector(
                    onTap: _confirmClearAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _kAmber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kAmber.withOpacity(0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 15, color: _kAmber),
                          SizedBox(width: 6),
                          Text(
                            'Clear All Data',
                            style: TextStyle(
                              color: _kAmber,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: 'Log out',
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pushReplacementNamed('/'),
                    child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _kRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kRed.withOpacity(0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout_rounded, size: 15, color: _kRed),
                      SizedBox(width: 6),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: _kRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ]
          ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 390, child: _buildForm()),
                Container(width: 1, color: _kBorder),
                Expanded(child: _buildRegistry()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════ FORM PANEL ════════
  Widget _buildForm() {
    return Container(
      color: _kCard,
      child: Column(
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _kNavy.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add_business_rounded,
                    size: 18,
                    color: _kNavy,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Hospital Account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                      ),
                    ),
                    Text(
                      'Provision a new hospital admin',
                      style: TextStyle(fontSize: 11, color: _kSub),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Hospital info ─────────────────────────────────────────────
                    _secLabel(Icons.apartment_rounded, 'HOSPITAL INFORMATION'),
                    const SizedBox(height: 10),
                    _textField(
                      ctrl: _hospitalNameCtrl,
                      label: 'Hospital Name',
                      icon: Icons.apartment_rounded,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),

                    const SizedBox(height: 22),
                    const Divider(height: 1, color: _kBorder),
                    const SizedBox(height: 22),

                    // ── Credentials ───────────────────────────────────────────────
                    _secLabel(
                      Icons.admin_panel_settings_rounded,
                      'ADMINISTRATOR CREDENTIALS',
                    ),
                    const SizedBox(height: 10),
                    _textField(
                      ctrl: _adminUserIdCtrl,
                      label: 'Admin User ID',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _adminPwdCtrl,
                      obscureText: _obscurePwd,
                      style: const TextStyle(fontSize: 13),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      decoration: _dec(
                        label: 'Admin Password',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePwd
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                            color: _kSub,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePwd = !_obscurePwd),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),
                    const Divider(height: 1, color: _kBorder),
                    const SizedBox(height: 22),

                    // ── Expiry ────────────────────────────────────────────────────
                    _secLabel(
                      Icons.calendar_month_rounded,
                      'SOFTWARE EXPIRY DATE',
                    ),
                    const SizedBox(height: 10),
                    _ExpirySelector(
                      selected: _expiryDate,
                      onPick: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => _expiryDate = d);
                      },
                    ),

                    const SizedBox(height: 22),
                    const Divider(height: 1, color: _kBorder),
                    const SizedBox(height: 22),

                    // ── Access areas ──────────────────────────────────────────────
                    _secLabel(Icons.lock_open_rounded, 'ACCESS AREAS'),
                    const SizedBox(height: 10),
                    ..._access.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AccessTile(
                          label: _instLabel(e.key),
                          selected: e.value,
                          onTap: () =>
                              setState(() => _access[e.key] = !e.value),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Submit ────────────────────────────────────────────────────
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _createAccount,
                        icon: _saving
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 17,
                                color: Colors.white,
                              ),
                        label: Text(
                          _saving ? 'Creating...' : 'Create Hospital Account',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kRed,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secLabel(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 12, color: _kSub),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _kSub,
          letterSpacing: 1.1,
        ),
      ),
    ],
  );

  Widget _textField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl,
    style: const TextStyle(fontSize: 13),
    validator: validator,
    decoration: _dec(label: label, icon: icon),
  );

  InputDecoration _dec({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: _kSub),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(icon, size: 16, color: _kSub),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44),
      suffixIcon: suffix,
      filled: true,
      fillColor: _kBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kRed),
      ),
    );
  }

  // ═══════════════════════════════════════════════════ REGISTRY PANEL ════════
  Widget _buildRegistry() {
    return Column(
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
          color: _kCard,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Registry',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kNavy,
                    ),
                  ),
                  Text(
                    '${_allUsers.length} total accounts in the system',
                    style: const TextStyle(fontSize: 11, color: _kSub),
                  ),
                ],
              ),
              const Spacer(),
              // Search
              Container(
                width: 220,
                height: 36,
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() => _applyFilter()),
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Search users...',
                    hintStyle: TextStyle(fontSize: 12, color: _kSub),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: _kSub,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Refresh',
                child: GestureDetector(
                  onTap: () {
                    setState(() => _loadingUsers = true);
                    _loadUsers();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: _kSub,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Role filter chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          color: _kCard,
          child: Row(
            children: [
              ...['All', 'rootUser', 'admin', 'staff'].map((r) {
                final active = _roleFilter == r;
                final label = r == 'All'
                    ? 'All'
                    : r == 'rootUser'
                    ? 'Root'
                    : r == 'admin'
                    ? 'Hospital Admin'
                    : 'Staff';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _roleFilter = r;
                      _applyFilter();
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: active ? _kNavy : _kBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? _kNavy : _kBorder),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : _kSub,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              Text(
                '${_filtered.length} shown',
                style: const TextStyle(fontSize: 11, color: _kSub),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _kBorder),
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          color: _kBg,
          child: const Row(
            children: [
              SizedBox(width: 36),
              SizedBox(width: 10),
              Expanded(flex: 3, child: _TH('ACCOUNT / HOSPITAL')),
              Expanded(flex: 2, child: _TH('USER ID')),
              Expanded(flex: 2, child: _TH('ROLE')),
              Expanded(flex: 3, child: _TH('ACCESS AREAS')),
              Expanded(flex: 2, child: _TH('EXPIRY')),
              SizedBox(width: 54, child: _TH('ACTION')),
            ],
          ),
        ),
        const Divider(height: 1, color: _kBorder),
        // Table body
        Expanded(
          child: _loadingUsers
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _kNavy,
                    strokeWidth: 2.5,
                  ),
                )
              : _filtered.isEmpty
              ? _empty()
              : ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _kBorder),
                  itemBuilder: (_, i) => _UserRow(
                    user: _filtered[i],
                    isEven: i.isEven,
                    roleColor: _roleColor(_filtered[i].userType),
                    roleLabel: _roleLabel(_filtered[i].userType),
                    roleIcon: _roleIcon(_filtered[i].userType),
                    instLabel: _instLabel,
                    onDelete: () => _deleteUser(_filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kBg,
            shape: BoxShape.circle,
            border: Border.all(color: _kBorder),
          ),
          child: const Icon(
            Icons.people_outline_rounded,
            size: 36,
            color: _kSub,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'No users found',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kNavy,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Create a hospital account or adjust your search.',
          style: TextStyle(fontSize: 12, color: _kSub),
        ),
      ],
    ),
  );
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
      color: _kSub,
      letterSpacing: 0.9,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// User Row
// ─────────────────────────────────────────────────────────────────────────────
class _UserRow extends StatefulWidget {
  final UserModel user;
  final bool isEven;
  final Color roleColor;
  final String roleLabel;
  final IconData roleIcon;
  final String Function(InstrumentAccess) instLabel;
  final VoidCallback onDelete;

  const _UserRow({
    required this.user,
    required this.isEven,
    required this.roleColor,
    required this.roleLabel,
    required this.roleIcon,
    required this.instLabel,
    required this.onDelete,
  });

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _hovered = false;

  String _expiryText(DateTime? d) {
    if (d == null) return '—';
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Today';
    return DateFormat('dd MMM yyyy').format(d);
  }

  Color _expiryColor(DateTime? d) {
    if (d == null) return _kSub;
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return _kRed;
    if (days < 30) return _kAmber;
    return _kSub;
  }

  (Color, IconData) _accessStyle(InstrumentAccess inst) {
    switch (inst) {
      case InstrumentAccess.liver:
        return (_kAmber, Icons.local_hospital_rounded);
      case InstrumentAccess.lung:
        return (_kRed, Icons.favorite_rounded);
      case InstrumentAccess.kidney:
        return (_kBlue, Icons.water_drop_rounded);
      case InstrumentAccess.bone:
        return (Colors.grey, Icons.medical_services_rounded);
      case InstrumentAccess.thyroid:
        return (_kPurple, Icons.adjust_rounded);
      case InstrumentAccess.endovenuos:
        return (_kGreen, Icons.timeline_rounded);
      case InstrumentAccess.breast:
        return (Colors.pink, Icons.face_3_rounded);
      case InstrumentAccess.uterus:
        return (Colors.deepPurple, Icons.child_care_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final isRoot = u.userType == UserType.rootUser;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered
            ? widget.roleColor.withOpacity(0.04)
            : widget.isEven
            ? _kCard
            : _kBg.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.roleColor.withOpacity(0.12),
              child: Text(
                u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: widget.roleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Name
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _kNavy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (u.data.isNotEmpty)
                    Text(
                      u.data,
                      style: const TextStyle(fontSize: 10, color: _kSub),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // User ID
            Expanded(
              flex: 2,
              child: Text(
                u.userid,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: _kSub,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Role badge
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.roleColor.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.roleIcon, size: 11, color: widget.roleColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.roleLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.roleColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Access areas
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: u.accessInstruments.map((inst) {
                  final (color, icon) = _accessStyle(inst);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 10, color: color),
                        const SizedBox(width: 3),
                        Text(
                          widget.instLabel(inst),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            // Expiry
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _expiryText(u.expiryDate),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _expiryColor(u.expiryDate),
                    ),
                  ),
                  if (u.expiryDate != null)
                    Builder(
                      builder: (_) {
                        final days = u.expiryDate!
                            .difference(DateTime.now())
                            .inDays;
                        return days > 0
                            ? Text(
                                '$days days left',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _kSub,
                                ),
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                ],
              ),
            ),
            // Delete / lock
            SizedBox(
              width: 54,
              child: Center(
                child: isRoot
                    ? Tooltip(
                        message: 'Root users cannot be deleted',
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: _kSub.withOpacity(0.4),
                        ),
                      )
                    : Tooltip(
                        message: 'Delete user',
                        child: GestureDetector(
                          onTap: widget.onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _kRed.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: _kRed.withOpacity(0.15),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 15,
                              color: _kRed,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expiry Selector Widget
// ─────────────────────────────────────────────────────────────────────────────
class _ExpirySelector extends StatelessWidget {
  final DateTime? selected;
  final VoidCallback onPick;
  const _ExpirySelector({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final has = selected != null;
    final days = has ? selected!.difference(DateTime.now()).inDays : null;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: has ? _kBlue.withOpacity(0.4) : _kBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: has ? _kBlue : _kSub,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    has
                        ? DateFormat('MMM dd, yyyy').format(selected!)
                        : 'Select expiry date',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: has ? _kNavy : _kSub,
                    ),
                  ),
                  if (has && days != null)
                    Text(
                      days >= 0
                          ? 'Valid for $days day${days == 1 ? '' : 's'}'
                          : 'Date is in the past',
                      style: TextStyle(
                        fontSize: 10,
                        color: days >= 0 ? _kSub : _kRed,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _kNavy,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Choose',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Access Toggle Tile
// ─────────────────────────────────────────────────────────────────────────────
class _AccessTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AccessTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kNavy.withOpacity(0.05) : _kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _kNavy.withOpacity(0.3) : _kBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 16,
              color: selected ? _kRed : _kSub,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _kNavy : _kSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirm Delete Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmDeleteDialog extends StatelessWidget {
  final UserModel user;
  const _ConfirmDeleteDialog({required this.user});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 420,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(color: _kRed.withOpacity(0.15)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kRed.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: _kRed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete User Account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _kNavy,
                        ),
                      ),
                      Text(
                        'This action cannot be undone',
                        style: TextStyle(fontSize: 11, color: _kSub),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You are about to permanently delete:',
                    style: TextStyle(fontSize: 13, color: _kSub),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _kNavy,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'User ID: ${user.userid}  •  ${user.userType.name}',
                          style: const TextStyle(fontSize: 11, color: _kSub),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Staff accounts linked to this admin will still exist but lose their admin association.',
                    style: TextStyle(fontSize: 11, color: _kSub),
                  ),
                ],
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: _kSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(
                      Icons.delete_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRed,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
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
}
