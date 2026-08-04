import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'vendor_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../admin/presentation/admin_providers.dart';
import 'cater_onboarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Colors (ShadiSphere – Emerald Green & Gold Wedding Theme)
const _primaryDark = Color(0xFF064E3B);   // Deep Emerald Green
const _accentGold = Color(0xFFD4AF37);    // Classic Luxury Gold
const _bgOffWhite = Color(0xFFF8FAF9);    // Crisp light background

/// Format a number as a readable currency string: Rs. 1,000,000
String _formatCurrency(double amount) {
  if (amount == 0) return 'Rs. 0';
  String s = amount.toStringAsFixed(0);
  // Add commas for thousands
  final result = StringBuffer();
  int count = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) result.write(',');
    result.write(s[i]);
    count++;
  }
  return 'Rs. ${result.toString().split('').reversed.join()}';
}

Future<bool?> _showLuxuryConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
  Color confirmColor = const Color(0xFF991B1B),
  IconData icon = Icons.warning_amber_rounded,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dlgCtx) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: _accentGold.withValues(alpha: 0.3), width: 1.5),
      ),
      backgroundColor: Colors.white,
      elevation: 16,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: confirmColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: confirmColor.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Icon(icon, color: confirmColor, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _primaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(dlgCtx, false),
                    child: Text('Cancel', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: confirmColor.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(dlgCtx, true),
                    child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold)),
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

class CaterPortalShell extends ConsumerStatefulWidget {
  const CaterPortalShell({super.key});

  @override
  ConsumerState<CaterPortalShell> createState() => _CaterPortalShellState();
}

class _CaterPortalShellState extends ConsumerState<CaterPortalShell> {
  int _selectedIndex = 0;

  void selectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  // 10 views total:
  // 0-3: Bottom nav (Dashboard, Bookings, Catalog, Messages)
  // 4-9: Sidebar-only (Promotions, Availability, Analytics, Reviews, Profile, Settings)
  List<Widget> get _views => [
    const CaterDashboardOverview(),   // 0
    const CaterPricingView(),         // 1 (Manage)
    const CaterBookingsView(),        // 2 (Bookings)
    const CaterMessagesView(),        // 3
    const CaterPromotionsView(),      // 4
    const CaterAvailabilityView(),    // 5
    const CaterAnalyticsView(),       // 6
    const CaterReviewsView(),         // 7
    const CaterProfileView(),         // 8
    const CaterSettingsView(),        // 9
  ];

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 750;
    final profile = ref.watch(vendorProfileProvider);
    
