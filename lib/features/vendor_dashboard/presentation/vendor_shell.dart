import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vendor_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../admin/presentation/admin_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'generic_onboarding_screen.dart';
import 'components/generic_catalog_view.dart';
import 'package:http/http.dart' as http;

// Colors (Emerald Green & Gold Theme)
const _primaryDark = Color(0xFF064E3B);
const _accentGold = Color(0xFFD4AF37);
const _bgOffWhite = Color(0xFFF8FAF9);

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
// ignore: unused_element
const _textDark = Color(0xFF022C22);

class VendorShell extends ConsumerStatefulWidget {
  const VendorShell({super.key});

  @override
  ConsumerState<VendorShell> createState() => _VendorShellState();
}

class _VendorShellState extends ConsumerState<VendorShell> {
  int _selectedIndex = 0;

  // 10 views total:
  // 0-3: Bottom nav (Dashboard, Bookings, Catalog, Messages)
  // 4-9: Sidebar-only (Promotions, Availability, Analytics, Reviews, Profile, Settings)
  List<Widget> get _views => [
    const VendorDashboardOverview(),   // 0
    const VendorBookingsView(),        // 1
    const GenericCatalogView(),        // 2
    const VendorMessagesView(),        // 3
    const VendorPromotionsView(),      // 4
    const VendorAvailabilityView(),    // 5
    const VendorAnalyticsView(),       // 6
    const VendorReviewsView(),         // 7
    const VendorProfileView(),         // 8
    const VendorSettingsView(),        // 9
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
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded, color: Colors.red, size: 64),
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
                  'Your vendor account has been suspended due to compliance violations. Your catalog has been revoked and you have been removed from all consumer ledgers.',
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
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
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
                    'Vendor Terms & Conditions',
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
                    child: SingleChildScrollView(
                      child: const Text(
                        'By continuing to use the ShadiSphere Vendor Portal, you agree to the following Terms and Conditions:\n\n'
                        '1. Quality Assurance: You must maintain a minimum average rating of 3.5 stars. Falling below this threshold may result in suspension.\n\n'
                        '2. Prompt Responses: You agree to respond to consumer inquiries within 48 hours.\n\n'
                        '3. Accurate Representation: All services, media, and pricing listed in your catalog must be accurate and up-to-date.\n\n'
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
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
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

    // Onboarding gate for generic vendors (non-venue, non-cater)
    final cat = profile.category.toLowerCase();
    final isGenericVendor = cat != 'venues' && cat != 'catering';
    if (isGenericVendor && !profile.isSetupComplete) {
      return const GenericOnboardingScreen();
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
          title: const Text('Vendor Dashboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'PlayfairDisplay')),
        ),
        drawer: Drawer(
          width: 280,
          backgroundColor: Colors.transparent,
          child: _buildMobileDrawerContent(context),
        ),
        body: mainView,
        // Bottom nav only shows for bottom-nav views (index 0-3) but always visible
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
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Bookings'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Catalog'),
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
                'Exit Vendor Portal',
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
                        // Invalidate all vendor-specific providers to prevent stale data leakage
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
                  const Text('Manage your bookings, catalog, and analytics.', style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                  child: Text(profile.businessName.isNotEmpty ? profile.businessName[0] : 'V', style: const TextStyle(color: _accentGold, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MOBILE DRAWER: Only shows items NOT in bottom nav ---
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

  // --- DESKTOP SIDEBAR: Shows all items grouped ---
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
                // MAIN
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('MAIN', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
                const SizedBox(height: 12),
                _buildNavItem(0, 'Dashboard', Icons.space_dashboard_rounded, isDrawer: false),
                const SizedBox(height: 8),
                _buildNavItem(1, 'Bookings', Icons.event_available_rounded, isDrawer: false),
                const SizedBox(height: 8),
                _buildNavItem(2, 'Catalog', Icons.inventory_2_rounded, isDrawer: false),
                const SizedBox(height: 8),
                _buildNavItem(3, 'Messages', Icons.forum_rounded, isDrawer: false),
                const SizedBox(height: 24),
                // GROW
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('GROW', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
                const SizedBox(height: 12),
                _buildNavItem(4, 'Promotions & Deals', Icons.local_offer_rounded, isDrawer: false),
                const SizedBox(height: 8),
                _buildNavItem(5, 'Availability', Icons.date_range_rounded, isDrawer: false),
                const SizedBox(height: 24),
                // INSIGHTS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('INSIGHTS', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
                const SizedBox(height: 12),
                _buildNavItem(6, 'Analytics', Icons.insights_rounded, isDrawer: false),
                const SizedBox(height: 8),
                _buildNavItem(7, 'Reviews', Icons.star_rate_rounded, isDrawer: false),
                const SizedBox(height: 24),
                // ACCOUNT
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
                Text('Vendor Dashboard', style: TextStyle(color: _accentGold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2), overflow: TextOverflow.ellipsis),
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
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20), SizedBox(width: 10), Text('Exit Portal', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))]),
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
// 1. DASHBOARD OVERVIEW — with Performance Tips & Active Promotions
// ======================================================================
class VendorDashboardOverview extends ConsumerWidget {
  const VendorDashboardOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(vendorAnalyticsProvider);
    final inquiries = ref.watch(vendorInquiriesProvider);
    final pendingCount = inquiries.where((i) => i.status == 'Pending').length;
    final tips = ref.watch(vendorPerformanceTipsProvider);
    final profile = ref.watch(vendorProfileProvider);
    final isWarned = profile.accountStatus == 'warning';
    final promos = ref.watch(vendorPromotionsProvider);
    final activePromos = promos.where((p) => p.isActive).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account Warning Banner
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
          
          // Pending actions banner
          if (pendingCount > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange.shade700, Colors.orange.shade500]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$pendingCount Pending Request${pendingCount > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('You have booking requests waiting for your response.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      final shellState = context.findAncestorStateOfType<_VendorShellState>();
                      shellState?.setState(() => shellState._selectedIndex = 1);
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                    child: const Text('View'),
                  ),
                ],
              ),
            ),

          // Confirmed bookings banner
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
                        Text('${analytics.confirmedBookings} Active Confirmed Booking${analytics.confirmedBookings > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Clients pay instantly upon checkout. Review and manage your upcoming events.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      final shellState = context.findAncestorStateOfType<_VendorShellState>();
                      shellState?.setState(() => shellState._selectedIndex = 1);
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                    child: const Text('View'),
                  ),
                ],
              ),
            ),

          // At a Glance
          const Text('At a Glance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _MetricData('Total Revenue', _formatCurrency(analytics.totalEarnings), Icons.account_balance_wallet_rounded, Colors.green),
                _MetricData('Completed', '${analytics.completedBookings}', Icons.check_circle_rounded, _primaryDark),
                _MetricData('Confirmed Bookings', '${analytics.confirmedBookings}', Icons.event_available_rounded, Colors.teal),
                _MetricData('Avg. Rating', analytics.totalReviews > 0 ? '${analytics.averageRating.toStringAsFixed(1)} ★' : 'N/A', Icons.star_rounded, _accentGold),
              ];
              if (constraints.maxWidth < 600) {
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  children: cards.map((c) => _buildMetricCard(c.title, c.value, c.icon, c.color)).toList(),
                );
              }
              return Row(
                children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _buildMetricCard(c.title, c.value, c.icon, c.color)))).toList(),
              );
            },
          ),

          // Active Promotions strip
          if (activePromos.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Active Promotions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
                TextButton(
                  onPressed: () {
                    final shellState = context.findAncestorStateOfType<_VendorShellState>();
                    shellState?.setState(() => shellState._selectedIndex = 4);
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
                      gradient: const LinearGradient(colors: [Color(0xFF047857), _primaryDark]),
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

          // Performance Tips
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('Performance Tips', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
            const SizedBox(height: 4),
            const Text('Actionable insights to grow your business', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tips.take(4).length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tip = tips[index];
                final priorityColor = tip.priority == 'high' ? Colors.red : (tip.priority == 'medium' ? Colors.orange : Colors.blue);
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: priorityColor.withValues(alpha: 0.2)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(child: Text(tip.icon, style: const TextStyle(fontSize: 20))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(tip.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _primaryDark))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: priorityColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text(tip.priority.toUpperCase(), style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(tip.description, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          // Quick Actions
          const SizedBox(height: 28),
          const Text('Quick Actions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickActionChip(label: 'Add Package', icon: Icons.add_box_rounded, onTap: () {
                final shellState = context.findAncestorStateOfType<_VendorShellState>();
                shellState?.setState(() => shellState._selectedIndex = 2);
              }),
              _QuickActionChip(label: 'Create Promo', icon: Icons.local_offer_rounded, onTap: () {
                final shellState = context.findAncestorStateOfType<_VendorShellState>();
                shellState?.setState(() => shellState._selectedIndex = 4);
              }),
              _QuickActionChip(label: 'View Analytics', icon: Icons.insights_rounded, onTap: () {
                final shellState = context.findAncestorStateOfType<_VendorShellState>();
                shellState?.setState(() => shellState._selectedIndex = 6);
              }),
              _QuickActionChip(label: 'Manage Calendar', icon: Icons.date_range_rounded, onTap: () {
                final shellState = context.findAncestorStateOfType<_VendorShellState>();
                shellState?.setState(() => shellState._selectedIndex = 5);
              }),
              _QuickActionChip(label: 'Check Reviews', icon: Icons.reviews_rounded, onTap: () {
                final shellState = context.findAncestorStateOfType<_VendorShellState>();
                shellState?.setState(() => shellState._selectedIndex = 7);
              }),
              _QuickActionChip(label: 'Edit Profile', icon: Icons.edit_rounded, onTap: () {
                final shellState = context.findAncestorStateOfType<_VendorShellState>();
                shellState?.setState(() => shellState._selectedIndex = 8);
              }),
            ],
          ),

          // Recent Activity
          const SizedBox(height: 28),
          const Text('Recent Activity', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
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
                  Text('When clients send you booking requests, they will appear here.', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// --- Helper functions for status colors/icons ---
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

class _MetricData {
  final String title, value;
  final IconData icon;
  final Color color;
  const _MetricData(this.title, this.value, this.icon, this.color);
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickActionChip({required this.label, required this.icon, required this.onTap});

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
// 2. BOOKINGS VIEW — Streamlined Instant Booking Pipeline
// ======================================================================
class VendorBookingsView extends ConsumerWidget {
  const VendorBookingsView({super.key});

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
          const Text('Booking Pipeline', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
          const SizedBox(height: 8),
          const Text('Instant booking active: Clients pay upfront. Manage confirmed events through completion.', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 20),

          // Pipeline stages visual (3 streamlined stages: Confirmed -> Completed -> Cancelled)
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
                  _PipelineStage(label: 'Confirmed (Paid)', count: confirmedCount, color: Colors.teal, icon: Icons.check_circle_rounded),
                  _PipelineArrow(),
                  _PipelineStage(label: 'Completed', count: completedCount, color: const Color(0xFF2E7D32), icon: Icons.verified_rounded),
                  _PipelineArrow(),
                  _PipelineStage(label: 'Cancelled', count: rejectedCount, color: const Color(0xFF991B1B), icon: Icons.cancel_rounded),
                ],
              ),
            ),
          ),

          // Search bar
          TextField(
            onChanged: (v) => ref.read(vendorBookingSearchProvider.notifier).state = v,
            decoration: InputDecoration(
              hintText: 'Search by client name or details...',
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

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'All', count: inquiries.length, isSelected: filter == 'All', onTap: () => ref.read(vendorBookingFilterProvider.notifier).state = 'All'),
                const SizedBox(width: 8),
                _FilterChip(label: 'Confirmed', count: confirmedCount, isSelected: filter == 'Confirmed' || filter == 'Pending' || filter == 'Negotiating' || filter == 'Accepted', onTap: () => ref.read(vendorBookingFilterProvider.notifier).state = 'Confirmed', color: Colors.teal),
                const SizedBox(width: 8),
                _FilterChip(label: 'Completed', count: completedCount, isSelected: filter == 'Completed', onTap: () => ref.read(vendorBookingFilterProvider.notifier).state = 'Completed', color: const Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Cancelled', count: rejectedCount, isSelected: filter == 'Cancelled' || filter == 'Rejected', onTap: () => ref.read(vendorBookingFilterProvider.notifier).state = 'Cancelled', color: const Color(0xFF991B1B)),
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
                    Text(search.isNotEmpty ? 'No bookings match your search.' : 'No $filter bookings.', style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('When clients book your services, their confirmed orders will appear here.', style: TextStyle(fontSize: 14, color: Colors.grey)),
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
                              child: Text(inq.clientName.isNotEmpty ? inq.clientName[0].toUpperCase() : 'U', style: const TextStyle(color: _primaryDark, fontWeight: FontWeight.bold, fontSize: 15)),
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

                        // Action Buttons for Confirmed Bookings
                        if (isConfirmed) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => ref.read(vendorInquiriesProvider.notifier).rejectInquiry(inq.id),
                                  icon: const Icon(Icons.close, size: 14),
                                  label: const Text('Cancel Booking', style: TextStyle(fontSize: 12)),
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

class _PipelineStage extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _PipelineStage({required this.label, required this.count, required this.color, required this.icon});

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

class _PipelineArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  const _FilterChip({required this.label, required this.count, required this.isSelected, required this.onTap, this.color = _primaryDark});

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

// ======================================================================
// 3. CATALOG VIEW — with edit/delete
// ======================================================================
class VendorCatalogView extends ConsumerWidget {
  const VendorCatalogView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(vendorCatalogProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 500) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Catalog & Inventory', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
                    const SizedBox(height: 4),
                    Text('${catalog.length} package${catalog.length == 1 ? '' : 's'} listed', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showPackageDialog(context, ref),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Package'),
                      style: ElevatedButton.styleFrom(backgroundColor: _accentGold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Catalog & Inventory', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
                        const SizedBox(height: 8),
                        Text('${catalog.length} package${catalog.length == 1 ? '' : 's'} listed', style: const TextStyle(fontSize: 15, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showPackageDialog(context, ref),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Package'),
                    style: ElevatedButton.styleFrom(backgroundColor: _accentGold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          if (catalog.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('Your catalog is empty', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Click "Add Package" to start listing your services.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 300,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: catalog.length,
                itemBuilder: (context, index) {
                  final pkg = catalog[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            image: pkg.imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(pkg.imageUrl), fit: BoxFit.cover) : null,
                          ),
                          child: pkg.imageUrl.isEmpty ? Center(child: Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400)) : null,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDark), overflow: TextOverflow.ellipsis)),
                                    PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                                      onSelected: (action) {
                                        if (action == 'edit') {
                                          _showPackageDialog(context, ref, existing: pkg);
                                        } else if (action == 'delete') {
                                          _showDeleteConfirm(context, ref, pkg);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: _primaryDark), SizedBox(width: 8), Text('Edit')])),
                                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pkg.pricingUnit.isNotEmpty ? '${pkg.price} / ${pkg.pricingUnit}' : pkg.price,
                                  style: const TextStyle(color: _accentGold, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                Expanded(child: Text(pkg.description, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
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

  void _showPackageDialog(BuildContext context, WidgetRef ref, {CatalogPackage? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing?.price ?? '');
    final unitCtrl = TextEditingController(text: existing?.pricingUnit ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String currentImageUrl = existing?.imageUrl ?? '';
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AlertDialog(
              backgroundColor: const Color(0xFFFAF5EC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                existing != null ? 'Edit Package' : 'Add New Package', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay', fontSize: 22),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl, 
                        decoration: InputDecoration(
                          labelText: 'Package Name', 
                          prefixIcon: const Icon(Icons.label_outline, color: _primaryDark, size: 20),
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
                              controller: priceCtrl, 
                              decoration: InputDecoration(
                                labelText: 'Price (e.g., Rs. 50,000)', 
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
                              controller: unitCtrl, 
                              decoration: InputDecoration(
                                labelText: 'Unit (e.g., per day)', 
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ],
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
                      
                      // Image Picker Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            if (currentImageUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(currentImageUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
                                ),
                              ),
                            if (isUploading)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(color: _accentGold),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                  
                                  if (image != null) {
                                    setState(() => isUploading = true);
                                    try {
                                      final bytes = await image.readAsBytes();
                                      final request = http.MultipartRequest(
                                        'POST',
                                        Uri.parse('https://api.cloudinary.com/v1_1/isuedugk/image/upload'),
                                      );
                                      request.fields['upload_preset'] = 'shadi_sphere_uploads';
                                      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'package.jpg'));

                                      final response = await request.send();
                                      final responseData = await response.stream.toBytes();
                                      final jsonMap = jsonDecode(String.fromCharCodes(responseData));
                                      
                                      if (response.statusCode == 200) {
                                        setState(() {
                                          currentImageUrl = jsonMap['secure_url'];
                                          isUploading = false;
                                        });
                                      } else {
                                        throw Exception('Cloudinary error: ${jsonMap['error']?['message']}');
                                      }
                                    } catch (e) {
                                      print('Error uploading image: $e');
                                      setState(() => isUploading = false);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.upload_file, color: _primaryDark),
                                label: Text(currentImageUrl.isEmpty ? 'Upload Package Image' : 'Change Image', style: const TextStyle(color: _primaryDark)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                          ],
                        ),
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
                  onPressed: isUploading ? null : () {
                    if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                      if (existing != null) {
                        ref.read(vendorCatalogProvider.notifier).updatePackage(existing.id, name: nameCtrl.text, price: priceCtrl.text, pricingUnit: unitCtrl.text, description: descCtrl.text, imageUrl: currentImageUrl);
                      } else {
                        ref.read(vendorCatalogProvider.notifier).addPackage(nameCtrl.text, priceCtrl.text, unitCtrl.text, descCtrl.text, imageUrl: currentImageUrl);
                      }
                      Navigator.pop(dlgCtx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGold, 
                    foregroundColor: _primaryDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: Text(existing != null ? 'Save Changes' : 'Add Package', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, CatalogPackage pkg) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Package', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Are you sure you want to delete "${pkg.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              ref.read(vendorCatalogProvider.notifier).deletePackage(pkg.id);
              Navigator.pop(dlgCtx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// 4. MESSAGES VIEW — with Quick Reply Templates
// ======================================================================
class VendorMessagesView extends ConsumerWidget {
  const VendorMessagesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(vendorMessagesProvider);
    final templates = ref.watch(quickReplyTemplatesProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 500) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Messages', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
                    const SizedBox(height: 4),
                    const Text('Communicate with potential clients.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 12),
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
                );
              }
              return Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Messages', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
                        SizedBox(height: 8),
                        Text('Communicate with potential clients.', style: TextStyle(fontSize: 15, color: Colors.grey)),
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
              );
            },
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
                    const Text('When clients reach out, their messages will appear here.', style: TextStyle(fontSize: 14, color: Colors.grey)),
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
                    leading: CircleAvatar(backgroundColor: _accentGold, child: Text(msg.clientName.isNotEmpty ? msg.clientName[0] : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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
// 5. PROMOTIONS & DEALS VIEW (NEW)
// ======================================================================
class VendorPromotionsView extends ConsumerWidget {
  const VendorPromotionsView({super.key});

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
                    const Text('Promotions & Deals', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
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

          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Active promotions are shown to consumers on your listing. Limited-time deals create urgency and boost bookings by up to 40%!',
                    style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
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
                    const Text('Create your first deal to attract more clients.', style: TextStyle(fontSize: 14, color: Colors.grey)),
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
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (dlgCtx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text('Delete Promotion?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                    content: Text('Delete "${promo.title}"? This cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                                      ElevatedButton(
                                        onPressed: () {
                                          ref.read(vendorPromotionsProvider.notifier).deletePromotion(promo.id);
                                          Navigator.pop(dlgCtx);
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
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
          backgroundColor: const Color(0xFFFAF5EC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(existingPromo == null ? 'Create New Deal' : 'Edit Deal', style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay', fontSize: 22)),
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
                      hintText: 'e.g., Summer Special',
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
// 6. AVAILABILITY CALENDAR VIEW (NEW)
// ======================================================================
class VendorAvailabilityView extends ConsumerStatefulWidget {
  const VendorAvailabilityView({super.key});

  @override
  ConsumerState<VendorAvailabilityView> createState() => _VendorAvailabilityViewState();
}

class _VendorAvailabilityViewState extends ConsumerState<VendorAvailabilityView> {
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
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1=Mon, 7=Sun
    final monthName = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][_currentMonth.month - 1];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Availability Calendar', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
          const SizedBox(height: 8),
          const Text('Tap dates to mark them as blocked. Consumers will see your availability.', style: TextStyle(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 24),

          // Legend
          Row(
            children: [
              _CalendarLegend(color: Colors.green.shade100, borderColor: Colors.green, label: 'Available'),
              const SizedBox(width: 16),
              _CalendarLegend(color: Colors.red.shade100, borderColor: Colors.red, label: 'Blocked'),
              const SizedBox(width: 16),
              _CalendarLegend(color: Colors.grey.shade200, borderColor: Colors.grey, label: 'Past'),
            ],
          ),
          const SizedBox(height: 24),

          // Month navigation
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

                // Day headers
                Row(
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => Expanded(
                    child: Center(child: Text(d, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600))),
                  )).toList(),
                ),
                const SizedBox(height: 8),

                // Calendar grid
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
                      return const SizedBox(); // Empty cells for offset
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
                                Icon(Icons.block, size: 10, color: Colors.red.shade400),
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

          // Stats
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
                    _AvailabilityStat(label: 'Days This Month', value: '$daysInMonth', color: _primaryDark),
                    _AvailabilityStat(label: 'Blocked', value: '$blockedThisMonth', color: Colors.red),
                    _AvailabilityStat(label: 'Available', value: '${daysInMonth - blockedThisMonth}', color: Colors.green),
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

class _CalendarLegend extends StatelessWidget {
  final Color color, borderColor;
  final String label;
  const _CalendarLegend({required this.color, required this.borderColor, required this.label});

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

class _AvailabilityStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AvailabilityStat({required this.label, required this.value, required this.color});

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
// 7. ANALYTICS VIEW — with extra metrics
// ======================================================================
class VendorAnalyticsView extends ConsumerWidget {
  const VendorAnalyticsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(vendorAnalyticsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue & Analytics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
          const SizedBox(height: 24),

          // 4 stat cards
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _MetricData('Total Earnings', _formatCurrency(analytics.totalEarnings), Icons.payments_rounded, Colors.green),
                _MetricData('Pending Revenue', _formatCurrency(analytics.pendingRevenue), Icons.hourglass_top_rounded, Colors.orange),
                _MetricData('Avg. Rating', analytics.totalReviews > 0 ? '${analytics.averageRating.toStringAsFixed(1)} ★' : 'N/A', Icons.star_rounded, _accentGold),
                _MetricData('Conversion', '${analytics.conversionRate.toStringAsFixed(0)}%', Icons.trending_up_rounded, Colors.blue),
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

          // Booking breakdown
          const SizedBox(height: 32),
          const Text('Booking Pipeline Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BreakdownItem(label: 'Confirmed', count: analytics.confirmedBookings, color: Colors.teal),
                _BreakdownItem(label: 'Completed', count: analytics.completedBookings, color: const Color(0xFF2E7D32)),
                _BreakdownItem(label: 'Cancelled', count: analytics.rejectedBookings, color: const Color(0xFF991B1B)),
              ],
            ),
          ),

          // Revenue chart
          const SizedBox(height: 32),
          Container(
            height: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monthly Revenue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
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

class _BreakdownItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _BreakdownItem({required this.label, required this.count, required this.color});

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
// 8. REVIEWS VIEW — with working reply
// ======================================================================
class VendorReviewsView extends ConsumerWidget {
  const VendorReviewsView({super.key});

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
                    const Text('Customer Reviews', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryDark, fontFamily: 'PlayfairDisplay')),
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
                    const Text('Reviews from your clients will appear here.', style: TextStyle(fontSize: 14, color: Colors.grey)),
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
                            CircleAvatar(backgroundColor: _primaryDark, child: Text(review.clientName.isNotEmpty ? review.clientName[0] : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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
// 9. PROFILE VIEW — full professional profile
// ======================================================================
class VendorProfileView extends ConsumerWidget {
  const VendorProfileView({super.key});

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
          // Profile header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primaryDark, Color(0xFF4C1D66)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _primaryDark.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _accentGold,
                  child: Text(profile.businessName.isNotEmpty ? profile.businessName[0] : 'V', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _primaryDark)),
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
                // Stats row
                Row(
                  children: [
                    Expanded(child: _ProfileStat(value: '${analytics.completedBookings}', label: 'Bookings')),
                    Container(width: 1, height: 30, color: Colors.white24),
                    Expanded(child: _ProfileStat(value: analytics.totalReviews > 0 ? '${analytics.averageRating.toStringAsFixed(1)} ★' : 'N/A', label: 'Rating')),
                    Container(width: 1, height: 30, color: Colors.white24),
                    Expanded(child: _ProfileStat(value: 'Rs. ${(analytics.totalEarnings / 1000).toStringAsFixed(0)}k', label: 'Revenue')),
                  ],
                ),
              ],
            ),
          ),

          // Bio
          const SizedBox(height: 24),
          const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
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
                    child: Text(profile.bio.isNotEmpty ? profile.bio : 'No description yet. Tap to add your business bio.', style: TextStyle(color: profile.bio.isNotEmpty ? Colors.black87 : Colors.grey, fontSize: 14, height: 1.6)),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.edit_outlined, size: 20, color: _accentGold),
                ],
              ),
            ),
          ),

          // Account Info
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _accentGold.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.person_outline, color: _accentGold),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Manage Account Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDark)),
                        SizedBox(height: 4),
                        Text('View and edit your personal & business details', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),

          // Portfolio Gallery
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Portfolio Gallery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
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
            final List<String> allPhotos = [
              ...profile.outsidePictures.where((u) => u.isNotEmpty),
              ...profile.insidePictures.where((u) => u.isNotEmpty),
              ...media.where((u) => u.isNotEmpty),
            ].toSet().toList();

            if (allPhotos.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: const Column(
                  children: [
                    Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No photos yet', style: TextStyle(color: Colors.grey, fontSize: 15)),
                    SizedBox(height: 4),
                    Text('Showcase your work to attract more clients.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              );
            }
            
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: allPhotos.length,
              itemBuilder: (context, index) {
                final url = allPhotos[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildGalleryImage(url),
                    ),
                    Positioned(
                      top: 6, right: 6,
                      child: GestureDetector(
                        onTap: () {
                          if (profile.outsidePictures.contains(url)) {
                            final updated = profile.outsidePictures.where((u) => u != url).toList();
                            ref.read(vendorProfileProvider.notifier).updateProfile(outsidePictures: updated);
                          }
                          if (profile.insidePictures.contains(url)) {
                            final updated = profile.insidePictures.where((u) => u != url).toList();
                            ref.read(vendorProfileProvider.notifier).updateProfile(insidePictures: updated);
                          }
                          if (media.contains(url)) {
                            ref.read(uploadedMediaProvider.notifier).removeMedia(url);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
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
      
      // Instead of relying on Firebase Storage which might fail in offline/mock/web environments without CORS,
      // convert directly to base64 data URI to be saved directly in Firestore documents alongside other data.
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
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      }
    }
  }
}

class _ProfileStat extends StatelessWidget {
  final String value, label;
  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
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
    builder: (context) => _AccountInfoModal(profile: profile),
  );
}

class _AccountInfoModal extends ConsumerStatefulWidget {
  final VendorProfile profile;
  const _AccountInfoModal({required this.profile});

  @override
  ConsumerState<_AccountInfoModal> createState() => _AccountInfoModalState();
}

class _AccountInfoModalState extends ConsumerState<_AccountInfoModal> {
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
    _ownerNameController = TextEditingController(text: auth.displayName ?? '');
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
    ref.read(authProvider.notifier).updateUserName(_ownerNameController.text.trim());
    ref.read(vendorProfileProvider.notifier).updateProfile(
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
            _buildField('Owner / Full Name', _ownerNameController, hint: 'Enter your full name'),
            const SizedBox(height: 16),
            _buildField('Business / Venue Name', _businessNameController, hint: 'Enter your business name'),
            const SizedBox(height: 16),
            _buildField('Email Address', _emailController, readOnly: true),
            const SizedBox(height: 16),
            _buildField('Location / City', _locationController, hint: 'Enter your city'),
            const SizedBox(height: 16),
            _buildField('Phone Number', _phoneController, hint: 'Enter your phone number'),
            const SizedBox(height: 16),
            _buildField('Website / Social Link', _websiteController, hint: 'Enter your website or social link'),
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
// 10. SETTINGS VIEW — with working save & notifications
// ======================================================================
class VendorSettingsView extends ConsumerStatefulWidget {
  const VendorSettingsView({super.key});

  @override
  ConsumerState<VendorSettingsView> createState() => _VendorSettingsViewState();
}

class _VendorSettingsViewState extends ConsumerState<VendorSettingsView> {
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

          // Subscription Plan
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

              final currentPlan = plans.where((p) => p.id == profile.subscriptionTier.toLowerCase()).firstOrNull;
              final currentPlanName = currentPlan?.name ?? (profile.subscriptionTier == 'free' ? 'Free' : profile.subscriptionTier);

              if (profile.subscriptionTier != 'free' && currentPlan != null) {
                final badgeColor = Color(int.parse('0xFF${currentPlan.colorHex}'));
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [badgeColor, badgeColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: badgeColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ACTIVE SUBSCRIPTION', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentPlanName.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: Colors.white, fontFamily: 'PlayfairDisplay'),
                      ),
                      const SizedBox(height: 16),
                      if (profile.subscriptionExpiry != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Expires on: ${profile.subscriptionExpiry.toString().substring(0, 10)}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
                    if (profile.subscriptionTier != 'free' && profile.subscriptionExpiry != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Expires on: ${profile.subscriptionExpiry.toString().substring(0, 10)}', style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 8),
                    const Text('Upgrade your subscription for maximum reach.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 20),
                    ...plans.map((plan) {
                      final isCurrentTier = profile.subscriptionTier.toLowerCase() == plan.id.toLowerCase();
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
                    }),
                  ],
                ),
              );
            },
          ),

          // Quick Replies
          const SizedBox(height: 32),
          const Text('Quick Replies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (ctx) => const VendorQuickRepliesScreen()));
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

          // Notification Preferences
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
                    subtitle: const Text('Get notified when you receive new booking requests', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    value: _bookingAlerts,
                    activeTrackColor: _accentGold.withValues(alpha: 0.5),
                    activeThumbColor: _accentGold,
                    onChanged: (v) => setState(() => _bookingAlerts = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Review Alerts', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Get notified when clients leave reviews', style: TextStyle(fontSize: 12, color: Colors.grey)),
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

          // Account section
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
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Permanently delete your vendor account', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (dlgCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          content: const Text('This action is permanent and cannot be undone. All your data will be lost.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () async {
                                // Pop dialog immediately to prevent it getting stuck over the screen
                                Navigator.pop(dlgCtx);
                                
                                final uid = FirebaseAuth.instance.currentUser?.uid;
                                final authNotifier = ref.read(authProvider.notifier);
                                
                                // Invalidate providers
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
                                    // Delete Auth Account FIRST! 
                                    // This prevents the zombie consumer issue if Auth deletion fails.
                                    await FirebaseAuth.instance.currentUser?.delete();
                                    
                                    // If Auth deletion succeeded, delete Firestore data
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
                                
                                // context.mounted check might fail after redirect, but snackbar uses root context if possible, 
                                // or we can just rely on the redirect. Since dialog is already popped, it's fine.
                                if (requiresRecentLogin && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please log in again to verify your identity before deleting your account.'),
                                      backgroundColor: Colors.orange,
                                      duration: Duration(seconds: 5),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
    builder: (context) => _AboutEditModal(profile: profile),
  );
}

class _AboutEditModal extends ConsumerStatefulWidget {
  final VendorProfile profile;
  const _AboutEditModal({required this.profile});

  @override
  ConsumerState<_AboutEditModal> createState() => _AboutEditModalState();
}

class _AboutEditModalState extends ConsumerState<_AboutEditModal> {
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
              const Text('Edit About', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _bioController,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Business Description',
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

// =====================================================================
// NEW: QUICK REPLIES SCREEN
// =====================================================================

class VendorQuickRepliesScreen extends ConsumerWidget {
  const VendorQuickRepliesScreen({super.key});

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
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Reply?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                    content: const Text('Are you sure you want to delete this quick reply?'),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        onPressed: () {
                                          ref.read(quickReplyTemplatesProvider.notifier).deleteTemplate(template.id);
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text('Delete'),
                                      )
                                    ],
                                  ),
                                );
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
          backgroundColor: const Color(0xFFFAF5EC),
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
                      hintText: 'e.g. 💰 Pricing Info',
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
