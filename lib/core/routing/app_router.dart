import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/consumer/presentation/consumer_shell.dart';
import '../../features/vendor_dashboard/presentation/vendor_shell.dart';
import '../../features/vendor_dashboard/presentation/venue_portal.dart';
import '../../features/vendor_dashboard/presentation/cater_portal.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/consumer/presentation/consumer_providers.dart';
import '../../features/auth/presentation/auth_screen.dart' hide LoopingSparkle, AnimatedEmblem;
import '../../features/auth/presentation/auth_providers.dart';
import '../widgets/responsive_wrapper.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ResponsiveWrapper(child: SplashScreen()),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const ResponsiveWrapper(child: WelcomeScreen()),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'consumer';
        return ResponsiveWrapper(child: AuthScreen(initialRole: role));
      },
    ),
    GoRoute(
      path: '/consumer',
      builder: (context, state) => const ResponsiveWrapper(child: ConsumerShell()),
    ),
    GoRoute(
      path: '/vendor',
      builder: (context, state) => const ResponsiveWrapper(child: VendorShell()),
    ),
    GoRoute(
      path: '/venue_portal',
      builder: (context, state) => const ResponsiveWrapper(child: VenuePortalShell()),
    ),
    GoRoute(
      path: '/cater_portal',
      builder: (context, state) => const ResponsiveWrapper(child: CaterPortalShell()),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const ResponsiveWrapper(child: AdminShell()),
    ),
    GoRoute(
      path: '/consumer/saved_vendors',
      builder: (context, state) => const ResponsiveWrapper(child: SavedVendorsScreen()),
    ),
    GoRoute(
      path: '/consumer/my_bookings',
      builder: (context, state) => const ResponsiveWrapper(child: MyBookingsScreen()),
    ),
    GoRoute(
      path: '/consumer/vendor_replies',
      builder: (context, state) => const ResponsiveWrapper(child: VendorRepliesScreen()),
    ),
    GoRoute(
      path: '/consumer/settings',
      builder: (context, state) => const ResponsiveWrapper(child: SettingsScreen()),
    ),
    GoRoute(
      path: '/consumer/profile_details',
      builder: (context, state) => const ResponsiveWrapper(child: ProfileDetailsScreen()),
    ),
    GoRoute(
      path: '/consumer/notifications',
      builder: (context, state) => const ResponsiveWrapper(child: NotificationsScreen()),
    ),
    GoRoute(
      path: '/consumer/category/:categoryName',
      builder: (context, state) {
        final categoryName = state.pathParameters['categoryName'] ?? 'Venues';
        return ResponsiveWrapper(child: CategoryListScreen(categoryName: categoryName));
      },
    ),
    GoRoute(
      path: '/consumer/categories',
      builder: (context, state) => const ResponsiveWrapper(child: AllCategoriesScreen()),
    ),
    GoRoute(
      path: '/consumer/top_picks',
      builder: (context, state) => const ResponsiveWrapper(child: TopPicksScreen()),
    ),
    GoRoute(
      path: '/consumer/vendor_detail',
      builder: (context, state) {
        final vendor = state.extra as Vendor;
        return ResponsiveWrapper(child: VendorDetailScreen(vendor: vendor));
      },
    ),
    GoRoute(
      path: '/consumer/venue_pick_date',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final vendor = extra['vendor'] as Vendor;
        final profileData = extra['profileData'] as Map<String, dynamic>?;
        return ResponsiveWrapper(child: VenueDatePickerScreen(vendor: vendor, initialProfileData: profileData));
      },
    ),
    GoRoute(
      path: '/consumer/make_payment',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final ledgerCode = extra['ledgerCode'] as String? ?? '';
        final items = (extra['items'] as List<dynamic>?)?.cast<LedgerItem>() ?? [];
        final totalAmount = double.tryParse(extra['totalAmount']?.toString() ?? '0') ?? 0.0;
        return ResponsiveWrapper(
          child: MakePaymentScreen(
            ledgerCode: ledgerCode,
            items: items,
            totalAmount: totalAmount,
          ),
        );
      },
    ),
    GoRoute(
      path: '/consumer/saved_cards',
      builder: (context, state) => const ResponsiveWrapper(child: SavedCardsScreen()),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// SPLASH SCREEN — Cinematic staggered entrance
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _emblemScale;
  late Animation<double> _emblemFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _dividerWidth;
  late Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains('Test');

    // Main staggered entrance animation
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Shimmer controller for gold text shimmer
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Pulse controller for loading ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Emblem: 0% → 40%
    _emblemScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack)),
    );
    _emblemFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)),
    );

    // Title: 25% → 60%
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.25, 0.55, curve: Curves.easeOut)),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic)),
    );

    // Gold divider line: 40% → 70%
    _dividerWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 0.7, curve: Curves.easeInOut)),
    );

    // Subtitle: 55% → 80%
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.55, 0.8, curve: Curves.easeOut)),
    );

    // Loader: 70% → 100%
    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.7, 1.0, curve: Curves.easeOut)),
    );

    if (isTesting) {
      _mainController.value = 1.0;
      _shimmerController.value = 1.0;
      _pulseController.value = 1.0;
    } else {
      _mainController.forward();
      _shimmerController.repeat();
      _pulseController.repeat(reverse: true);
    }

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) context.go('/welcome');
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A28),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/images/splash_bg.png',
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                child: child,
              );
            },
          ),
          // Gradient overlay — darker, more cinematic
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A0A28).withValues(alpha: 0.55),
                  const Color(0xFF2D103E).withValues(alpha: 0.75),
                  const Color(0xFF1A0A28).withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Floating gold particles
          if (!isTesting) ..._buildFloatingParticles(),

          // Center content
          SafeArea(
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, _) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),

                      // Emblem with glow ring
                      FadeTransition(
                        opacity: _emblemFade,
                        child: ScaleTransition(
                          scale: _emblemScale,
                          child: _buildGlowingEmblem(),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Title with shimmer
                      FadeTransition(
                        opacity: _titleFade,
                        child: SlideTransition(
                          position: _titleSlide,
                          child: _buildShimmerTitle(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Gold divider line
                      AnimatedBuilder(
                        animation: _dividerWidth,
                        builder: (context, _) {
                          return Container(
                            height: 1.5,
                            width: 120 * _dividerWidth.value,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFFD4AF37).withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Subtitle
                      FadeTransition(
                        opacity: _subtitleFade,
                        child: Text(
                          'YOUR ALL-IN-ONE WEDDING APP',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            letterSpacing: 4.0,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const Spacer(flex: 4),

                      // Loading ring
                      FadeTransition(
                        opacity: _loaderFade,
                        child: _buildLoadingRing(isTesting),
                      ),
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: _loaderFade,
                        child: Text(
                          'PLANNING YOUR PERFECT DAY',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                            letterSpacing: 3.0,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const Spacer(flex: 1),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingEmblem() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = 0.8 + (_pulseController.value * 0.4);
        return Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.15 * pulse),
                blurRadius: 40 * pulse,
                spreadRadius: 8 * pulse,
              ),
              BoxShadow(
                color: const Color(0xFF6B2FA0).withValues(alpha: 0.15 * pulse),
                blurRadius: 60 * pulse,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(3),
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
                          child: const Center(
                            child: Text(
                              'SS',
                              style: TextStyle(
                                fontFamily: 'PlayfairDisplay',
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD4AF37),
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
          ),
        );
      },
    );
  }

  Widget _buildShimmerTitle() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFFF9E5B5),
                Color(0xFFFFD700),
                Color(0xFFF9E5B5),
              ],
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value,
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: const Text(
            'SHADI SPHERE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 44,
              letterSpacing: 3.0,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingRing(bool isTesting) {
    if (isTesting) return const SizedBox(width: 44, height: 44);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.lerp(
                      const Color(0xFFD4AF37).withValues(alpha: 0.4),
                      const Color(0xFFD4AF37),
                      _pulseController.value,
                    )!,
                  ),
                ),
              ),
              Icon(
                Icons.favorite,
                color: Color.lerp(
                  const Color(0xFFD4AF37).withValues(alpha: 0.3),
                  const Color(0xFFD4AF37).withValues(alpha: 0.8),
                  _pulseController.value,
                ),
                size: 16,
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildFloatingParticles() {
    final rng = Random(42);
    return List.generate(8, (i) {
      final left = rng.nextDouble() * 350;
      final top = rng.nextDouble() * 700;
      final size = 2.0 + rng.nextDouble() * 4;
      final delay = rng.nextDouble() * 3;
      return Positioned(
        left: left,
        top: top,
        child: _FloatingParticle(size: size, delay: delay),
      );
    });
  }
}

class _FloatingParticle extends StatefulWidget {
  final double size;
  final double delay;
  const _FloatingParticle({required this.size, required this.delay});

  @override
  State<_FloatingParticle> createState() => _FloatingParticleState();
}

class _FloatingParticleState extends State<_FloatingParticle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3000 + (widget.delay * 1000).toInt()),
    );
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTesting) {
      Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
        if (mounted) _controller.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = (0.1 + _controller.value * 0.5).clamp(0.0, 1.0);
        final translateY = -8 + (_controller.value * 16);
        return Transform.translate(
          offset: Offset(0, translateY),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD4AF37).withValues(alpha: opacity),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: opacity * 0.5),
                  blurRadius: widget.size * 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WELCOME SCREEN — Premium wedding app landing
