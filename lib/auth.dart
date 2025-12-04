import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';
import 'services/auth_service.dart';
import 'services/analytics_service.dart';

// --- PREMIUM COLOR PALETTE ---
const Color primaryGreen = Color(0xFF00796B);      // Primary accent color
const Color primaryLight = Color(0xFF4DB6AC);      // Lighter gradient/highlight
const Color backgroundGray = Color(0xFFF0F4F7);    // Very subtle, soft page background
const Color lightFill = Color(0xFFE8F5E9);         // Very light green for form field background
const Color cardWhite = Color(0xFFFFFFFF);         // Pure white for cards
const Color textDark = Color(0xFF212121);          // Deep black for headlines
const Color textLight = Color(0xFF757575);         // Subtle gray for body text
const Color shadowColor = Color(0xFFC5DDE8);       // Soft shadow color

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _obscurePasswordLogin = true;
  bool _obscurePasswordSignup = true;
  bool _obscurePasswordConfirm = true;
  
  final AuthService _authService = AuthService();
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  final TextEditingController _signupNameController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController = TextEditingController();
  final TextEditingController _signupConfirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  
  Future<void> _handleLogin() async {
    if (_loginEmailController.text.isEmpty || _loginPasswordController.text.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = await _authService.signInWithEmailAndPassword(
        _loginEmailController.text.trim(),
        _loginPasswordController.text,
      );
      
      if (user != null) {
        AnalyticsService.logLogin('email');
        AnalyticsService.setUserProperties(userId: user.uid);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      print('Firebase Auth error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect email or password';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'unknown':
          if (e.message?.contains('Identity Toolkit API') == true) {
            message = 'Firebase Authentication is not properly configured. Please contact support.';
          } else {
            message = e.message ?? 'Login failed';
          }
          break;
        default:
          message = e.message ?? 'Login failed';
      }
      _showErrorDialog(message);
    } catch (e) {
      debugPrint('Login error: $e');
      _showErrorDialog('Login failed: Please try again');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    if (_signupNameController.text.isEmpty ||
        _signupEmailController.text.isEmpty ||
        _signupPasswordController.text.isEmpty ||
        _signupConfirmPasswordController.text.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    if (_signupPasswordController.text != _signupConfirmPasswordController.text) {
      _showErrorDialog('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _signupEmailController.text.trim(),
        password: _signupPasswordController.text,
      );

      // Save user data to Firestore immediately
      await _authService.saveUserData(userCredential.user!.uid, {
        'name': _signupNameController.text.trim(),
        'email': userCredential.user!.email,
        'createdAt': FieldValue.serverTimestamp(),
        'profileComplete': false,
      });
      
      setState(() => _isLoading = false);
      
      // Track signup analytics
      AnalyticsService.logSignUp('email');
      AnalyticsService.setUserProperties(userId: userCredential.user!.uid);
      
      // Navigate directly to home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
      
    } on FirebaseAuthException catch (e) {
      String message = 'Signup failed';
      switch (e.code) {
        case 'weak-password':
          message = 'Password is too weak (minimum 6 characters)';
          break;
        case 'email-already-in-use':
          message = 'Email is already registered. Try logging in instead.';
          break;
        case 'invalid-email':
          message = 'Invalid email address format';
          break;
        default:
          message = e.message ?? 'Signup failed. Please try again.';
      }
      _showErrorDialog(message);
    } catch (e) {
      _showErrorDialog('Signup failed: Please check your connection and try again');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Error', style: TextStyle(color: textDark)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: textLight, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: primaryGreen),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Reset Password', style: TextStyle(color: textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email to receive password reset instructions.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                hintText: 'Email address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: primaryGreen, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isNotEmpty) {
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: emailController.text.trim(),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset email sent!'),
                      backgroundColor: primaryGreen,
                    ),
                  );
                } catch (e) {
                  _showErrorDialog('Failed to send reset email. Please check your email address.');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            child: const Text('Send Reset Email', style: TextStyle(color: cardWhite)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGray,
      body: SafeArea(
        // FIX 2: Removed the outer SingleChildScrollView here.
        // The individual tabs now handle their own scrolling.
        child: Column(
          children: [
                  // Header removed per request (logo removed)
                  // 2. Modern Segmented Tab Bar (Fixed Height)
                  _buildModernTabBar(),

            // 3. Tab Views
            // FIX 2: Wrapped in Expanded to take up the remaining screen space, 
            // resolving the shadow clipping/interruption issue.
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginTab(),
                  _buildSignupTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REFINED WIDGETS ---

  Widget _buildModernTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.6),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: primaryGreen,
            borderRadius: BorderRadius.circular(13),
          ),
          labelPadding: EdgeInsets.zero,
          labelColor: cardWhite,
          unselectedLabelColor: textDark,
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),

          tabs: const [
            Tab(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Login'),
              ),
            ),
            Tab(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Sign Up'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // FIX 1: Added the missing "Welcome Back 👋" text
          const Text('Welcome Back 👋', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 4),
          Text('Please log in to your account', style: TextStyle(fontSize: 16, color: textLight, fontWeight: FontWeight.w500)),
          const SizedBox(height: 40),

          // Input Card Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildTextField(
                  label: 'Email Address',
                  hint: 'your.email@example.com',
                  icon: Icons.email_outlined,
                  controller: _loginEmailController,
                ),
                const SizedBox(height: 30),
                _buildPasswordField(
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: _obscurePasswordLogin,
                  onToggle: () => setState(() => _obscurePasswordLogin = !_obscurePasswordLogin),
                  controller: _loginPasswordController,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              child: const Text('Forgot Password?', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 30),
          _buildMainButton('Login', _isLoading ? null : _handleLogin),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(child: Divider(color: textLight.withOpacity(0.3), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Or sign in with', style: TextStyle(color: textLight, fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              Expanded(child: Divider(color: textLight.withOpacity(0.3), thickness: 1)),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              _buildSocialButton(Icons.g_mobiledata, 'Google'),
              const SizedBox(height: 12),
              _buildSocialButton(Icons.apple, 'Apple'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Create Account',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Join CuraScan to book appointments',
            style: TextStyle(
              fontSize: 16,
              color: textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),

          // Input Card Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildTextField(label: 'Full Name', hint: 'John Doe', icon: Icons.person_outline, controller: _signupNameController),
                const SizedBox(height: 30),
                _buildTextField(label: 'Email Address', hint: 'your.email@example.com', icon: Icons.email_outlined, controller: _signupEmailController),
                const SizedBox(height: 30),
                _buildPasswordField(
                  label: 'Password',
                  hint: 'Create a password',
                  obscureText: _obscurePasswordSignup,
                  onToggle: () => setState(() => _obscurePasswordSignup = !_obscurePasswordSignup),
                  controller: _signupPasswordController,
                ),
                const SizedBox(height: 30),
                _buildPasswordField(
                  label: 'Confirm Password',
                  hint: 'Confirm your password',
                  obscureText: _obscurePasswordConfirm,
                  onToggle: () => setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm),
                  controller: _signupConfirmPasswordController,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: true,
                      onChanged: (value) {},
                      activeColor: primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          text: 'I agree to the ',
                          style: TextStyle(color: textLight, fontSize: 13),
                          children: const [
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _buildMainButton('Create Account', _isLoading ? null : _handleSignup),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(child: Divider(color: textLight.withOpacity(0.3), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Or sign up with', style: TextStyle(color: textLight, fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              Expanded(child: Divider(color: textLight.withOpacity(0.3), thickness: 1)),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              _buildSocialButton(Icons.g_mobiledata, 'Google'),
              const SizedBox(height: 12),
              _buildSocialButton(Icons.apple, 'Apple'),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // --- REFINED INPUT WIDGETS (Filled and Defined) ---

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: primaryGreen.withOpacity(0.7), size: 20),
            hintStyle: TextStyle(color: textLight.withOpacity(0.7), fontSize: 15),

            // **IMPROVED FILLED INPUT DESIGN**
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide.none, // Hide default border
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: const BorderSide(color: primaryGreen, width: 2.0), // Accent border on focus
            ),
            filled: true,
            fillColor: lightFill, // Use the light green background
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            isDense: true,
          ),
          style: const TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggle,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(Icons.lock_outline, color: primaryGreen.withOpacity(0.7), size: 20),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: textLight,
                size: 20,
              ),
            ),
            hintStyle: TextStyle(color: textLight.withOpacity(0.7), fontSize: 15),

            // **IMPROVED FILLED INPUT DESIGN**
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide.none, // Hide default border
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: const BorderSide(color: primaryGreen, width: 2.0), // Accent border on focus
            ),
            filled: true,
            fillColor: lightFill, // Use the light green background
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            isDense: true,
          ),
          style: const TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMainButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          elevation: 8,
          shadowColor: primaryGreen.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: cardWhite,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: cardWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String label) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: textLight.withOpacity(0.2), width: 1),
          borderRadius: BorderRadius.circular(15),
          color: cardWhite,
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label login coming soon!'),
                  backgroundColor: primaryGreen,
                ),
              );
            },
            borderRadius: BorderRadius.circular(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textDark, size: 24),
                const SizedBox(width: 8),
                Text(
                  '$label (Coming Soon)',
                  style: const TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}