    if (profile.accountStatus == 'suspended') {
      return Scaffold(
        backgroundColor: _bgOffWhite,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF991B1B).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded, color: Color(0xFF991B1B), size: 64),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Account Suspended',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _primaryDark,
                    fontFamily: 'PlayfairDisplay',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your caterer account has been suspended due to compliance violations. Your catalog has been revoked and you have been removed from all consumer ledgers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _handleLogout(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF991B1B),
                        side: const BorderSide(color: Color(0xFF991B1B)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.exit_to_app_rounded),
                      label: const Text('Exit Portal'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (!profile.hasAcceptedTerms) {
      return Scaffold(
        backgroundColor: _bgOffWhite,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gavel_rounded, color: _primaryDark, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Caterer Terms & Conditions',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _primaryDark,
                      fontFamily: 'PlayfairDisplay',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: const SingleChildScrollView(
                      child: Text(
                        'By continuing to use the ShadiSphere Caterer Portal, you agree to the following Terms and Conditions:\n\n'
                        '1. Quality Assurance: You must maintain a minimum average rating of 3.5 stars. Falling below this threshold may result in suspension.\n\n'
                        '2. Prompt Responses: You agree to respond to consumer inquiries within 48 hours.\n\n'
                        '3. Accurate Representation: All catering menus, dishes, and pricing listed in your catalog must be accurate and up-to-date.\n\n'
                        '4. Professional Conduct: Any reports of unprofessional behavior or fraud will result in immediate termination of your vendor account.\n\n'
                        '5. Platform Fees: You agree to ShadiSphere\'s commission and subscription fee structures as updated from time to time.\n\n'
                        'By clicking "Accept", you acknowledge that you have read and understood these rules.',
                        style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      OutlinedButton(
                        onPressed: () => _handleLogout(context, ref),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF991B1B),
                          side: const BorderSide(color: Color(0xFF991B1B)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Decline & Exit'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid != null) {
                            await FirebaseFirestore.instance.collection('vendors').doc(uid).update({'hasAcceptedTerms': true});
                            await FirebaseFirestore.instance.collection('vendor_profile').doc(uid).update({'hasAcceptedTerms': true});
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: _primaryDark,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('I Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    if (!profile.isSetupComplete) {
      return const CaterOnboardingScreen();
    }

    final safeIndex = _selectedIndex >= 0 && _selectedIndex < _views.length ? _selectedIndex : 0;

    final Widget mainView = AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(safeIndex),
        child: _views[safeIndex],
      ),
    );

    if (isMobile) {
      return Scaffold(
        backgroundColor: _bgOffWhite,
        appBar: AppBar(
          backgroundColor: _primaryDark,
          elevation: 4,
          shadowColor: _primaryDark.withValues(alpha: 0.4),
          iconTheme: const IconThemeData(color: _accentGold),
          title: const Text('Catering Dashboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'PlayfairDisplay')),
        ),
        drawer: Drawer(
          width: 280,
          backgroundColor: Colors.transparent,
          child: _buildMobileDrawerContent(context),
        ),
        body: mainView,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: safeIndex < 4 ? safeIndex : 0,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: Colors.white,
          selectedItemColor: _primaryDark,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 12,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_rounded), label: 'Pricing'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Bookings'),
            BottomNavigationBarItem(icon: Icon(Icons.forum_rounded), label: 'Messages'),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgOffWhite,
      body: Row(
        children: [
          _buildDesktopSidebar(context),
          Expanded(
            child: Column(
              children: [
                _buildDesktopHeader(context),
                Expanded(child: mainView),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _accentGold.withValues(alpha: 0.3), width: 1.5),
        ),
        backgroundColor: Colors.white,
        elevation: 16,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF991B1B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF991B1B).withValues(alpha: 0.3), width: 1.5),
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFF991B1B), size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Exit Caterer Portal',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _primaryDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to log out? Any unsaved changes in your active session will be closed.',
                style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('Cancel', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF991B1B),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFF991B1B).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        ref.invalidate(vendorCatalogProvider);
                        ref.invalidate(vendorMessagesProvider);
                        ref.invalidate(vendorReviewsProvider);
                        ref.invalidate(vendorPromotionsProvider);
                        ref.invalidate(vendorProfileProvider);
                        ref.invalidate(uploadedMediaProvider);
                        ref.invalidate(vendorAvailabilityProvider);
                        ref.invalidate(quickReplyTemplatesProvider);
                        ref.invalidate(vendorInquiriesProvider);
                        ref.invalidate(vendorAnalyticsProvider);
                        ref.invalidate(vendorPerformanceTipsProvider);
                        ref.invalidate(vendorBookingFilterProvider);
                        ref.invalidate(vendorBookingSearchProvider);

                        await ref.read(authProvider.notifier).signOut();
                        if (context.mounted) {
                          Navigator.pop(dialogContext);
                          context.go('/welcome');
                        }
                      },
                      child: const Text('Exit Portal', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildDesktopHeader(BuildContext context) {
    final profile = ref.watch(vendorProfileProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        border: const Border(bottom: BorderSide(color: Color(0xFFF0E5D8))),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome, ${profile.businessName}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
                  const SizedBox(height: 6),
                  const Text('Manage your catering bookings, menus, and analytics.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_accentGold, Color(0xFFFFF2CD)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: _accentGold.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: _primaryDark,
                  child: Text(profile.businessName.isNotEmpty ? profile.businessName[0] : 'C', style: const TextStyle(color: _accentGold, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawerContent(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_primaryDark, Color(0xFF022C22)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: Column(
        children: [
          const SizedBox(height: 50),
          _buildSidebarBranding(),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('GROW YOUR BUSINESS', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
                const SizedBox(height: 12),
                _buildNavItem(4, 'Promotions & Deals', Icons.local_offer_rounded, isDrawer: true),
                const SizedBox(height: 8),
                _buildNavItem(5, 'Availability', Icons.date_range_rounded, isDrawer: true),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('INSIGHTS', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
                const SizedBox(height: 12),
                _buildNavItem(6, 'Analytics', Icons.insights_rounded, isDrawer: true),
                const SizedBox(height: 8),
                _buildNavItem(7, 'Reviews', Icons.star_rate_rounded, isDrawer: true),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('ACCOUNT', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
                const SizedBox(height: 12),
                _buildNavItem(8, 'Profile', Icons.person_rounded, isDrawer: true),
                const SizedBox(height: 8),
                _buildNavItem(9, 'Settings', Icons.settings_rounded, isDrawer: true),
              ],
            ),
          ),
          _buildExitButton(context, isDrawer: true),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_primaryDark, Color(0xFF022C22)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        boxShadow: [BoxShadow(color: _primaryDark.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(5, 0))],
      ),
      child: Column(
        children: [
          const SizedBox(height: 50),
          _buildSidebarBranding(),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('MAIN', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
                const SizedBox(height: 12),
                _buildNavItem(0, 'Dashboard', Icons.space_dashboard_rounded, isDrawer: false),
                const SizedBox(height: 8),
                _buildNavItem(1, 'Menus & Pricing', Icons.restaurant_menu_rounded, isDrawer: false),
                const SizedBox(height: 8),
                _buildNavItem(2, 'Bookings', Icons.event_available_rounded, isDrawer: false),
                const SizedBox(height: 8),
                _buildNavItem(3, 'Messages', Icons.forum_rounded, isDrawer: false),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('GROW', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
                const SizedBox(height: 12),
                _buildNavItem(4, 'Promotions & Deals', Icons.local_offer_rounded, isDrawer: false),
                const SizedBox(height: 8),
                _buildNavItem(5, 'Availability', Icons.date_range_rounded, isDrawer: false),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('INSIGHTS', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
                const SizedBox(height: 12),
                _buildNavItem(6, 'Analytics', Icons.insights_rounded, isDrawer: false),
                const SizedBox(height: 8),
                _buildNavItem(7, 'Reviews', Icons.star_rate_rounded, isDrawer: false),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('ACCOUNT', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
                const SizedBox(height: 12),
                _buildNavItem(8, 'Profile', Icons.person_rounded, isDrawer: false),
                const SizedBox(height: 8),
                _buildNavItem(9, 'Settings', Icons.settings_rounded, isDrawer: false),
              ],
            ),
          ),
          _buildExitButton(context, isDrawer: false),
        ],
      ),
    );
  }

  Widget _buildSidebarBranding() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          const AnimatedEmblem(size: 48, animate: false),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ShadiSphere', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5), overflow: TextOverflow.ellipsis),
                Text('Catering Dashboard', style: TextStyle(color: _accentGold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExitButton(BuildContext context, {required bool isDrawer}) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withValues(alpha: 0.2)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: InkWell(
        onTap: () {
          if (isDrawer) Navigator.pop(context);
          _handleLogout(context, ref);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20), SizedBox(width: 10), Text('Exit Portal', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))]),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, {required bool isDrawer}) {
    final isSelected = _selectedIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isSelected ? const LinearGradient(colors: [Color(0xFF059669), _primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        border: Border.all(color: isSelected ? _accentGold.withValues(alpha: 0.5) : Colors.transparent, width: 1.5),
        boxShadow: isSelected ? [BoxShadow(color: _accentGold.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() { _selectedIndex = index; });
            if (isDrawer) Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? _accentGold : Colors.white60, size: 22),
                const SizedBox(width: 16),
                Expanded(child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 15, letterSpacing: 0.3), overflow: TextOverflow.ellipsis)),
                if (isSelected) Container(width: 6, height: 6, decoration: const BoxDecoration(color: _accentGold, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _accentGold, blurRadius: 4)])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// 1. DASHBOARD OVERVIEW — Caterer Portal
// ======================================================================
class CaterDashboardOverview extends ConsumerWidget {
  const CaterDashboardOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(vendorAnalyticsProvider);
    final inquiries = ref.watch(vendorInquiriesProvider);
    final profile = ref.watch(vendorProfileProvider);
    final isWarned = profile.accountStatus == 'warning';
    final promos = ref.watch(vendorPromotionsProvider);
    final activePromos = promos.where((p) => p.isActive).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWarned)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.red.shade700, Colors.red.shade500]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.report_problem_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Account Warning', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Your account has been issued a formal warning by an admin due to low ratings or compliance issues. Please improve your service to avoid suspension.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          if (analytics.confirmedBookings > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF10B981)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${analytics.confirmedBookings} Active Confirmed Catering Event${analytics.confirmedBookings > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Clients pay instantly upon checkout. Review and manage your upcoming catering orders.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      final shellState = context.findAncestorStateOfType<_CaterPortalShellState>();
                      shellState?.selectTab(2);
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                    child: const Text('View'),
                  ),
                ],
              ),
            ),

          const Text('Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _CaterMetricData('This Month Revenue', _formatCurrency(analytics.totalEarnings), Icons.account_balance_wallet_rounded, Colors.green),
                _CaterMetricData('Total Completed', '${analytics.completedBookings}', Icons.check_circle_rounded, _primaryDark),
                _CaterMetricData('Confirmed Orders', '${analytics.confirmedBookings}', Icons.event_available_rounded, Colors.teal),
                _CaterMetricData('Avg. Rating', analytics.totalReviews > 0 ? '${analytics.averageRating.toStringAsFixed(1)} ★' : 'N/A', Icons.star_rounded, _accentGold),
              ];
              if (constraints.maxWidth < 600) {
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: cards.map((c) => _buildMetricCard(c.title, c.value, c.icon, c.color)).toList(),
                );
              }
              return Row(
                children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _buildMetricCard(c.title, c.value, c.icon, c.color)))).toList(),
              );
            },
          ),

          if (activePromos.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Active Deals', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
                TextButton(
                  onPressed: () {
                    final shellState = context.findAncestorStateOfType<_CaterPortalShellState>();
                    shellState?.selectTab(4);
                  },
                  child: const Text('Manage All →', style: TextStyle(color: _accentGold, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: activePromos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final promo = activePromos[index];
                  return Container(
                    width: 260,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF10B981), _primaryDark]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: _primaryDark.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: _accentGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('${promo.discountPercent}%', style: const TextStyle(color: _accentGold, fontWeight: FontWeight.w900, fontSize: 16))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(promo.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('${promo.startDate} – ${promo.endDate}', style: const TextStyle(color: Colors.white60, fontSize: 12), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 28),
          const Text('Quick Actions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _CaterQuickActionChip(label: 'Manage Menus & Pricing', icon: Icons.restaurant_menu_rounded, onTap: () {
                final shellState = context.findAncestorStateOfType<_CaterPortalShellState>();
                shellState?.selectTab(1);
              }),
              _CaterQuickActionChip(label: 'Create Promo', icon: Icons.local_offer_rounded, onTap: () {
                final shellState = context.findAncestorStateOfType<_CaterPortalShellState>();
                shellState?.selectTab(4);
              }),
              _CaterQuickActionChip(label: 'View Analytics', icon: Icons.insights_rounded, onTap: () {
                final shellState = context.findAncestorStateOfType<_CaterPortalShellState>();
                shellState?.selectTab(6);
              }),
              _CaterQuickActionChip(label: 'Manage Calendar', icon: Icons.date_range_rounded, onTap: () {
                final shellState = context.findAncestorStateOfType<_CaterPortalShellState>();
                shellState?.selectTab(5);
              }),
              _CaterQuickActionChip(label: 'Check Reviews', icon: Icons.reviews_rounded, onTap: () {
                final shellState = context.findAncestorStateOfType<_CaterPortalShellState>();
                shellState?.selectTab(7);
              }),
              _CaterQuickActionChip(label: 'Edit Profile', icon: Icons.edit_rounded, onTap: () {
                final shellState = context.findAncestorStateOfType<_CaterPortalShellState>();
                shellState?.selectTab(8);
              }),
            ],
          ),

          const SizedBox(height: 28),
          const Text('Recent Catering Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 16),
          if (inquiries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: const Column(
                children: [
                  Icon(Icons.history_rounded, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No recent activity to show', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                  SizedBox(height: 8),
                  Text('When clients send you catering booking requests, they will appear here.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: inquiries.take(5).length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (c, i) {
                final inq = inquiries[i];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(inq.status).withValues(alpha: 0.1),
                    child: Icon(_statusIcon(inq.status), color: _statusColor(inq.status)),
                  ),
                  title: Text(inq.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${inq.date} • ${inq.detail}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(inq.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(inq.status, style: TextStyle(color: _statusColor(inq.status), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Icon(Icons.arrow_outward_rounded, color: Colors.grey.shade400, size: 20),
            ],
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 2))],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'Confirmed':
    case 'Accepted':
    case 'User Accepted':
    case 'Pending':
    case 'Negotiating':
      return Colors.teal;
    case 'Completed':
      return const Color(0xFF2E7D32);
    case 'Cancelled':
    case 'Rejected':
      return const Color(0xFF991B1B);
    default:
      return Colors.grey;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'Confirmed':
    case 'Accepted':
    case 'User Accepted':
    case 'Pending':
    case 'Negotiating':
      return Icons.check_circle_rounded;
    case 'Completed':
      return Icons.verified_rounded;
    case 'Cancelled':
    case 'Rejected':
      return Icons.cancel_rounded;
    default:
      return Icons.help_outline;
  }
}

class _CaterMetricData {
  final String title, value;
  final IconData icon;
  final Color color;
  const _CaterMetricData(this.title, this.value, this.icon, this.color);
}

class _CaterQuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _CaterQuickActionChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accentGold.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _accentGold, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: _primaryDark, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// 2. BOOKINGS VIEW — Caterer Order Pipeline
// ======================================================================
class CaterBookingsView extends ConsumerWidget {
  const CaterBookingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiries = ref.watch(vendorInquiriesProvider);
    final filter = ref.watch(vendorBookingFilterProvider);
    final search = ref.watch(vendorBookingSearchProvider);

    final confirmedCount = inquiries.where((i) => i.status == 'Confirmed' || i.status == 'Accepted' || i.status == 'User Accepted' || i.status == 'Pending' || i.status == 'Negotiating').length;
    final completedCount = inquiries.where((i) => i.status == 'Completed').length;
    final rejectedCount = inquiries.where((i) => i.status == 'Rejected' || i.status == 'Cancelled').length;

    final filtered = inquiries.where((inq) {
      bool matchesFilter = false;
      if (filter == 'All') {
        matchesFilter = true;
      } else if (filter == 'Confirmed' || filter == 'Pending' || filter == 'Negotiating' || filter == 'Accepted') {
        matchesFilter = inq.status == 'Confirmed' || inq.status == 'Accepted' || inq.status == 'User Accepted' || inq.status == 'Pending' || inq.status == 'Negotiating';
      } else if (filter == 'Completed') {
        matchesFilter = inq.status == 'Completed';
      } else if (filter == 'Cancelled' || filter == 'Rejected') {
        matchesFilter = inq.status == 'Cancelled' || inq.status == 'Rejected';
      } else {
        matchesFilter = inq.status == filter;
      }

      final matchesSearch = search.isEmpty || inq.clientName.toLowerCase().contains(search.toLowerCase()) || inq.detail.toLowerCase().contains(search.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      DateTime getFallback(String dStr) {
        try {
          final parts = dStr.split('/');
          if (parts.length == 3) {
            return DateTime(int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
          }
        } catch (_) {}
        return DateTime(2000);
      }
      final dateA = a.createdAt ?? getFallback(a.date);
      final dateB = b.createdAt ?? getFallback(b.date);
      return dateB.compareTo(dateA); // Descending
    });

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Catering Order Pipeline', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
          const SizedBox(height: 8),
          const Text('Instant booking active: Clients pay upfront. Manage confirmed catering orders through completion.', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CaterPipelineStage(label: 'Confirmed (Paid)', count: confirmedCount, color: Colors.teal, icon: Icons.check_circle_rounded),
                  _CaterPipelineArrow(),
                  _CaterPipelineStage(label: 'Completed', count: completedCount, color: const Color(0xFF2E7D32), icon: Icons.verified_rounded),
                  _CaterPipelineArrow(),
                  _CaterPipelineStage(label: 'Cancelled', count: rejectedCount, color: const Color(0xFF991B1B), icon: Icons.cancel_rounded),
                ],
              ),
            ),
          ),

          TextField(
            onChanged: (v) => ref.read(vendorBookingSearchProvider.notifier).state = v,
            decoration: InputDecoration(
              hintText: 'Search by client name or order details...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
          const SizedBox(height: 16),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CaterFilterChip(label: 'All', count: inquiries.length, isSelected: filter == 'All', onTap: () => ref.read(vendorBookingFilterProvider.notifier).state = 'All'),
                const SizedBox(width: 8),
                _CaterFilterChip(label: 'Confirmed', count: confirmedCount, isSelected: filter == 'Confirmed' || filter == 'Pending' || filter == 'Negotiating' || filter == 'Accepted', onTap: () => ref.read(vendorBookingFilterProvider.notifier).state = 'Confirmed', color: Colors.teal),
                const SizedBox(width: 8),
                _CaterFilterChip(label: 'Completed', count: completedCount, isSelected: filter == 'Completed', onTap: () => ref.read(vendorBookingFilterProvider.notifier).state = 'Completed', color: const Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                _CaterFilterChip(label: 'Cancelled', count: rejectedCount, isSelected: filter == 'Cancelled' || filter == 'Rejected', onTap: () => ref.read(vendorBookingFilterProvider.notifier).state = 'Cancelled', color: const Color(0xFF991B1B)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(search.isNotEmpty ? 'No orders match your search.' : 'No $filter orders.', style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('When clients book your catering services, their confirmed orders will appear here.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final inq = filtered[index];
                  final isConfirmed = inq.status == 'Confirmed' || inq.status == 'Accepted' || inq.status == 'User Accepted' || inq.status == 'Pending' || inq.status == 'Negotiating';
                  final isCompleted = inq.status == 'Completed';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: _primaryDark.withValues(alpha: 0.1),
                              child: Text(inq.clientName.isNotEmpty ? inq.clientName[0].toUpperCase() : 'C', style: const TextStyle(color: _primaryDark, fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(inq.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(inq.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isConfirmed ? Colors.teal.withValues(alpha: 0.12) : (isCompleted ? const Color(0xFF2E7D32).withValues(alpha: 0.12) : const Color(0xFF991B1B).withValues(alpha: 0.12)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isConfirmed ? Icons.check_circle_rounded : (isCompleted ? Icons.verified_rounded : Icons.cancel_rounded),
                                    size: 14,
                                    color: isConfirmed ? Colors.teal : (isCompleted ? const Color(0xFF2E7D32) : const Color(0xFF991B1B)),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isConfirmed ? 'Confirmed • Paid' : (isCompleted ? 'Completed' : 'Cancelled'),
                                    style: TextStyle(
                                      color: isConfirmed ? Colors.teal : (isCompleted ? const Color(0xFF2E7D32) : const Color(0xFF991B1B)),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                        Text('Details: ${inq.detail}', style: const TextStyle(fontSize: 13, height: 1.3)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Amount Paid: ${inq.amount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _primaryDark)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade200)),
                              child: const Text('Instant Checkout', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),

                        if (isConfirmed) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => ref.read(vendorInquiriesProvider.notifier).rejectInquiry(inq.id),
                                  icon: const Icon(Icons.close, size: 14),
                                  label: const Text('Cancel Order', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF991B1B),
                                    side: const BorderSide(color: Color(0xFF991B1B)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () => ref.read(vendorInquiriesProvider.notifier).markCompleted(inq.id),
                                  icon: const Icon(Icons.verified_rounded, size: 16),
                                  label: const Text('Mark as Completed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
}

class _CaterPipelineStage extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _CaterPipelineStage({required this.label, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CaterPipelineArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
    );
  }
}

class _CaterFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  const _CaterFilterChip({required this.label, required this.count, required this.isSelected, required this.onTap, this.color = _primaryDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
// 3. PRICING VIEW — Catering Menu & Packages Management
// ======================================================================
class CaterPricingView extends ConsumerStatefulWidget {
  const CaterPricingView({super.key});

  @override
  ConsumerState<CaterPricingView> createState() => _CaterPricingViewState();
}

class _CaterPricingViewState extends ConsumerState<CaterPricingView> {
  final List<CateringDishItem> _dishes = [];
  final List<CateringPackageItem> _packages = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCateringData();
  }

  Future<void> _loadCateringData() async {
    final auth = ref.read(authProvider);
    final uid = auth.userId;

    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('vendors').doc(uid).get();
        final profileDoc = await FirebaseFirestore.instance.collection('vendor_profile').doc(uid).get();
        final data = <String, dynamic>{};
        if (doc.exists && doc.data() != null) data.addAll(doc.data()!);
        if (profileDoc.exists && profileDoc.data() != null) {
          final pMap = profileDoc.data()!;
          if (pMap['cateringDishes'] != null) data['cateringDishes'] = pMap['cateringDishes'];
          if (pMap['cateringPackages'] != null) data['cateringPackages'] = pMap['cateringPackages'];
        }
        if (data.isNotEmpty) {
          if (data['cateringDishes'] != null && data['cateringDishes'] is List) {
            final list = data['cateringDishes'] as List;
            if (list.isNotEmpty) {
              _dishes.clear();
              for (var d in list) {
                if (d is Map) {
                  _dishes.add(CateringDishItem(
                    id: d['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: d['name'] ?? '',
                    pricePerPlate: (d['pricePerPlate'] as num?)?.toDouble() ?? 0.0,
                    minQuantity: (d['minQuantity'] as num?)?.toInt() ?? 1,
                    category: d['category'] ?? 'Main Course',
                  ));
                }
              }
            }
          }

          if (data['cateringPackages'] != null && data['cateringPackages'] is List) {
            final list = data['cateringPackages'] as List;
            if (list.isNotEmpty) {
              _packages.clear();
              for (var p in list) {
                if (p is Map) {
                  List<String> items = [];
                  if (p['items'] is List) {
                    items = List<String>.from(p['items']);
                  } else if (p['description'] is String && (p['description'] as String).isNotEmpty) {
                    items = (p['description'] as String).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                  }
                  _packages.add(CateringPackageItem(
                    id: p['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: p['name'] ?? '',
                    pricePerPlate: (p['pricePerPlate'] as num?)?.toDouble() ?? 0.0,
                    minGuests: (p['minGuests'] as num?)?.toInt() ?? 1,
                    items: items,
                  ));
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading catering profile data: $e');
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _savePricing() async {
    setState(() => _isSaving = true);
    
    try {
      final auth = ref.read(authProvider);
      final uid = (auth.isAuthenticated && auth.role == 'vendor') ? auth.userId! : 'profile_details';
      
      double minPrice = 100.0;
      double maxPrice = 100.0;
      if (_dishes.isNotEmpty) {
        minPrice = _dishes.map((d) => d.pricePerPlate).reduce((a, b) => a < b ? a : b);
        maxPrice = _dishes.map((d) => d.pricePerPlate).reduce((a, b) => a > b ? a : b);
      }

      await FirebaseFirestore.instance.collection('vendors').doc(uid).set({
        'cateringDishes': _dishes.map((d) => d.toMap()).toList(),
        'cateringPackages': _packages.map((p) => p.toMap()).toList(),
        'price': minPrice,
        'weekendPrice': maxPrice,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('vendor_profile').doc(uid).set({
        'cateringDishes': _dishes.map((d) => d.toMap()).toList(),
        'cateringPackages': _packages.map((p) => p.toMap()).toList(),
        'price': minPrice,
        'weekendPrice': maxPrice,
      }, SetOptions(merge: true));

      final profile = ref.read(vendorProfileProvider);
      await ref.read(vendorProfileProvider.notifier).updateProfile(
        businessName: profile.businessName,
        ownerName: profile.ownerName,
        capacity: profile.capacity,
        location: profile.location,
        city: profile.city,
        bio: profile.bio,
        price: minPrice,
        weekendPrice: maxPrice,
        specialPrices: profile.specialPrices,
        outsidePictures: profile.outsidePictures,
        insidePictures: profile.insidePictures,
        subscriptionTier: profile.subscriptionTier,
        isSetupComplete: profile.isSetupComplete,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catering menu & packages saved successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving catering menu: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddDishDialog({CateringDishItem? existingDish}) {
    final nameCtrl = TextEditingController(text: existingDish?.name ?? '');
    final priceCtrl = TextEditingController(text: existingDish != null ? existingDish.pricePerPlate.toStringAsFixed(0) : '');
    final minQtyCtrl = TextEditingController(text: existingDish != null ? existingDish.minQuantity.toString() : '20');
    String selectedCategory = existingDish?.category ?? 'Main Course';
    final categories = ['Main Course', 'Appetizer', 'Dessert', 'Beverage', 'BBQ', 'Salad & Side'];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 16,
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: 440,
              decoration: const BoxDecoration(color: Colors.white),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF064E3B), Color(0xFF059669)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                            child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existingDish == null ? 'Add Signature Dish' : 'Edit Signature Dish',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  existingDish == null ? 'Add dish name, rate per plate & min quantity' : 'Update dish rate & minimum quantity',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('DISH NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameCtrl,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'e.g. Chicken Biryani / Mutton Karahi',
                              prefixIcon: const Icon(Icons.fastfood_outlined, color: Color(0xFF064E3B), size: 18),
                              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAF9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.8)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('PER PLATE RATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: priceCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: '350',
                                        prefixText: 'Rs. ',
                                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                                        isDense: true,
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAF9),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('MIN QUANTITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: minQtyCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B), fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: '20',
                                        suffixText: 'Pers.',
                                        suffixStyle: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                                        isDense: true,
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAF9),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('CUISINE CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAF9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF064E3B), width: 1.8)),
                            ),
                            items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                            onChanged: (v) {
                              if (v != null) setDlgState(() => selectedCategory = v);
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  foregroundColor: Colors.grey.shade700,
                                ),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                  label: Text(existingDish == null ? 'Save Dish' : 'Update Dish', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF064E3B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    elevation: 2,
                                    shadowColor: const Color(0xFF064E3B).withValues(alpha: 0.3),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    final name = nameCtrl.text.trim();
                                    final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                                    final minQty = int.tryParse(minQtyCtrl.text.trim()) ?? 1;

                                    if (name.isEmpty || price <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid dish name and price')));
                                      return;
                                    }

                                    setState(() {
                                      if (existingDish != null) {
                                        final idx = _dishes.indexWhere((d) => d.id == existingDish.id);
                                        if (idx != -1) {
                                          _dishes[idx] = CateringDishItem(
                                            id: existingDish.id,
                                            name: name,
                                            pricePerPlate: price,
                                            minQuantity: minQty,
                                            category: selectedCategory,
                                          );
                                        }
                                      } else {
                                        _dishes.add(
                                          CateringDishItem(
                                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                                            name: name,
                                            pricePerPlate: price,
                                            minQuantity: minQty,
                                            category: selectedCategory,
                                          ),
                                        );
                                      }
                                    });
                                    Navigator.pop(ctx);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddPackageDialog({CateringPackageItem? existingPackage}) {
    final nameCtrl = TextEditingController(text: existingPackage?.name ?? '');
    final priceCtrl = TextEditingController(text: existingPackage != null ? existingPackage.pricePerPlate.toStringAsFixed(0) : '');
    final minGuestsCtrl = TextEditingController(text: existingPackage != null ? existingPackage.minGuests.toString() : '50');
    final itemInputCtrl = TextEditingController();

    List<String> dlgItems = List.from(
      (existingPackage != null && existingPackage.safeItems.isNotEmpty)
          ? existingPackage.safeItems
          : [],
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 16,
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: 440,
              decoration: const BoxDecoration(color: Colors.white),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFB48A1D), Color(0xFFD4AF37)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                            child: const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existingPackage == null ? 'Create Catering Package' : 'Edit Catering Package',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  existingPackage == null ? 'Group signature dishes into a feast deal' : 'Update package rates & menu items',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('PACKAGE NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameCtrl,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'e.g. Barat Special Feast Package',
                              prefixIcon: const Icon(Icons.card_giftcard_outlined, color: Color(0xFFD4AF37), size: 18),
                              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAF9),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.8)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('PACKAGE RATE / PLATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: priceCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: '950',
                                        prefixText: 'Rs. ',
                                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                                        isDense: true,
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAF9),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('MIN GUESTS ORDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: minGuestsCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B), fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: '50',
                                        suffixText: 'Guests',
                                        suffixStyle: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                                        isDense: true,
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAF9),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('INCLUDED DISHES & MENU ITEMS (BULLET LIST)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: itemInputCtrl,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    hintText: 'Add dish / item (e.g. Roghani Naan)',
                                    isDense: true,
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAF9),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  ),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      setDlgState(() {
                                        dlgItems.add(val.trim());
                                        itemInputCtrl.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF064E3B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  final val = itemInputCtrl.text.trim();
                                  if (val.isNotEmpty) {
                                    setDlgState(() {
                                      dlgItems.add(val);
                                      itemInputCtrl.clear();
                                    });
                                  }
                                },
                                child: const Text('+ Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (dlgItems.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAF9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Text('No menu items added to list yet.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                            )
                          else
                            Container(
                              constraints: const BoxConstraints(maxHeight: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAF9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: dlgItems.length,
                                separatorBuilder: (_, __) => const Divider(height: 8),
                                itemBuilder: (context, idx) {
                                  final item = dlgItems[idx];
                                  return Row(
                                    children: [
                                      const Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFFD4AF37)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(item, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF064E3B))),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        onPressed: () {
                                          setDlgState(() => dlgItems.removeAt(idx));
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  foregroundColor: Colors.grey.shade700,
                                ),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                  label: Text(existingPackage == null ? 'Save Package' : 'Update Package', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD4AF37),
                                    foregroundColor: const Color(0xFF064E3B),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    elevation: 2,
                                    shadowColor: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    final name = nameCtrl.text.trim();
                                    final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                                    final minGuests = int.tryParse(minGuestsCtrl.text.trim()) ?? 1;

                                    if (name.isEmpty || price <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid package name and price')));
                                      return;
                                    }

                                    if (dlgItems.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one menu item to the bullet list')));
                                      return;
                                    }

                                    setState(() {
                                      if (existingPackage != null) {
                                        final idx = _packages.indexWhere((p) => p.id == existingPackage.id);
                                        if (idx != -1) {
                                          _packages[idx] = CateringPackageItem(
                                            id: existingPackage.id,
                                            name: name,
                                            pricePerPlate: price,
                                            minGuests: minGuests,
                                            items: List.from(dlgItems),
                                          );
                                        }
                                      } else {
                                        _packages.add(
                                          CateringPackageItem(
                                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                                            name: name,
                                            pricePerPlate: price,
                                            minGuests: minGuests,
                                            items: List.from(dlgItems),
                                          ),
                                        );
                                      }
                                    });
                                    Navigator.pop(ctx);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primaryDark));
    }

    double lowestRate = 0;
    if (_dishes.isNotEmpty) {
      lowestRate = _dishes.map((d) => d.pricePerPlate).reduce((a, b) => a < b ? a : b);
    }

    final Map<String, List<CateringDishItem>> groupedDishes = {};
    for (var dish in _dishes) {
      groupedDishes.putIfAbsent(dish.category, () => []).add(dish);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                stops: [0.0, 0.6, 1.0],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: const Color(0xFF064E3B).withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              children: [
                Positioned(right: -20, top: -20, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
                Positioned(right: 30, bottom: -15, child: Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.04)))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFFDE68A), size: 26),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Catering Menu & Packages', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'PlayfairDisplay', letterSpacing: 0.5)),
                              SizedBox(height: 4),
                              Text('Set per-plate dish rates & build curated feast package deals', style: TextStyle(color: Colors.white60, fontSize: 12.5, letterSpacing: 0.3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        _buildStatChip('Dishes', '${_dishes.length} items', Icons.restaurant_outlined),
                        const SizedBox(width: 10),
                        _buildStatChip('Packages', '${_packages.length} deals', Icons.card_giftcard),
                        const SizedBox(width: 10),
                        _buildStatChip('Min Rate', lowestRate > 0 ? 'Rs. ${lowestRate.toStringAsFixed(0)}' : 'N/A', Icons.payments_outlined),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 28),

          // --- Signature Dishes Section ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Signature Dishes (${_dishes.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddDishDialog(),
                icon: const Icon(Icons.restaurant_menu, size: 16),
                label: const Text('Add Dish', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF064E3B),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_dishes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Column(
                children: [
                  Icon(Icons.restaurant_outlined, color: Colors.grey, size: 40),
                  SizedBox(height: 8),
                  Text('No dishes added yet.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('Click "+ Add Dish" to list items like Biryani, Karahi, Naan, etc.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: groupedDishes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final category = groupedDishes.keys.elementAt(index);
                final categoryDishes = groupedDishes[category]!;
                
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF064E3B).withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                      initiallyExpanded: index == 0,
                      iconColor: const Color(0xFF064E3B),
                      collapsedIconColor: Colors.grey,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Row(
                        children: [
                          const Icon(Icons.fastfood_outlined, color: Color(0xFFD4AF37), size: 20),
                          const SizedBox(width: 12),
                          Text(
                            '$category (${categoryDishes.length})', 
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B), fontSize: 16),
                          ),
                        ],
                      ),
                      children: categoryDishes.map((dish) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: const Icon(Icons.restaurant, color: Color(0xFF064E3B), size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(dish.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF064E3B))),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text('Rs. ${dish.pricePerPlate.toStringAsFixed(0)} / plate', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                                          Text('•  Min Order: ${dish.minQuantity} Persons', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFFD4AF37), size: 18),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () => _showAddDishDialog(existingDish: dish),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () {
                                    setState(() => _dishes.remove(dish));
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
            ),

          const SizedBox(height: 32),

          // --- Catering Packages Section ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Catering Packages (${_packages.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
              ),
              OutlinedButton.icon(
                onPressed: () => _showAddPackageDialog(),
                icon: const Icon(Icons.card_giftcard, size: 16),
                label: const Text('Add Package', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF064E3B),
                  side: const BorderSide(color: Color(0xFF064E3B)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_packages.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 40),
                  SizedBox(height: 8),
                  Text('No packages created yet.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('Packages let you group multiple dishes into a complete menu deal.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _packages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final pkg = _packages[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.stars_rounded, color: Color(0xFFD4AF37), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF064E3B))),
                            const SizedBox(height: 4),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text('Rs. ${pkg.pricePerPlate.toStringAsFixed(0)} / plate', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                                Text('•  Min Guests: ${pkg.minGuests}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                            if (pkg.safeItems.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: pkg.safeItems.map((it) => Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.fiber_manual_record, size: 6, color: Color(0xFFD4AF37)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(it, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500)),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFFD4AF37), size: 18),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: () => _showAddPackageDialog(existingPackage: pkg),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: () {
                          setState(() => _packages.removeAt(index));
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 36),

          // Save All Changes Button
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF064E3B), Color(0xFF059669)],
                begin: Alignment.centerLeft, end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: const Color(0xFF064E3B).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePricing,
              icon: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) 
                  : const Icon(Icons.save_rounded, size: 22),
              label: Text(_isSaving ? 'Saving...' : 'Save All Changes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildStatChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFDE68A), size: 18),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 10, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// 4. MESSAGES VIEW — Caterer Messaging & Quick Replies
// ======================================================================
class CaterMessagesView extends ConsumerWidget {
  const CaterMessagesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(vendorMessagesProvider);
    final templates = ref.watch(quickReplyTemplatesProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client Messages', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
                    SizedBox(height: 8),
                    Text('Communicate with clients regarding catering orders.', style: TextStyle(fontSize: 15, color: Colors.grey)),
                  ],
                ),
              ),
              PopupMenuButton<QuickReplyTemplate>(
                position: PopupMenuPosition.under,
                offset: const Offset(0, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _accentGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accentGold.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flash_on_rounded, color: _accentGold, size: 18),
                      SizedBox(width: 6),
                      Text('Quick Reply', style: TextStyle(color: _primaryDark, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                onSelected: (template) {
                  _showTemplatePreview(context, template);
                },
                itemBuilder: (ctx) => templates.map((t) => PopupMenuItem<QuickReplyTemplate>(
                  value: t,
                  child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (messages.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No messages yet', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('When clients reach out about catering, their messages will appear here.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: messages.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  final msg = messages[i];
                  return ListTile(
                    onTap: () {
                      _showReplySheet(context, ref, msg);
                    },
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    leading: CircleAvatar(backgroundColor: _accentGold, child: Text(msg.clientName.isNotEmpty ? msg.clientName[0] : 'C', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    title: Text(msg.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (msg.vendorReply != null && msg.vendorReply!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.reply, size: 14, color: Colors.green),
                                const SizedBox(width: 4),
                                Expanded(child: Text('Replied: ${msg.vendorReply}', style: const TextStyle(color: Colors.green, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(msg.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        if (msg.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: Color(0xFF991B1B), shape: BoxShape.circle),
                            child: Text('${msg.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
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

  void _showTemplatePreview(BuildContext context, QuickReplyTemplate template) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(template.title, style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Preview:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bgOffWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(template.body, style: const TextStyle(fontSize: 14, height: 1.5)),
            ),
            const SizedBox(height: 12),
            const Text('Tap "Copy" to use this template in a conversation.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Close', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: template.body));
              Navigator.pop(dlgCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Template copied! Paste it in your conversation.'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryDark, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showReplySheet(BuildContext context, WidgetRef ref, VendorMessage msg) {
    final hasReplied = msg.vendorReply != null && msg.vendorReply!.isNotEmpty;
    final replyCtrl = TextEditingController(text: msg.vendorReply ?? '');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Message from ${msg.clientName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(msg.lastMessage, style: const TextStyle(fontSize: 15, height: 1.4)),
            ),
            const SizedBox(height: 24),
            Text(hasReplied ? 'Your Reply' : 'Draft Reply', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            if (hasReplied)
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(msg.vendorReply!, style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87)),
              )
            else
              TextField(
                controller: replyCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Type your reply here...',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _accentGold)),
                ),
              ),
            const SizedBox(height: 24),
            if (!hasReplied)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (replyCtrl.text.trim().isNotEmpty) {
                      ref.read(vendorMessagesProvider.notifier).replyToMessage(msg.id, replyCtrl.text.trim());
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reply sent!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Send Reply', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// 5. PROMOTIONS & DEALS VIEW — Catering Deals
// ======================================================================
class CaterPromotionsView extends ConsumerWidget {
  const CaterPromotionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promos = ref.watch(vendorPromotionsProvider);
    final activeCount = promos.where((p) => p.isActive).length;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Promotions & Menu Deals', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
                    const SizedBox(height: 8),
                    Text('$activeCount active promotion${activeCount == 1 ? '' : 's'} • ${promos.length} total', style: const TextStyle(fontSize: 15, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showPromoDialog(context, ref),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Create Deal'),
                style: ElevatedButton.styleFrom(backgroundColor: _accentGold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: const [
                Icon(Icons.lightbulb_outline, color: Color(0xFF047857), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Active catering promotions are highlighted to clients searching for wedding food packages.',
                    style: TextStyle(color: Color(0xFF065F46), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (promos.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No promotions yet', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Create your first catering deal to attract more clients.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: promos.length,
                separatorBuilder: (_, _i) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final promo = promos[index];
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: promo.isActive ? _accentGold.withValues(alpha: 0.3) : Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                gradient: promo.isActive
                                  ? const LinearGradient(colors: [_accentGold, Color(0xFFF9E596)])
                                  : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade200]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(child: Text('${promo.discountPercent}%', style: TextStyle(color: promo.isActive ? _primaryDark : Colors.grey, fontWeight: FontWeight.w900, fontSize: 16))),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(promo.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _primaryDark)),
                                  const SizedBox(height: 4),
                                  Text(promo.description, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Switch(
                              value: promo.isActive,
                              activeTrackColor: _accentGold.withValues(alpha: 0.5),
                              activeThumbColor: _accentGold,
                              onChanged: (val) => ref.read(vendorPromotionsProvider.notifier).togglePromotion(promo.id, val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.date_range, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text('${promo.startDate} – ${promo.endDate}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: promo.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(promo.isActive ? 'LIVE' : 'PAUSED', style: TextStyle(color: promo.isActive ? Colors.green : Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: _accentGold, size: 20),
                              onPressed: () => _showPromoDialog(context, ref, existingPromo: promo),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFF991B1B), size: 20),
                              onPressed: () async {
                                final confirmed = await _showLuxuryConfirmDialog(
                                  context: context,
                                  title: 'Delete Promotion',
                                  message: 'Are you sure you want to delete "${promo.title}"? This action cannot be undone.',
                                  confirmText: 'Delete',
                                  icon: Icons.delete_outline_rounded,
                                );
                                if (confirmed == true) {
                                  ref.read(vendorPromotionsProvider.notifier).deletePromotion(promo.id);
                                }
                              },
                            ),
                          ],
                        ),
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

  void _showPromoDialog(BuildContext context, WidgetRef ref, {VendorPromotion? existingPromo}) {
    final titleCtrl = TextEditingController(text: existingPromo?.title ?? '');
    final descCtrl = TextEditingController(text: existingPromo?.description ?? '');
    final discountCtrl = TextEditingController(text: existingPromo != null ? existingPromo.discountPercent.toString() : '');
    final startCtrl = TextEditingController(text: existingPromo?.startDate ?? '');
    final endCtrl = TextEditingController(text: existingPromo?.endDate ?? '');

    showDialog(
      context: context,
      builder: (dlgCtx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: _bgOffWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(existingPromo == null ? 'Create Catering Deal' : 'Edit Catering Deal', style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay', fontSize: 22)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Deal Title',
                      hintText: 'e.g., Barat Buffet Special',
                      prefixIcon: const Icon(Icons.title, color: _primaryDark, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: discountCtrl, 
                    keyboardType: TextInputType.number, 
                    decoration: InputDecoration(
                      labelText: 'Discount %', 
                      prefixIcon: const Icon(Icons.percent, color: _primaryDark, size: 20), 
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl, 
                    maxLines: 3, 
                    decoration: InputDecoration(
                      labelText: 'Description',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startCtrl, 
                          decoration: InputDecoration(
                            labelText: 'Start Date', 
                            hintText: 'Jul 15',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: endCtrl, 
                          decoration: InputDecoration(
                            labelText: 'End Date', 
                            hintText: 'Aug 15',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx), 
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentGold,
                foregroundColor: _primaryDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                if (titleCtrl.text.isNotEmpty && discountCtrl.text.isNotEmpty) {
                  if (existingPromo == null) {
                    ref.read(vendorPromotionsProvider.notifier).addPromotion(
                      title: titleCtrl.text,
                      description: descCtrl.text,
                      discountPercent: int.tryParse(discountCtrl.text) ?? 0,
                      startDate: startCtrl.text,
                      endDate: endCtrl.text,
                    );
                  } else {
                    ref.read(vendorPromotionsProvider.notifier).updatePromotion(
                      existingPromo.id,
                      title: titleCtrl.text,
                      description: descCtrl.text,
                      discountPercent: int.tryParse(discountCtrl.text) ?? 0,
                      startDate: startCtrl.text,
                      endDate: endCtrl.text,
                    );
                  }
                  Navigator.pop(dlgCtx);
                }
              },
              child: Text(existingPromo == null ? 'Create Deal' : 'Update Deal', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// 6. AVAILABILITY CALENDAR VIEW — Catering Booking Dates
// ======================================================================
class CaterAvailabilityView extends ConsumerStatefulWidget {
  const CaterAvailabilityView({super.key});

  @override
  ConsumerState<CaterAvailabilityView> createState() => _CaterAvailabilityViewState();
}

class _CaterAvailabilityViewState extends ConsumerState<CaterAvailabilityView> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(vendorAvailabilityProvider);
    final blockedDates = availability.where((d) => d.isBlocked).map((d) => d.date).toSet();

    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final monthName = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][_currentMonth.month - 1];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Availability Calendar', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
          const SizedBox(height: 8),
          const Text('Tap dates to mark them as blocked for catering events.', style: TextStyle(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 24),

          Row(
            children: [
              _CaterCalendarLegend(color: Colors.green.shade100, borderColor: Colors.green, label: 'Available'),
              const SizedBox(width: 16),
              _CaterCalendarLegend(color: const Color(0xFFFEE2E2), borderColor: const Color(0xFF991B1B), label: 'Blocked'),
              const SizedBox(width: 16),
              _CaterCalendarLegend(color: Colors.grey.shade200, borderColor: Colors.grey, label: 'Past'),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 28, color: _primaryDark),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                        });
                      },
                    ),
                    Text('$monthName ${_currentMonth.year}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 28, color: _primaryDark),
                      onPressed: () {
                        setState(() {
                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => Expanded(
                    child: Center(child: Text(d, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600))),
                  )).toList(),
                ),
                const SizedBox(height: 8),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: ((firstWeekday - 1) + daysInMonth),
                  itemBuilder: (context, index) {
                    if (index < (firstWeekday - 1)) {
                      return const SizedBox();
                    }
                    final day = index - (firstWeekday - 1) + 1;
                    final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    final isBlocked = blockedDates.contains(dateStr);
                    final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
                    final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;

                    return GestureDetector(
                      onTap: isPast ? null : () {
                        ref.read(vendorAvailabilityProvider.notifier).toggleDate(dateStr);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isPast
                            ? Colors.grey.shade100
                            : (isBlocked ? Colors.red.shade50 : Colors.green.shade50),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isToday
                              ? _accentGold
                              : (isPast ? Colors.grey.shade300 : (isBlocked ? Colors.red.shade300 : Colors.green.shade300)),
                            width: isToday ? 2.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style: TextStyle(
                                  color: isPast ? Colors.grey : (isBlocked ? Colors.red.shade700 : _primaryDark),
                                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              if (isBlocked && !isPast)
                                const Icon(Icons.block, size: 10, color: Color(0xFFF87171)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Builder(
              builder: (context) {
                final currentMonthPrefix = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';
                final blockedThisMonth = blockedDates.where((d) => d.startsWith(currentMonthPrefix)).length;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _CaterAvailabilityStat(label: 'Days This Month', value: '$daysInMonth', color: _primaryDark),
                    _CaterAvailabilityStat(label: 'Blocked', value: '$blockedThisMonth', color: const Color(0xFF991B1B)),
                    _CaterAvailabilityStat(label: 'Available', value: '${daysInMonth - blockedThisMonth}', color: Colors.green),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}

class _CaterCalendarLegend extends StatelessWidget {
  final Color color, borderColor;
  final String label;
  const _CaterCalendarLegend({required this.color, required this.borderColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: borderColor))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _CaterAvailabilityStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _CaterAvailabilityStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

// ======================================================================
// 7. ANALYTICS VIEW — Caterer Analytics
// ======================================================================
class CaterAnalyticsView extends ConsumerWidget {
  const CaterAnalyticsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(vendorAnalyticsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Catering Revenue & Analytics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _CaterMetricData('Total Earnings', _formatCurrency(analytics.totalEarnings), Icons.payments_rounded, Colors.green),
                _CaterMetricData('Pending Revenue', _formatCurrency(analytics.pendingRevenue), Icons.hourglass_top_rounded, _accentGold),
                _CaterMetricData('Avg. Rating', analytics.totalReviews > 0 ? '${analytics.averageRating.toStringAsFixed(1)} ★' : 'N/A', Icons.star_rounded, _accentGold),
                _CaterMetricData('Conversion', '${analytics.conversionRate.toStringAsFixed(0)}%', Icons.trending_up_rounded, const Color(0xFF0F766E)),
              ];
              if (constraints.maxWidth < 600) {
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  children: cards.map((c) => _buildStatCard(c.title, c.value, c.icon, c.color)).toList(),
                );
              }
              return Row(
                children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _buildStatCard(c.title, c.value, c.icon, c.color)))).toList(),
              );
            },
          ),

          const SizedBox(height: 32),
          const Text('Catering Order Pipeline Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CaterBreakdownItem(label: 'Confirmed', count: analytics.confirmedBookings, color: Colors.teal),
                _CaterBreakdownItem(label: 'Completed', count: analytics.completedBookings, color: const Color(0xFF2E7D32)),
                _CaterBreakdownItem(label: 'Cancelled', count: analytics.rejectedBookings, color: const Color(0xFF991B1B)),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Container(
            height: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monthly Catering Revenue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
                const SizedBox(height: 24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(analytics.monthLabels.length, (i) {
                      final val = analytics.monthlyRevenue[i];
                      final maxVal = analytics.monthlyRevenue.reduce((curr, next) => curr > next ? curr : next);
                      final heightRatio = maxVal > 0 ? (val / maxVal) : 0.0;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (val > 0) Text('Rs.${(val / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Container(
                            width: 30,
                            height: (heightRatio * 150).clamp(5.0, 150.0),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_accentGold, Color(0xFFF9E596)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(analytics.monthLabels[i], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), radius: 20, child: Icon(icon, color: color, size: 22)),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark)),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 12)),
        ],
      ),
    );
  }
}

class _CaterBreakdownItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CaterBreakdownItem({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Center(child: Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color))),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ======================================================================
// 8. REVIEWS VIEW — Catering Reviews
// ======================================================================
class CaterReviewsView extends ConsumerWidget {
  const CaterReviewsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(vendorReviewsProvider);
    final analytics = ref.watch(vendorAnalyticsProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Client Food Reviews', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
                    const SizedBox(height: 8),
                    Text('${reviews.length} review${reviews.length == 1 ? '' : 's'} • ${analytics.totalReviews > 0 ? '${analytics.averageRating.toStringAsFixed(1)} ★ average' : 'No ratings yet'}', style: const TextStyle(fontSize: 15, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (reviews.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_border_rounded, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No reviews yet', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Reviews from your catering clients will appear here.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: reviews.length,
                separatorBuilder: (c, i) => const SizedBox(height: 16),
                itemBuilder: (c, i) {
                  final review = reviews[i];
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundColor: _primaryDark, child: Text(review.clientName.isNotEmpty ? review.clientName[0] : 'C', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(review.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(review.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            Row(children: List.generate(5, (index) => Icon(index < review.rating ? Icons.star : Icons.star_border, color: _accentGold, size: 18))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(review.comment, style: const TextStyle(fontSize: 14, height: 1.5)),
                        if (review.reply != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: _bgOffWhite, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.reply, color: _primaryDark, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Your reply: ${review.reply}', style: const TextStyle(fontSize: 13, color: Colors.black87))),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showReplyDialog(context, ref, review.id),
                            icon: const Icon(Icons.reply, size: 16),
                            label: const Text('Reply to review'),
                            style: OutlinedButton.styleFrom(foregroundColor: _primaryDark, side: BorderSide(color: _primaryDark.withValues(alpha: 0.3))),
                          ),
                        ],
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

  void _showReplyDialog(BuildContext context, WidgetRef ref, String reviewId) {
    final replyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reply to Review', style: TextStyle(fontWeight: FontWeight.bold, color: _primaryDark)),
        content: TextField(
          controller: replyCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write your reply...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (replyCtrl.text.isNotEmpty) {
                ref.read(vendorReviewsProvider.notifier).replyToReview(reviewId, replyCtrl.text);
                Navigator.pop(dlgCtx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryDark, foregroundColor: Colors.white),
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// 9. PROFILE VIEW — Caterer Professional Profile
// ======================================================================
class CaterProfileView extends ConsumerWidget {
  const CaterProfileView({super.key});

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(vendorProfileProvider);
    final analytics = ref.watch(vendorAnalyticsProvider);
    final media = ref.watch(uploadedMediaProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primaryDark, Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _primaryDark.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _accentGold,
                  child: Text(profile.businessName.isNotEmpty ? profile.businessName[0] : 'C', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _primaryDark)),
                ),
                const SizedBox(height: 16),
                Text(profile.businessName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'PlayfairDisplay'), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _accentGold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text(profile.category, style: const TextStyle(color: _accentGold, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                if (profile.location.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: Colors.white60, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(profile.location, style: const TextStyle(color: Colors.white60, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _CaterProfileStat(value: '${analytics.completedBookings}', label: 'Orders')),
                    Container(width: 1, height: 30, color: Colors.white24),
                    Expanded(child: _CaterProfileStat(value: analytics.totalReviews > 0 ? '${analytics.averageRating.toStringAsFixed(1)} ★' : 'N/A', label: 'Rating')),
                    Container(width: 1, height: 30, color: Colors.white24),
                    Expanded(child: _CaterProfileStat(value: _formatCurrency(analytics.totalEarnings), label: 'Revenue')),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('About Catering Service', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showAboutEditModal(context, profile),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(profile.bio.isNotEmpty ? profile.bio : 'No description yet. Tap to add your catering bio and specialities.', style: TextStyle(color: profile.bio.isNotEmpty ? Colors.black87 : Colors.grey, fontSize: 14, height: 1.6)),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.edit_outlined, size: 20, color: _accentGold),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text('Account Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showAccountInfoModal(context, profile),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(16), 
                border: Border.all(color: _accentGold.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(color: _accentGold.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Caterer Business Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDark)),
                      Row(
                        children: const [
                          Text('Edit', style: TextStyle(color: _accentGold, fontSize: 13, fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.edit_outlined, size: 16, color: _accentGold),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Builder(builder: (context) {
                    final auth = ref.watch(authProvider);
                    final ownerDisp = profile.ownerName.isNotEmpty ? profile.ownerName : (auth.displayName != null && auth.displayName!.isNotEmpty ? auth.displayName! : 'Not specified');
                    final emailDisp = profile.email.isNotEmpty ? profile.email : (auth.email != null && auth.email!.isNotEmpty ? auth.email! : 'Not specified');
                    return Column(
                      children: [
                        _buildInfoRow(Icons.person_outline, 'Owner / Manager Name', ownerDisp),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.phone_outlined, 'Phone', profile.phone.isNotEmpty ? profile.phone : 'Not specified'),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.email_outlined, 'Email', emailDisp),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.language_outlined, 'Website / Social', profile.website.isNotEmpty ? profile.website : 'Not specified'),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Menu & Food Showcase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
                  const SizedBox(height: 2),
                  Text(
                    '${profile.outsidePictures.length} Dishes • ${profile.insidePictures.length} Setup photos',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _addMedia(context, ref),
                icon: const Icon(Icons.add_photo_alternate, size: 20),
                label: const Text('Add Photo'),
                style: TextButton.styleFrom(foregroundColor: _accentGold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final List<_CaterPhotoItem> allPhotos = [
              ...profile.outsidePictures.where((u) => u.isNotEmpty).map((url) => _CaterPhotoItem(url: url, category: 'Dishes')),
              ...profile.insidePictures.where((u) => u.isNotEmpty).map((url) => _CaterPhotoItem(url: url, category: 'Setup')),
              ...media.where((u) => u.isNotEmpty).map((url) => _CaterPhotoItem(url: url, category: 'Gallery', isRemovable: true)),
            ];

            if (allPhotos.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: const Column(
                  children: [
                    Icon(Icons.restaurant_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No food photos uploaded yet', style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('Add photos of your signature dishes and buffet setups to attract clients.', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                  ],
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.0),
              itemCount: allPhotos.length,
              itemBuilder: (context, index) {
                final photo = allPhotos[index];
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildGalleryImage(photo.url),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: photo.category == 'Dishes'
                              ? const Color(0xFF059669).withOpacity(0.85)
                              : photo.category == 'Setup'
                                  ? const Color(0xFFD4AF37).withOpacity(0.85)
                                  : Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          photo.category.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () {
                          if (photo.isRemovable) {
                            ref.read(uploadedMediaProvider.notifier).removeMedia(photo.url);
                          } else if (photo.category == 'Dishes') {
                            final updated = profile.outsidePictures.where((u) => u != photo.url).toList();
                            ref.read(vendorProfileProvider.notifier).updateProfile(outsidePictures: updated);
                          } else if (photo.category == 'Setup') {
                            final updated = profile.insidePictures.where((u) => u != photo.url).toList();
                            ref.read(vendorProfileProvider.notifier).updateProfile(insidePictures: updated);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          }),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGalleryImage(String url) {
    if (url.startsWith('data:image')) {
      final split = url.split(',');
      if (split.length == 2) {
        try {
          return Image.memory(
            base64Decode(split[1]),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (c, e, s) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)),
          );
        } catch (_) {}
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (c, e, s) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)),
    );
  }

  void _addMedia(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 70);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64String';

      ref.read(uploadedMediaProvider.notifier).uploadMedia(dataUri);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Photo uploaded successfully!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: const Color(0xFF991B1B), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      }
    }
  }
}

class _CaterPhotoItem {
  final String url;
  final String category;
  final bool isRemovable;
  _CaterPhotoItem({required this.url, required this.category, this.isRemovable = false});
}

class _CaterProfileStat extends StatelessWidget {
  final String value, label;
  const _CaterProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

void _showAccountInfoModal(BuildContext context, VendorProfile profile) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => _CaterAccountInfoModal(profile: profile),
  );
}

class _CaterAccountInfoModal extends ConsumerStatefulWidget {
  final VendorProfile profile;
  const _CaterAccountInfoModal({required this.profile});

  @override
  ConsumerState<_CaterAccountInfoModal> createState() => _CaterAccountInfoModalState();
}

class _CaterAccountInfoModalState extends ConsumerState<_CaterAccountInfoModal> {
  late TextEditingController _ownerNameController;
  late TextEditingController _businessNameController;
  late TextEditingController _locationController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _websiteController;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    final initialOwner = widget.profile.ownerName.isNotEmpty
        ? widget.profile.ownerName
        : (auth.displayName ?? '');
    _ownerNameController = TextEditingController(text: initialOwner);
    _businessNameController = TextEditingController(text: widget.profile.businessName);
    _emailController = TextEditingController(text: widget.profile.email.isNotEmpty ? widget.profile.email : (auth.email ?? ''));
    _locationController = TextEditingController(text: widget.profile.location);
    _websiteController = TextEditingController(text: widget.profile.website);
    _phoneController = TextEditingController(text: widget.profile.phone);
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _businessNameController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    final ownerText = _ownerNameController.text.trim();
    if (ownerText.isNotEmpty) {
      ref.read(authProvider.notifier).updateUserName(ownerText);
    }
    ref.read(vendorProfileProvider.notifier).updateProfile(
      ownerName: ownerText,
      businessName: _businessNameController.text.trim(),
      location: _locationController.text.trim(),
      website: _websiteController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Account info updated!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Account Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 24),
            _buildField('Owner / Manager Name', _ownerNameController, hint: 'Enter owner or manager name'),
            const SizedBox(height: 16),
            _buildField('Business / Catering Service Name', _businessNameController, hint: 'Enter catering service name'),
            const SizedBox(height: 16),
            _buildField('Email Address', _emailController, readOnly: true),
            const SizedBox(height: 16),
            _buildField('Location / Operating Cities', _locationController, hint: 'Enter operating cities'),
            const SizedBox(height: 16),
            _buildField('Phone Number', _phoneController, hint: 'Enter phone number'),
            const SizedBox(height: 16),
            _buildField('Website / Instagram Link', _websiteController, hint: 'Enter website or social media link'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool readOnly = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: TextStyle(color: readOnly ? Colors.grey.shade600 : Colors.black87, fontWeight: FontWeight.w500, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal, fontSize: 14),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

// ======================================================================
// 10. SETTINGS VIEW — Caterer Settings
// ======================================================================
class CaterSettingsView extends ConsumerStatefulWidget {
  const CaterSettingsView({super.key});

  @override
  ConsumerState<CaterSettingsView> createState() => _CaterSettingsViewState();
}

class _CaterSettingsViewState extends ConsumerState<CaterSettingsView> {
  late TextEditingController _nameCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _websiteCtrl;
  bool _bookingAlerts = true;
  bool _reviewAlerts = true;
  bool _promoAlerts = true;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  void _initControllers(VendorProfile profile) {
    if (!_initialized) {
      _nameCtrl = TextEditingController(text: profile.businessName);
      _locationCtrl = TextEditingController(text: profile.location);
      _bioCtrl = TextEditingController(text: profile.bio);
      _phoneCtrl = TextEditingController(text: profile.phone);
      _emailCtrl = TextEditingController(text: profile.email);
      _websiteCtrl = TextEditingController(text: profile.website);
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(vendorProfileProvider);
    _initControllers(profile);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
          const SizedBox(height: 32),

          const Text('Subscription Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final plans = ref.watch(subscriptionPlansProvider);
              final isHighest = plans.isNotEmpty && profile.subscriptionTier.toLowerCase() == plans.last.id.toLowerCase();

              if (isHighest) {
                final topPlan = plans.last;
                final badgeColor = Color(int.parse('0xFF${topPlan.colorHex}'));
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [badgeColor, _primaryDark]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: _accentGold, size: 48),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${topPlan.name} Member', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            const Text('You have unlocked the highest tier of visibility and premium features.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            if (profile.subscriptionExpiry != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
                                child: Text('Expires on: ${profile.subscriptionExpiry.toString().substring(0, 10)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('admin_subscriptions')
                    .where('vendorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  String activeTier = profile.subscriptionTier;
                  DateTime? activeExpiry = profile.subscriptionExpiry;

                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final docs = snapshot.data!.docs.toList();
                    docs.sort((a, b) {
                      final mapA = a.data() as Map<String, dynamic>;
                      final mapB = b.data() as Map<String, dynamic>;
                      
                      DateTime? dateA;
                      final valA = mapA['date'];
                      if (valA != null) {
                        if (valA is Timestamp) {
                          dateA = valA.toDate();
                        } else if (valA is String) {
                          dateA = DateTime.tryParse(valA);
                        }
                      }
                      
                      DateTime? dateB;
                      final valB = mapB['date'];
                      if (valB != null) {
                        if (valB is Timestamp) {
                          dateB = valB.toDate();
                        } else if (valB is String) {
                          dateB = DateTime.tryParse(valB);
                        }
                      }

                      if (dateA == null && dateB == null) return 0;
                      if (dateA == null) return 1;
                      if (dateB == null) return -1;
                      return dateB.compareTo(dateA);
                    });

                    final doc = docs.first.data() as Map<String, dynamic>;
                    if (doc.containsKey('tier')) activeTier = doc['tier'].toString();
                    if (doc.containsKey('date') && doc['date'] != null) {
                      final val = doc['date'];
                      DateTime? parsedDate;
                      if (val is Timestamp) {
                        parsedDate = val.toDate();
                      } else if (val is String) {
                        parsedDate = DateTime.tryParse(val);
                      }
                      if (parsedDate != null) {
                        activeExpiry = parsedDate.add(const Duration(days: 30));
                      }
                    }
                  }

                  final currentPlan = plans.where((p) => p.id == activeTier.toLowerCase()).firstOrNull;
                  final currentPlanName = currentPlan?.name ?? (activeTier == 'free' ? 'Free' : activeTier);

                  if (activeTier != 'free' && currentPlan != null) {
                    final badgeColor = Color(int.parse('0xFF${currentPlan.colorHex}'));
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            badgeColor,
                            Color.lerp(badgeColor, Colors.black, 0.35) ?? badgeColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: badgeColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned(right: -30, top: -30, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
                          Positioned(right: 50, bottom: -20, child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)))),
                          
                          Padding(
                            padding: const EdgeInsets.all(26),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      child: const Text('ACTIVE SUBSCRIPTION', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                    ),
                                    const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  currentPlanName.toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 36, color: Colors.white, fontFamily: 'PlayfairDisplay', letterSpacing: 1),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        activeExpiry != null 
                                          ? 'Expires on: ${activeExpiry.toString().substring(0, 10)}'
                                          : 'Valid till: Lifetime Access',
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
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

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _accentGold, width: 1.5)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current: ${currentPlanName.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDark)),
                        if (activeTier != 'free' && activeExpiry != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Expires on: ${activeExpiry.toString().substring(0, 10)}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(height: 8),
                        const Text('Upgrade your subscription for maximum reach.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 20),
                        ...plans.map((plan) {
                          final isCurrentTier = activeTier.toLowerCase() == plan.id.toLowerCase();
                          final badgeColor = Color(int.parse('0xFF${plan.colorHex}'));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isCurrentTier ? null : () async {
                                  final authState = ref.read(authProvider);
                                  if (!authState.isAuthenticated || authState.userId == null) return;
                                  final vendorId = authState.userId!;
                                  
                                  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                                  
                                  try {
                                    final now = DateTime.now();
                                    final expiry = now.add(const Duration(days: 30));
                                    
                                    final batch = FirebaseFirestore.instance.batch();
                                    
                                    final vendorRef = FirebaseFirestore.instance.collection('vendors').doc(vendorId);
                                    batch.update(vendorRef, {'subscriptionTier': plan.id});
                                    
                                    final profileRef = FirebaseFirestore.instance.collection('vendor_profile').doc(vendorId);
                                    batch.update(profileRef, {
                                      'subscriptionTier': plan.id,
                                      'subscriptionExpiry': expiry.toIso8601String(),
                                    });
                                    
                                    final adminSubRef = FirebaseFirestore.instance.collection('admin_subscriptions').doc();
                                    batch.set(adminSubRef, {
                                      'vendorId': vendorId,
                                      'vendorName': profile.businessName,
                                      'tier': plan.name,
                                      'amount': plan.price,
                                      'date': now.toIso8601String(),
                                    });
                                    
                                    await batch.commit();
                                    
                                    if (context.mounted) {
                                      Navigator.pop(context); 
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully upgraded to ${plan.name}!')));
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      Navigator.pop(context); 
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upgrade failed: $e')));
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isCurrentTier ? Colors.grey.shade300 : badgeColor,
                                  foregroundColor: isCurrentTier ? Colors.grey.shade600 : Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(isCurrentTier ? 'Current: ${plan.name}' : 'Upgrade to ${plan.name} (${(plan.price / 1000).toStringAsFixed(0)}k PKR)', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 32),
          const Text('Quick Replies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (ctx) => const CaterQuickRepliesScreen()));
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
              child: const Row(
                children: [
                  Icon(Icons.reply_all_rounded, color: _accentGold, size: 28),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Manage Quick Replies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDark)),
                        SizedBox(height: 4),
                        Text('Edit, add or delete your message templates', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          const Text('Notification Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Booking Alerts', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Get notified when you receive new catering orders', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    value: _bookingAlerts,
                    activeTrackColor: _accentGold.withValues(alpha: 0.5),
                    activeThumbColor: _accentGold,
                    onChanged: (v) => setState(() => _bookingAlerts = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Review Alerts', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Get notified when clients leave food reviews', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    value: _reviewAlerts,
                    activeTrackColor: _accentGold.withValues(alpha: 0.5),
                    activeThumbColor: _accentGold,
                    onChanged: (v) => setState(() => _reviewAlerts = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Promotion Alerts', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Get notified about promotion performance and expiry', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    value: _promoAlerts,
                    activeTrackColor: _accentGold.withValues(alpha: 0.5),
                    activeThumbColor: _accentGold,
                    onChanged: (v) => setState(() => _promoAlerts = v),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          const Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: _primaryDark),
                    title: const Text('Signed in as', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(profile.email.isNotEmpty ? profile.email : 'No email set', style: const TextStyle(fontWeight: FontWeight.w500, color: _primaryDark)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Color(0xFF991B1B)),
                    title: const Text('Delete Account', style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w500)),
                    subtitle: const Text('Permanently delete your caterer account', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (dlgCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                          content: const Text('This action is permanent and cannot be undone. All your data will be lost.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(dlgCtx);
                                
                                final uid = FirebaseAuth.instance.currentUser?.uid;
                                final authNotifier = ref.read(authProvider.notifier);
                                
                                ref.invalidate(vendorCatalogProvider);
                                ref.invalidate(vendorMessagesProvider);
                                ref.invalidate(vendorReviewsProvider);
                                ref.invalidate(vendorPromotionsProvider);
                                ref.invalidate(vendorProfileProvider);
                                ref.invalidate(uploadedMediaProvider);
                                ref.invalidate(vendorAvailabilityProvider);
                                ref.invalidate(quickReplyTemplatesProvider);
                                ref.invalidate(vendorInquiriesProvider);
                                ref.invalidate(vendorAnalyticsProvider);
                                ref.invalidate(vendorPerformanceTipsProvider);
                                ref.invalidate(vendorBookingFilterProvider);
                                ref.invalidate(vendorBookingSearchProvider);

                                bool requiresRecentLogin = false;
                                if (uid != null) {
                                  try {
                                    await FirebaseAuth.instance.currentUser?.delete();
                                    await FirebaseFirestore.instance.collection('vendors').doc(uid).delete();
                                    await FirebaseFirestore.instance.collection('vendor_profile').doc(uid).delete();
                                    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
                                  } catch (e) {
                                    print('Error deleting account: $e');
                                    if (e.toString().contains('requires-recent-login')) {
                                      requiresRecentLogin = true;
                                    }
                                  }
                                }

                                await authNotifier.signOut();
                                
                                if (requiresRecentLogin && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please log in again to verify your identity before deleting your account.'),
                                      backgroundColor: _accentGold,
                                      duration: Duration(seconds: 5),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF991B1B), foregroundColor: Colors.white),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

void _showAboutEditModal(BuildContext context, VendorProfile profile) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => _CaterAboutEditModal(profile: profile),
  );
}

class _CaterAboutEditModal extends ConsumerStatefulWidget {
  final VendorProfile profile;
  const _CaterAboutEditModal({required this.profile});

  @override
  ConsumerState<_CaterAboutEditModal> createState() => _CaterAboutEditModalState();
}

class _CaterAboutEditModalState extends ConsumerState<_CaterAboutEditModal> {
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.profile.bio);
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(vendorProfileProvider.notifier).updateProfile(
      bio: _bioController.text,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('About section updated successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 32, left: 24, right: 24, top: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Edit Catering Bio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _bioController,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Catering Description & Specialties',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accentGold, width: 2)),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: _primaryDark, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class CaterQuickRepliesScreen extends ConsumerWidget {
  const CaterQuickRepliesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(quickReplyTemplatesProvider);

    return Scaffold(
      backgroundColor: _bgOffWhite,
      appBar: AppBar(
        title: const Text('Quick Replies', style: TextStyle(color: _primaryDark, fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: _primaryDark),
        elevation: 0,
      ),
      body: templates.isEmpty
          ? const Center(child: Text('No quick replies available. Create one!', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  shadowColor: Colors.black12,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(template.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDark))),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: _accentGold, size: 20),
                              onPressed: () => _showEditDialog(context, ref, template: template),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFF991B1B), size: 20),
                              onPressed: () async {
                                final confirmed = await _showLuxuryConfirmDialog(
                                  context: context,
                                  title: 'Delete Quick Reply',
                                  message: 'Are you sure you want to delete "${template.title}"? This cannot be undone.',
                                  confirmText: 'Delete',
                                  icon: Icons.delete_outline_rounded,
                                );
                                if (confirmed == true) {
                                  ref.read(quickReplyTemplatesProvider.notifier).deleteTemplate(template.id);
                                }
                              },
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(template.body, style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87)),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context, ref),
        backgroundColor: _primaryDark,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Reply'),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, {QuickReplyTemplate? template}) {
    final titleCtrl = TextEditingController(text: template?.title ?? '');
    final bodyCtrl = TextEditingController(text: template?.body ?? '');

    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: _bgOffWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(template == null ? 'New Quick Reply' : 'Edit Quick Reply', style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay', fontSize: 22)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Title', 
                      hintText: 'e.g. 🍛 Per-Head Menu Rates',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Message Body',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentGold, 
                foregroundColor: _primaryDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) return;
                if (template == null) {
                  ref.read(quickReplyTemplatesProvider.notifier).addTemplate(titleCtrl.text.trim(), bodyCtrl.text.trim());
                } else {
                  ref.read(quickReplyTemplatesProvider.notifier).updateTemplate(template.id, titleCtrl.text.trim(), bodyCtrl.text.trim());
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
