import 'dart:ui';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'admin_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../consumer/presentation/consumer_providers.dart';
import 'package:http/http.dart' as http;

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _selectedIndex = 0;

  List<Widget> get _views => const [
    MetricsDashboard(),
    RevenueSubscriptionsView(),
    SubscriptionModelsAdminView(),
    VendorComplianceView(),
    CityRecommendationsView(),
    UserFeedbackView(),
    FeatureTeasersAdminView(),
    ContentManagerView(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 750;

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
        key: ValueKey<int>(_selectedIndex),
        child: _views[_selectedIndex],
      ),
    );

    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF5EC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D103E),
          elevation: 4,
          shadowColor: const Color(0xFF2D103E).withValues(alpha: 0.4),
          iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
          title: const Text(
            'Admin Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'PlayfairDisplay',
            ),
          ),
        ),
        drawer: Drawer(
          width: 280,
          backgroundColor: Colors.transparent,
          child: _buildSidebarContent(context, isDrawer: true),
        ),
        body: mainView,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EC),
      body: Row(
        children: [
          _buildSidebarContent(context, isDrawer: false),
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
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit Admin Panel', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
        content: const Text('Are you sure you want to log out and exit the admin panel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Logged out of Admin Panel'),
                    backgroundColor: const Color(0xFF2D103E),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                context.go('/welcome');
              }
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, System Admin',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D103E),
                      fontFamily: 'PlayfairDisplay',
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Here\'s what\'s happening on ShadiSphere today.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2D103E).withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: Color(0xFFD4AF37), size: 26),
                          onPressed: () {},
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4AF37), Color(0xFFFFF2CD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFF2D103E),
                      child: Text('SA', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 16)),
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


  Widget _buildSidebarContent(BuildContext context, {required bool isDrawer}) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D103E), Color(0xFF1B0727)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: isDrawer ? [] : [
          BoxShadow(
            color: const Color(0xFF2D103E).withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(5, 0),
          )
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 50),
          // Brand Logo Header
          Container(
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
                      Text(
                        'ShadiSphere',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildNavItem(0, 'Dashboard', Icons.space_dashboard_rounded, isDrawer: isDrawer),
                const SizedBox(height: 12),
                _buildNavItem(1, 'Revenue', Icons.payments_rounded, isDrawer: isDrawer),
                const SizedBox(height: 12),
                _buildNavItem(2, 'Subscription Models', Icons.card_membership, isDrawer: isDrawer),
                const SizedBox(height: 12),
                _buildNavItem(3, 'Compliance', Icons.gavel_rounded, isDrawer: isDrawer),
                const SizedBox(height: 12),
                _buildNavItem(4, 'Expansion', Icons.trending_up_rounded, isDrawer: isDrawer),
                const SizedBox(height: 12),
                _buildNavItem(5, 'Feedback', Icons.rate_review_rounded, isDrawer: isDrawer),
                const SizedBox(height: 12),
                _buildNavItem(6, 'Teasers', Icons.campaign_rounded, isDrawer: isDrawer),
                const SizedBox(height: 12),
                _buildNavItem(7, 'Content', Icons.view_carousel_rounded, isDrawer: isDrawer),
              ],
            ),
          ),

          // Footer (Logout Action)
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: InkWell(
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                _handleLogout(context, ref);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Exit Panel',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
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

  Widget _buildNavItem(int index, String label, IconData icon, {required bool isDrawer}) {
    final isSelected = _selectedIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isSelected ? const LinearGradient(
          colors: [Color(0xFF4C1D66), Color(0xFF2D103E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        border: Border.all(
          color: isSelected ? const Color(0xFFD4AF37).withValues(alpha: 0.5) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isSelected ? [
          BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
            if (isDrawer) {
              Navigator.pop(context);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFFD4AF37) : Colors.white60,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4AF37),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFFD4AF37), blurRadius: 4),
                      ],
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

class MetricsDashboard extends ConsumerWidget {
  const MetricsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(adminMetricsProvider);
    final bool isMobile = MediaQuery.of(context).size.width <= 850;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D103E),
              fontFamily: 'PlayfairDisplay',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Live statistical data and ecosystem activity metrics.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          // Metrics Cards
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMetricCard(context, 'Total Consumers', metrics.totalConsumers, '+12% growth', Icons.people_outline_rounded, Colors.green),
                const SizedBox(height: 20),
                _buildMetricCard(context, 'Active Vendors', metrics.activeVendors, 'High activity', Icons.storefront_rounded, const Color(0xFF2D103E)),
                const SizedBox(height: 20),
                _buildMetricCard(context, 'Total Bookings', metrics.totalBookings, '+18% this month', Icons.event_available_rounded, const Color(0xFFD4AF37)),
                const SizedBox(height: 20),
                _buildMetricCard(context, 'Total Revenue', 'Rs. ${metrics.totalRevenue.toStringAsFixed(0)}', 'Premium Subscriptions', Icons.payments_rounded, const Color(0xFF2E8B57)),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _buildMetricCard(context, 'Total Consumers', metrics.totalConsumers, '+12% growth', Icons.people_outline_rounded, Colors.green)),
                const SizedBox(width: 24),
                Expanded(child: _buildMetricCard(context, 'Active Vendors', metrics.activeVendors, 'High activity', Icons.storefront_rounded, const Color(0xFF2D103E))),
                const SizedBox(width: 24),
                Expanded(child: _buildMetricCard(context, 'Total Bookings', metrics.totalBookings, '+18% this month', Icons.event_available_rounded, const Color(0xFFD4AF37))),
                const SizedBox(width: 24),
                Expanded(child: _buildMetricCard(context, 'Total Revenue', 'Rs. ${metrics.totalRevenue.toStringAsFixed(0)}', 'Premium Subs', Icons.payments_rounded, const Color(0xFF2E8B57), topBubble: 'revenue this month')),
              ],
            ),
          const SizedBox(height: 32),
          // Native Custom Weekly Activity Chart
          Container(
            height: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF0E5D8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2D103E).withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Weekly Platform Activity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay'),
                    ),
                    Text(
                      'Registrations',
                      style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: metrics.weeklyRegistrations.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: _buildChartBar(entry.key, entry.value, entry.value.toInt().toString()),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, String tagline, IconData icon, Color color, {String? topBubble}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.05), color.withValues(alpha: 0.15)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2D103E),
              fontSize: 38,
              fontWeight: FontWeight.w900,
              fontFamily: 'PlayfairDisplay',
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.trending_up, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  tagline,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    if (topBubble != null)
      Positioned(
          top: -12,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Text(
              topBubble,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
    ],
  );
}

  Widget _buildChartBar(String day, double height, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D103E),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutQuart,
          width: 36,
          height: (height * 1.5).clamp(10.0, 160.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD4AF37), Color(0xFFFFF2CD)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          day,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class VendorComplianceView extends ConsumerStatefulWidget {
  const VendorComplianceView({super.key});

  @override
  ConsumerState<VendorComplianceView> createState() => _VendorComplianceViewState();
}