// ─────────────────────────────────────────────────────────────────────────────
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _entranceController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _carouselFade;
  late Animation<double> _buttonsFade;
  Timer? _timer;
  int _currentPage = 0;

  final List<String> _images = [
    'https://images.unsplash.com/photo-1583939003579-730e3918a45a?q=80&w=800&auto=format&fit=crop',
    'assets/images/carousel_2.jpg',
    'assets/images/carousel_3.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains('Test');

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );
    _carouselFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)),
    );
    _buttonsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );

    if (isTesting) {
      _entranceController.value = 1.0;
    } else {
      _entranceController.forward();
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_pageController.hasClients) {
          final nextPage = (_currentPage + 1) % _images.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Auto-redirect if already logged in
    if (authState.isAuthenticated) {
      final email = authState.email ?? '';
      final finalRole = authState.role ?? (email.contains('admin') ? 'admin' : (email.contains('vendor') ? 'vendor' : 'consumer'));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (finalRole == 'admin') {
          context.go('/admin');
        } else if (finalRole == 'vendor') {
          final cat = authState.category?.toLowerCase() ?? '';
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
      });
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
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Subtle decorative gold corner accents
            _buildCornerAccent(top: 0, left: 0, angle: 0),
            _buildCornerAccent(top: 0, right: 0, angle: pi / 2),
            _buildCornerAccent(bottom: 0, left: 0, angle: -pi / 2),
            _buildCornerAccent(bottom: 0, right: 0, angle: pi),

            // Floating sparkles
            const Positioned(top: 70, left: 30, child: LoopingSparkle(scale: 1.3)),
            const Positioned(top: 140, right: 35, child: LoopingSparkle(scale: 0.9)),
            const Positioned(bottom: 200, left: 50, child: LoopingSparkle(scale: 1.1)),
            const Positioned(bottom: 90, right: 55, child: LoopingSparkle(scale: 1.5)),
            const Positioned(top: 300, left: 15, child: LoopingSparkle(scale: 0.7)),
            const Positioned(bottom: 350, right: 20, child: LoopingSparkle(scale: 0.8)),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),

                        // Header section with entrance animation
                        FadeTransition(
                          opacity: _headerFade,
                          child: SlideTransition(
                            position: _headerSlide,
                            child: Column(
                              children: [
                                // Logo
                                const AnimatedEmblem(size: 100),
                                const SizedBox(height: 16),
                                // Gold sparkle divider above title
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(width: 30, height: 0.5, color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
                                    const SizedBox(width: 8),
                                    Icon(Icons.auto_awesome, size: 12, color: const Color(0xFFD4AF37).withValues(alpha: 0.7)),
                                    const SizedBox(width: 8),
                                    Container(width: 30, height: 0.5, color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Welcome to',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'PlayfairDisplay',
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFFD4AF37),
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Shadi Sphere',
                                  style: TextStyle(
                                    fontFamily: 'PlayfairDisplay',
                                    fontSize: 36,
                                    color: Color(0xFF2D103E),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Your all-in-one wedding planning companion',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    letterSpacing: 0.3,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Carousel with entrance animation
                        FadeTransition(
                          opacity: _carouselFade,
                          child: _buildCarousel(),
                        ),
                        const SizedBox(height: 14),
                        FadeTransition(
                          opacity: _carouselFade,
                          child: _buildIndicatorDots(),
                        ),
                        const SizedBox(height: 24),

                        // Buttons with entrance animation
                        FadeTransition(
                          opacity: _buttonsFade,
                          child: Column(
                            children: [
                              _buildGetStartedButton(authState),
                              const SizedBox(height: 14),
                              _buildBrowseAsGuestButton(),
                              const SizedBox(height: 20),
                              _buildPortalCardsRow(authState),
                              const SizedBox(height: 20),
                              // Footer
                              Text(
                                'By continuing, you agree to our Terms & Conditions and Privacy Policy',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
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

  Widget _buildCornerAccent({double? top, double? bottom, double? left, double? right, required double angle}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.25), width: 1.5),
              left: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.25), width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return Container(
      height: 220,
      width: 170,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(110),
          topRight: Radius.circular(110),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D103E).withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(104),
            topRight: Radius.circular(104),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final isActive = _currentPage == index;
                  return TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 5),
                    tween: Tween<double>(begin: 1.0, end: isActive ? 1.12 : 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: _images[index].startsWith('http')
                            ? Image.network(
                                _images[index],
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  final isTesting = WidgetsBinding.instance.runtimeType.toString().contains('Test');
                                  if (isTesting) return child;
                                  return Container(
                                    color: const Color(0xFFFAF5EC),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Image.asset(
                                _images[index],
                                fit: BoxFit.cover,
                              ),
                      );
                    },
                  );
                },
              ),
              // Subtle bottom gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF2D103E).withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_images.length, (index) {
        final isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isActive ? 24 : 6,
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF2D103E), Color(0xFF4C1D66)],
                  )
                : null,
            color: isActive ? null : const Color(0xFFD4AF37).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildGetStartedButton(AuthState authState) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D103E).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (authState.isAuthenticated) {
            final email = authState.email ?? '';
            final finalRole = authState.role ?? (email.contains('admin') ? 'admin' : (email.contains('vendor') ? 'vendor' : 'consumer'));
            if (finalRole == 'admin') {
              context.go('/admin');
            } else if (finalRole == 'vendor') {
              final cat = authState.category?.toLowerCase() ?? '';
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
          } else {
            context.go('/auth?role=consumer');
          }
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2D103E), Color(0xFF4C1D66)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  authState.isAuthenticated ? 'Enter ShadiSphere' : 'Get Started / Log In',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrowseAsGuestButton() {
    return TextButton(
      onPressed: () => context.go('/consumer'),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF2D103E),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Browse as Guest',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Color(0xFF2D103E),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: const Color(0xFFD4AF37).withValues(alpha: 0.8)),
        ],
      ),
    );
  }

  Widget _buildPortalCardsRow(AuthState authState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (authState.isAuthenticated) {
              final email = authState.email ?? '';
              final finalRole = authState.role ?? (email.contains('admin') ? 'admin' : (email.contains('vendor') ? 'vendor' : 'consumer'));
              if (finalRole == 'admin') {
                context.go('/admin');
              } else if (finalRole == 'vendor') {
                final cat = authState.category?.toLowerCase() ?? '';
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
            } else {
              context.go('/auth?role=vendor');
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D103E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFF2D103E), size: 18),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Vendor Portal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2D103E),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      'Manage your business',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Widgets — LoopingSparkle & AnimatedEmblem
// ─────────────────────────────────────────────────────────────────────────────
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
