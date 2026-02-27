import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';
import 'package:autodentifyr/presentation/bloc/auth/auth_bloc.dart';
import 'package:sign_in_button/sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppPalette.appBlue, AppPalette.blackColor],
          ),
        ),
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppPalette.redColor,
                ),
              );
            } else if (state is AuthPasswordResetEmailSent) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password reset email sent! Check your inbox.'),
                  backgroundColor: AppPalette.appGreen,
                ),
              );
            }
          },
          builder: (context, state) {
            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo or Title
                      /* const Icon(
                        Icons.car_repair_rounded,
                        color: AppPallete.whiteColor,
                        size: 80,
                      ), */
                      Image.asset(
                        'assets/app_icon.png',
                        width: 100,
                        height: 100,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'AutoDentifyr',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: AppPalette.whiteColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Damage Decoded',
                        style: TextStyle(
                          color: AppPalette.appGreen,
                          fontSize: 16,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Email Field
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),

                      if (!_isSignUp)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              final email = _emailController.text.trim();
                              if (email.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter your email first.',
                                    ),
                                    backgroundColor: AppPalette.redColor,
                                  ),
                                );
                                return;
                              }
                              context.read<AuthBloc>().add(
                                AuthPasswordResetRequested(email),
                              );
                            },
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: AppPalette.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Email/Password Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: state is AuthLoading
                              ? null
                              : () {
                                  final email = _emailController.text.trim();
                                  final password = _passwordController.text
                                      .trim();
                                  if (email.isNotEmpty && password.isNotEmpty) {
                                    if (_isSignUp) {
                                      context.read<AuthBloc>().add(
                                        AuthSignUpRequested(email, password),
                                      );
                                    } else {
                                      context.read<AuthBloc>().add(
                                        AuthLoginRequested(email, password),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.appGreen,
                            foregroundColor: AppPalette.appBlue,
                            // shape: RoundedRectangleBorder(
                            //   borderRadius: BorderRadius.circular(12),
                            // ),
                            shape: const StadiumBorder(),
                            elevation: 8,
                          ),
                          child: state is AuthLoading
                              ? const CircularProgressIndicator(
                                  color: AppPalette.appBlue,
                                )
                              : Text(
                                  _isSignUp ? 'REGISTER' : 'LOGIN',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Toggle Mode
                      TextButton(
                        onPressed: () => setState(() => _isSignUp = !_isSignUp),
                        child: Text(
                          _isSignUp
                              ? 'Already have an account? Login'
                              : 'New here? Create an account',
                          style: TextStyle(color: AppPalette.white70),
                        ),
                      ),

                      // ── OR Divider ──
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: AppPalette.white70,
                              thickness: 0.5,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: AppPalette.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppPalette.white70,
                              thickness: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Google Sign-In Button
                      SizedBox(
                        width: double.infinity,
                        child: SignInButton(
                          Buttons.google,
                          text: "Continue with Google",
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          onPressed: state is AuthLoading
                              ? () {}
                              : () {
                                  context.read<AuthBloc>().add(
                                    AuthGoogleSignInRequested(),
                                  );
                                },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppPalette.whiteColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppPalette.white70),
        prefixIcon: Icon(icon, color: AppPalette.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.appGreen),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.appGreen),
        ),
        filled: true,
        fillColor: AppPalette.textFieldFillColor,
      ),
    );
  }
}