class _VendorComplianceViewState extends ConsumerState<VendorComplianceView> {
  void _reviewItem(AdminVendor item, String action) {
    String title = '';
    String message = '';
    Color actionColor = Colors.green;
    String confirmLabel = '';

    switch (action) {
      case 'warn':
        title = 'Issue Formal Warning';
        message = 'Issue a warning to "${item.name}"? They will receive a notification.';
        actionColor = Colors.orange;
        confirmLabel = 'Issue Warning';
        break;
      case 'suspend':
        title = 'Suspend Vendor';
        message = 'Suspend "${item.name}"? They will be locked out of their account and removed from all ledgers.';
        actionColor = Colors.red;
        confirmLabel = 'Confirm Suspend';
        break;
      case 'reactivate':
        title = 'Reactivate Vendor';
        message = 'Reactivate "${item.name}"? Their account warnings and suspensions will be cleared.';
        actionColor = Colors.green;
        confirmLabel = 'Reactivate';
        break;
    }

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontSize: 22)),
        content: Text(message, style: const TextStyle(fontSize: 15, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              switch (action) {
                case 'warn':
                  await ref.read(adminVendorManagementProvider.notifier).warnVendor(item.id);
                  break;
                case 'suspend':
                  await ref.read(adminVendorManagementProvider.notifier).suspendVendor(item.id);
                  break;
                case 'reactivate':
                  await ref.read(adminVendorManagementProvider.notifier).reactivateVendor(item.id);
                  break;
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF2D103E),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    content: Text('Action "$action" completed for ${item.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminVendorManagementProvider);
    final notifier = ref.read(adminVendorManagementProvider.notifier);

    // Get unique cities for filter, ensuring major cities are included by default
    final defaultCities = {'All', 'karachi', 'lahore', 'islamabad', 'rawalpindi', 'peshawar', 'multan', 'faisalabad', 'quetta', 'hyderabad'};
    final dynamicCities = state.vendors.map((v) => v.location.split(RegExp(r'[,•|\-]')).first.trim().toLowerCase()).toSet();
    final cities = defaultCities.union(dynamicCities).toList()..sort();
    final ratings = ['All', '1 Star', '2 Stars', '3 Stars', '4 Stars', '5 Stars'];

    final filteredVendors = state.vendors.where((v) {
      if (state.selectedCity != 'All') {
        final vendorCity = v.location.split(RegExp(r'[,•|\-]')).first.trim().toLowerCase();
        if (vendorCity != state.selectedCity.toLowerCase()) {
          return false;
        }
      }
      if (state.selectedRating != 'All') {
        final ratingValue = double.tryParse(v.rating) ?? 0.0;
        final selectedStars = int.tryParse(state.selectedRating.split(' ')[0]) ?? 0;
        if (ratingValue.floor() != selectedStars) return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vendor Compliance',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D103E),
              fontFamily: 'PlayfairDisplay',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage vendor standings, issue warnings, and enforce suspensions.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildDropdown('City', cities, state.selectedCity, (val) => notifier.setCityFilter(val!))),
              const SizedBox(width: 16),
              Expanded(child: _buildDropdown('Rating', ratings, state.selectedRating, (val) => notifier.setRatingFilter(val!))),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: filteredVendors.isEmpty
                ? const Center(
                    child: Text('No vendors match the current filters.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  )
                : ListView.builder(
                    itemCount: filteredVendors.length,
                    itemBuilder: (context, index) {
                      final item = filteredVendors[index];
                      final isSuspended = item.accountStatus == 'suspended';
                      final isWarned = item.accountStatus == 'warning';
                      
                      Color borderColor = Colors.grey.shade300;
                      Color bgColor = Colors.white;
                      if (isSuspended) {
                        borderColor = Colors.red.shade200;
                        bgColor = Colors.red.withValues(alpha: 0.03);
                      } else if (isWarned) {
                        borderColor = Colors.orange.shade200;
                        bgColor = Colors.orange.withValues(alpha: 0.02);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: borderColor.withValues(alpha: 0.2), blurRadius: 8),
                                      ],
                                    ),
                                    child: Icon(
                                      isSuspended ? Icons.block_rounded : isWarned ? Icons.warning_amber_rounded : Icons.storefront_rounded,
                                      color: isSuspended ? Colors.red : isWarned ? Colors.orange : const Color(0xFFD4AF37),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontSize: 18),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.category} • ${item.location}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 16),
                                            const SizedBox(width: 4),
                                            Text('${item.rating}/5.0', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isSuspended ? Colors.red : isWarned ? Colors.orange : Colors.green,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                item.accountStatus.toUpperCase(),
                                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (!isSuspended && !isWarned) ...[
                                    OutlinedButton(
                                      onPressed: () => _reviewItem(item, 'warn'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orange.shade800,
                                        side: BorderSide(color: Colors.orange.shade300),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Warn'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _reviewItem(item, 'suspend'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade600,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Suspend'),
                                    ),
                                  ] else ...[
                                    if (isWarned && !isSuspended)
                                      ElevatedButton(
                                        onPressed: () => _reviewItem(item, 'suspend'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade600,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('Suspend'),
                                      ),
                                    ElevatedButton(
                                      onPressed: () => _reviewItem(item, 'reactivate'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Reactivate'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, Function(String?) onChanged) {
    // Ensure the value exists in the items list to prevent DropdownButton crash
    final safeValue = items.contains(value) ? value : items.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E5D8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: safeValue,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFD4AF37)),
          style: const TextStyle(color: Color(0xFF2D103E), fontWeight: FontWeight.w600),
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class CityRecommendationsView extends ConsumerWidget {
  const CityRecommendationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendationsAsync = ref.watch(adminCityRecommendationsProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Market Expansion',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D103E),
              fontFamily: 'PlayfairDisplay',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Geographic demand indicators and user-requested city expansions.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: recommendationsAsync.when(
              data: (cities) {
                if (cities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          'No city recommendations yet.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF0E5D8), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cities.length,
                    separatorBuilder: (context, index) => const Divider(color: Color(0xFFF0E5D8), height: 32),
                    itemBuilder: (context, index) {
                      final city = cities[index];
                      final maxCount = cities.first.count;
                      final double demandFactor = maxCount > 0 ? (city.count / maxCount).clamp(0.0, 1.0) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF5EC),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.location_city_rounded, color: Color(0xFFD4AF37), size: 28),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        city.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontSize: 18),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2D103E),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '${city.count} requests',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                            tooltip: 'Remove City',
                                            onPressed: () async {
                                              try {
                                                await FirebaseFirestore.instance.collection('city_recommendations').doc(city.id).delete();
                                              } catch (e) {
                                                debugPrint('Error deleting city: $e');
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Stack(
                                    children: [
                                      Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0E5D8),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 1000),
                                        curve: Curves.easeOutCubic,
                                        height: 8,
                                        width: MediaQuery.of(context).size.width * 0.5 * demandFactor, // rough width
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: 1.0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFFD4AF37), Color(0xFFFFF2CD)],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                              boxShadow: [
                                                BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))
                                              ]
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Last requested: ${city.lastRequested.day}/${city.lastRequested.month}/${city.lastRequested.year}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)))),
              error: (err, stack) => Center(child: Text('Error loading recommendations: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class UserFeedbackView extends ConsumerWidget {
  const UserFeedbackView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(adminFeedbackProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Feedback',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D103E),
              fontFamily: 'PlayfairDisplay',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Reviews and comments submitted by ShadiSphere consumers.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: feedbackAsync.when(
              data: (feedbacks) {
                if (feedbacks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          'No feedback has been submitted yet.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    _FeedbackLineChart(feedbacks: feedbacks),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 600,
                          mainAxisExtent: 220,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                        itemCount: feedbacks.length,
                        itemBuilder: (context, index) {
                          final feedback = feedbacks[index];
                          final bool isPositive = feedback.rating >= 4;
                          final bool isNegative = feedback.rating <= 2;
                          
                          return Container(
                            padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isNegative ? Colors.orange.shade200 : (isPositive ? const Color(0xFFD4AF37).withValues(alpha: 0.5) : const Color(0xFFF0E5D8)),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isPositive ? const Color(0xFFD4AF37).withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF2D103E).withValues(alpha: 0.05),
                                    child: const Icon(Icons.person_rounded, color: Color(0xFF2D103E), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    feedback.userEmail,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontSize: 15),
                                  ),
                                ],
                              ),
                              Row(
                                children: List.generate(5, (starIndex) {
                                  return Icon(
                                    starIndex < feedback.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: const Color(0xFFD4AF37),
                                    size: 20,
                                    shadows: starIndex < feedback.rating ? [const Shadow(color: Color(0xFFD4AF37), blurRadius: 4)] : null,
                                  );
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: feedback.comment.isNotEmpty
                                ? Text(
                                    '"${feedback.comment}"',
                                    style: const TextStyle(
                                      color: Color(0xFF2D103E),
                                      fontSize: 15,
                                      height: 1.5,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : const Text(
                                    'No comment provided.',
                                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Submitted on: ${feedback.submittedAt.day}/${feedback.submittedAt.month}/${feedback.submittedAt.year}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
              loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)))),
              error: (err, stack) => Center(child: Text('Error loading feedback: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class RevenueSubscriptionsView extends ConsumerStatefulWidget {
  const RevenueSubscriptionsView({super.key});

  @override
  ConsumerState<RevenueSubscriptionsView> createState() => _RevenueSubscriptionsViewState();
}

class _RevenueSubscriptionsViewState extends ConsumerState<RevenueSubscriptionsView> {
  String _filter = 'All Time';

  @override
  Widget build(BuildContext context) {
    final subscriptions = ref.watch(adminSubscriptionsProvider);
    final now = DateTime.now();
    
    final filteredSubscriptions = subscriptions.where((sub) {
      if (_filter == 'This Month') {
        return sub.date.year == now.year && sub.date.month == now.month;
      } else if (_filter == 'This Week') {
        final difference = now.difference(sub.date).inDays;
        return difference <= 7;
      }
      return true; // All Time
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: const Text(
                  'Revenue & Subscriptions',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D103E),
                    fontFamily: 'PlayfairDisplay',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF0E5D8)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filter,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF2D103E)),
                    style: const TextStyle(color: Color(0xFF2D103E), fontWeight: FontWeight.bold),
                    items: ['All Time', 'This Month', 'This Week']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _filter = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Monitor premium vendor payments and subscription upgrades.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF0E5D8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2D103E).withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ListView.separated(
                  itemCount: filteredSubscriptions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF0E5D8)),
                  itemBuilder: (context, index) {
                    final sub = filteredSubscriptions[index];
                    final isPlatinum = sub.tier == 'platinum';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPlatinum ? const Color(0xFFE5E4E2).withValues(alpha: 0.3) : const Color(0xFFD4AF37).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlatinum ? Icons.diamond : Icons.star,
                          color: isPlatinum ? const Color(0xFF2D103E) : const Color(0xFFD4AF37),
                        ),
                      ),
                      title: Text(
                        sub.vendorName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D103E)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Upgraded to ${sub.tier.toUpperCase()} • ${_formatDate(sub.date)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '+Rs. ${sub.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class SubscriptionModelsAdminView extends ConsumerStatefulWidget {
  const SubscriptionModelsAdminView({super.key});

  @override
  ConsumerState<SubscriptionModelsAdminView> createState() => _SubscriptionModelsAdminViewState();
}

class _SubscriptionModelsAdminViewState extends ConsumerState<SubscriptionModelsAdminView> {
  void _showAddPlanDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String selectedColor = 'D4AF37'; // Default Gold
    String selectedIcon = 'star';

    final colors = {
      'Gold': 'D4AF37',
      'Silver': 'E5E4E2',
      'Bronze': 'CD7F32',
      'Blue': '4169E1',
      'Emerald': '50C878',
      'Purple': '800080',
    };

    final icons = ['star', 'diamond', 'workspace_premium', 'verified'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Add Subscription Tier', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Tier Name', hintText: 'e.g. Diamond'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Monthly Price (PKR)', hintText: 'e.g. 15000'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Badge Color', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: colors.entries.map((entry) {
                        final isSelected = selectedColor == entry.value;
                        return ChoiceChip(
                          label: Text(entry.key),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => selectedColor = entry.value);
                          },
                          selectedColor: Color(int.parse('0xFF${entry.value}')).withOpacity(0.3),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Badge Icon', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: icons.map((iconName) {
                        final isSelected = selectedIcon == iconName;
                        IconData iconData = Icons.star;
                        if (iconName == 'diamond') iconData = Icons.diamond;
                        if (iconName == 'workspace_premium') iconData = Icons.workspace_premium;
                        if (iconName == 'verified') iconData = Icons.verified;

                        return ChoiceChip(
                          label: Icon(iconData, size: 20),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => selectedIcon = iconName);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D103E)),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                    if (name.isNotEmpty && price > 0) {
                      ref.read(subscriptionPlansProvider.notifier).addPlan(name, price, selectedColor, selectedIcon);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription Tier Added!')));
                    }
                  },
                  child: const Text('Add Tier'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(subscriptionPlansProvider);

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subscription Models',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create, update, and manage pricing tiers for vendors.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showAddPlanDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add New Tier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 350,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 1.5,
              ),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                IconData iconData = Icons.star;
                if (plan.iconName == 'diamond') iconData = Icons.diamond;
                if (plan.iconName == 'workspace_premium') iconData = Icons.workspace_premium;
                if (plan.iconName == 'verified') iconData = Icons.verified;

                Color badgeColor = Color(int.parse('0xFF${plan.colorHex}'));

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(color: badgeColor.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D103E)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(iconData, color: badgeColor, size: 28),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Rs. ${plan.price.toStringAsFixed(0)} / month',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              ref.read(subscriptionPlansProvider.notifier).removePlan(plan.id);
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
}

class FeatureTeasersAdminView extends ConsumerStatefulWidget {
  const FeatureTeasersAdminView({super.key});

  @override
  ConsumerState<FeatureTeasersAdminView> createState() => _FeatureTeasersAdminViewState();
}

class _FeatureTeasersAdminViewState extends ConsumerState<FeatureTeasersAdminView> {
  void _showAddTeaserDialog(BuildContext context, WidgetRef ref) {
    final textCtrl = TextEditingController();
    Uint8List? selectedImageBytes;
    String? selectedImagePath;
    String? selectedImageExt;
    int selectedDurationHours = 24;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Add Feature Teaser', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: textCtrl,
                      decoration: const InputDecoration(labelText: 'Teaser Text', hintText: 'e.g. A new AI tool is coming...'),
                      maxLines: 3,
                      enabled: !isUploading,
                    ),
                    const SizedBox(height: 16),
                    const Text('Image', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (selectedImageBytes != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(selectedImageBytes!, height: 150, width: double.infinity, fit: BoxFit.cover),
                          ),
                          if (!isUploading)
                            Positioned(
                              top: 4, right: 4,
                              child: IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.white),
                                onPressed: () => setState(() => selectedImageBytes = null),
                              ),
                            )
                        ],
                      )
                    else
                      InkWell(
                        onTap: isUploading ? null : () async {
                          final picker = ImagePicker();
                          final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 800);
                          if (xfile != null) {
                            final bytes = await xfile.readAsBytes();
                            setState(() {
                              selectedImageBytes = bytes;
                              selectedImagePath = xfile.path;
                              selectedImageExt = xfile.name.split('.').last;
                            });
                          }
                        },
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                              Text('Select Image', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text('Duration (Hours)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Slider(
                      value: selectedDurationHours.toDouble(),
                      min: 1,
                      max: 168, // up to 1 week
                      divisions: 167,
                      label: '$selectedDurationHours hours',
                      activeColor: const Color(0xFFD4AF37),
                      onChanged: isUploading ? null : (val) {
                        setState(() => selectedDurationHours = val.toInt());
                      },
                    ),
                    Text('Expires in: $selectedDurationHours hours', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              actions: [
                if (!isUploading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D103E)),
                  onPressed: isUploading ? null : () async {
                    if (textCtrl.text.isNotEmpty && selectedImageBytes != null) {
                      setState(() => isUploading = true);
                      try {
                        // Bypass Firebase Storage completely to avoid Android object-not-found errors.
                        // Since we compress the image heavily, it easily fits within Firestore's 1MB limit.
                        final base64String = base64Encode(selectedImageBytes!);
                        final downloadUrl = 'base64:$base64String';

                        await ref.read(featureTeasersServiceProvider).addTeaser(
                          textCtrl.text.trim(),
                          downloadUrl,
                          Duration(hours: selectedDurationHours),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teaser broadcasted!')));
                        }
                      } catch (e) {
                        setState(() => isUploading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
                        }
                      }
                    } else if (selectedImageBytes == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image.')));
                    }
                  },
                  child: isUploading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Broadcast Teaser'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final teasersAsync = ref.watch(featureTeasersProvider);

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Feature Teasers',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Broadcast "Coming Soon" teasers to consumer portal. They will auto-delete when time expires.',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showAddTeaserDialog(context, ref),
            icon: const Icon(Icons.campaign),
            label: const Text('Broadcast New Teaser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: teasersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
              error: (e, st) => Center(child: Text('Error loading teasers: $e', style: const TextStyle(color: Colors.red))),
              data: (activeTeasers) {
                if (activeTeasers.isEmpty) {
                  return const Center(child: Text('No active teasers.', style: TextStyle(color: Colors.grey, fontSize: 16)));
                }
                return ListView.builder(
                    itemCount: activeTeasers.length,
                    itemBuilder: (context, index) {
                      final teaser = activeTeasers[index];
                      final timeLeft = teaser.expiresAt.difference(DateTime.now());
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          leading: teaser.imageUrl.isNotEmpty
                            ? Image.network(teaser.imageUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.image_not_supported))
                            : const Icon(Icons.campaign, size: 40),
                          title: Text(teaser.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('Expires in: ${timeLeft.inHours}h ${timeLeft.inMinutes.remainder(60)}m', style: const TextStyle(color: Colors.redAccent)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              ref.read(featureTeasersServiceProvider).removeTeaser(teaser.id);
                            },
                          ),
                        ),
                      );
                    },
                  );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// DYNAMIC CONTENT MANAGER
// -----------------------------------------------------------------------------

class ContentManagerView extends ConsumerStatefulWidget {
  const ContentManagerView({super.key});

  @override
  ConsumerState<ContentManagerView> createState() => _ContentManagerViewState();
}

class _ContentManagerViewState extends ConsumerState<ContentManagerView> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Content Manager', 
            style: TextStyle(
              fontFamily: 'PlayfairDisplay', 
              fontSize: 26, 
              color: Color(0xFF2D103E), 
              fontWeight: FontWeight.bold
            )
          ),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Color(0xFF2D103E),
            unselectedLabelColor: Colors.black54,
            indicatorColor: Color(0xFFD4AF37),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
            tabs: [
              Tab(text: 'Categories'),
              Tab(text: 'Banners'),
              Tab(text: 'Guides'),
              Tab(text: 'Cities'),
              Tab(text: 'Checklist'),
              Tab(text: 'Budget'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminCategoriesTab(),
            _AdminBannersTab(),
            _AdminGuidesTab(),
            _AdminCitiesTab(),
            _AdminChecklistTab(),
            _AdminBudgetTab(),
          ],
        ),
      ),
    );
  }
}

class _AdminCategoriesTab extends ConsumerWidget {
  const _AdminCategoriesTab();

  IconData _getIcon(String iconName) {
    const map = <String, IconData>{
      'account_balance': Icons.account_balance,
      'restaurant_menu': Icons.restaurant_menu,
      'celebration': Icons.celebration,
      'camera_alt': Icons.camera_alt,
      'local_fire_department': Icons.local_fire_department,
      'directions_car': Icons.directions_car,
      'checkroom': Icons.checkroom,
      'card_giftcard': Icons.card_giftcard,
      'music_note': Icons.music_note,
      'local_florist': Icons.local_florist,
      'spa': Icons.spa,
      'diamond': Icons.diamond,
      'palette': Icons.palette,
      'cake': Icons.cake,
      'hotel': Icons.hotel,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'shopping_bag': Icons.shopping_bag,
      'category': Icons.category,
    };
    return map[iconName] ?? Icons.category;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appCategoriesProvider);
    return _buildList(
      asyncData: asyncData,
      titleFn: (c) => c.name,
      subtitleFn: (c) => 'Category Profile',
      leadingFn: (c) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF5EC),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
        ),
        child: Icon(_getIcon(c.iconName), color: const Color(0xFFD4AF37), size: 24),
      ),
      onAdd: () => _showAddDialog(context, ref, 'Category'),
      onTap: (c) => _showEditCategoryDialog(context, c),
      onDelete: (c) {
        FirebaseFirestore.instance.collection('app_categories').doc(c.id).delete();
      },
    );
  }
}

