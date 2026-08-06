import 'package:flutter/material.dart';
import 'package:raddmed/Screens/DashboardScreen/DashboardScreen.dart';
import 'package:raddmed/Screens/RootAdminScreen/RootAdminScreen.dart';
import 'package:raddmed/Repositories/UserRepository.dart';
import 'package:raddmed/Models/Enums/UserType.dart';

class AuthenticationScreen extends StatelessWidget {
  const AuthenticationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image Layer
          Positioned.fill(
            child: Image.asset("Assets/bg2.png", fit: BoxFit.cover),
          ),

          // Foreground UI Layer
          Positioned.fill(
            child: Row(
              children: [
                // Left Panel - Branding & Marketing
                Expanded(
                  flex: 9,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 60.0, top: 60.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _BrandLogo(),
                        const SizedBox(height: 16),
                        const Text(
                          'PRECISION. SAFETY. BETTER OUTCOMES.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Color(0xFF1B2332),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _CustomDivider(),
                        const SizedBox(height: 32),
                        const Text(
                          'Advanced Ablation.',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1B2332),
                            height: 1.2,
                          ),
                        ),
                        const Text(
                          'Trusted Technology.',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFE31820),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Engineered for precision.\nDesigned for better patient outcomes.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Panel - Authentication Card
                Expanded(
                  flex: 11,
                  child: Column(
                    children: [
                      const Spacer(),
                      // Center the card in the available space
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: const _LoginCard(),
                        ),
                      ),
                      const Spacer(),
                      // Footer Copyright
                      const Padding(
                        padding: EdgeInsets.only(bottom: 24.0),
                        child: Text(
                          '© 2026 RADDMED. All rights reserved.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Component: Login Card ---
class _LoginCard extends StatefulWidget {
  const _LoginCard();

  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final userId = _userIdController.text.trim();
    final password = _passwordController.text;

    if (userId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both User ID and Password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = await UserRepository.authenticate(userId, password);

    setState(() {
      _isLoading = false;
    });

    if (user != null) {
      if (mounted) {
        if (user.userType == UserType.rootUser) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (ctx) => const RootAdminScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (ctx) => DashboardScreen(currentUser: user),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid User ID or Password'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 40.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BrandLogo(),
          const SizedBox(height: 24),
          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2332),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to continue to your account',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 36),

          // User ID Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User ID',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2332),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _userIdController,
                decoration: InputDecoration(
                  hintText: 'Enter your user ID',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: Colors.grey.shade500,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
          const SizedBox(height: 20),

          // Password Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Password',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2332),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: Colors.grey.shade500,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey.shade500,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
          const SizedBox(height: 32),

          // Sign In Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE31820),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Component: Image Logo ---
class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'Assets/logo.png',
      height: 48, // Adjust based on your logo's aspect ratio
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback in case the image path is incorrect during dev
        return const Text(
          'Logo Missing',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        );
      },
    );
  }
}

// --- Component: Red Divider Line ---
class _CustomDivider extends StatelessWidget {
  const _CustomDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 50, height: 2, color: const Color(0xFFE31820)),
        const SizedBox(width: 4),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFFE31820),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
