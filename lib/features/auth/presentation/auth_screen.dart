import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_providers.dart';
import '../../consumer/presentation/consumer_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final String initialRole; // 'consumer' | 'vendor'
  const AuthScreen({super.key, this.initialRole = 'consumer'});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  late String _activeRole; // 'consumer' | 'vendor'
  bool _isSignUp = false; // toggles between Login and Sign Up
  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _entranceController;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  // Form Fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  
  String? _selectedCategory;
  String? _selectedLocation;

  final List<String> _fallbackCategories = ['Venues', 'Catering', 'Decor', 'Photography', 'Music', 'Pyrotechnics', 'Logistics', 'Apparel'];
  final List<String> _fallbackLocations = ['Karachi, Pakistan', 'Lahore, Pakistan', 'Islamabad, Pakistan', 'Faisalabad, Pakistan'];

  @override
  void initState() {
    super.initState();
    _activeRole = widget.initialRole;

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)),
    );

    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTesting) {
      _entranceController.value = 1.0;
    } else {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _switchRole(String role) {
    setState(() {
      _activeRole = role;
      _formKey.currentState?.reset();
    });
  }

  void _toggleAuthMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authNotifier = ref.read(authProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_isSignUp) {
        await authNotifier.signUpWithEmailAndPassword(
          email: email,
          password: password,
          role: _activeRole,
          name: _nameController.text.trim(),
          phone: _activeRole == 'consumer' ? _phoneController.text.trim() : null,
          businessName: _activeRole == 'vendor' ? _businessNameController.text.trim() : null,
          category: _activeRole == 'vendor' ? (_selectedCategory ?? 'Venues') : null,
          location: _activeRole == 'vendor' ? (_selectedLocation ?? 'Karachi, Pakistan') : null,
        );
        _showSnackBar('Account created successfully!', Colors.green);
      } else {
        await authNotifier.signInWithEmailAndPassword(email, password);
        _showSnackBar('Welcome back!', Colors.green);
      }

      // Check final role in AuthState and navigate
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        final finalRole = authState.role ?? (email.contains('admin') ? 'admin' : (email.contains('vendor') ? 'vendor' : 'consumer'));
        if (finalRole == 'admin') {
          context.go('/admin');
        } else if (finalRole == 'vendor') {
          final cat = (authState.category ?? (_isSignUp ? (_selectedCategory ?? '') : '')).toLowerCase();
          if (cat == 'venues') {
            context.go('/venue_portal');
          } else if (cat == 'catering' || cat == 'caters' || cat == 'caterer' || cat == 'caterers') {
            context.go('/cater_portal');
          } else {
            context.go('/vendor');
          }
        } else {
          context.go('/consumer');
        }
      }
    } catch (e) {
      _showSnackBar(e.toString(), Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dynamicCategories = ref.watch(appCategoriesProvider).value?.map((c) => c.name).toList() ?? _fallbackCategories;
    final dynamicLocations = ref.watch(appCitiesProvider).value?.map((c) => c.name).toList() ?? _fallbackLocations;
    
    // Ensure selected values are in the dynamic list
    if (_selectedCategory != null && !dynamicCategories.contains(_selectedCategory)) {
      _selectedCategory = null;
    }
    if (_selectedLocation != null && !dynamicLocations.contains(_selectedLocation)) {
      _selectedLocation = null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EC),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFAF5EC),
              Color(0xFFF7EDD8),
              Color(0xFFFAF5EC),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Sparkles in the background
            const Positioned(top: 60, left: 30, child: LoopingSparkle(scale: 1.1)),
            const Positioned(top: 180, right: 40, child: LoopingSparkle(scale: 0.8)),
            const Positioned(bottom: 240, left: 50, child: LoopingSparkle(scale: 1.0)),
            const Positioned(bottom: 100, right: 60, child: LoopingSparkle(scale: 1.3)),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
                child: FadeTransition(
                  opacity: _cardFade,
                  child: SlideTransition(
                    position: _cardSlide,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Emblem + Title (outside card for breathing room)
                          const AnimatedEmblem(size: 80),
                          const SizedBox(height: 14),
                          Text(
                            _isSignUp ? 'Create Account' : 'Welcome Back',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D103E),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isSignUp ? 'Join the ShadiSphere family' : 'Sign in to access your dashboard',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Main Card
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2D103E).withValues(alpha: 0.06),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(28.0),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Segment Tab Control (Role Switcher)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF5EC),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _buildRoleButton('consumer', 'Customer'),
                                          ),
                                          Expanded(
                                            child: _buildRoleButton('vendor', 'Vendor'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Email input
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: _buildInputDecoration('Email Address', Icons.email_outlined),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) return 'Email is required';
                                        if (!value.contains('@')) return 'Enter a valid email';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),

                                    // Password input
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: _buildInputDecoration(
                                        'Password',
                                        Icons.lock_outlined,
                                        suffixIcon: IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword = !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) return 'Password is required';
                                        if (value.length < 6) return 'Password must be at least 6 characters';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),

                                    // Conditional Fields via AnimatedSize
                                    AnimatedSize(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                      clipBehavior: Clip.hardEdge,
                                      child: _isSignUp
                                          ? Column(
                                              children: [
                                                if (_activeRole == 'consumer') ...[
                                                  TextFormField(
                                                    controller: _nameController,
                                                    decoration: _buildInputDecoration('Full Name', Icons.person_outline),
                                                    validator: (value) {
                                                      if (_isSignUp && (value == null || value.trim().isEmpty)) {
                                                        return 'Name is required';
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                  const SizedBox(height: 14),
                                                  TextFormField(
                                                    controller: _phoneController,
                                                    keyboardType: TextInputType.phone,
                                                    decoration: _buildInputDecoration('Phone Number', Icons.phone_outlined),
                                                    validator: (value) {
                                                      if (_isSignUp && (value == null || value.trim().isEmpty)) {
                                                        return 'Phone number is required';
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                  const SizedBox(height: 14),
                                                ] else ...[
                                                  TextFormField(
                                                    controller: _nameController,
                                                    decoration: _buildInputDecoration('Your Full Name', Icons.person_outline),
                                                    validator: (value) {
                                                      if (_isSignUp && _activeRole == 'vendor' && (value == null || value.trim().isEmpty)) {
                                                        return 'Your name is required';
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                  const SizedBox(height: 14),
                                                  TextFormField(
                                                    controller: _businessNameController,
                                                    decoration: _buildInputDecoration('Business / Venue Name', Icons.storefront_outlined),
                                                    validator: (value) {
                                                      if (_isSignUp && _activeRole == 'vendor' && (value == null || value.trim().isEmpty)) {
                                                        return 'Business name is required';
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                  const SizedBox(height: 14),
                                                  
                                                  // Dropdown Category selection
                                                  DropdownButtonFormField<String>(
                                                    isExpanded: true,
                                                    value: _selectedCategory ?? (dynamicCategories.isNotEmpty ? dynamicCategories.first : null),
                                                    decoration: _buildInputDecoration('Business Category', Icons.category_outlined),
                                                    items: dynamicCategories.map((cat) {
                                                      return DropdownMenuItem(value: cat, child: Text(cat));
                                                    }).toList(),
                                                    onChanged: (val) {
                                                      if (val != null) {
                                                        setState(() {
                                                          _selectedCategory = val;
                                                        });
                                                      }
                                                    },
                                                  ),
                                                  const SizedBox(height: 14),

                                                  // Dropdown Location selection
                                                  DropdownButtonFormField<String>(
                                                    isExpanded: true,
                                                    value: _selectedLocation ?? (dynamicLocations.isNotEmpty ? dynamicLocations.first : null),
                                                    decoration: _buildInputDecoration('Business City', Icons.location_on_outlined),
                                                    items: dynamicLocations.map((loc) {
                                                      return DropdownMenuItem(value: loc, child: Text(loc));
                                                    }).toList(),
                                                    onChanged: (val) {
                                                      if (val != null) {
                                                        setState(() {
                                                          _selectedLocation = val;
                                                        });
                                                      }
                                                    },
                                                  ),
                                                  const SizedBox(height: 14),
                                                ]
                                              ],
                                            )
                                          : const SizedBox.shrink(),
                                    ),

                                    const SizedBox(height: 8),

                                    // Submit Button
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: _isLoading
                                            ? null
                                            : const LinearGradient(
                                                colors: [Color(0xFF2D103E), Color(0xFF4C1D66)],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ),
                                        color: _isLoading ? Colors.grey.shade300 : null,
                                        boxShadow: _isLoading
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: const Color(0xFF2D103E).withValues(alpha: 0.25),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _isLoading ? null : _submitForm,
                                          borderRadius: BorderRadius.circular(16),
                                          child: Container(
                                            height: 54,
                                            alignment: Alignment.center,
                                            child: _isLoading
                                                ? const SizedBox(
                                                    height: 24,
                                                    width: 24,
                                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                                  )
                                                : Text(
                                                    _isSignUp ? 'Create Account' : 'Log In',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Toggle Auth Mode
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                        GestureDetector(
                                          onTap: _isLoading ? null : _toggleAuthMode,
                                          child: Text(
                                            _isSignUp ? 'Log In' : 'Sign Up',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xFFD4AF37),
                                              decoration: TextDecoration.underline,
                                              decorationColor: Color(0xFFD4AF37),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Back to Welcome (outside card)
                          TextButton.icon(
                            onPressed: () => context.go('/welcome'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade500,
                            ),
                            icon: Icon(Icons.arrow_back_rounded, size: 16, color: Colors.grey.shade500),
                            label: Text(
                              'Back to Welcome',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildRoleButton(String role, String label) {
    final isSelected = _activeRole == role;
    return GestureDetector(
      onTap: () => _switchRole(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF2D103E), Color(0xFF4C1D66)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF2D103E).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              role == 'consumer' ? Icons.person_outline : Icons.storefront_outlined,
              color: isSelected ? Colors.white : Colors.grey.shade500,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Icon(icon, color: const Color(0xFFD4AF37).withValues(alpha: 0.7), size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      filled: true,
      fillColor: const Color(0xFFFAF5EC).withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFF0E5D8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFF0E5D8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2D103E), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

// LoopingSparkle and AnimatedEmblem defined here to avoid circular imports with app_router.dart
class LoopingSparkle extends StatefulWidget {
  final double scale;
  const LoopingSparkle({super.key, this.scale = 1.0});

  @override
  State<LoopingSparkle> createState() => _LoopingSparkleState();
}

class _LoopingSparkleState extends State<LoopingSparkle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTesting) {
      _controller.value = 1.0;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.1, end: 0.7).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Transform.scale(
        scale: widget.scale,
        child: const Icon(
          Icons.auto_awesome,
          color: Color(0xFFD4AF37),
          size: 12,
        ),
      ),
    );
  }
}

class AnimatedEmblem extends StatelessWidget {
  final double size;
  final bool animate;
  const AnimatedEmblem({super.key, this.size = 110, this.animate = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
            blurRadius: size * 0.25,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFF2D103E).withValues(alpha: 0.1),
            blurRadius: size * 0.4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Transform.scale(
          scale: 1.25,
          child: Image.asset(
            'assets/images/royal_logo.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/images/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0xFF6B2FA0), Color(0xFF2D103E)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'SS',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: size * 0.4,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD4AF37),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