class _AdminBannersTab extends ConsumerWidget {
  const _AdminBannersTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appBannersProvider);
    return _buildList(
      asyncData: asyncData,
      titleFn: (b) => b.title,
      subtitleFn: (b) => b.subtitle,
      onAdd: () => _showAddDialog(context, ref, 'Banner'),
      onTap: (b) => _showEditBannerDialog(context, ref, b),
      onDelete: (b) {
        FirebaseFirestore.instance.collection('app_banners').doc(b.id).delete();
      },
    );
  }
}

class _AdminGuidesTab extends ConsumerWidget {
  const _AdminGuidesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appGuidesProvider);
    return _buildList(
      asyncData: asyncData,
      titleFn: (g) => g.title,
      subtitleFn: (g) => g.tag,
      onAdd: () => _showAddDialog(context, ref, 'Guide'),
      onTap: (g) => _showEditGuideDialog(context, g),
      onDelete: (g) {
        FirebaseFirestore.instance.collection('app_guides').doc(g.id).delete();
      },
    );
  }
}

class _AdminCitiesTab extends ConsumerWidget {
  const _AdminCitiesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appCitiesProvider);
    return _buildList(
      asyncData: asyncData,
      titleFn: (c) => c.name,
      subtitleFn: (c) => 'Sort Order: ${c.sortOrder}',
      onAdd: () => _showAddDialog(context, ref, 'City'),
      onTap: (c) => _showEditCityDialog(context, c),
      onDelete: (c) {
        FirebaseFirestore.instance.collection('app_cities').doc(c.id).delete();
      },
    );
  }
}

