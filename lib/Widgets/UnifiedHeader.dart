import 'package:flutter/material.dart';
import 'package:raddmed/Models/UserModel.dart';
import 'package:raddmed/Screens/AuthenticationScreen/AuthenticationScreen.dart';
import 'package:raddmed/Services/SerialService.dart';

class UnifiedHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final UserModel? currentUser;

  const UnifiedHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 24)],
              Image.asset(
                'Assets/logo.png',
                height: 70,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Text(
                    'RADDMED',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  );
                },
              ),
              const SizedBox(width: 32),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              const SizedBox(width: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2332),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 24),
              const _ConnectionStatusBadge(),
            ],
          ),
          if (trailing != null)
            trailing!
          else if (currentUser != null)
            _UserProfile(currentUser: currentUser!),
        ],
      ),
    );
  }
}

class _UserProfile extends StatelessWidget {
  final UserModel currentUser;

  const _UserProfile({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              child: Icon(Icons.person_outline, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentUser.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1B2332),
                  ),
                ),
                Text(
                  currentUser.userid,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey.shade600,
              ),
              onSelected: (value) {
                if (value == 'logout') {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (ctx) => const AuthenticationScreen(),
                    ),
                  );
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Logout'),
                  ),
                ];
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ConnectionStatusBadge extends StatefulWidget {
  const _ConnectionStatusBadge();

  @override
  State<_ConnectionStatusBadge> createState() => _ConnectionStatusBadgeState();
}

class _ConnectionStatusBadgeState extends State<_ConnectionStatusBadge> {
  final _serial = SerialService.instance;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _isConnected = _serial.isConnected;
    _serial.statusStream.listen((_) {
      if (mounted) {
        setState(() {
          _isConnected = _serial.isConnected;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _isConnected
        ? const Color(0xFF00C896)
        : const Color(0xFFE3192B);
    final text = _isConnected ? 'SYSTEM CONNECTED' : 'SYSTEM DISCONNECTED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
