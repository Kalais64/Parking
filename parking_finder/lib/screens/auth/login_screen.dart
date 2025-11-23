import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors_new.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isPhoneLogin = false;
  bool _isOTPMode = false;
  String? _verificationId;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: AppColorsNew.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColorsNew.primaryGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Logo and Title
                _buildHeader(),
                
                const SizedBox(height: 48),
                
                // Login Method Toggle
                _buildLoginMethodToggle(),
                
                const SizedBox(height: 32),
                
                // Login Form
                _buildLoginForm(),
                
                const SizedBox(height: 24),
                
                // Additional Options
                _buildAdditionalOptions(),
                
                const SizedBox(height: 32),
                
                // Social Login
                _buildSocialLogin(),
                
                const SizedBox(height: 24),
                
                // Register Option
                _buildRegisterOption(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // App Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColorsNew.accentGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.local_parking,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        
        Text(
          'Park Smarter',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: AppColorsNew.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Masuk untuk melanjutkan',
          style: TextStyle(
            fontSize: 16,
            color: AppColorsNew.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginMethodToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColorsNew.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isPhoneLogin = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isPhoneLogin ? AppColorsNew.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isPhoneLogin ? AppColorsNew.buttonText : AppColorsNew.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isPhoneLogin = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isPhoneLogin ? AppColorsNew.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Nomor HP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isPhoneLogin ? AppColorsNew.buttonText : AppColorsNew.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isOTPMode) ...[
            // Email/Phone Input
            if (_isPhoneLogin)
              _buildPhoneInput()
            else
              _buildEmailInput(),
            
            const SizedBox(height: 16),
            
            // Password Input (only for email login)
            if (!_isPhoneLogin)
              _buildPasswordInput(),
          ] else ...[
            // OTP Input
            _buildOTPInput(),
          ],
          
          const SizedBox(height: 24),
          
          // Login Button
          _buildLoginButton(),
          
          if (_isOTPMode) ...[
            const SizedBox(height: 16),
            // Back to login method
            TextButton(
              onPressed: () => setState(() => _isOTPMode = false),
              child: Text(
                'Kembali',
                style: TextStyle(
                  color: AppColorsNew.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailInput() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'Masukkan email Anda',
        prefixIcon: const Icon(Icons.email_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: AppColorsNew.surface,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Email tidak boleh kosong';
        }
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
          return 'Format email tidak valid';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneInput() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(13),
      ],
      decoration: InputDecoration(
        labelText: 'Nomor HP',
        hintText: '81234567890',
        prefixIcon: const Icon(Icons.phone_outlined),
        prefixText: '+62 ',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: AppColorsNew.surface,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Nomor HP tidak boleh kosong';
        }
        if (value.length < 10 || value.length > 13) {
          return 'Nomor HP harus 10-13 digit';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordInput() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Masukkan password Anda',
        prefixIcon: const Icon(Icons.lock_outlined),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: AppColorsNew.surface,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Password tidak boleh kosong';
        }
        if (value.length < 6) {
          return 'Password minimal 6 karakter';
        }
        return null;
      },
    );
  }

  Widget _buildOTPInput() {
    return Column(
      children: [
        Text(
          'Masukkan kode OTP yang telah dikirim ke ${_isPhoneLogin ? '+62 ${_phoneController.text}' : _emailController.text}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColorsNew.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            hintText: '123456',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AppColorsNew.surface,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'OTP tidak boleh kosong';
            }
            if (value.length != 6) {
              return 'OTP harus 6 digit';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Tidak menerima kode? ',
              style: TextStyle(
                color: AppColorsNew.textSecondary,
                fontSize: 14,
              ),
            ),
            TextButton(
              onPressed: () {
                // Resend OTP logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kode OTP telah dikirim ulang')),
                );
              },
              child: Text(
                'Kirim Ulang',
                style: TextStyle(
                  color: AppColorsNew.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsNew.accent,
          foregroundColor: AppColorsNew.buttonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColorsNew.buttonText),
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isOTPMode ? 'Verifikasi' : 'Masuk',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildAdditionalOptions() {
    return Column(
      children: [
        if (!_isOTPMode && !_isPhoneLogin) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  // Forgot password logic
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Lupa Password'),
                      content: const Text('Kami akan mengirimkan link reset password ke email Anda.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Link reset password telah dikirim')),
                            );
                          },
                          child: const Text('Kirim'),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  'Lupa Password?',
                  style: TextStyle(
                    color: AppColorsNew.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_isPhoneLogin && !_isOTPMode) ...[
          Text(
            'Kami akan mengirimkan kode OTP ke nomor Anda',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColorsNew.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSocialLogin() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: AppColorsNew.textSecondary.withValues(alpha: 0.3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'atau masuk dengan',
                style: TextStyle(
                  color: AppColorsNew.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: AppColorsNew.textSecondary.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleGoogleSignIn(),
                icon: const Icon(Icons.g_mobiledata, size: 24),
                label: const Text('Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleAppleSignIn(),
                icon: const Icon(Icons.apple, size: 20),
                label: const Text('Apple'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Belum punya akun? ',
          style: TextStyle(
            color: AppColorsNew.textSecondary,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () {
            // Navigate to register screen
            Navigator.pushNamed(context, '/register');
          },
          child: Text(
            'Daftar',
            style: TextStyle(
              color: AppColorsNew.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      if (_isOTPMode) {
        // Verify OTP
        _verifyOTP();
      } else if (_isPhoneLogin) {
        // Send OTP for phone login
        _sendOTP();
      } else {
        // Email login
        _loginWithEmail();
      }
    }
  }

  // Handle Google Sign In
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      final userCredential = await _authService.signInWithGoogle();
      
      if (userCredential != null && mounted) {
        // Login successful
        Navigator.pushReplacementNamed(context, '/');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login dengan Google berhasil!')),
        );
      } else if (mounted) {
        // User canceled Google sign-in
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Google dibatalkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Google gagal: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Handle Apple Sign In
  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      final userCredential = await _authService.signInWithApple();
      
      if (userCredential != null && mounted) {
        // Login successful
        Navigator.pushReplacementNamed(context, '/');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login dengan Apple berhasil!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Apple gagal: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Send OTP for phone authentication
  Future<void> _sendOTP() async {
    final phoneNumber = '+62${_phoneController.text.trim()}';
    
    await _authService.verifyPhoneNumber(
      phoneNumber,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _isOTPMode = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Kode OTP telah dikirim ke $phoneNumber')),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengirim OTP: $error')),
          );
        }
      },
      onAutoVerify: (credential) async {
        // Auto verification completed
        try {
          await _authService.verifyOTP(_verificationId ?? '', credential.smsCode ?? '');
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Login berhasil!')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Verifikasi otomatis gagal')),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      },
    );
  }

  // Verify OTP
  Future<void> _verifyOTP() async {
    if (_verificationId == null) return;
    
    try {
      final userCredential = await _authService.verifyOTP(
        _verificationId!,
        _otpController.text.trim(),
      );
      
      if (userCredential != null && mounted) {
        Navigator.pushReplacementNamed(context, '/');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login berhasil!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kode OTP salah atau kedaluwarsa')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Login with email and password
  Future<void> _loginWithEmail() async {
    try {
      await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login berhasil!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login gagal: Email atau password salah')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}