class _AdminChecklistTab extends ConsumerWidget {
  const _AdminChecklistTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appChecklistTemplateProvider);
    return _buildList(
      asyncData: asyncData,
      titleFn: (t) => t.label,
      subtitleFn: (t) => 'Sort Order: ${t.sortOrder}',
      onAdd: () => _showAddDialog(context, ref, 'Checklist Template'),
      onTap: (t) => _showEditChecklistDialog(context, t),
      onDelete: (t) {
        FirebaseFirestore.instance.collection('app_checklist').doc(t.id).delete();
      },
    );
  }
}

class _AdminBudgetTab extends ConsumerWidget {
  const _AdminBudgetTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(budgetConfigProvider);
    return _buildList(
      asyncData: asyncData,
      titleFn: (b) => b.category,
      subtitleFn: (b) => 'Percentage: ${b.percentage}%',
      onAdd: () => _showAddDialog(context, ref, 'Budget Allocation'),
      onTap: (b) => _showEditBudgetDialog(context, b),
      onDelete: (b) async {
        final doc = await FirebaseFirestore.instance.collection('app_config').doc('budget_allocations').get();
        if (doc.exists) {
          final data = doc.data()!;
          final List allocations = data['allocations'] ?? [];
          allocations.removeWhere((a) => a['category'] == b.category);
          await FirebaseFirestore.instance.collection('app_config').doc('budget_allocations').update({
            'allocations': allocations,
          });
        }
      },
    );
  }
}

Widget _buildList<T>({
  required AsyncValue<List<T>> asyncData,
  required String Function(T) titleFn,
  required String Function(T) subtitleFn,
  Widget Function(T)? leadingFn,
  void Function(T)? onTap,
  required VoidCallback onAdd,
  required void Function(T) onDelete,
}) {
  return asyncData.when(
    loading: () => const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37))
      )
    ),
    error: (e, st) => Center(child: Text('Error: $e')),
    data: (items) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: onAdd,
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4AF37), Color(0xFFC59B27)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, size: 20),
                        SizedBox(width: 8),
                        Text('Add New', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D103E).withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      onTap: onTap != null ? () => onTap(item) : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: leadingFn != null ? leadingFn(item) : null,
                      title: Text(
                        titleFn(item), 
                        style: const TextStyle(
                          fontWeight: FontWeight.w700, 
                          fontSize: 17, 
                          color: Color(0xFF2D103E),
                          letterSpacing: 0.3,
                        )
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          subtitleFn(item),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      trailing: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 22),
                          onPressed: () => onDelete(item),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

void _showAddDialog(BuildContext context, WidgetRef ref, String entityName) {
  if (entityName == 'Category') {
    _showAddCategoryDialog(context);
  } else if (entityName == 'Banner') {
    _showAddBannerDialog(context, ref);
  } else if (entityName == 'Guide') {
    _showAddGuideDialog(context);
  } else if (entityName == 'City') {
    _showAddCityDialog(context);
  } else if (entityName == 'Checklist Template') {
    _showAddChecklistDialog(context);
  } else if (entityName == 'Budget Allocation') {
    _showAddBudgetDialog(context);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adding $entityName (UI not fully implemented in skeleton)')),
    );
  }
}

void _showAddCategoryDialog(BuildContext context) {
  final nameCtrl = TextEditingController();
  final taglineCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  String selectedIcon = 'category';
  
  final Map<String, IconData> availableIcons = {
    'account_balance': Icons.account_balance,
    'restaurant_menu': Icons.restaurant_menu,
    'celebration': Icons.celebration,
    'camera_alt': Icons.camera_alt,
    'local_fire_department': Icons.local_fire_department,
    'directions_car': Icons.directions_car,
    'checkroom': Icons.checkroom,
    'card_giftcard': Icons.card_giftcard,
    'music_note': Icons.music_note,
    'local_florist': Icons.local_florist,
    'spa': Icons.spa,
    'diamond': Icons.diamond,
    'palette': Icons.palette,
    'cake': Icons.cake,
    'hotel': Icons.hotel,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'shopping_bag': Icons.shopping_bag,
    'category': Icons.category,
  };

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Category', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 24)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl, 
                  decoration: InputDecoration(
                    labelText: 'Name (e.g. Bakers)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                    ),
                  )
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: taglineCtrl, 
                  decoration: InputDecoration(
                    labelText: 'Tagline (e.g. Custom Cakes)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                    ),
                  )
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionCtrl, 
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                    ),
                  )
                ),
                const SizedBox(height: 20),
                const Text('Select Icon', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedIcon,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFD4AF37)),
                      items: availableIcons.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Row(
                            children: [
                              Icon(entry.value, color: const Color(0xFF2D103E)),
                              const SizedBox(width: 12),
                              Text(entry.key.replaceAll('_', ' ')),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedIcon = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                FirebaseFirestore.instance.collection('app_categories').add({
                  'name': nameCtrl.text.trim(),
                  'iconName': selectedIcon,
                  'tagline': taglineCtrl.text.trim(),
                  'description': descriptionCtrl.text.trim(),
                  'sortOrder': 99,
                });
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    ),
  );
}

void _showEditCategoryDialog(BuildContext context, AppCategory category) {
  final nameCtrl = TextEditingController(text: category.name);
  final taglineCtrl = TextEditingController(text: category.tagline);
  final descriptionCtrl = TextEditingController(text: category.description);
  String selectedIcon = category.iconName;
  
  final Map<String, IconData> availableIcons = {
    'account_balance': Icons.account_balance,
    'restaurant_menu': Icons.restaurant_menu,
    'celebration': Icons.celebration,
    'camera_alt': Icons.camera_alt,
    'local_fire_department': Icons.local_fire_department,
    'directions_car': Icons.directions_car,
    'checkroom': Icons.checkroom,
    'card_giftcard': Icons.card_giftcard,
    'music_note': Icons.music_note,
    'local_florist': Icons.local_florist,
    'spa': Icons.spa,
    'diamond': Icons.diamond,
    'palette': Icons.palette,
    'cake': Icons.cake,
    'hotel': Icons.hotel,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'shopping_bag': Icons.shopping_bag,
    'category': Icons.category,
  };

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Category', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 24)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl, 
                  decoration: InputDecoration(
                    labelText: 'Name (e.g. Bakers)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                    ),
                  )
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: taglineCtrl, 
                  decoration: InputDecoration(
                    labelText: 'Tagline (e.g. Custom Cakes)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                    ),
                  )
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionCtrl, 
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                    ),
                  )
                ),
                const SizedBox(height: 20),
                const Text('Select Icon', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: availableIcons.containsKey(selectedIcon) ? selectedIcon : 'category',
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFD4AF37)),
                      items: availableIcons.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Row(
                            children: [
                              Icon(entry.value, color: const Color(0xFF2D103E)),
                              const SizedBox(width: 12),
                              Text(entry.key.replaceAll('_', ' ')),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedIcon = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                FirebaseFirestore.instance.collection('app_categories').doc(category.id).update({
                  'name': nameCtrl.text.trim(),
                  'iconName': selectedIcon,
                  'tagline': taglineCtrl.text.trim(),
                  'description': descriptionCtrl.text.trim(),
                });
                Navigator.pop(context);
              },
              child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    ),
  );
}

void _showAddBannerDialog(BuildContext context, WidgetRef ref) {
  final titleCtrl = TextEditingController();
  final subtitleCtrl = TextEditingController();
  final tagCtrl = TextEditingController();
  
  final categoriesAsync = ref.watch(appCategoriesProvider);
  final List<AppCategory> categories = categoriesAsync.value ?? [];
  final List<String> categoryNames = ['All', ...categories.map((c) => c.name)];
  String selectedCategory = categoryNames.first;

  Uint8List? _imageBytes;
  bool _isUploading = false;

  Future<void> _pickImage(StateSetter setState) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _uploadAndSave(StateSetter setState) async {
    if (titleCtrl.text.trim().isEmpty) return;
    
    setState(() => _isUploading = true);
    try {
      String imageUrl = '';
      if (_imageBytes != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/isuedugk/image/upload'),
        );
        request.fields['upload_preset'] = 'shadi_sphere_uploads';
        request.files.add(http.MultipartFile.fromBytes('file', _imageBytes!, filename: 'banner.jpg'));

        final response = await request.send();
        final responseData = await response.stream.toBytes();
        final jsonMap = jsonDecode(String.fromCharCodes(responseData));
        
        if (response.statusCode == 200) {
          imageUrl = jsonMap['secure_url'];
        } else {
          throw Exception('Cloudinary error: ${jsonMap['error']?['message']}');
        }
      }

      await FirebaseFirestore.instance.collection('app_banners').add({
        'title': titleCtrl.text.trim(),
        'subtitle': subtitleCtrl.text.trim(),
        'tag': tagCtrl.text.trim(),
        'imageUrl': imageUrl,
        'linkCategory': selectedCategory,
        'sortOrder': 99,
      });
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Banner', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 24)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subtitleCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Subtitle',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tagCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Tag (e.g. LIMITED OFFER)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 20),
                  const Text('Link Category', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFD4AF37)),
                        items: categoryNames.map((name) {
                          return DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedCategory = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Banner Image', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _pickImage(setState),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, color: Colors.grey.shade400, size: 40),
                                const SizedBox(height: 8),
                                Text('Tap to upload image', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isUploading ? null : () => Navigator.pop(context), 
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _isUploading ? null : () => _uploadAndSave(setState),
              child: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    ),
  );
}

void _showEditBannerDialog(BuildContext context, WidgetRef ref, AppBanner banner) {
  final titleCtrl = TextEditingController(text: banner.title);
  final subtitleCtrl = TextEditingController(text: banner.subtitle);
  final tagCtrl = TextEditingController(text: banner.tag);
  
  final categoriesAsync = ref.watch(appCategoriesProvider);
  final List<AppCategory> categories = categoriesAsync.value ?? [];
  final List<String> categoryNames = ['All', ...categories.map((c) => c.name)];
  String selectedCategory = categoryNames.contains(banner.linkCategory) ? banner.linkCategory : categoryNames.first;

  Uint8List? _imageBytes;
  bool _isUploading = false;
  String _existingImageUrl = banner.imageUrl;

  Future<void> _pickImage(StateSetter setState) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _uploadAndSave(StateSetter setState) async {
    if (titleCtrl.text.trim().isEmpty) return;
    
    setState(() => _isUploading = true);
    try {
      String imageUrl = _existingImageUrl;
      if (_imageBytes != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/isuedugk/image/upload'),
        );
        request.fields['upload_preset'] = 'shadi_sphere_uploads';
        request.files.add(http.MultipartFile.fromBytes('file', _imageBytes!, filename: 'banner.jpg'));

        final response = await request.send();
        final responseData = await response.stream.toBytes();
        final jsonMap = jsonDecode(String.fromCharCodes(responseData));
        
        if (response.statusCode == 200) {
          imageUrl = jsonMap['secure_url'];
        } else {
          throw Exception('Cloudinary error: ${jsonMap['error']?['message']}');
        }
      }

      await FirebaseFirestore.instance.collection('app_banners').doc(banner.id).update({
        'title': titleCtrl.text.trim(),
        'subtitle': subtitleCtrl.text.trim(),
        'tag': tagCtrl.text.trim(),
        'imageUrl': imageUrl,
        'linkCategory': selectedCategory,
      });
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Banner', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 24)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subtitleCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Subtitle',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tagCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Tag (e.g. LIMITED OFFER)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 20),
                  const Text('Link Category', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFD4AF37)),
                        items: categoryNames.map((name) {
                          return DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedCategory = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Banner Image', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _pickImage(setState),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                            )
                          : _existingImageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(_existingImageUrl, fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate, color: Colors.grey.shade400, size: 40),
                                    const SizedBox(height: 8),
                                    Text('Tap to upload image', style: TextStyle(color: Colors.grey.shade600)),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isUploading ? null : () => Navigator.pop(context), 
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _isUploading ? null : () => _uploadAndSave(setState),
              child: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    ),
  );
}

void _showAddGuideDialog(BuildContext context) {
  final titleCtrl = TextEditingController();
  final tagCtrl = TextEditingController();
  final readCtrl = TextEditingController();
  final contentCtrl = TextEditingController();

  Uint8List? _imageBytes;
  bool _isUploading = false;

  Future<void> _pickImage(StateSetter setState) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _uploadAndSave(StateSetter setState) async {
    if (titleCtrl.text.trim().isEmpty) return;
    
    setState(() => _isUploading = true);
    try {
      String imageUrl = '';
      if (_imageBytes != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/isuedugk/image/upload'),
        );
        request.fields['upload_preset'] = 'shadi_sphere_uploads';
        request.files.add(http.MultipartFile.fromBytes('file', _imageBytes!, filename: 'guide.jpg'));

        final response = await request.send();
        final responseData = await response.stream.toBytes();
        final jsonMap = jsonDecode(String.fromCharCodes(responseData));
        
        if (response.statusCode == 200) {
          imageUrl = jsonMap['secure_url'];
        } else {
          throw Exception('Cloudinary error: ${jsonMap['error']?['message']}');
        }
      }

      await FirebaseFirestore.instance.collection('app_guides').add({
        'title': titleCtrl.text.trim(),
        'tag': tagCtrl.text.trim(),
        'readTime': readCtrl.text.trim(),
        'imageUrl': imageUrl,
        'content': contentCtrl.text.trim(),
      });
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Guide', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 24)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tagCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Tag (e.g. Planning)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: readCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Read Time (e.g. 5 min)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentCtrl, 
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Content',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 20),
                  const Text('Guide Image', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _pickImage(setState),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, color: Colors.grey.shade400, size: 40),
                                const SizedBox(height: 8),
                                Text('Tap to upload image', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isUploading ? null : () => Navigator.pop(context), 
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _isUploading ? null : () => _uploadAndSave(setState),
              child: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    ),
  );
}

void _showEditGuideDialog(BuildContext context, AppGuide guide) {
  final titleCtrl = TextEditingController(text: guide.title);
  final tagCtrl = TextEditingController(text: guide.tag);
  final readCtrl = TextEditingController(text: guide.readTime);
  final contentCtrl = TextEditingController(text: guide.content);

  Uint8List? _imageBytes;
  bool _isUploading = false;
  String _existingImageUrl = guide.imageUrl;

  Future<void> _pickImage(StateSetter setState) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _uploadAndSave(StateSetter setState) async {
    if (titleCtrl.text.trim().isEmpty) return;
    
    setState(() => _isUploading = true);
    try {
      String imageUrl = _existingImageUrl;
      if (_imageBytes != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/isuedugk/image/upload'),
        );
        request.fields['upload_preset'] = 'shadi_sphere_uploads';
        request.files.add(http.MultipartFile.fromBytes('file', _imageBytes!, filename: 'guide.jpg'));

        final response = await request.send();
        final responseData = await response.stream.toBytes();
        final jsonMap = jsonDecode(String.fromCharCodes(responseData));
        
        if (response.statusCode == 200) {
          imageUrl = jsonMap['secure_url'];
        } else {
          throw Exception('Cloudinary error: ${jsonMap['error']?['message']}');
        }
      }

      await FirebaseFirestore.instance.collection('app_guides').doc(guide.id).update({
        'title': titleCtrl.text.trim(),
        'tag': tagCtrl.text.trim(),
        'readTime': readCtrl.text.trim(),
        'imageUrl': imageUrl,
        'content': contentCtrl.text.trim(),
      });
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Guide', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 24)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tagCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Tag (e.g. Planning)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: readCtrl, 
                    decoration: InputDecoration(
                      labelText: 'Read Time (e.g. 5 min)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentCtrl, 
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Content',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                    )
                  ),
                  const SizedBox(height: 20),
                  const Text('Guide Image', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _pickImage(setState),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                            )
                          : _existingImageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(_existingImageUrl, fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate, color: Colors.grey.shade400, size: 40),
                                    const SizedBox(height: 8),
                                    Text('Tap to upload image', style: TextStyle(color: Colors.grey.shade600)),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isUploading ? null : () => Navigator.pop(context), 
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _isUploading ? null : () => _uploadAndSave(setState),
              child: _isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    ),
  );
}

void _showAddCityDialog(BuildContext context) {
  final nameCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add City', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl, 
            decoration: InputDecoration(
              labelText: 'Name (e.g. Lahore, Pakistan)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            )
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            if (nameCtrl.text.trim().isEmpty) return;
            FirebaseFirestore.instance.collection('app_cities').add({
              'name': nameCtrl.text.trim(),
              'isActive': true,
              'sortOrder': 99,
            });
            Navigator.pop(context);
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

void _showEditCityDialog(BuildContext context, AppCity city) {
  final nameCtrl = TextEditingController(text: city.name);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit City', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl, 
            decoration: InputDecoration(
              labelText: 'Name (e.g. Lahore, Pakistan)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            )
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            if (nameCtrl.text.trim().isEmpty) return;
            FirebaseFirestore.instance.collection('app_cities').doc(city.id).update({
              'name': nameCtrl.text.trim(),
            });
            Navigator.pop(context);
          },
          child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

void _showAddChecklistDialog(BuildContext context) {
  final labelCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Checklist Item', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: labelCtrl, 
            decoration: InputDecoration(
              labelText: 'Task Label',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            )
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            if (labelCtrl.text.trim().isEmpty) return;
            FirebaseFirestore.instance.collection('app_checklist').add({
              'label': labelCtrl.text.trim(),
              'sortOrder': 99,
            });
            Navigator.pop(context);
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

void _showEditChecklistDialog(BuildContext context, AppChecklistTemplate item) {
  final labelCtrl = TextEditingController(text: item.label);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit Checklist Item', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: labelCtrl, 
            decoration: InputDecoration(
              labelText: 'Task Label',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            )
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            if (labelCtrl.text.trim().isEmpty) return;
            FirebaseFirestore.instance.collection('app_checklist').doc(item.id).update({
              'label': labelCtrl.text.trim(),
            });
            Navigator.pop(context);
          },
          child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

void _showAddBudgetDialog(BuildContext context) {
  final catCtrl = TextEditingController();
  final pctCtrl = TextEditingController();
  final emojiCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Budget Allocation', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: catCtrl, 
            decoration: InputDecoration(
              labelText: 'Category (e.g. Catering)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            )
          ),
          const SizedBox(height: 16),
          TextField(
            controller: pctCtrl, 
            decoration: InputDecoration(
              labelText: 'Percentage (e.g. 40)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            )
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emojiCtrl, 
            decoration: InputDecoration(
              labelText: 'Emoji (e.g. 🍽️)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            )
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () async {
            if (catCtrl.text.trim().isEmpty) return;
            final doc = await FirebaseFirestore.instance.collection('app_config').doc('budget_allocations').get();
            List allocations = [];
            if (doc.exists) {
              allocations = List.from(doc.data()!['allocations'] ?? []);
            }
            allocations.add({
              'category': catCtrl.text.trim(),
              'percentage': double.tryParse(pctCtrl.text.trim()) ?? 0.0,
              'emoji': emojiCtrl.text.trim(),
            });
            await FirebaseFirestore.instance.collection('app_config').doc('budget_allocations').set({
              'allocations': allocations,
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

void _showEditBudgetDialog(BuildContext context, dynamic item) {
  final catCtrl = TextEditingController(text: item.category);
  final pctCtrl = TextEditingController(text: item.percentage.toString());
  final emojiCtrl = TextEditingController(text: item.emoji);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit Budget Allocation', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: catCtrl, 
            decoration: InputDecoration(
              labelText: 'Category (e.g. Catering)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            )
          ),
          const SizedBox(height: 16),
          TextField(
            controller: pctCtrl, 
            decoration: InputDecoration(
              labelText: 'Percentage (e.g. 40)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            )
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emojiCtrl, 
            decoration: InputDecoration(
              labelText: 'Emoji (e.g. 🍽️)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            )
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () async {
            if (catCtrl.text.trim().isEmpty) return;
            final doc = await FirebaseFirestore.instance.collection('app_config').doc('budget_allocations').get();
            List allocations = [];
            if (doc.exists) {
              allocations = List.from(doc.data()!['allocations'] ?? []);
            }
            final index = allocations.indexWhere((a) => a['category'] == item.category);
            if (index != -1) {
              allocations[index] = {
                'category': catCtrl.text.trim(),
                'percentage': double.tryParse(pctCtrl.text.trim()) ?? 0.0,
                'emoji': emojiCtrl.text.trim(),
              };
            }
            await FirebaseFirestore.instance.collection('app_config').doc('budget_allocations').set({
              'allocations': allocations,
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

class _FeedbackLineChart extends StatelessWidget {
  final List<dynamic> feedbacks;

  const _FeedbackLineChart({required this.feedbacks});

  @override
  Widget build(BuildContext context) {
    if (feedbacks.isEmpty) return const SizedBox.shrink();

    final Map<String, List<int>> monthlyRatings = {};
    for (var f in feedbacks) {
      final date = f.submittedAt;
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      monthlyRatings.putIfAbsent(key, () => []).add(f.rating);
    }

    final sortedKeys = monthlyRatings.keys.toList()..sort();
    final keys = sortedKeys.length > 6 ? sortedKeys.sublist(sortedKeys.length - 6) : sortedKeys;

    final points = <Offset>[];
    double maxRating = 5.0;
    List<String> labels = [];

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final ratings = monthlyRatings[key]!;
      final avg = ratings.reduce((a, b) => a + b) / ratings.length;
      
      final x = keys.length == 1 ? 0.5 : (i / (keys.length - 1));
      points.add(Offset(x, 1 - (avg / maxRating)));
      
      final parts = key.split('-');
      final m = int.parse(parts[1]);
      final monthStr = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
      labels.add(monthStr);
    }

    return Container(
      height: 220,
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E5D8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Average App Rating (Monthly)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontSize: 16)),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('5.0', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('2.5', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('0.0', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          size: const Size(double.infinity, double.infinity),
                          painter: _LineChartPainter(points: points),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: labels.map((l) => Text(l, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))).toList(),
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

class _LineChartPainter extends CustomPainter {
  final List<Offset> points;
  _LineChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final path = Path();
    final paint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = const Color(0xFF2D103E)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final p = Offset(points[i].dx * size.width, points[i].dy * size.height);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    canvas.drawPath(path, paint);

    for (var p in points) {
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), 5, dotPaint);
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
