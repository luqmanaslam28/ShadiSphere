import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'consumer_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../booking/presentation/booking_providers.dart';
import '../../../core/localization/app_translations.dart';
import '../../admin/presentation/admin_providers.dart';
import '../../../core/services/pdf_receipt_service.dart';
import '../../vendor_dashboard/presentation/cater_onboarding_screen.dart';

String _formatCurrency(double amount) {
  final s = amount.toStringAsFixed(0);
  final result = StringBuffer();
  int count = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) result.write(',');
    result.write(s[i]);
    count++;
  }
  return 'Rs. ${result.toString().split('').reversed.join()}';
}

class VendorBadge extends ConsumerWidget {
  final String tier;
  const VendorBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tier == 'free' || tier.isEmpty) return const SizedBox.shrink();

    final plans = ref.watch(subscriptionPlansProvider);
    final plan = plans.firstWhere(
      (p) => p.id == tier,
      orElse: () => const SubscriptionPlan(id: '', name: '', price: 0, colorHex: '000000', iconName: 'star')
    );

    if (plan.id.isEmpty) return const SizedBox.shrink();

    final badgeColor = Color(int.parse('0xFF${plan.colorHex}'));
    
    IconData iconData = Icons.star;
    if (plan.iconName == 'diamond') iconData = Icons.diamond;
    if (plan.iconName == 'workspace_premium') iconData = Icons.workspace_premium;
    if (plan.iconName == 'verified') iconData = Icons.verified;

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        border: Border.all(color: badgeColor, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 10, color: badgeColor),
          const SizedBox(width: 2),
          Text(
            plan.name.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: badgeColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class ConsumerShell extends ConsumerWidget {
  const ConsumerShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: const TabBarView(
          children: [
            DiscoverView(),
            SmartPlannerView(),
            SharedLedgerView(),
            MyBookingsScreen(),
            UserProfileView(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: const TabBar(
              labelColor: Color(0xFFD4AF37),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.transparent,
              labelPadding: EdgeInsets.symmetric(horizontal: 1.0),
              labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
              tabs: [
                Tab(icon: Icon(Icons.explore, size: 20), text: 'Discover'),
                Tab(icon: Icon(Icons.event_note, size: 20), text: 'Planner'),
                Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 20), text: 'Ledger'),
                Tab(icon: Icon(Icons.confirmation_number_rounded, size: 20), text: 'Bookings'),
                Tab(icon: Icon(Icons.person, size: 20), text: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GradientBackgroundWrapper extends StatelessWidget {
  final Widget child;
  const GradientBackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}

// Helper: map icon name strings from Firestore to Material IconData
IconData getCategoryIcon(String iconName) {
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

class DiscoverView extends ConsumerStatefulWidget {
  const DiscoverView({super.key});

  @override
  ConsumerState<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends ConsumerState<DiscoverView> {
  bool _hasPromptedCity = false;

  void _showCityRecommendationDialog() {
    final TextEditingController cityController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Recommend a City', style: TextStyle(color: Color(0xFF2D103E), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Is your city not listed? Tell us where we should expand next!', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: cityController,
                decoration: InputDecoration(
                  hintText: 'Enter your city name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Reopen the city selection popup so they aren't stuck
                _showCitySelection();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final city = cityController.text.trim();
                if (city.isNotEmpty) {
                  ref.read(authProvider.notifier).submitCityRecommendation(city);
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Thank you! $city has been recorded.'),
                      backgroundColor: const Color(0xFF2D103E),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  
                  // Reopen the city selection popup so they can choose a fallback
                  _showCitySelection();
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _showCitySelection() {
    final tr = ref.read(translationProvider);
    final citiesAsync = ref.read(appCitiesProvider);
    final cities = citiesAsync.value?.map((c) => c.name).toList() ?? ['Lahore, Pakistan', 'Karachi, Pakistan', 'Islamabad, Pakistan', 'Rawalpindi, Pakistan', 'Faisalabad, Pakistan', 'Multan, Pakistan'];
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(tr('Select Your City'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                ),
                ...cities.map((city) => ListTile(
                      leading: const Icon(Icons.location_city, color: Color(0xFFD4AF37)),
                      title: Text(city, style: const TextStyle(fontSize: 16)),
                      onTap: () {
                        ref.read(authProvider.notifier).updateUserCity(city);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Location updated to $city successfully.'),
                            backgroundColor: const Color(0xFF2D103E),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                    )),
                const Divider(color: Color(0xFFF0E5D8)),
                ListTile(
                  leading: const Icon(Icons.add_location_alt_outlined, color: Color(0xFF2D103E)),
                  title: const Text('City not listed? Recommend it', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                  onTap: () {
                    Navigator.pop(context); // Close the bottom sheet
                    _showCityRecommendationDialog(); // Open recommendation dialog
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToCategory(BuildContext context, String taskName) {
    String category = 'All';
    final lower = taskName.toLowerCase();
    if (lower.contains('venue')) {
      category = 'Venues';
    } else if (lower.contains('catering')) {
      category = 'Catering';
    } else if (lower.contains('decor')) {
      category = 'Decor';
    } else if (lower.contains('photographer')) {
      category = 'Photography';
    } else if (lower.contains('pyro')) {
      category = 'Pyrotechnics';
    } else if (lower.contains('logist')) {
      category = 'Logistics';
    } else if (lower.contains('apparel') || lower.contains('grooming')) {
      category = 'Apparel';
    }
    context.push('/consumer/category/$category');
  }

  Widget _buildChecklistCard(BuildContext context, WidgetRef ref) {
    final checklist = ref.watch(checklistProvider);
    final completedCount = checklist.values.where((v) => v).length;
    final totalCount = checklist.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E5D8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: const Color(0xFFFAF5EC),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF2D103E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wedding Planning Checklist',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D103E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedCount of $totalCount milestones achieved',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF0E5D8)),
          ...checklist.entries.map((entry) {
            final task = entry.key;
            final isChecked = entry.value;
            return InkWell(
              onTap: () {
                ref.read(checklistProvider.notifier).toggle(task);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isChecked,
                        activeColor: const Color(0xFF2D103E),
                        checkColor: Colors.white,
                        onChanged: (val) {
                          ref.read(checklistProvider.notifier).toggle(task);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                          color: isChecked ? Colors.grey : const Color(0xFF2D103E),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Color(0xFFD4AF37),
                      ),
                      onPressed: () => _navigateToCategory(context, task),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showGuideModal(BuildContext context, AppGuide guide) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.network(
                        guide.imageUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 180,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.article, color: Colors.white, size: 60),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white70,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 20, color: Color(0xFF2D103E)),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5EC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFD4AF37), width: 0.5),
                            ),
                            child: Text(
                              guide.tag,
                              style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            guide.readTime,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        guide.title,
                        style: const TextStyle(
                          color: Color(0xFF2D103E),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: SingleChildScrollView(
                          child: Text(
                            guide.content,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(BuildContext context, WidgetRef ref, String query, AsyncValue<List<Vendor>> vendorsAsyncValue) {
    final allVendors = vendorsAsyncValue.value ?? [];
    final matchingVendors = allVendors.where((v) {
      final nameMatch = v.name.toLowerCase().contains(query.toLowerCase());
      final locMatch = v.location.toLowerCase().contains(query.toLowerCase());
      final catMatch = v.category.toLowerCase().contains(query.toLowerCase());
      final descMatch = v.description.toLowerCase().contains(query.toLowerCase());
      return nameMatch || locMatch || catMatch || descMatch;
    }).toList();

    final allGuides = ref.watch(appGuidesProvider).value ?? defaultAppGuides;
    final matchingGuides = allGuides.where((g) {
      final titleMatch = g.title.toLowerCase().contains(query.toLowerCase());
      final tagMatch = g.tag.toLowerCase().contains(query.toLowerCase());
      final contentMatch = g.content.toLowerCase().contains(query.toLowerCase());
      return titleMatch || tagMatch || contentMatch;
    }).toList();

    final noResults = matchingVendors.isEmpty && matchingGuides.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Search Results for "$query"',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D103E)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(searchQueryProvider.notifier).clear();
              },
              child: const Text('Clear', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (noResults)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Column(
                children: [
                  const Icon(Icons.search_off, size: 64, color: Color(0xFFD4AF37)),
                  const SizedBox(height: 16),
                  const Text(
                    'No results found',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D103E)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We couldn\'t find any vendors or guides matching "$query".',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else ...[
          if (matchingVendors.isNotEmpty) ...[
            const Text('Matching Vendors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: matchingVendors.length,
              itemBuilder: (context, index) {
                final v = matchingVendors[index];
                final isSaved = ref.watch(savedVendorsProvider).contains(v.id);
                return _buildVendorCard(
                  context: context,
                  vendor: v,
                  isSaved: isSaved,
                  onToggleSave: () => ref.read(savedVendorsProvider.notifier).toggleSaved(v.id),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          if (matchingGuides.isNotEmpty) ...[
            const Text('Matching Guides & Ideas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: matchingGuides.length,
                itemBuilder: (context, index) {
                  final guide = matchingGuides[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => _showGuideModal(context, guide),
                      child: Container(
                        width: 280,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF0E5D8), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              child: Image.network(
                                guide.imageUrl,
                                height: 110,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 110,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.article, color: Colors.white, size: 40),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAF5EC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFD4AF37), width: 0.5),
                                        ),
                                        child: Text(
                                          guide.tag,
                                          style: const TextStyle(
                                            color: Color(0xFFD4AF37),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        guide.readTime,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    guide.title,
                                    style: const TextStyle(
                                      color: Color(0xFF2D103E),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
            ),
            const SizedBox(height: 24),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(translationProvider);
    final vendorsAsyncValue = ref.watch(filteredVendorsProvider);
    final query = ref.watch(searchQueryProvider);
    final dynamicGuides = ref.watch(appGuidesProvider).value ?? defaultAppGuides;
    final authState = ref.watch(authProvider);
    final selectedCity = authState.city != null && authState.city!.isNotEmpty ? authState.city! : tr('Select City');
    
    // Auto-prompt city selection if not set
    if (authState.isAuthenticated && !authState.isLoadingProfile && (authState.city == null || authState.city!.isEmpty) && !_hasPromptedCity) {
      _hasPromptedCity = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCitySelection();
      });
    }

    final notificationsAsync = ref.watch(notificationsProvider);
    final notifications = notificationsAsync.value ?? [];
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return GradientBackgroundWrapper(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _showCitySelection(),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 24),
                        const SizedBox(width: 8),
                        Text(selectedCity, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFD4AF37))),
                        const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFFD4AF37)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const TeaserView()));
                        },
                        child: const Icon(Icons.auto_awesome, size: 28, color: Color(0xFFD4AF37)),
                      ),
                      const SizedBox(width: 16),
                      if (false)
                        GestureDetector(
                          onTap: () => context.push('/consumer/notifications'),
                          child: Stack(
                            children: [
                              const Icon(Icons.notifications_none, size: 28, color: Color(0xFFD4AF37)),
                              if (unreadCount > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Search Bar
              const PremiumSearchBar(),
              const SizedBox(height: 24),

              if (query.isNotEmpty) ...[
                _buildSearchResults(context, ref, query, vendorsAsyncValue),
              ] else ...[
                // Premium Featured Carousel
                const PremiumFeaturedCarousel(),
                const SizedBox(height: 24),

                // AI Planner Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D103E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Plan Smarter with', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 4),
                            const Text('AI Budget Planner', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text('Get personalized budget\nbreakdown in seconds', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => DefaultTabController.of(context).animateTo(1),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(100, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: const Text('Try Planner', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Icon(Icons.smart_toy, size: 80, color: Color(0xFFD4AF37)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Wedding Checklist Progress Card
                _buildChecklistCard(context, ref),
                const SizedBox(height: 32),

                // Browse by Category
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Browse by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => context.push('/consumer/categories'),
                      child: const Text('See all', style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (ref.watch(appCategoriesProvider).value ?? defaultAppCategories)
                      .take(4)
                      .map((cat) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _buildCategoryIcon(context, cat.name, getCategoryIcon(cat.iconName)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 32),

                // Top Picks
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Top Picks for You', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => context.push('/consumer/top_picks'),
                      child: const Text('See all', style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (vendorsAsyncValue.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (vendorsAsyncValue.value != null && vendorsAsyncValue.value!.isNotEmpty)
                  SizedBox(
                    height: 250,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: vendorsAsyncValue.value!.length,
                      itemBuilder: (context, index) {
                        final v = vendorsAsyncValue.value![index];
                        final isSaved = ref.watch(savedVendorsProvider).contains(v.id);
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _buildVerticalVendorCard(
                            context: context,
                            vendor: v,
                            isSaved: isSaved,
                            onToggleSave: () => ref.read(savedVendorsProvider.notifier).toggleSaved(v.id),
                          ),
                        );
                      },
                    ),
                  )
                else
                  const Center(child: Text('No top picks available right now.')),
                const SizedBox(height: 24),

                const _DealsAndPromotionsSection(),
                const SizedBox(height: 24),

                // Trending Guides & Expert Ideas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Trending Guides & Ideas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: dynamicGuides.length,
                    itemBuilder: (context, index) {
                      final guide = dynamicGuides[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: () => _showGuideModal(context, guide),
                          child: Container(
                            width: 280,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF0E5D8), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                  child: Image.network(
                                    guide.imageUrl,
                                    height: 110,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 110,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.article, color: Colors.white, size: 40),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFAF5EC),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFD4AF37), width: 0.5),
                                            ),
                                            child: Text(
                                              guide.tag,
                                              style: const TextStyle(
                                                color: Color(0xFFD4AF37),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            guide.readTime,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        guide.title,
                                        style: const TextStyle(
                                          color: Color(0xFF2D103E),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(BuildContext context, String label, IconData icon) {
    return InkWell(
      onTap: () {
        context.push('/consumer/category/$label');
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0E5D8).withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFD4AF37), size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildVerticalVendorCard({required BuildContext context, required Vendor vendor, required bool isSaved, required VoidCallback onToggleSave}) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/consumer/vendor_detail', extra: vendor),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      child: vendor.images.isNotEmpty
                          ? Image.network(
                              vendor.images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Center(child: Icon(Icons.storefront, color: Colors.grey, size: 40)),
                            )
                          : const Center(child: Icon(Icons.storefront, color: Colors.grey, size: 40)),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onToggleSave,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(isSaved ? Icons.favorite : Icons.favorite_border, color: isSaved ? Colors.red : Colors.grey, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(vendor.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        VendorBadge(tier: vendor.subscriptionTier),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(vendor.category, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(vendor.rating, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        const Icon(Icons.location_on, color: Colors.grey, size: 14),
                        const SizedBox(width: 2),
                        Flexible(child: Text(vendor.location, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
  }

  Widget _buildVendorCard({required BuildContext context, required Vendor vendor, required bool isSaved, required VoidCallback onToggleSave}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/consumer/vendor_detail', extra: vendor),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 80,
                    width: 80,
                    color: Colors.grey.shade200,
                    child: vendor.images.isNotEmpty
                        ? Image.network(
                            vendor.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Center(child: Icon(Icons.storefront, color: Colors.grey, size: 30)),
                          )
                        : const Center(child: Icon(Icons.storefront, color: Colors.grey, size: 30)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(vendor.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                          VendorBadge(tier: vendor.subscriptionTier),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(vendor.category, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(vendor.rating, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on, color: Colors.grey, size: 14),
                          const SizedBox(width: 2),
                          Expanded(child: Text(vendor.location, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border, color: isSaved ? Colors.red : Colors.grey),
                  onPressed: onToggleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SmartPlannerView extends ConsumerStatefulWidget {
  const SmartPlannerView({super.key});

  @override
  ConsumerState<SmartPlannerView> createState() => _SmartPlannerViewState();
}

class _SmartPlannerViewState extends ConsumerState<SmartPlannerView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      ref.read(chatProvider.notifier).sendMessage(text);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100, // extra padding for bottom
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);

    // Auto-scroll when new messages are added
    ref.listen(chatProvider, (previous, next) {
      if (previous != null && next.length > previous.length) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      } else if (previous != null && next.isNotEmpty && next.last.text != previous.last.text) {
        // Also scroll if the last message was updated (like when RAG streaming finishes)
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return GradientBackgroundWrapper(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text('ShadiSphere Assistant', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
            ),
            Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              if (msg.isBreakdown) {
                return _buildBudgetBreakdown(context, notifier.budget);
              }
              return _buildChatBubble(context, msg, index, ref);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.grey),
                onPressed: () => ref.read(chatProvider.notifier).clearChat(),
                tooltip: 'Clear Chat',
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _submit,
                ),
              )
            ],
          ),
        )
        ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(BuildContext context, ChatMessage msg, int index, WidgetRef ref) {
    return Align(
      alignment: msg.isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: msg.isAI ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: msg.isAI ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (!msg.isAI)
                IconButton(
                  icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                  onPressed: () => _showEditDialog(context, index, msg.text, ref),
                ),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
                decoration: BoxDecoration(
                  color: msg.isAI ? Colors.grey.shade100 : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomLeft: msg.isAI ? const Radius.circular(0) : const Radius.circular(20),
                    bottomRight: msg.isAI ? const Radius.circular(20) : const Radius.circular(0),
                  ),
                ),
                child: Text(msg.text, style: const TextStyle(color: Colors.black87, fontSize: 15)),
              ),
            ],
          ),
          if (msg.isVendorRecommendation)
            _buildVendorRecommendationsList(context, ref, msg.recommendedCategory!),
        ],
      ),
    );
  }

  Widget _buildVendorRecommendationsList(BuildContext context, WidgetRef ref, String category) {
    final vendorsAsyncValue = ref.watch(filteredVendorsProvider);
    
    return vendorsAsyncValue.when(
      data: (vendors) {
        final filtered = vendors.where((v) => v.category == category).toList();
        if (filtered.isEmpty) return const SizedBox.shrink();
        
        return Container(
          height: 180,
          margin: const EdgeInsets.only(bottom: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final v = filtered[i];
              return Card(
                margin: const EdgeInsets.only(right: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: const Center(child: Icon(Icons.image, color: Colors.white)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(v.location, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  void _showEditDialog(BuildContext context, int index, String currentText, WidgetRef ref) {
    final editController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: editController,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(chatProvider.notifier).editMessage(index, editController.text);
              },
              child: const Text('Save'),
            )
          ],
        );
      }
    );
  }

  Widget _buildBudgetBreakdown(BuildContext context, double totalBudget) {
    final allocations = ref.watch(budgetConfigProvider).value ?? defaultBudgetAllocations;

    String formatAmt(double amt) => 'Rs. ${amt.toStringAsFixed(0)}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.primary)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suggested Allocation (${formatAmt(totalBudget)})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary)),
            const Divider(height: 24),
            ...allocations.map((a) => _buildAllocationRow(a.category, formatAmt(totalBudget * a.percentage / 100), '${a.percentage}%')),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationRow(String category, String amount, String percentage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(category)),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          SizedBox(width: 40, child: Text(percentage, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class SharedLedgerView extends ConsumerStatefulWidget {
  const SharedLedgerView({super.key});

  @override
  ConsumerState<SharedLedgerView> createState() => _SharedLedgerViewState();
}

class _SharedLedgerViewState extends ConsumerState<SharedLedgerView> {
  final _joinCodeCtrl = TextEditingController();
  bool _isCreating = false;
  bool _isJoining = false;
  String? _joinError;
  bool _showMembers = false;

  @override
  void dispose() {
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final bool isGuest = !authState.isAuthenticated;

    if (isGuest) {
      return _buildGuestLockedScreen(context);
    }

    final uid = authState.userId ?? '';
    // Guard: if userId is empty (during auth transition), show loading
    if (uid.isEmpty) {
      return _buildLoadingScreen();
    }

    final displayName = authState.displayName ?? authState.email ?? 'User';
    final activeLedgerCode = ref.watch(activeLedgerCodeProvider);
    final viewingJoined = ref.watch(viewingJoinedLedgerProvider);
    final joinedCode = ref.watch(joinedLedgerCodeProvider);

    // If no active ledger code set, try to load user's own
    if (activeLedgerCode.isEmpty) {
      final userLedgerAsync = ref.watch(userLedgerCodeProvider(uid));
      return userLedgerAsync.when(
        data: (code) {
          if (code != null && code.isNotEmpty) {
            // User has an existing ledger, set it
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(activeLedgerCodeProvider.notifier).update(code);
            });
            return _buildLoadingScreen();
          } else if (joinedCode.isNotEmpty) {
            // User doesn't have an own ledger, but HAS a joined ledger!
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(activeLedgerCodeProvider.notifier).update(joinedCode);
              ref.read(viewingJoinedLedgerProvider.notifier).update(true);
            });
            return _buildLoadingScreen();
          }
          // No ledger yet — show create/join
          return _buildCreateJoinScreen(context, uid, displayName);
        },
        loading: () => _buildLoadingScreen(),
        error: (_, __) => _buildCreateJoinScreen(context, uid, displayName),
      );
    }

    final myCodeAsync = ref.watch(userLedgerCodeProvider(uid));
    final myCode = myCodeAsync.value ?? '';

    // Active ledger loaded — show it
    final currentCode = viewingJoined && joinedCode.isNotEmpty ? joinedCode : activeLedgerCode;
    return _buildActiveLedgerScreen(context, ref, currentCode, myCode, uid, displayName, viewingJoined, joinedCode);
  }

  // --- GUEST LOCKED SCREEN ---
  Widget _buildGuestLockedScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D103E).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline, size: 64, color: Color(0xFF2D103E)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sign In Required',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D103E),
                      fontFamily: 'PlayfairDisplay',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The Shared Event Ledger is a collaborative planning tool for logged-in users. Sign in to create your own ledger or join a partner\'s.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/auth?role=consumer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D103E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Sign In / Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- LOADING SCREEN ---
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackgroundWrapper(
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
          ),
        ),
      ),
    );
  }

  // --- CREATE / JOIN SCREEN ---
  Widget _buildCreateJoinScreen(BuildContext context, String uid, String displayName) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Shared Event\nLedger',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD4AF37),
                    fontFamily: 'PlayfairDisplay',
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Collaborate with your partner or family on wedding planning.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 40),

                // Create Ledger Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2D103E), Color(0xFF4C1D66)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D103E).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.add_circle_outline, color: Color(0xFFD4AF37), size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Create My Ledger',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Start a new shared event ledger. You\'ll get a unique code to share with your partner, family, or wedding planner.',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isCreating ? null : () => _handleCreateLedger(uid, displayName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: const Color(0xFF2D103E),
                            disabledBackgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isCreating
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2D103E)))
                              : const Text('Create & Get Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 32),

                // Join Ledger Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.group_add, color: Color(0xFF2D103E), size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Join a Shared Ledger',
                            style: TextStyle(color: Color(0xFF2D103E), fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter the unique code shared by someone to view and collaborate on their wedding ledger.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _joinCodeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'e.g. SS-ABC-123',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.vpn_key_outlined, color: Color(0xFFD4AF37)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                          ),
                          errorText: _joinError,
                        ),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isJoining ? null : () => _handleJoinLedger(uid, displayName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D103E),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF2D103E).withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isJoining
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Join Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
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

  // --- ACTIVE LEDGER SCREEN ---
  Widget _buildActiveLedgerScreen(
    BuildContext context,
    WidgetRef ref,
    String currentCode,
    String myCode,
    String uid,
    String displayName,
    bool viewingJoined,
    String joinedCode,
  ) {
    final itemsAsync = ref.watch(ledgerItemsProvider(currentCode));
    final metaAsync = ref.watch(sharedLedgerMetaProvider(currentCode));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      viewingJoined ? 'Joined Ledger' : 'My Event Ledger',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD4AF37),
                            fontFamily: 'PlayfairDisplay',
                          ),
                    ),
                  ),
                  // Invite button
                  IconButton(
                    icon: const Icon(Icons.share),
                    color: const Color(0xFFD4AF37),
                    tooltip: 'Share Code',
                    onPressed: () => _showShareCodeDialog(context, currentCode),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Code badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D103E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.vpn_key, color: Color(0xFFD4AF37), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          currentCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')),
                      );
                    },
                    child: const Icon(Icons.copy, size: 18, color: Color(0xFFD4AF37)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Ledger Switcher (if user has a joined ledger too)
              if (myCode.isNotEmpty) _buildLedgerSwitcher(context, ref, myCode, viewingJoined, joinedCode, uid, displayName),

              const SizedBox(height: 12),

              // Members expandable
              metaAsync.when(
                data: (meta) {
                  if (meta == null) return const SizedBox.shrink();
                  return _buildMembersSection(meta, uid, currentCode);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),

              // Ledger Items
              itemsAsync.when(
                data: (allItems) {
                  final now = DateTime.now();
                  final todayMidnight = DateTime(now.year, now.month, now.day);
                  final items = allItems.where((item) {
                    if (item.eventDate == null || item.eventDate!.trim().isEmpty) return true;
                    final str = item.eventDate!.trim();
                    DateTime? eDate = DateTime.tryParse(str);
                    if (eDate == null) {
                      final formats = [
                        DateFormat('yyyy-MM-dd'),
                        DateFormat('MM/dd/yyyy'),
                        DateFormat('M/d/yyyy'),
                        DateFormat('MMM d, yyyy'),
                        DateFormat('MMMM d, yyyy'),
                        DateFormat('dd/MM/yyyy'),
                      ];
                      for (final fmt in formats) {
                        try {
                          eDate = fmt.parse(str);
                          break;
                        } catch (_) {}
                      }
                    }
                    if (eDate != null) {
                      final eDateMidnight = DateTime(eDate.year, eDate.month, eDate.day);
                      if (eDateMidnight.isBefore(todayMidnight)) return false;
                    }
                    return true;
                  }).toList();

                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('No entries yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              'Tap + to add your first wedding expense',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Calculate total
                  final total = items.fold<double>(0, (sum, i) => sum + i.amount);

                  return Column(
                    children: [
                      // Total card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2D103E), Color(0xFF4C1D66)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Budget', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Text(
                              'Rs. ${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Items
                      ...items.map((item) => _buildLedgerItem(context, ref, item, currentCode)),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            context.push('/consumer/make_payment', extra: {
                              'ledgerCode': currentCode,
                              'items': items,
                              'totalAmount': total,
                            });
                          },
                          icon: const Icon(Icons.payment_rounded, color: Color(0xFF2D103E), size: 22),
                          label: Text(
                            'Confirm & Pay Ledger (${_formatCurrency(total)})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D103E),
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: const Color(0xFF2D103E),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)))),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: const Color(0xFF2D103E),
        onPressed: () => _showAddItemDialog(context, currentCode, uid, displayName),
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- LEDGER SWITCHER ---
  Widget _buildLedgerSwitcher(BuildContext context, WidgetRef ref, String myCode, bool viewingJoined, String joinedCode, String uid, String displayName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSwitchTab(
                  label: 'My Ledger',
                  icon: Icons.person,
                  isActive: !viewingJoined,
                  onTap: () {
                    ref.read(viewingJoinedLedgerProvider.notifier).update(false);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSwitchTab(
                  label: 'Joined Ledger',
                  icon: Icons.group,
                  isActive: viewingJoined,
                  onTap: () {
                    if (joinedCode.isNotEmpty) {
                      ref.read(viewingJoinedLedgerProvider.notifier).update(true);
                    } else {
                      _showJoinCodeBottomSheet(context, uid, displayName);
                    }
                  },
                ),
              ),
            ],
          ),
          if (viewingJoined && joinedCode.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Viewing: $joinedCode', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                InkWell(
                  onTap: () async {
                    // Clean up: remove user from members and clear persisted joined code
                    await leaveJoinedLedger(uid, joinedCode);
                    ref.read(joinedLedgerCodeProvider.notifier).update('');
                    ref.read(viewingJoinedLedgerProvider.notifier).update(false);
                  },
                  child: const Text('Leave', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitchTab({required String label, required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2D103E) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? const Color(0xFFD4AF37) : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MEMBERS SECTION ---
  Widget _buildMembersSection(SharedLedger meta, String currentUid, String currentCode) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showMembers = !_showMembers),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.group, color: Color(0xFF2D103E), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '${meta.members.length} member${meta.members.length != 1 ? 's' : ''} with access',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF2D103E)),
                  ),
                  const Spacer(),
                  Icon(
                    _showMembers ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_showMembers) ...[
            const Divider(height: 1),
            ...meta.members.map((member) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: member.uid == meta.ownerUid
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                        : Colors.grey.shade200,
                    child: Icon(
                      Icons.person,
                      size: 16,
                      color: member.uid == meta.ownerUid ? const Color(0xFFD4AF37) : Colors.grey,
                    ),
                  ),
                  title: Text(
                    member.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  trailing: member.uid == meta.ownerUid
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Owner', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                        )
                      : (currentUid == meta.ownerUid)
                          ? InkWell(
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Remove Member'),
                                    content: Text('Are you sure you want to remove ${member.name}?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Remove', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await leaveJoinedLedger(member.uid, currentCode);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${member.name} removed from ledger.')),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Remove', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                              ),
                            )
                          : const Text('Member', style: TextStyle(fontSize: 10, color: Colors.grey)),
                )),
          ],
        ],
      ),
    );
  }

  // --- LEDGER ITEM CARD ---
  Widget _buildLedgerItem(BuildContext context, WidgetRef ref, LedgerItem item, String ledgerCode) {
    Color statusColor = Colors.orange;
    if (item.status == 'Booked') statusColor = Colors.green;
    if (item.status == 'Needs Action') statusColor = Colors.red;
    if (item.status == 'Confirmed') statusColor = Colors.blue;
    if (item.status == 'Completed') statusColor = Colors.purple;

    final authState = ref.read(authProvider);
    final actorUid = authState.userId ?? 'guest';
    final actorName = authState.displayName ?? authState.email ?? 'Guest User';

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (dir) => deleteLedgerItem(item.id, ledgerCode: ledgerCode, actorUid: actorUid, actorName: actorName, vendorName: item.vendorName, vendorInquiryId: item.vendorInquiryId),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category & vendor
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D103E))),
                        const SizedBox(height: 2),
                        Text(item.vendorName, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                  // Amount & status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rs. ${item.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.status,
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                    onSelected: (value) {
                      if (value == 'delete') {
                        deleteLedgerItem(item.id, ledgerCode: ledgerCode, actorUid: actorUid, actorName: actorName, vendorName: item.vendorName, vendorInquiryId: item.vendorInquiryId);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
              // Event Details
              if (item.eventDate != null || item.numberOfGuests != null || item.notes != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.eventDate != null && item.eventDate!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text('Date: ${item.eventDate}', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                          ],
                        ),
                      if (item.numberOfGuests != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text('Guests: ${item.numberOfGuests}', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                          ],
                        ),
                      ],
                      if (item.notes != null && item.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Expanded(child: Text('Notes: ${item.notes}', style: TextStyle(fontSize: 12, color: Colors.grey.shade800))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Actions and Added By
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Added by badge
                  if (item.addedByName.isNotEmpty)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Added by ${item.addedByName}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.addedAt != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${_formatTimeAgo(item.addedAt!)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    const Spacer(),

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DIALOGS ---
  void _showAddItemDialog(BuildContext context, String ledgerCode, String uid, String displayName) {
    final catCtrl = TextEditingController();
    final vendorCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Ledger Item', style: TextStyle(color: Color(0xFF2D103E), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category (e.g. Catering)', prefixIcon: Icon(Icons.category, size: 20))),
            const SizedBox(height: 8),
            TextField(controller: vendorCtrl, decoration: const InputDecoration(labelText: 'Vendor Name', prefixIcon: Icon(Icons.storefront, size: 20))),
            const SizedBox(height: 8),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (Rs)', prefixIcon: Icon(Icons.payments, size: 20))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D103E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text) ?? 0;
              if (catCtrl.text.trim().isEmpty || vendorCtrl.text.trim().isEmpty) return;
              addLedgerItem(catCtrl.text.trim(), vendorCtrl.text.trim(), amt, ledgerCode: ledgerCode, addedBy: uid, addedByName: displayName);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showShareCodeDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.share, color: Color(0xFFD4AF37)),
            SizedBox(width: 10),
            Text('Share Ledger Code', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with your partner or family so they can view and collaborate on this ledger:'),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2D103E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  code,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3, color: Color(0xFFD4AF37)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: const Color(0xFF2D103E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied to clipboard!')));
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Code'),
          ),
        ],
      ),
    );
  }

  void _showJoinCodeBottomSheet(BuildContext context, String uid, String displayName) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Join a Shared Ledger', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
            const SizedBox(height: 8),
            Text('Enter the unique code to view someone else\'s ledger.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. SS-ABC-123',
                prefixIcon: const Icon(Icons.vpn_key_outlined, color: Color(0xFFD4AF37)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2)),
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D103E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final code = ctrl.text.trim().toUpperCase();
                  if (code.isEmpty) return;
                  final success = await joinSharedLedger(code, uid, displayName);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    if (success) {
                      ref.read(joinedLedgerCodeProvider.notifier).update(code);
                      ref.read(viewingJoinedLedgerProvider.notifier).update(true);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined ledger $code!')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid code. Ledger not found.')));
                    }
                  }
                },
                child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS ---
  Future<void> _handleCreateLedger(String uid, String displayName) async {
    setState(() => _isCreating = true);
    final code = await createLedgerForUser(uid, displayName);
    if (mounted) {
      ref.read(activeLedgerCodeProvider.notifier).update(code);
      ref.invalidate(userLedgerCodeProvider(uid));
      setState(() => _isCreating = false);
    }
  }

  Future<void> _handleJoinLedger(String uid, String displayName) async {
    final code = _joinCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _joinError = 'Please enter a code');
      return;
    }
    setState(() {
      _isJoining = true;
      _joinError = null;
    });

    final success = await joinSharedLedger(code, uid, displayName);
    if (mounted) {
      if (success) {
        ref.read(joinedLedgerCodeProvider.notifier).update(code);
        ref.read(viewingJoinedLedgerProvider.notifier).update(true);
        // Also create user's own ledger if they don't have one
        final ownCode = await createLedgerForUser(uid, displayName);
        ref.read(activeLedgerCodeProvider.notifier).update(ownCode);
        ref.invalidate(userLedgerCodeProvider(uid));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined ledger $code!')));
        }
      } else {
        setState(() => _joinError = 'Invalid code. Ledger not found.');
      }
      setState(() => _isJoining = false);
    }
  }

  // --- HELPERS ---
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

class UserProfileView extends ConsumerWidget {
  const UserProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(translationProvider);
    final authState = ref.watch(authProvider);
    final bool isGuest = !authState.isAuthenticated;
    final String displayName = isGuest
        ? tr('Guest User').toUpperCase()
        : (authState.displayName ?? authState.email?.split('@').first ?? 'Consumer').toUpperCase();

    return GradientBackgroundWrapper(
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 40),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isGuest
                            ? [Colors.grey.shade300, Colors.grey.shade400]
                            : [const Color(0xFFD4AF37), const Color(0xFFF9E5B5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isGuest ? Colors.grey : const Color(0xFFD4AF37)).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 124,
                    height: 124,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Center(
                      child: Icon(
                        isGuest ? Icons.person_outline : Icons.person,
                        size: 60,
                        color: isGuest ? Colors.grey.shade600 : const Color(0xFF2D103E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 26,
                  fontFamily: 'PlayfairDisplay',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isGuest ? Colors.grey.shade700 : const Color(0xFF2D103E),
                ),
              ),
            ),
            if (isGuest) ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tr('Browsing without an account'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // --- Guest: Sign In / Create Account Banner ---
            if (isGuest) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2D103E), Color(0xFF4C1D66)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D103E).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_open, color: Color(0xFFD4AF37), size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Unlock Full Access',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sign in to save vendors, manage bookings, access your ledger, and get personalized recommendations.',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go('/auth?role=consumer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: const Color(0xFF2D103E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Sign In / Create Account',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // --- Menu Items ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.favorite, color: Color(0xFF2D103E)),
                          title: Text(tr('Saved Vendors')),
                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
                          onTap: () {
                            if (isGuest) {
                              _showGuestGateDialog(context, 'save vendors');
                            } else {
                              context.push('/consumer/saved_vendors');
                            }
                          },
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.forum, color: Color(0xFF2D103E)),
                          title: Text(tr('Vendor Replies')),
                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
                          onTap: () {
                            if (isGuest) {
                              _showGuestGateDialog(context, 'view vendor replies');
                            } else {
                              context.push('/consumer/vendor_replies');
                            }
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.rate_review, color: Color(0xFF2D103E)),
                          title: Text(tr('Share App Feedback')),
                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
                          onTap: () {
                            if (isGuest) {
                              _showGuestGateDialog(context, 'share feedback');
                            } else {
                              showDialog(context: context, builder: (_) => FeedbackDialog());
                            }
                          },
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.settings, color: Color(0xFF2D103E)),
                          title: Text(tr('Settings')),
                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
                          onTap: () => context.push('/consumer/settings'),
                        ),
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

  void _showGuestGateDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Color(0xFFD4AF37), size: 24),
            SizedBox(width: 10),
            Text('Sign In Required', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontSize: 18)),
          ],
        ),
        content: Text(
          'You need to sign in to $featureName. Create a free account to unlock all features!',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D103E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/auth?role=consumer');
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

class SavedVendorsScreen extends ConsumerWidget {
  const SavedVendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(allVendorsProvider);
    final savedIds = ref.watch(savedVendorsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: const Text('Saved Vendors', style: TextStyle(color: Color(0xFFD4AF37))),
      ),
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: vendorsAsync.when(
        data: (vendors) {
          final savedVendors = vendors.where((v) => savedIds.contains(v.id)).toList();
          if (savedVendors.isEmpty) {
            return const Center(child: Text('No saved vendors yet.', style: TextStyle(color: Colors.grey)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: savedVendors.length,
            itemBuilder: (context, i) {
              final v = savedVendors[i];
              return _buildSavedVendorCard(context, ref, v);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      ),
      ),
    );
  }

  Widget _buildSavedVendorCard(BuildContext context, WidgetRef ref, Vendor v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => context.push('/consumer/vendor_detail', extra: v),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.image, color: Colors.white),
        ),
        title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(v.category),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () => ref.read(savedVendorsProvider.notifier).toggleSaved(v.id),
        ),
      ),
    );
  }
}

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(consumerBookingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: const Text('My Bookings', style: TextStyle(color: Color(0xFFD4AF37), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold)),
      ),
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: bookingsAsync.when(
            data: (allBookings) {
              final confirmedBookings = allBookings.where((b) {
                final st = b.status.toLowerCase();
                return st == 'confirmed' || st == 'booked' || st == 'accepted';
              }).toList();

              if (confirmedBookings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('No Confirmed Bookings Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                      const SizedBox(height: 6),
                      Text('Bookings confirmed & paid via your ledger will appear here.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                );
              }
              final groupedBookings = <String, List<Booking>>{};
              for (final b in confirmedBookings) {
                final key = b.transactionId ?? b.id;
                if (!groupedBookings.containsKey(key)) {
                  groupedBookings[key] = [];
                }
                groupedBookings[key]!.add(b);
              }
              final groups = groupedBookings.values.toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: groups.length,
                itemBuilder: (context, i) {
                  return _buildGroupedBookingCard(context, ref, groups[i]);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedBookingCard(BuildContext context, WidgetRef ref, List<Booking> group) {
    if (group.isEmpty) return const SizedBox.shrink();
    
    final bFirst = group.first;
    final txnId = bFirst.transactionId ?? 'TXN-${bFirst.id.substring(0, min(6, bFirst.id.length)).toUpperCase()}';
    final totalAmount = group.fold<double>(0, (sum, b) => sum + b.amount);
    final consumerName = bFirst.consumerName;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRANSACTION: $txnId',
                style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'CONFIRMED',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...group.map((b) {
            String dText = b.eventDate ?? 'Flexible Date';
            try {
              if (b.eventDate != null) {
                final dt = DateTime.parse(b.eventDate!);
                dText = DateFormat('MMMM d, yyyy').format(dt);
              }
            } catch (_) {}
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${b.category.toUpperCase()} • ${b.vendorName}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D103E)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text('Date: $dText', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                      ),
                      Text(
                        'Rs. ${b.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Paid:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              Text(
                'Rs. ${totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2D103E)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final auth = ref.read(authProvider);
                      await PdfReceiptService.generateAndShareReceipt(
                        transactionId: txnId,
                        userName: auth.displayName ?? auth.email ?? consumerName,
                        userEmail: auth.email ?? '',
                        ledgerCode: 'ORDER-${txnId.substring(max(0, txnId.length - 4))}',
                        paymentMethod: 'Credit Card (Paid & Verified)',
                        totalAmount: totalAmount,
                        items: group.map((b) => {
                          'category': b.category,
                          'vendorName': b.vendorName,
                          'eventDate': b.eventDate ?? 'Flexible Date',
                          'amount': b.amount,
                        }).toList(),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFF2D103E)),
                    label: const Text(
                      'PDF Receipt',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2D103E)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                      foregroundColor: const Color(0xFF2D103E),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cancel Booking?'),
                        content: const Text('Are you sure you want to cancel this entire booking?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        for (final b in group) {
                          await FirebaseFirestore.instance.collection('bookings').doc(b.id).update({'status': 'Cancelled'});
                          
                          if (b.vendorId.isNotEmpty && b.eventDate != null) {
                            final norm = normalizeSingleDate(b.eventDate!);
                            if (norm != null) {
                              final availRef = FirebaseFirestore.instance.collection('vendor_availability').doc(b.vendorId);
                              final snap = await availRef.get();
                              if (snap.exists && snap.data() != null) {
                                final days = snap.data()!['days'] as List<dynamic>? ?? [];
                                final updatedDays = days.where((d) => (d is Map && d['date']?.toString() != norm)).toList();
                                await availRef.update({'days': updatedDays});
                              }
                            }
                          }

                          final inqSnap = await FirebaseFirestore.instance.collection('vendor_inquiries').where('vendorId', isEqualTo: b.vendorId).get();
                          for (final doc in inqSnap.docs) {
                            final dt = doc.data()['eventDate']?.toString() ?? doc.data()['detail']?.toString() ?? doc.data()['date']?.toString() ?? '';
                            if (b.eventDate != null && normalizeSingleDate(dt) == normalizeSingleDate(b.eventDate!)) {
                              await doc.reference.update({'status': 'Cancelled'});
                            }
                          }
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled successfully.')));
                        }
                      } catch (e) {
                        print("Error cancelling booking: $e");
                      }
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                  label: const Text('Cancel', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FullImageGalleryDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullImageGalleryDialog({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullImageGalleryDialog> createState() => _FullImageGalleryDialogState();
}

class _FullImageGalleryDialogState extends State<_FullImageGalleryDialog> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildGalleryImage(String url) {
    if (url.startsWith('data:image')) {
      final split = url.split(',');
      if (split.length == 2) {
        try {
          return Image.memory(
            base64Decode(split[1]),
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 64)),
          );
        } catch (_) {}
      }
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 64)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                child: Center(
                  child: _buildGalleryImage(widget.images[index]),
                ),
              );
            },
          ),
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (_currentIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 22),
                  ),
                  onPressed: () {
                    _controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                ),
              ),
            ),
          if (_currentIndex < widget.images.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 22),
                  ),
                  onPressed: () {
                    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                ),
              ),
            ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: widget.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final isSelected = idx == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        _controller.animateToPage(idx, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _buildGalleryImage(widget.images[idx]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class VendorDetailScreen extends ConsumerStatefulWidget {
  final Vendor vendor;

  const VendorDetailScreen({super.key, required this.vendor});

  @override
  ConsumerState<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends ConsumerState<VendorDetailScreen> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildDetailImageWidget(String url) {
    if (url.startsWith('data:image')) {
      final split = url.split(',');
      if (split.length == 2) {
        try {
          return Image.memory(
            base64Decode(split[1]),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (c, e, s) => Container(color: Colors.grey.shade300, child: const Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey))),
          );
        } catch (_) {}
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (c, e, s) => Container(color: Colors.grey.shade300, child: const Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey))),
    );
  }

  Widget _buildVenuePricingSection(BuildContext context, Map<String, dynamic> pData) {
    if (widget.vendor.category.toLowerCase() != 'venues') return const SizedBox.shrink();

    final double weekdayPrice = double.tryParse(pData['price']?.toString() ?? '0') ?? 0.0;
    final double weekendPrice = double.tryParse(pData['weekendPrice']?.toString() ?? '0') ?? weekdayPrice;
    final Map<String, dynamic> specialMap = (pData['specialPrices'] as Map<String, dynamic>?) ?? {};
    final int capacity = int.tryParse(pData['capacity']?.toString() ?? '0') ?? 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2D103E).withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D103E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.monetization_on_outlined, color: Color(0xFF2D103E), size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Venue Pricing Plans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay')),
                  SizedBox(height: 2),
                  Text('Dynamic weekday & weekend rates', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Rates Row Grid
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Weekday (Mon-Thu)', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(weekdayPrice > 0 ? _formatCurrency(weekdayPrice) : 'Contact Vendor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D103E))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Weekend (Fri-Sun)', style: TextStyle(fontSize: 11, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(weekendPrice > 0 ? _formatCurrency(weekendPrice) : 'Contact Vendor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D103E))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (capacity > 0 || specialMap.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (capacity > 0)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        children: [
                          const Icon(Icons.people_outline, size: 18, color: Color(0xFF2D103E)),
                          const SizedBox(width: 8),
                          Text('$capacity Guests Cap', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF2D103E))),
                        ],
                      ),
                    ),
                  ),
                if (capacity > 0 && specialMap.isNotEmpty) const SizedBox(width: 10),
                if (specialMap.isNotEmpty)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        children: [
                          const Icon(Icons.star_outline, size: 18, color: Color(0xFFD4AF37)),
                          const SizedBox(width: 8),
                          Text('${specialMap.length} Peak Dates', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF2D103E))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = ref.watch(savedVendorsProvider).contains(widget.vendor.id);
    
    List<String> images = widget.vendor.images;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                isSaved ? Icons.favorite : Icons.favorite_border,
                color: isSaved ? Colors.red : Colors.white,
              ),
              onPressed: () {
                ref.read(savedVendorsProvider.notifier).toggleSaved(widget.vendor.id);
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('vendors').doc(widget.vendor.id).snapshots(),
        builder: (context, vendorDocSnap) {
          final vData = (vendorDocSnap.hasData && vendorDocSnap.data!.exists)
              ? (vendorDocSnap.data!.data() as Map<String, dynamic>? ?? {})
              : <String, dynamic>{};

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('vendor_profile').doc(widget.vendor.id).snapshots(),
            builder: (context, profileSnap) {
              final rawPData = (profileSnap.hasData && profileSnap.data!.exists)
                  ? (profileSnap.data!.data() as Map<String, dynamic>? ?? {})
                  : <String, dynamic>{};

              final pData = {...vData, ...rawPData};
              if (vData['cateringPackages'] != null) {
                pData['cateringPackages'] = vData['cateringPackages'];
              }
              if (vData['cateringDishes'] != null) {
                pData['cateringDishes'] = vData['cateringDishes'];
              }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('vendor_media').doc(widget.vendor.id).snapshots(),
            builder: (context, mediaSnap) {
              List<String> liveImages = [...widget.vendor.images];

              if (profileSnap.hasData && profileSnap.data!.exists) {
                final outs = (pData['outsidePictures'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
                final ins = (pData['insidePictures'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
                liveImages.addAll(outs);
                liveImages.addAll(ins);
              }

              if (mediaSnap.hasData && mediaSnap.data!.exists) {
                final mData = mediaSnap.data!.data() as Map<String, dynamic>? ?? {};
                final urls = (mData['urls'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
                liveImages.addAll(urls);
              }

              final finalImages = liveImages.where((u) => u.isNotEmpty).toSet().toList();

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Carousel with indicators
                    Stack(
                      children: [
                        SizedBox(
                          height: 320,
                          width: double.infinity,
                          child: finalImages.isEmpty
                              ? Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: Icon(Icons.storefront, size: 80, color: Colors.grey),
                                  ),
                                )
                              : PageView.builder(
                                  controller: _pageController,
                                  itemCount: finalImages.length,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentImageIndex = index;
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => _FullImageGalleryDialog(
                                            images: finalImages,
                                            initialIndex: index,
                                          ),
                                        );
                                      },
                                      child: _buildDetailImageWidget(finalImages[index]),
                                    );
                                  },
                                ),
                        ),
                        // Gradient Overlay for text readability
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.3),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Dot Indicators
                        if (finalImages.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                finalImages.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  height: 8,
                                  width: _currentImageIndex == index ? 24 : 8,
                                  decoration: BoxDecoration(
                                    color: _currentImageIndex == index
                                        ? const Color(0xFFD4AF37)
                                        : Colors.white70,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Vendor Details Section
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title, Category, and Rating
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.vendor.name,
                                            style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2D103E),
                                              fontFamily: 'PlayfairDisplay',
                                            ),
                                          ),
                                        ),
                                        VendorBadge(tier: widget.vendor.subscriptionTier),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2D103E).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        widget.vendor.category,
                                        style: const TextStyle(
                                          color: Color(0xFF2D103E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 20),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.vendor.rating,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF2D103E),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.grey, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.vendor.location,
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Dynamic Venue Pricing Section
                          _buildVenuePricingSection(context, pData),

                          // About Section
                          const Text(
                            'About this Vendor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D103E),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.vendor.description,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Message Vendor Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showMessageDialog(context, widget.vendor, ref),
                              icon: const Icon(Icons.message_rounded, size: 20),
                              label: Text('Message ${widget.vendor.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                foregroundColor: const Color(0xFF2D103E),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          _VendorCatalogSection(
                            vendor: widget.vendor,
                            pData: pData,
                            onAddPackage: (pkg) => _showAddToLedgerBottomSheet(context, ref, package: pkg),
                          ),

                          // User Reviews Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'User Reviews',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D103E),
                                ),
                              ),
                              Text(
                                '(${widget.vendor.reviews.length} reviews)',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Rate This Vendor Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showReviewDialog(context, ref),
                              icon: const Icon(Icons.star_rate_rounded, size: 20),
                              label: const Text('Rate This Vendor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD4AF37),
                                side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (widget.vendor.reviews.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'No reviews for this vendor yet. Be the first to review!',
                                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              ),
                            )
                          else
                            ...widget.vendor.reviews.map((review) => _buildReviewCard(review)),
                          const SizedBox(height: 80), // extra padding for bottom button space
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  ),
      bottomNavigationBar: (widget.vendor.category.toLowerCase() == 'venue' || widget.vendor.category.toLowerCase() == 'venues' || widget.vendor.category.toLowerCase().contains('venue'))
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/consumer/venue_pick_date', extra: {
                      'vendor': widget.vendor,
                    });
                  },
                  icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
                  label: const Text('Pick Date & Book', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D103E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildReviewCard(VendorReview review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  review.reviewerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D103E),
                  ),
                ),
                Text(
                  review.date,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < review.rating.floor() ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SRS §3.3: Booking inquiry dialog
  void _showAddToLedgerBottomSheet(BuildContext context, WidgetRef ref, {VendorPackage? package}) {
    final dateCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    if (package != null) {
      notesCtrl.text = 'Selected Package: ${package.name}\n\n${package.description}';
    }
    final guestsCtrl = TextEditingController();
    final authState = ref.read(authProvider);

    final bool showGuests = widget.vendor.category.toLowerCase() == 'venues' || 
                            widget.vendor.category.toLowerCase() == 'catering';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add to Ledger', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(package != null ? '${widget.vendor.name} - ${package.name}' : widget.vendor.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                              if (package == null) VendorBadge(tier: widget.vendor.subscriptionTier),
                            ],
                          ),
                          Text(package != null ? 'PKR ${package.price}${package.pricingUnit.isNotEmpty ? ' / ${package.pricingUnit}' : ''}' : widget.vendor.estimatedPrice, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: dateCtrl,
                readOnly: true,
                onTap: () async {
                  // Fetch blocked & booked dates from vendor_availability, bookings & vendor_inquiries
                  Set<String> blockedDates = {};
                  try {
                    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                    final Set<String> activeConfirmedDates = {};

                    final bSnap = await FirebaseFirestore.instance.collection('bookings').where('vendorId', isEqualTo: widget.vendor.id).get();
                    for (var d in bSnap.docs) {
                      final status = d.data()['status']?.toString() ?? '';
                      final isConfirmed = status == 'Confirmed' || status == 'Accepted' || status == 'User Accepted';
                      if (isConfirmed) {
                        final dt = d.data()['eventDate']?.toString();
                        if (dt != null) {
                          final norm = normalizeSingleDate(dt);
                          if (norm != null && norm.compareTo(todayStr) >= 0) {
                            blockedDates.add(norm);
                            activeConfirmedDates.add(norm);
                          }
                        }
                      }
                    }

                    final inqSnap = await FirebaseFirestore.instance.collection('vendor_inquiries').where('vendorId', isEqualTo: widget.vendor.id).get();
                    for (var d in inqSnap.docs) {
                      final status = d.data()['status']?.toString() ?? '';
                      final isConfirmed = status == 'Confirmed' || status == 'Accepted' || status == 'User Accepted';
                      if (isConfirmed) {
                        final dt = d.data()['eventDate']?.toString() ?? d.data()['detail']?.toString();
                        if (dt != null) {
                          final norm = normalizeSingleDate(dt);
                          if (norm != null && norm.compareTo(todayStr) >= 0) {
                            blockedDates.add(norm);
                            activeConfirmedDates.add(norm);
                          }
                        }
                      }
                    }

                    final doc = await FirebaseFirestore.instance.collection('vendor_availability').doc(widget.vendor.id).get();
                    if (doc.exists && doc.data() != null) {
                      final days = doc.data()!['days'] as List<dynamic>? ?? [];
                      for (var d in days) {
                        if (d['isBlocked'] == true && d['date'] != null) {
                          final norm = normalizeSingleDate(d['date'].toString());
                          final note = d['note']?.toString().toLowerCase() ?? '';
                          final isBookingAutoBlock = note.contains('booked');
                          if (isBookingAutoBlock) {
                            if (norm != null && activeConfirmedDates.contains(norm)) {
                              blockedDates.add(norm);
                            }
                          } else {
                            if (norm != null && norm.compareTo(todayStr) >= 0) {
                              blockedDates.add(norm);
                            }
                          }
                        }
                      }
                    }
                  } catch (e) {
                    print("Error fetching availability: $e");
                  }

                  final now = DateTime.now();
                  final firstDate = DateTime(now.year, now.month, now.day);
                  
                  // Ensure initial date is not a blocked date
                  DateTime initial = firstDate;
                  while (true) {
                    final dateStr = DateFormat('yyyy-MM-dd').format(initial);
                    if (!blockedDates.contains(dateStr)) break;
                    initial = initial.add(const Duration(days: 1));
                    // Prevent infinite loop in edge case where all dates are blocked
                    if (initial.difference(firstDate).inDays > 365) {
                      initial = firstDate;
                      break;
                    }
                  }

                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: firstDate,
                    lastDate: now.add(const Duration(days: 3650)),
                    selectableDayPredicate: (DateTime date) {
                      final dateStr = DateFormat('yyyy-MM-dd').format(date);
                      return !blockedDates.contains(dateStr);
                    },
                  );

                  if (selectedDate != null) {
                    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
                    dateCtrl.text = '${months[selectedDate.month - 1]} ${selectedDate.day}, ${selectedDate.year}';
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Event Date',
                  hintText: 'e.g. December 15, 2026',
                  prefixIcon: const Icon(Icons.calendar_today, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (showGuests) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: guestsCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setModalState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Number of Guests',
                    hintText: 'e.g. 500',
                    prefixIcon: const Icon(Icons.people, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (guestsCtrl.text.trim().isNotEmpty && int.tryParse(guestsCtrl.text.trim()) != null) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final price = package != null 
                          ? (double.tryParse(package.price) ?? _parsePrice(widget.vendor.estimatedPrice))
                          : _parsePrice(widget.vendor.estimatedPrice);
                      final guests = int.tryParse(guestsCtrl.text.trim()) ?? 0;
                      final total = price * guests;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('Estimated Total: ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                          Text('Rs. ${total.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      );
                    },
                  ),
                ],
              ],
              const SizedBox(height: 16),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Any special requirements...',
                  prefixIcon: const Icon(Icons.notes, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D103E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (dateCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select an Event Date before adding to ledger.')),
                      );
                      return;
                    }

                    if (showGuests && guestsCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter the Number of Guests.')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    final basePrice = package != null 
                        ? (double.tryParse(package.price) ?? _parsePrice(widget.vendor.estimatedPrice))
                        : _parsePrice(widget.vendor.estimatedPrice);
                    
                    int? guests = int.tryParse(guestsCtrl.text.trim());
                    double finalPrice = basePrice;
                    if (showGuests && guests != null && guests > 0) {
                      finalPrice = basePrice * guests;
                    }
                    
                    String ledgerCode = '';
                    if (authState.isAuthenticated) {
                      final uid = authState.userId ?? '';
                      final displayName = authState.displayName ?? authState.email ?? 'User';
                      try {
                        ledgerCode = ref.read(activeLedgerCodeProvider);
                        if (ledgerCode.isEmpty) {
                          ledgerCode = await createLedgerForUser(uid, displayName);
                          ref.read(activeLedgerCodeProvider.notifier).update(ledgerCode);
                        }
                      } catch (_) {}
                    }

                    await addLedgerItem(
                      widget.vendor.category,
                      package != null ? '${widget.vendor.name} (${package.name})' : widget.vendor.name,
                      finalPrice,
                      ledgerCode: ledgerCode,
                      addedBy: authState.userId ?? '',
                      addedByName: authState.displayName ?? authState.email ?? 'User',
                      vendorId: widget.vendor.id,
                      eventDate: dateCtrl.text.trim().isNotEmpty ? dateCtrl.text.trim() : null,
                      notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                      numberOfGuests: guests,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF2D103E),
                          content: Text('${widget.vendor.name} added to ledger! You can confirm booking from there.'),
                        ),
                      );
                      context.pop();
                    }
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add to Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ));
  }

  double _parsePrice(String priceText) {
    final digitsOnly = priceText.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return 0.0;
    return double.tryParse(digitsOnly) ?? 0.0;
  }

  void _showMessageDialog(BuildContext context, Vendor vendor, WidgetRef ref) {
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Message ${vendor.name}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ask about availability, pricing, or specific requirements.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (msgCtrl.text.trim().isNotEmpty) {
                final authState = ref.read(authProvider);
                final clientName = authState.displayName ?? authState.email ?? 'A user';
                
                try {
                  await FirebaseFirestore.instance.collection('vendor_messages').add({
                    'vendorId': vendor.id,
                    'threadId': 'thread_${DateTime.now().millisecondsSinceEpoch}',
                    'clientName': clientName,
                    'clientId': authState.userId ?? 'anonymous',
                    'lastMessage': msgCtrl.text.trim(),
                    'date': '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    'unreadCount': 1,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    Navigator.pop(dlgCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Message sent to ${vendor.name}!'), 
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to send message.'), 
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D103E), foregroundColor: Colors.white),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to leave a review.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    int selectedRating = 0;
    final commentCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (stCtx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rate_review_rounded, color: Color(0xFFD4AF37), size: 48),
                const SizedBox(height: 16),
                Text(
                  'Rate ${widget.vendor.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D103E),
                    fontFamily: 'PlayfairDisplay',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share your experience with this vendor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Star rating row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedRating = index + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: const Color(0xFFD4AF37),
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),
                if (selectedRating > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][selectedRating],
                      style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                const SizedBox(height: 16),

                // Comment field
                TextField(
                  controller: commentCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Tell others about your experience...',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit & Cancel buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          if (selectedRating == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select a star rating.'), backgroundColor: Colors.orange),
                            );
                            return;
                          }
                          if (commentCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please write a comment.'), backgroundColor: Colors.orange),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            final reviewerName = authState.displayName ?? authState.email ?? 'Anonymous';
                            await submitVendorReview(
                              vendorId: widget.vendor.id,
                              reviewerName: reviewerName,
                              comment: commentCtrl.text.trim(),
                              rating: selectedRating.toDouble(),
                            );

                            if (context.mounted) {
                              Navigator.pop(dlgCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Thank you! Your review has been submitted. ⭐'),
                                  backgroundColor: Color(0xFF2D103E),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to submit review. Please try again.'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D103E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
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
}

class CategoryListScreen extends ConsumerWidget {
  final String categoryName;

  const CategoryListScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(filteredVendorsProvider);
    final savedIds = ref.watch(savedVendorsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: Text(
          categoryName,
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontFamily: 'PlayfairDisplay',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: vendorsAsync.when(
            data: (vendors) {
              final filteredVendors = vendors
                  .where((v) => v.category.toLowerCase() == categoryName.toLowerCase())
                  .toList();

              if (filteredVendors.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No vendors found in $categoryName',
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: filteredVendors.length,
                itemBuilder: (context, index) {
                  final vendor = filteredVendors[index];
                  final isSaved = savedIds.contains(vendor.id);
                  
                  return _buildCategoryVendorCard(context, ref, vendor, isSaved);
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            ),
            error: (e, s) => Center(
              child: Text(
                'Error loading vendors: $e',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryVendorCard(BuildContext context, WidgetRef ref, Vendor vendor, bool isSaved) {
    final heroImage = vendor.images.isNotEmpty ? vendor.images.first : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push('/consumer/vendor_detail', extra: vendor),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: heroImage.isNotEmpty
                        ? Image.network(
                            heroImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.storefront, size: 48, color: Colors.grey),
                          ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isSaved ? Icons.favorite : Icons.favorite_border,
                        color: isSaved ? Colors.red : Colors.white,
                      ),
                      onPressed: () => ref.read(savedVendorsProvider.notifier).toggleSaved(vendor.id),
                    ),
                  ),
                ),

              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                vendor.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D103E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            VendorBadge(tier: vendor.subscriptionTier),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            vendor.rating,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vendor.location,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vendor.description,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AllCategoriesScreen extends ConsumerWidget {
  const AllCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(appCategoriesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: const Text(
          'Service Categories',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontFamily: 'PlayfairDisplay',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: categoriesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37))),
            ),
            error: (err, stack) => Center(child: Text('Error loading categories', style: const TextStyle(color: Colors.red))),
            data: (categories) {
              if (categories.isEmpty) {
                return const Center(child: Text('No categories found', style: TextStyle(color: Colors.grey)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final item = _CategoryItem(
                    name: cat.name,
                    icon: getCategoryIcon(cat.iconName),
                    tagline: cat.tagline.isNotEmpty ? cat.tagline : 'Explore ${cat.name}',
                    description: cat.description.isNotEmpty ? cat.description : 'Find the best ${cat.name.toLowerCase()} for your special day.',
                  );
                  return _buildCategoryCard(context, item);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, _CategoryItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          context.push('/consumer/category/${item.name}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D103E).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: const Color(0xFF2D103E), size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D103E),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFD4AF37)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.tagline,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryItem {
  final String name;
  final IconData icon;
  final String tagline;
  final String description;

  _CategoryItem({
    required this.name,
    required this.icon,
    required this.tagline,
    required this.description,
  });
}

class TopPicksScreen extends ConsumerWidget {
  const TopPicksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(filteredVendorsProvider);
    final savedIds = ref.watch(savedVendorsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: const Text(
          'Top Picks for You',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontFamily: 'PlayfairDisplay',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: vendorsAsync.when(
            data: (vendors) {
              if (vendors.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No top picks available right now.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: vendors.length,
                itemBuilder: (context, index) {
                  final vendor = vendors[index];
                  final isSaved = savedIds.contains(vendor.id);
                  
                  return _buildTopPickVendorCard(context, ref, vendor, isSaved);
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            ),
            error: (e, s) => Center(
              child: Text(
                'Error loading top picks: $e',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopPickVendorCard(BuildContext context, WidgetRef ref, Vendor vendor, bool isSaved) {
    final heroImage = vendor.images.isNotEmpty ? vendor.images.first : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push('/consumer/vendor_detail', extra: vendor),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: heroImage.isNotEmpty
                        ? Image.network(
                            heroImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.storefront, size: 48, color: Colors.grey),
                          ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isSaved ? Icons.favorite : Icons.favorite_border,
                        color: isSaved ? Colors.red : Colors.white,
                      ),
                      onPressed: () => ref.read(savedVendorsProvider.notifier).toggleSaved(vendor.id),
                    ),
                  ),
                ),

              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    vendor.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D103E),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                VendorBadge(tier: vendor.subscriptionTier),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D103E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                vendor.category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D103E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            vendor.rating,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vendor.location,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    vendor.description,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(translationProvider);
    final selectedLanguage = ref.watch(languageProvider);
    final authState = ref.watch(authProvider);
    final bool isGuest = !authState.isAuthenticated;
    final String? userRole = authState.role;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: Text(
          tr('Settings'),
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontFamily: 'PlayfairDisplay',
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // --- Account Section ---
              _buildSectionHeader(tr('ACCOUNT')),
              const SizedBox(height: 8),
              if (isGuest) ...[
                // Guest: Show sign-in banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2D103E), Color(0xFF4C1D66)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D103E).withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_outline, color: Color(0xFFD4AF37), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('Browsing as Guest'),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tr('Limited access mode'),
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('Sign in to save vendors, manage bookings, access your ledger, and get personalized recommendations.'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => context.go('/auth?role=consumer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                foregroundColor: const Color(0xFF2D103E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                              ),
                              child: Text(tr('Sign In'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => context.go('/auth?role=consumer'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(tr('Create Account'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Authenticated: Show account info card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/consumer/profile_details'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                child: const Icon(Icons.person, color: Color(0xFFD4AF37), size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      authState.displayName ?? authState.email ?? 'User',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D103E)),
                                    ),
                                    if (authState.email != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        authState.email!,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2D103E).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        tr((userRole ?? 'consumer').toUpperCase()),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2D103E), letterSpacing: 1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Color(0xFFD4AF37), size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        leading: const Icon(Icons.credit_card_rounded, color: Color(0xFFD4AF37)),
                        title: const Text('Saved Payment Cards', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                        subtitle: const Text('Manage your saved credit & debit cards', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
                        onTap: () => context.push('/consumer/saved_cards'),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // --- Preferences Section ---
              _buildSectionHeader(tr('PREFERENCES')),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(tr('Push Notifications'), style: const TextStyle(fontSize: 15)),
                          subtitle: Text(tr('Receive updates about vendors & bookings'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          secondary: const Icon(Icons.notifications_active_outlined, color: Color(0xFF2D103E)),
                          value: true,
                          activeThumbColor: const Color(0xFFD4AF37),
                          onChanged: (val) {},
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- Portal Access Section (Only for authenticated users with proper role) ---
              if (!isGuest && (userRole == 'vendor' || userRole == 'admin')) ...[
                const SizedBox(height: 28),
                _buildSectionHeader(tr('PORTAL ACCESS')),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          if (userRole == 'vendor')
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.storefront, color: Color(0xFFD4AF37), size: 22),
                              ),
                              title: Text(tr('Switch to Vendor Panel'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              subtitle: Text(tr('Manage your vendor dashboard'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
                              onTap: () {
                                final cat = authState.category?.toLowerCase() ?? '';
                                if (cat == 'venues') {
                                  context.go('/venue_portal');
                                } else if (cat == 'catering' || cat == 'caters' || cat == 'caterer' || cat == 'caterers') {
                                  context.go('/cater_portal');
                                } else {
                                  context.go('/vendor');
                                }
                              },
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          if (userRole == 'vendor' && userRole == 'admin')
                            const Divider(height: 1, indent: 56),
                          if (userRole == 'admin')
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D103E).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.admin_panel_settings, color: Color(0xFF2D103E), size: 22),
                              ),
                              title: Text(tr('Switch to Admin Panel'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              subtitle: Text(tr('Access admin controls'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
                              onTap: () => context.go('/admin'),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // --- System Section ---
              _buildSectionHeader(tr('SYSTEM')),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.info_outline, color: Color(0xFF2D103E)),
                          title: Text(tr('About ShadiSphere'), style: const TextStyle(fontSize: 15)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Row(
                                  children: [
                                    const Icon(Icons.info, color: Color(0xFFD4AF37)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(tr('About ShadiSphere'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontSize: 18))),
                                  ],
                                ),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Platform Overview',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD4AF37)),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'ShaadiSphere is an innovative, mobile-first platform designed to modernize and streamline the coordination of traditional Pakistani weddings. By replacing chaotic group chats and physical notebooks with a centralized, real-time ecosystem, it allows multiple family members to collaborate seamlessly using a shared workspace. The application leverages an advanced AI intelligence core, utilizing the Google Gemini API to offer conversational planning advice, dynamic budget optimization based on regional metrics, and customized digital invitation generation. Furthermore, ShaadiSphere guarantees a premium, minimalist user experience while ensuring robust security through secure payment escrow and encrypted transactions. This comprehensive solution not only simplifies vendor discovery and booking but also provides intelligent safeguards, ensuring that families can plan their events with confidence, efficiency, and cultural authenticity.',
                                        style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Standout Features',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD4AF37)),
                                      ),
                                      const SizedBox(height: 8),
                                      RichText(
                                        text: const TextSpan(
                                          style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
                                          children: [
                                            TextSpan(text: '• AI-Powered Intelligence: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                                            TextSpan(text: 'Features an NLP chatbot with a localized "Baraati" personality, alongside an AI estimator that predicts expenses and optimizes budgets in PKR.\n\n'),
                                            TextSpan(text: '• Real-Time Collaboration: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                                            TextSpan(text: 'Utilizes Firebase to instantly sync checklists, budgets, and assignments across all joined family members\' devices in under 300 milliseconds.\n\n'),
                                            TextSpan(text: '• Secure Vendor Marketplace: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                                            TextSpan(text: 'Connects users with verified vendors (like banquet halls and photographers) through a secure booking and escrow payment workflow.\n\n'),
                                            TextSpan(text: '• Emergency Backup Protocol: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                                            TextSpan(text: 'Automatically queries and presents three alternative vendors if a booked vendor cancels within 7 days of the scheduled event.\n\n'),
                                            TextSpan(text: '• Smart Catering Calculator: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                                            TextSpan(text: 'Prevents food shortages and waste by automatically calculating plate counts with a 10% safety buffer based on confirmed RSVPs.'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(tr('Close'), style: const TextStyle(color: Color(0xFF2D103E), fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF2D103E)),
                          title: Text(tr('Privacy Policy'), style: const TextStyle(fontSize: 15)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () => _showLegalDocument(context, 'Privacy Policy', 'privacy'),
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.description_outlined, color: Color(0xFF2D103E)),
                          title: Text(tr('Terms of Service'), style: const TextStyle(fontSize: 15)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () => _showLegalDocument(context, 'Terms of Service', 'terms'),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // --- Log Out / Back to Welcome ---
              if (!isGuest)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: Text(tr('Log Out'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 15)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.red),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text(tr('Confirm Log Out'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                              content: Text(tr('Are you sure you want to log out from ShadiSphere?')),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text(tr('Cancel'), style: const TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () async {
                                    await ref.read(authProvider.notifier).signOut();
                                    if (context.mounted) {
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Logged out successfully!')),
                                      );
                                      context.go('/welcome');
                                    }
                                  },
                                  child: const Text('Log Out'),
                                ),
                              ],
                            ),
                          );
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        leading: Icon(Icons.arrow_back, color: Colors.grey.shade600),
                        title: Text('Back to Welcome', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 15)),
                        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                        onTap: () => context.go('/welcome'),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // --- Version Footer ---
              Center(
                child: Text(
                  'ShadiSphere v1.0.0',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  void _showLegalDocument(BuildContext context, String title, String docType) {
    final List<Map<String, dynamic>> sections = docType == 'privacy'
        ? [
            {
              'title': '1. Introduction',
              'content':
                  'At ShadiSphere, we value the trust you place in us to plan one of the most important days of your life. This Privacy Policy details how we collect, use, and protect your personal information when utilizing our collaborative marketplace.',
            },
            {
              'title': '2. Information We Collect',
              'content':
                  'We collect information that you directly provide to us to customize your wedding planning journey:\n\n'
                  '• Account Profile: Name, email address, password, role preferences.\n'
                  '• Collaborative Ledger: Expense tracking, categories, and logs of actions taken.\n'
                  '• Booking Requests: Inquiry details, event dates, and messages shared between consumers and vendors.'
            },
            {
              'title': '3. How We Use Your Data',
              'content': 'We process your information under the following guidelines:\n\n'
                  '• To manage and synchronize the Shared Event Ledger in real-time.\n'
                  '• To power the smart AI Planner for relevant local vendor suggestions.\n'
                  '• To route booking inquiries directly to your selected wedding vendors.'
            },
            {
              'title': '4. Data Sharing & Security',
              'content':
                  'We do not sell or trade your personal data. We implement technical and administrative safeguards using secure cloud architectures. Note that sharing your ledger join code grants collaborative access to anyone who inputs it.'
            },
          ]
        : [
            {
              'title': '1. Acceptance of Terms',
              'content':
                  'By accessing or using the ShadiSphere mobile app, you agree to comply with and be bound by these Terms of Service. If you do not agree to these terms, you must not use or access the services.',
            },
            {
              'title': '2. Scope of Services',
              'content':
                  'ShadiSphere operates as a matching and co-planning marketplace. We do not provide physical venue rental, catering, photography, or other physical vendor services. All agreements are made directly between consumers and third-party vendors.',
            },
            {
              'title': '3. User Accounts',
              'content':
                  'You must register an account and maintain the confidentiality of your credentials. You are entirely responsible for all activities and booking inquiries submitted under your account.',
            },
            {
              'title': '4. Collaborative Ledger',
              'content':
                  'The Shared Event Ledger generates collaborative access codes (SS-XXX-XXX). Any user who joins a ledger with a valid code receives full read/write edit permissions. Protect your code; ShadiSphere is not responsible for changes made by invited members.',
            },
            {
              'title': '5. Limitation of Liability',
              'content':
                  'ShadiSphere is provided on an "as is" basis. We do not guarantee vendor performance or availability. ShadiSphere will not be liable for any disputes, service failures, or financial transactions between users.',
            },
          ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(docType == 'privacy' ? Icons.privacy_tip_outlined : Icons.description_outlined, color: const Color(0xFFD4AF37)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: sections.map((section) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section['title']!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD4AF37)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      section['content']!,
                      style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF2D103E), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: const Text('Notifications', style: TextStyle(color: Color(0xFFD4AF37))),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              ref.read(notificationsServiceProvider)?.markAllAsRead();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All marked as read')));
            },
          ),
        ],
      ),
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: Builder(
            builder: (context) {
              final notifications = notificationsAsync.value;
              if (notificationsAsync.isLoading && notifications == null) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
              }
              if (notificationsAsync.hasError && notifications == null) {
                return Center(child: Text('Error: ${notificationsAsync.error}', style: const TextStyle(color: Colors.red)));
              }
              final data = notifications ?? [];
              if (data.isEmpty) {
                return const Center(child: Text('No notifications right now.', style: TextStyle(color: Colors.grey)));
              }
              return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final note = data[index];
                    return Dismissible(
                      key: Key(note.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        ref.read(notificationsServiceProvider)?.deleteNotification(note.id);
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: note.isRead ? 1 : 4,
                        color: note.isRead ? Colors.white : const Color(0xFFF0E5D8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications, color: Color(0xFFD4AF37)),
                          ),
                          title: Text(
                            note.title,
                            style: TextStyle(
                              fontWeight: note.isRead ? FontWeight.normal : FontWeight.bold,
                              color: note.isRead ? Colors.black87 : Colors.black,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(note.message, style: TextStyle(color: Colors.grey.shade700)),
                              const SizedBox(height: 8),
                              Text(
                                '${note.time.hour}:${note.time.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          onTap: () {
                            if (!note.isRead) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(note.title, style: const TextStyle(color: Color(0xFF2D103E), fontWeight: FontWeight.bold)),
                                  content: Text(note.message, style: const TextStyle(height: 1.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        ref.read(notificationsServiceProvider)?.markAsRead(note.id);
                                      },
                                      child: const Text('Close', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          trailing: note.isRead
                              ? null
                              : Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD4AF37),
                                    shape: BoxShape.circle,
                                  ),
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

// Legacy guide/carousel data has been moved to consumer_providers.dart
// as defaultAppGuides and defaultAppBanners. Data is now served from Firestore.

class PremiumFeaturedCarousel extends ConsumerStatefulWidget {
  const PremiumFeaturedCarousel({super.key});

  @override
  ConsumerState<PremiumFeaturedCarousel> createState() => _PremiumFeaturedCarouselState();
}

class _PremiumFeaturedCarouselState extends ConsumerState<PremiumFeaturedCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      final banners = ref.read(appBannersProvider).value ?? defaultAppBanners;
      if (_pageController.hasClients && banners.isNotEmpty) {
        int nextPage = _currentPage + 1;
        if (nextPage >= banners.length) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(appBannersProvider);
    final banners = bannersAsync.value ?? defaultAppBanners;

    if (banners.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: banners.length,
              itemBuilder: (context, index) {
                final item = banners[index];
                return GestureDetector(
                  onTap: () {
                    context.push('/consumer/category/${item.linkCategory}');
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF2D103E),
                          child: const Icon(Icons.celebration, color: Color(0xFFD4AF37), size: 50),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.3, 1.0],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.tag,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              bottom: 12,
              left: 20,
              child: Row(
                children: List.generate(banners.length, (index) {
                  final isActive = _currentPage == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 6),
                    height: 6,
                    width: isActive ? 18 : 6,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFD4AF37) : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumSearchBar extends ConsumerStatefulWidget {
  const PremiumSearchBar({super.key});

  @override
  ConsumerState<PremiumSearchBar> createState() => _PremiumSearchBarState();
}

class _PremiumSearchBarState extends ConsumerState<PremiumSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.text = ref.read(searchQueryProvider);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(searchQueryProvider, (previous, next) {
      if (next != _controller.text) {
        _controller.text = next;
      }
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFF0E5D8), width: 1.0),
      ),
      child: TextField(
        controller: _controller,
        onChanged: (val) {
          ref.read(searchQueryProvider.notifier).setQuery(val);
        },
        decoration: InputDecoration(
          icon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _controller.clear();
                    ref.read(searchQueryProvider.notifier).clear();
                  },
                  child: const Icon(Icons.clear, color: Colors.grey, size: 20),
                )
              : null,
          hintText: 'Search vendors, venues, guides...',
          border: InputBorder.none,
          hintStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

class FeedbackDialog extends ConsumerStatefulWidget {
  const FeedbackDialog({super.key});

  @override
  ConsumerState<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<FeedbackDialog> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  void _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    await ref.read(authProvider.notifier).submitPlatformFeedback(_rating, _commentController.text);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you! Your feedback helps us improve.'),
          backgroundColor: Color(0xFF2D103E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.rate_review, color: Color(0xFFD4AF37), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Share Feedback',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D103E),
                fontFamily: 'PlayfairDisplay',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'How was your experience using ShadiSphere?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  iconSize: 36,
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFD4AF37),
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tell us more (optional)',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: _isSubmitting
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: const Color(0xFF2D103E),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _submit,
                      child: const Text(
                        'Submit Feedback',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeaserView extends ConsumerWidget {
  const TeaserView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teasersAsync = ref.watch(featureTeasersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sneak Peek',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontFamily: 'PlayfairDisplay',
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: teasersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
          ),
          error: (e, st) => Center(
            child: Text('Error loading teasers: $e', style: const TextStyle(color: Colors.red)),
          ),
          data: (activeTeasers) {
            if (activeTeasers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D103E).withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, size: 64, color: Color(0xFFD4AF37)),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Exciting Features Coming Soon',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D103E),
                          fontFamily: 'PlayfairDisplay',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Our team is crafting brand new experiences for your special events. Check back soon for exclusive updates!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: activeTeasers.length,
              itemBuilder: (context, index) {
                final teaser = activeTeasers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (teaser.imageUrl.isNotEmpty)
                        Stack(
                          children: [
                            teaser.imageUrl.startsWith('base64:')
                                ? Image.memory(
                                    base64Decode(teaser.imageUrl.substring(7)),
                                    height: 230,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 180,
                                      color: const Color(0xFF2D103E).withValues(alpha: 0.05),
                                      child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                                    ),
                                  )
                                : Image.network(
                                    teaser.imageUrl,
                                    height: 230,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 180,
                                      color: const Color(0xFF2D103E).withValues(alpha: 0.05),
                                      child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                                    ),
                                  ),
                            // Gradient Overlay at bottom of image
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            // Floating Coming Soon Badge
                            Positioned(
                              top: 14,
                              left: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D103E).withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'COMING SOON',
                                      style: TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (teaser.imageUrl.isEmpty) ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'SNEAK PEEK',
                                          style: TextStyle(
                                            color: Color(0xFF2D103E),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              teaser.text,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D103E),
                                fontFamily: 'PlayfairDisplay',
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Divider(color: Colors.grey.shade200, height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.stars_rounded, color: Color(0xFFD4AF37), size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Exclusive Preview',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2D103E).withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Stay Tuned',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D103E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  ConsumerState<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      _nameController.text = authState.displayName ?? '';
      _cityController.text = authState.city ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: const Text(
          'Profile Details',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontFamily: 'PlayfairDisplay',
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildLabel('Email (Read-only)'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    authState.email ?? 'No email associated',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildLabel('Full Name'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildLabel('City'),
                const SizedBox(height: 8),
                TextField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    hintText: 'Enter your city',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_nameController.text.isNotEmpty) {
                        await ref.read(authProvider.notifier).updateUserName(_nameController.text);
                      }
                      if (_cityController.text.isNotEmpty) {
                        await ref.read(authProvider.notifier).updateUserCity(_cityController.text);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile updated successfully!')),
                        );
                        context.pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Color(0xFF2D103E),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF2D103E),
        letterSpacing: 0.5,
      ),
    );
  }
}

// ======================================================================
// Vendor Replies Screen
// ======================================================================
class VendorRepliesScreen extends ConsumerWidget {
  const VendorRepliesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repliesAsync = ref.watch(vendorRepliesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: const Text('Vendor Replies', style: TextStyle(color: Color(0xFFD4AF37))),
      ),
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: Builder(
            builder: (context) {
              final replies = repliesAsync.value;
              if (repliesAsync.isLoading && replies == null) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
              }
              if (repliesAsync.hasError && replies == null) {
                return Center(child: Text('Error: ${repliesAsync.error}', style: const TextStyle(color: Colors.red)));
              }
              
              final data = replies ?? [];
              if (data.isEmpty) {
                return const Center(
                  child: Text('No replies from vendors yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final msg = data[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Message:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(msg.lastMessage, style: const TextStyle(fontSize: 14)),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.reply, size: 16, color: Color(0xFFD4AF37)),
                            const SizedBox(width: 6),
                            const Text('Vendor Reply:', style: TextStyle(color: Color(0xFF2D103E), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(msg.vendorReply ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF2D103E))),
                        const SizedBox(height: 12),
                        Text(msg.date, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
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

class _VendorCatalogSection extends ConsumerWidget {
  final Vendor vendor;
  final Map<String, dynamic> pData;
  final Function(VendorPackage) onAddPackage;

  const _VendorCatalogSection({
    required this.vendor,
    required this.pData,
    required this.onAddPackage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<VendorPackage> packagesList = [];
    List<Map<String, dynamic>> singleProductsList = [];

    final String cat = vendor.category.toLowerCase();
    final bool isCatererOrVenue = cat == 'catering' || cat == 'venue' || cat == 'venues' || cat.contains('venue');

    if (!isCatererOrVenue && pData['singleProducts'] != null && pData['singleProducts'] is List) {
      final list = pData['singleProducts'] as List;
      for (var item in list) {
        if (item is Map) {
          singleProductsList.add(Map<String, dynamic>.from(item));
        }
      }
    }

    // 1. Check Firestore vendor document for cateringPackages
    if (pData['cateringPackages'] != null && pData['cateringPackages'] is List) {
      final list = pData['cateringPackages'] as List;
      for (var item in list) {
        if (item is Map) {
          final name = item['name']?.toString() ?? 'Unnamed Package';
          final priceVal = item['pricePerPlate'] ?? item['price'] ?? 0;
          final minGuests = item['minGuests'] ?? 1;

          List<String> bulletItems = [];
          if (item['items'] is List) {
            bulletItems = List<String>.from(item['items']);
          } else if (item['description'] != null) {
            bulletItems = item['description'].toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          }

          String descStr = bulletItems.isNotEmpty
              ? bulletItems.map((it) => '• $it').join('\n')
              : (item['description']?.toString() ?? '');

          packagesList.add(VendorPackage(
            id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            price: priceVal.toString(),
            pricingUnit: 'plate (Min $minGuests Guests)',
            description: descStr,
            imageUrl: '',
            vendorId: vendor.id,
          ));
        }
      }
    }

    // 2. Check Firestore vendor document for generic servicePackages
    if (pData['servicePackages'] != null && pData['servicePackages'] is List) {
      final list = pData['servicePackages'] as List;
      for (var item in list) {
        if (item is Map) {
          final name = item['name']?.toString() ?? 'Unnamed Package';
          final priceVal = item['price'] ?? 0;

          List<String> bulletItems = [];
          if (item['items'] is List) {
            bulletItems = List<String>.from(item['items']);
          } else if (item['description'] != null) {
            bulletItems = item['description'].toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          }

          String descStr = bulletItems.isNotEmpty
              ? bulletItems.map((it) => '• $it').join('\n')
              : (item['description']?.toString() ?? '');

          packagesList.add(VendorPackage(
            id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            price: priceVal.toString(),
            pricingUnit: 'package',
            description: descStr,
            imageUrl: item['imageUrl']?.toString() ?? '',
            vendorId: vendor.id,
          ));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (singleProductsList.isNotEmpty)
          _buildShowProductsUI(context, singleProductsList, onAddPackage),
        if (packagesList.isNotEmpty)
          _buildPackageUI(context, ref, packagesList),
        if (vendor.category.toLowerCase().contains('cater'))
          _buildCustomPackageButton(context),
      ],
    );
  }

  Widget _buildCustomPackageButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D103E), Color(0xFF4A1F66)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2D103E).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomPackageCreatorScreen(
                vendor: vendor,
                pData: pData,
              ),
            ),
          );
        },
        icon: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFD4AF37), size: 20),
        label: const Text(
          'Make a Custom Package',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD4AF37), letterSpacing: 0.3),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFFD4AF37),
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildShowProductsUI(BuildContext context, List<Map<String, dynamic>> products, Function(VendorPackage) onAdd) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Individual Products',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D103E),
                fontFamily: 'PlayfairDisplay',
              ),
            ),
            Text(
              '${products.length} Available',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showProductsModal(context, products, onAdd),
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: Text('Show Products (${products.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2D103E),
              side: const BorderSide(color: Color(0xFF2D103E), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showProductsModal(BuildContext context, List<Map<String, dynamic>> products, Function(VendorPackage) onAdd) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAF5EC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Products & Services',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D103E),
                          fontFamily: 'PlayfairDisplay',
                        ),
                      ),
                      Text(
                        '${products.length} Items',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    itemCount: products.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final p = products[index];
                      final name = p['name']?.toString() ?? 'Unnamed';
                      final price = p['price'] ?? 0;
                      final desc = p['description']?.toString() ?? '';
                      final imgUrl = p['imageUrl']?.toString() ?? '';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imgUrl.isNotEmpty)
                              Image.network(imgUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                            if (imgUrl.isEmpty)
                              Container(
                                height: 120,
                                width: double.infinity,
                                color: Colors.grey.shade200,
                                child: Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade400),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2D103E)))),
                                      Text('Rs. $price', style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(desc, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                                  ],
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        onAdd(VendorPackage(
                                          id: p['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                          name: name,
                                          price: price.toString(),
                                          pricingUnit: 'item',
                                          description: desc,
                                          imageUrl: imgUrl,
                                          vendorId: vendor.id,
                                        ));
                                      },
                                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                                      label: const Text('Add to Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2D103E),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildPackageUI(BuildContext context, WidgetRef ref, List<VendorPackage> packages) {
    // Show max 2 packages in main detail view
    final displayedPackages = packages.take(2).toList();
    final hasMore = packages.length > 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Packages',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D103E),
                fontFamily: 'PlayfairDisplay',
              ),
            ),
            Text(
              '${packages.length} Available',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 14),

        ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayedPackages.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final pkg = displayedPackages[index];
            return _buildPackageCard(context, pkg);
          },
        ),

        if (hasMore) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAllPackagesModal(context, packages),
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              label: Text('See More Packages (${packages.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2D103E),
                side: const BorderSide(color: Color(0xFF2D103E), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPackageCard(BuildContext context, VendorPackage pkg) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pkg.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D103E)),
              ),
              const SizedBox(height: 6),
              Text(
                'PKR ${pkg.price}${pkg.pricingUnit.isNotEmpty ? ' / ${pkg.pricingUnit}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD4AF37), fontSize: 13.5),
              ),
            ],
          ),
          if (pkg.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              pkg.description,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onAddPackage(pkg),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add to Ledger'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2D103E),
                side: const BorderSide(color: Color(0xFF2D103E)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllPackagesModal(BuildContext context, List<VendorPackage> packages) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFFAF5EC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'All Packages (${vendor.name})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: packages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildPackageCard(ctx, packages[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// CUSTOM CATERING PACKAGE CREATOR SCREEN
// ======================================================================
class CustomPackageCreatorScreen extends ConsumerStatefulWidget {
  final Vendor vendor;
  final Map<String, dynamic> pData;

  const CustomPackageCreatorScreen({
    super.key,
    required this.vendor,
    required this.pData,
  });

  @override
  ConsumerState<CustomPackageCreatorScreen> createState() => _CustomPackageCreatorScreenState();
}

class _CustomPackageCreatorScreenState extends ConsumerState<CustomPackageCreatorScreen> {
  final List<CateringDishItem> _dishes = [];
  final Map<String, int> _selectedQuantities = {};
  final Set<String> _selectedDishIds = {};
  final TextEditingController _dateCtrl = TextEditingController();
  DateTime? _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  void _loadDishes() {
    if (widget.pData['cateringDishes'] != null && widget.pData['cateringDishes'] is List) {
      final list = widget.pData['cateringDishes'] as List;
      for (var d in list) {
        if (d is Map) {
          _dishes.add(CateringDishItem(
            id: d['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: d['name']?.toString() ?? '',
            pricePerPlate: (d['pricePerPlate'] as num?)?.toDouble() ?? 0.0,
            minQuantity: (d['minQuantity'] as num?)?.toInt() ?? 20,
            category: d['category']?.toString() ?? 'Main Course',
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  double get _totalPrice {
    double total = 0.0;
    for (var dishId in _selectedDishIds) {
      final dish = _dishes.firstWhere((d) => d.id == dishId);
      final qty = _selectedQuantities[dishId] ?? dish.minQuantity;
      total += (dish.pricePerPlate * qty);
    }
    return total;
  }

  int get _maxGuests {
    int maxG = 0;
    for (var dishId in _selectedDishIds) {
      final dish = _dishes.firstWhere((d) => d.id == dishId);
      final qty = _selectedQuantities[dishId] ?? dish.minQuantity;
      if (qty > maxG) maxG = qty;
    }
    return maxG;
  }

  Future<void> _pickEventDate() async {
    Set<String> blockedDates = {};
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final doc = await FirebaseFirestore.instance.collection('vendor_availability').doc(widget.vendor.id).get();
      if (doc.exists && doc.data() != null) {
        final days = doc.data()!['days'] as List<dynamic>? ?? [];
        for (var d in days) {
          if (d is Map && d['isBlocked'] == true && d['date'] != null) {
            final norm = normalizeSingleDate(d['date'].toString());
            final note = d['note']?.toString().toLowerCase() ?? '';
            final isBookingAutoBlock = note.contains('booked');
            // Only block dates explicitly blocked by the vendor in their availability screen
            if (!isBookingAutoBlock && norm != null && norm.compareTo(todayStr) >= 0) {
              blockedDates.add(norm);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching availability: $e");
    }

    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    
    DateTime initial = _selectedDate ?? firstDate;
    while (blockedDates.contains(DateFormat('yyyy-MM-dd').format(initial))) {
      initial = initial.add(const Duration(days: 1));
      if (initial.difference(firstDate).inDays > 365) {
        initial = firstDate;
        break;
      }
    }

    if (!mounted) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 3650)),
      selectableDayPredicate: (DateTime date) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        return !blockedDates.contains(dateStr);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2D103E),
              onPrimary: Color(0xFFD4AF37),
              onSurface: Color(0xFF2D103E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = DateFormat('MMMM d, yyyy').format(picked);
      });
    }
  }

  Future<void> _addToLedger() async {
    if (_selectedDishIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one menu dish for your custom package.')),
      );
      return;
    }

    if (_selectedDate == null && _dateCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your Event Date on the calendar before adding to ledger.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authState = ref.read(authProvider);
      String ledgerCode = '';
      if (authState.isAuthenticated) {
        final uid = authState.userId ?? '';
        final displayName = authState.displayName ?? authState.email ?? 'User';
        try {
          ledgerCode = ref.read(activeLedgerCodeProvider);
          if (ledgerCode.isEmpty) {
            ledgerCode = await createLedgerForUser(uid, displayName);
            ref.read(activeLedgerCodeProvider.notifier).update(ledgerCode);
          }
        } catch (_) {}
      }

      final List<String> dishSummaryList = [];
      for (var dishId in _selectedDishIds) {
        final dish = _dishes.firstWhere((d) => d.id == dishId);
        final qty = _selectedQuantities[dishId] ?? dish.minQuantity;
        dishSummaryList.add('${dish.name} (${qty} pers @ Rs. ${dish.pricePerPlate.toStringAsFixed(0)}/plate)');
      }

      final dateStr = _dateCtrl.text.trim();

      await addLedgerItem(
        'Catering',
        '${widget.vendor.name} (Custom Package)',
        _totalPrice,
        ledgerCode: ledgerCode,
        addedBy: authState.userId ?? '',
        addedByName: authState.displayName ?? authState.email ?? 'User',
        vendorId: widget.vendor.id,
        eventDate: dateStr,
        notes: 'Custom Package Menu:\n${dishSummaryList.map((s) => '• $s').join('\n')}',
        numberOfGuests: _maxGuests,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF064E3B),
            content: Text('Custom Catering Package added to Ledger! Total: PKR ${_totalPrice.toStringAsFixed(0)}'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding custom package to ledger: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Make Custom Package', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37), fontFamily: 'PlayfairDisplay')),
            Text(widget.vendor.name, style: TextStyle(fontSize: 12, color: const Color(0xFF2D103E).withValues(alpha: 0.7))),
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner Notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: const Color(0xFF2D103E).withValues(alpha: 0.06),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF2D103E), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Select dish items, specify guest quantity & pick your event date. Min order quantity set by vendor is enforced.',
                    style: TextStyle(color: Color(0xFF2D103E), fontSize: 12, height: 1.3, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Dish Items List
                if (_dishes.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.restaurant_outlined, color: Colors.grey, size: 40),
                        SizedBox(height: 10),
                        Text('No menu items listed by this caterer yet.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontSize: 14)),
                        SizedBox(height: 4),
                        Text('This vendor has not added signature dishes to their profile.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  )
                else
                  ..._dishes.map((dish) {
                    final isSelected = _selectedDishIds.contains(dish.id);
                    final currentQty = _selectedQuantities[dish.id] ?? dish.minQuantity;
                    final itemTotal = dish.pricePerPlate * currentQty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFD4AF37) : Colors.grey.shade200,
                          width: isSelected ? 1.8 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                activeColor: const Color(0xFF2D103E),
                                checkColor: const Color(0xFFD4AF37),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedDishIds.add(dish.id);
                                      if (!_selectedQuantities.containsKey(dish.id)) {
                                        _selectedQuantities[dish.id] = dish.minQuantity;
                                      }
                                    } else {
                                      _selectedDishIds.remove(dish.id);
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      children: [
                                        Text(dish.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D103E))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(dish.category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text('Rs. ${dish.pricePerPlate.toStringAsFixed(0)} / plate', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD4AF37), fontSize: 13)),
                                        const SizedBox(width: 8),
                                        Text('• Min: ${dish.minQuantity} Persons', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Text('Rs. ${itemTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2D103E), fontSize: 14)),
                            ],
                          ),

                          if (isSelected) ...[
                            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Colors.grey.shade200)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('Guest Quantity (Min: ${dish.minQuantity})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF5EC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 16, color: Color(0xFF2D103E)),
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          if (currentQty <= dish.minQuantity) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                duration: const Duration(seconds: 2),
                                                content: Text('Minimum order quantity set by vendor is ${dish.minQuantity} persons for ${dish.name}.'),
                                              ),
                                            );
                                          } else {
                                            setState(() {
                                              _selectedQuantities[dish.id] = currentQty - 10 < dish.minQuantity ? dish.minQuantity : currentQty - 10;
                                            });
                                          }
                                        },
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Text('$currentQty Guests', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2D103E))),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 16, color: Color(0xFF2D103E)),
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          setState(() {
                                            _selectedQuantities[dish.id] = currentQty + 10;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 10),

                // Event Date Picker Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EVENT DATE (SELECT ON CALENDAR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2D103E), letterSpacing: 0.8)),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _pickEventDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5EC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, color: Color(0xFFD4AF37), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _dateCtrl.text.isNotEmpty ? _dateCtrl.text : 'Tap to open calendar & choose date...',
                                  style: TextStyle(
                                    fontWeight: _dateCtrl.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                    color: _dateCtrl.text.isNotEmpty ? const Color(0xFF2D103E) : Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFFD4AF37)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),

          // Bottom Bar Total & Action
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_selectedDishIds.length} Dishes Selected', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('PKR ${_totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2D103E))),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _addToLedger,
                        icon: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFFD4AF37), strokeWidth: 2))
                            : const Icon(Icons.note_add_rounded, size: 20),
                        label: Text(_isSaving ? 'Adding...' : 'Add to Ledger', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D103E),
                          foregroundColor: const Color(0xFFD4AF37),
                          elevation: 3,
                          shadowColor: const Color(0xFF2D103E).withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DealsAndPromotionsSection extends ConsumerWidget {
  const _DealsAndPromotionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promosAsync = ref.watch(cityFilteredPromotionsProvider);

    return promosAsync.when(
      data: (promos) {
        if (promos.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deals & Promotions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: promos.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final promo = promos[index];
                  return GestureDetector(
                    onTap: () => _showPromotionLedgerDialog(context, ref, promo),
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2D103E), Color(0xFF4A1F66)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                promo.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                promo.description,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  const Icon(Icons.local_offer, color: Color(0xFFD4AF37), size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Valid till ${promo.endDate}',
                                    style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${promo.discountPercent}% OFF',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }

  void _showPromotionLedgerDialog(BuildContext context, WidgetRef ref, ConsumerVendorPromotion promo) {
    final dateCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    notesCtrl.text = 'Promotion Attached: ${promo.title} (${promo.discountPercent}% OFF)\n\n${promo.description}';
    final guestsCtrl = TextEditingController();
    final authState = ref.read(authProvider);

    final vendors = ref.read(allVendorsProvider).value ?? [];
    final vendor = vendors.firstWhere(
      (v) => v.id == promo.vendorId,
      orElse: () => Vendor(id: '', name: 'Unknown Vendor', category: 'Other', location: '', rating: '', imagePlaceholder: '', images: [], description: '', reviews: [], estimatedPrice: ''),
    );

    final bool showGuests = vendor.category.toLowerCase() == 'venues' || vendor.category.toLowerCase() == 'catering';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Promo to Ledger', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text('${vendor.name} - ${promo.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                            ],
                          ),
                          Text('${promo.discountPercent}% OFF Special Deal', style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: dateCtrl,
                readOnly: true,
                onTap: () async {
                  final now = DateTime.now();
                  final firstDate = DateTime(now.year, now.month, now.day);
                  final selected = await showDatePicker(
                    context: ctx,
                    initialDate: firstDate,
                    firstDate: firstDate,
                    lastDate: DateTime(now.year + 5),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF2D103E),
                            onPrimary: Colors.white,
                            onSurface: Color(0xFF2D103E),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (selected != null) {
                    dateCtrl.text = '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Select Event Date',
                  prefixIcon: const Icon(Icons.calendar_month, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (showGuests) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: guestsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Number of Guests',
                    prefixIcon: const Icon(Icons.people, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Any special requirements...',
                  prefixIcon: const Icon(Icons.notes, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D103E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (dateCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select an Event Date before adding to ledger.')),
                      );
                      return;
                    }

                    if (showGuests && guestsCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter the Number of Guests.')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    
                    String ledgerCode = '';
                    if (authState.isAuthenticated) {
                      final uid = authState.userId ?? '';
                      final displayName = authState.displayName ?? authState.email ?? 'User';
                      try {
                        ledgerCode = ref.read(activeLedgerCodeProvider);
                        if (ledgerCode.isEmpty) {
                          ledgerCode = await createLedgerForUser(uid, displayName);
                          ref.read(activeLedgerCodeProvider.notifier).update(ledgerCode);
                        }
                      } catch (_) {}
                    }

                    int? guests = int.tryParse(guestsCtrl.text.trim());

                    await addLedgerItem(
                      vendor.category,
                      '${vendor.name} (${promo.title})',
                      0.0, // default price for promo
                      ledgerCode: ledgerCode,
                      addedBy: authState.userId ?? '',
                      addedByName: authState.displayName ?? authState.email ?? 'User',
                      vendorId: vendor.id,
                      eventDate: dateCtrl.text.trim().isNotEmpty ? dateCtrl.text.trim() : null,
                      notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                      numberOfGuests: guests,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF2D103E),
                          content: Text('${promo.title} deal added to ledger!'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_task, color: Colors.white),
                  label: const Text('Add to Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// VENUE DATE PICKER SCREEN WITH DYNAMIC CALENDAR RATES
// ======================================================================

class VenueDatePickerScreen extends ConsumerStatefulWidget {
  final Vendor vendor;
  final Map<String, dynamic>? initialProfileData;

  const VenueDatePickerScreen({
    super.key,
    required this.vendor,
    this.initialProfileData,
  });

  @override
  ConsumerState<VenueDatePickerScreen> createState() => _VenueDatePickerScreenState();
}

class _VenueDatePickerScreenState extends ConsumerState<VenueDatePickerScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDate;
  double? _selectedPrice;
  bool _isBooking = false;

  String? _selectedBeverage;
  int _beverageQty = 1;
  final TextEditingController _beverageQtyCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _beverageQtyCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return 'Rs. ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  void _confirmBookingPopup(BuildContext context, double weekdayPrice, double weekendPrice, Map<String, dynamic> specialPrices, Map<String, dynamic> pData) {
    if (_selectedDate == null || _selectedPrice == null) return;

    double totalBevPrice = 0.0;
    if (_selectedBeverage != null && pData['beverages'] != null) {
      final bevMap = pData['beverages'] as Map<String, dynamic>;
      final bevPrice = double.tryParse(bevMap[_selectedBeverage]?.toString() ?? '0') ?? 0.0;
      totalBevPrice = bevPrice * _beverageQty;
    }

    final totalPrice = _selectedPrice! + totalBevPrice;
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!);
    final priceStr = _formatCurrency(totalPrice);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.stars_rounded, color: Color(0xFFD4AF37), size: 28),
            SizedBox(width: 10),
            Text('Confirm Booking', style: TextStyle(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please confirm your date selection:',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5EC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.vendor.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 16, color: Color(0xFFD4AF37)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          formattedDate,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.payments_rounded, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        totalBevPrice > 0 ? 'Venue Rate: ${_formatCurrency(_selectedPrice!)}' : 'Total Rate: $priceStr',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                      ),
                    ],
                  ),
                  if (totalBevPrice > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.local_cafe_rounded, size: 16, color: Color(0xFFD4AF37)),
                        const SizedBox(width: 8),
                        Text(
                          'Beverages: ${_formatCurrency(totalBevPrice)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFD4AF37)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.functions_rounded, size: 16, color: Color(0xFF2D103E)),
                        const SizedBox(width: 8),
                        Text(
                          'Total Rate: $priceStr',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF2D103E)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You have picked $formattedDate and the price for this date is $priceStr. Do you confirm this date?',
              style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeBooking(_selectedDate!, totalPrice, pData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D103E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm Booking', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeBooking(DateTime date, double price, Map<String, dynamic> pData) async {
    setState(() => _isBooking = true);
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final dateDisplayStr = DateFormat('MMM d, yyyy').format(date);

    final bookedDates = ref.read(venueBookedDatesProvider(widget.vendor.id)).value ?? {};
    if (bookedDates.contains(formattedDate)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ This date has already been booked by another client! Please select a different date.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() => _isBooking = false);
      }
      return;
    }

    try {
      final auth = ref.read(authProvider);
      final consumerId = auth.userId ?? '';
      final displayName = auth.displayName ?? auth.email ?? 'User';

      String ledgerCode = ref.read(activeLedgerCodeProvider);
      if (ledgerCode.isEmpty) {
        final uid = consumerId.isNotEmpty ? consumerId : 'guest';
        try {
          ledgerCode = await createLedgerForUser(uid, displayName);
          ref.read(activeLedgerCodeProvider.notifier).update(ledgerCode);
        } catch (_) {}
      }

      await addLedgerItem(
        widget.vendor.category,
        '${widget.vendor.name} (Booked: $dateDisplayStr)',
        price,
        ledgerCode: ledgerCode,
        addedBy: consumerId,
        addedByName: displayName,
        vendorId: widget.vendor.id,
        eventDate: formattedDate,
        notes: 'Booked via Venue Dynamic Pricing Calendar ($dateDisplayStr)',
      );

      if (_selectedBeverage != null) {
        final Map<String, double> beverages = {};
        if (pData['beverages'] != null) {
          final bevMap = pData['beverages'] as Map<String, dynamic>;
          beverages.addAll(bevMap.map((key, value) => MapEntry(key, double.tryParse(value.toString()) ?? 0.0)));
        }
        
        final bevPrice = beverages[_selectedBeverage!] ?? 0.0;
        final totalBevPrice = bevPrice * _beverageQty;

        if (totalBevPrice > 0) {
          await addLedgerItem(
            'Beverage',
            '$_selectedBeverage (Qty: $_beverageQty)',
            totalBevPrice,
            ledgerCode: ledgerCode,
            addedBy: consumerId,
            addedByName: displayName,
            vendorId: widget.vendor.id,
            eventDate: formattedDate,
            notes: 'Beverage added for Venue Booking: $dateDisplayStr',
          );
        }
      }

      // Auto-block the date in Firestore vendor_availability
      try {
        await FirebaseFirestore.instance.collection('vendor_availability').doc(widget.vendor.id).set({
          'days': FieldValue.arrayUnion([
            {
              'date': formattedDate,
              'isBlocked': true,
              'note': 'Booked by $displayName',
            }
          ]),
        }, SetOptions(merge: true));
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Booking confirmed for $dateDisplayStr at ${_formatCurrency(price)}! Added to Ledger.'),
            backgroundColor: const Color(0xFF2D103E),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting booking: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Widget _buildRateInfoCard({
    required String label,
    required String subLabel,
    required String priceText,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subLabel, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(priceText, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBeautifulCalendarGrid(double weekdayPrice, double weekendPrice, Map<String, dynamic> specialPrices) {
    final bookedDatesAsync = ref.watch(venueBookedDatesProvider(widget.vendor.id));
    final bookedDates = bookedDatesAsync.value ?? {};

    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday; // 1=Mon, 7=Sun
    int emptyCells = startingWeekday % 7;

    final compactFormat = NumberFormat.compact();
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2D103E).withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Month Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2D103E), Color(0xFF4C1D66)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                  onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1)),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'PlayfairDisplay', letterSpacing: 1),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                  onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1)),
                ),
              ],
            ),
          ),
          // Days of Week Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFFFAF5EC),
            child: Row(
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((d) => 
                Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2D103E)))))
              ).toList(),
            ),
          ),
          const Divider(height: 1),
          // Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: emptyCells + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.78,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
            ),
            itemBuilder: (context, index) {
              if (index < emptyCells) return Container(color: Colors.grey.shade50);

              final dayNum = index - emptyCells + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
              final dateString = DateFormat('yyyy-MM-dd').format(date);

              final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
              final hasSpecialPrice = specialPrices.containsKey(dateString);
              final isPast = date.isBefore(todayMidnight);
              final isBooked = !isPast && bookedDates.contains(dateString);
              final isDisabled = isPast || isBooked;

              double displayPrice = weekdayPrice;
              if (hasSpecialPrice) {
                final spVal = specialPrices[dateString];
                displayPrice = spVal is num ? spVal.toDouble() : (double.tryParse(spVal.toString()) ?? weekdayPrice);
              } else if (isWeekend) {
                displayPrice = weekendPrice > 0 ? weekendPrice : weekdayPrice;
              }

              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == date.year &&
                  _selectedDate!.month == date.month &&
                  _selectedDate!.day == date.day;

              Color bgColor = Colors.white;
              if (isSelected) {
                bgColor = const Color(0xFF2D103E);
              } else if (isBooked) {
                bgColor = const Color(0xFFFFEBEE);
              } else if (hasSpecialPrice) {
                bgColor = const Color(0xFFFFFBEB);
              } else if (isWeekend) {
                bgColor = const Color(0xFFFAF5EC);
              }

              return Material(
                color: isPast ? Colors.grey.shade100 : bgColor,
                child: InkWell(
                  onTap: isDisabled
                      ? null
                      : () {
                          setState(() {
                            _selectedDate = date;
                            _selectedPrice = displayPrice;
                          });
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24, height: 24,
                          alignment: Alignment.center,
                          decoration: isSelected
                              ? const BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle)
                              : null,
                          child: Text(
                            '$dayNum',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isPast
                                  ? Colors.grey
                                  : (isBooked
                                      ? Colors.red.shade900
                                      : (isSelected ? Colors.white : (hasSpecialPrice ? Colors.red.shade700 : Colors.black87))),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isBooked)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'BOOKED',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          )
                        else if (!isDisabled && displayPrice > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white24
                                    : (hasSpecialPrice
                                        ? Colors.red.shade50
                                        : (isWeekend ? const Color(0xFFD4AF37).withValues(alpha: 0.15) : Colors.purple.shade50)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Rs.${compactFormat.format(displayPrice)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? const Color(0xFFF9E5B5)
                                      : (hasSpecialPrice
                                          ? Colors.red.shade700
                                          : (isWeekend ? const Color(0xFF856404) : const Color(0xFF2D103E))),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EC),
      appBar: AppBar(
        title: const Text('Pick Date & Book Venue', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D103E)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('vendor_profile').doc(widget.vendor.id).snapshots(),
        builder: (context, snapshot) {
          Map<String, dynamic> pData = widget.initialProfileData ?? {};
          if (snapshot.hasData && snapshot.data!.exists) {
            pData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          }

          final double weekdayPrice = double.tryParse(pData['price']?.toString() ?? '0') ?? 0.0;
          final double weekendPrice = double.tryParse(pData['weekendPrice']?.toString() ?? '0') ?? weekdayPrice;
          final Map<String, dynamic> specialPrices = (pData['specialPrices'] as Map<String, dynamic>?) ?? {};

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Venue Info Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF2D103E).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 60, height: 60,
                                color: Colors.grey.shade200,
                                child: widget.vendor.images.isNotEmpty
                                    ? Image.network(widget.vendor.images.first, fit: BoxFit.cover)
                                    : const Icon(Icons.storefront, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.vendor.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay')),
                                  const SizedBox(height: 4),
                                  Text(widget.vendor.location, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Beverages Selection
                      _buildBeverageSelection(pData),

                      // Rate Cards Summary
                      Row(
                        children: [
                          Expanded(
                            child: _buildRateInfoCard(
                              label: 'Weekday Rate',
                              subLabel: 'Mon - Thu',
                              priceText: weekdayPrice > 0 ? _formatCurrency(weekdayPrice) : 'Ask Vendor',
                              color: const Color(0xFF2D103E),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRateInfoCard(
                              label: 'Weekend Rate',
                              subLabel: 'Fri - Sun',
                              priceText: weekendPrice > 0 ? _formatCurrency(weekendPrice) : 'Ask Vendor',
                              color: const Color(0xFFD4AF37),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Calendar Legend
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildLegendDot(const Color(0xFF2D103E), 'Weekday'),
                            _buildLegendDot(const Color(0xFFD4AF37), 'Weekend'),
                            _buildLegendDot(Colors.red.shade700, 'Custom Price'),
                            _buildLegendDot(Colors.red.shade900, 'Booked'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Calendar Grid
                      _buildBeautifulCalendarGrid(weekdayPrice, weekendPrice, specialPrices),
                    ],
                  ),
                ),
              ),

              // Bottom Confirmation Action Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedDate != null && _selectedPrice != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D103E).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2D103E).withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_available, color: Color(0xFF2D103E), size: 22),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE, MMM d, yyyy').format(_selectedDate!),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D103E)),
                                  ),
                                  Text(
                                    'Rate: ${_formatCurrency(_selectedPrice!)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD4AF37)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: (_selectedDate == null || _isBooking)
                              ? null
                              : () => _confirmBookingPopup(context, weekdayPrice, weekendPrice, specialPrices, pData),
                          icon: _isBooking
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_rounded, color: Colors.white),
                          label: Text(
                            _selectedDate == null ? 'Select a Date on Calendar' : 'Confirm Booking',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D103E),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBeverageSelection(Map<String, dynamic> pData) {
    final Map<String, double> beverages = {};
    if (pData['beverages'] != null) {
      final bevMap = pData['beverages'] as Map<String, dynamic>;
      beverages.addAll(bevMap.map((key, value) => MapEntry(key, double.tryParse(value.toString()) ?? 0.0)));
    }

    if (beverages.isEmpty) return const SizedBox.shrink();

    // Ensure _selectedBeverage is valid if it was set previously
    if (_selectedBeverage != null && !beverages.containsKey(_selectedBeverage)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedBeverage = null);
      });
    }

    final double bevPrice = _selectedBeverage != null ? (beverages[_selectedBeverage!] ?? 0.0) : 0.0;
    final double totalBevPrice = bevPrice * _beverageQty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_cafe_rounded, color: Color(0xFFD4AF37), size: 22),
              const SizedBox(width: 8),
              const Text('Add Beverages (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay')),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: _selectedBeverage,
                hint: const Text('Select Beverage Type'),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF2D103E)),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...beverages.entries.map((entry) {
                    return DropdownMenuItem<String?>(
                      value: entry.key,
                      child: Text('${entry.key} - ${_formatCurrency(entry.value)}'),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedBeverage = val;
                    if (val == null) {
                      _beverageQty = 1;
                      _beverageQtyCtrl.text = '1';
                    }
                  });
                },
              ),
            ),
          ),
          if (_selectedBeverage != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Quantity:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D103E))),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _beverageQtyCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (val) {
                        final qty = int.tryParse(val) ?? 0;
                        setState(() {
                          _beverageQty = qty > 0 ? qty : 1;
                        });
                      },
                    ),
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Beverage Total', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(_formatCurrency(totalBevPrice), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFD4AF37))),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ======================================================================
// MAKE PAYMENT SCREEN (INSTANT UNIFIED CHECKOUT)
// ======================================================================

class MakePaymentScreen extends ConsumerStatefulWidget {
  final String ledgerCode;
  final List<LedgerItem> items;
  final double totalAmount;

  const MakePaymentScreen({
    super.key,
    required this.ledgerCode,
    required this.items,
    required this.totalAmount,
  });

  @override
  ConsumerState<MakePaymentScreen> createState() => _MakePaymentScreenState();
}

class _MakePaymentScreenState extends ConsumerState<MakePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(text: 'Ahmed Khan');
  final _numberCtrl = TextEditingController(text: '4532 8901 2345 6789');
  final _expiryCtrl = TextEditingController(text: '08/28');
  final _cvvCtrl = TextEditingController(text: '888');

  bool _saveCard = true;
  bool _isPaying = false;
  SavedCard? _selectedSavedCard;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  void _onSavedCardSelected(SavedCard card) {
    setState(() {
      _selectedSavedCard = card;
      _nameCtrl.text = card.cardholderName;
      _numberCtrl.text = card.maskedNumber;
      _expiryCtrl.text = card.expiryDate;
      _cvvCtrl.text = '•••';
    });
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isPaying = true);

    final auth = ref.read(authProvider);
    final uid = auth.userId ?? 'guest';
    final userName = auth.displayName ?? auth.email ?? 'Customer';
    final userEmail = auth.email ?? 'customer@shadisphere.com';

    try {
      final transactionId = await processLedgerCheckoutPayment(
        ledgerCode: widget.ledgerCode,
        uid: uid,
        userName: userName,
        userEmail: userEmail,
        items: widget.items,
        cardholderName: _nameCtrl.text.trim(),
        cardNumber: _numberCtrl.text.trim(),
        expiryDate: _expiryCtrl.text.trim(),
        cvv: _cvvCtrl.text.trim(),
        saveCard: _saveCard,
      );

      if (mounted) {
        setState(() => _isPaying = false);
        _showSuccessDialog(context, transactionId, userName, userEmail);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e')),
        );
      }
    }
  }

  void _showSuccessDialog(BuildContext context, String txnId, String userName, String userEmail) {
    final firstVendor = widget.items.isNotEmpty ? widget.items.first.vendorName : 'Selected Vendors';
    final formattedTotal = 'Rs. ${widget.totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

    final itemsMap = widget.items.map((i) => {
      'category': i.category,
      'vendorName': i.vendorName,
      'eventDate': i.eventDate ?? 'Flexible Date',
      'amount': i.amount,
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF5EC),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stars_rounded, color: Color(0xFFD4AF37), size: 54),
            ),
            const SizedBox(height: 16),
            const Text(
              '🎉 Payment Successful!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D103E),
                fontFamily: 'PlayfairDisplay',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Your payment of $formattedTotal for $firstVendor (${widget.items.length} item${widget.items.length > 1 ? "s" : ""}) has been processed and confirmed.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D103E).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transaction ID:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2D103E))),
                  Text(txnId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Receipt Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await PdfReceiptService.generateAndShareReceipt(
                    transactionId: txnId,
                    userName: userName,
                    userEmail: userEmail,
                    ledgerCode: widget.ledgerCode,
                    paymentMethod: 'Credit Card',
                    totalAmount: widget.totalAmount,
                    items: itemsMap,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                label: const Text('Save Receipt (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF2D103E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Done / Go to Bookings Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/consumer');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2D103E),
                  side: const BorderSide(color: Color(0xFF2D103E), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done / View Bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final uid = authState.userId ?? '';
    final savedCardsAsync = ref.watch(savedCardsProvider(uid));

    final formattedTotal = 'Rs. ${widget.totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EC),
      appBar: AppBar(
        title: const Text('Make Payment', style: TextStyle(color: Color(0xFF2D103E), fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D103E)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D103E), Color(0xFF4C1D66)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF2D103E).withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Payable Amount', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Icon(Icons.shield_outlined, color: Color(0xFFD4AF37), size: 20),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formattedTotal,
                      style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'PlayfairDisplay'),
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    Text(
                      '${widget.items.length} Item${widget.items.length > 1 ? "s" : ""} from Ledger (${widget.ledgerCode})',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...widget.items.map((i) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '• ${i.vendorName}', 
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatCurrency(i.amount), style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Saved Cards Selection (if available)
              savedCardsAsync.when(
                data: (cards) {
                  if (cards.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Use Saved Card', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: cards.length,
                          itemBuilder: (context, idx) {
                            final card = cards[idx];
                            final isSelected = _selectedSavedCard?.id == card.id;
                            return GestureDetector(
                              onTap: () => _onSavedCardSelected(card),
                              child: Container(
                                width: 220,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF2D103E) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isSelected ? const Color(0xFFD4AF37) : Colors.grey.shade300, width: isSelected ? 2 : 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(card.brand, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? const Color(0xFFD4AF37) : Colors.black87)),
                                        Icon(Icons.credit_card, size: 18, color: isSelected ? Colors.white : Colors.grey),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(card.maskedNumber, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const Text('Card Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D103E))),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Cardholder Name',
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFD4AF37)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter cardholder name' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _numberCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Card Number',
                        hintText: '4532 8901 2345 6789',
                        prefixIcon: const Icon(Icons.credit_card, color: Color(0xFFD4AF37)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.trim().length < 12 ? 'Enter valid card number' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryCtrl,
                            keyboardType: TextInputType.datetime,
                            decoration: InputDecoration(
                              labelText: 'Expiry (MM/YY)',
                              hintText: '08/28',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'MM/YY' : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvCtrl,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'CVV',
                              hintText: '888',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => v == null || v.trim().length < 3 ? '3 digits' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Checkbox(
                          value: _saveCard,
                          activeColor: const Color(0xFF2D103E),
                          onChanged: (val) => setState(() => _saveCard = val ?? true),
                        ),
                        const Expanded(
                          child: Text(
                            'Save card for future wedding bookings',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isPaying ? null : _handlePayment,
                  icon: _isPaying
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.lock_rounded, color: Colors.white),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _isPaying ? 'Processing Payment...' : 'Pay $formattedTotal & Confirm Booking',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D103E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// SAVED CARDS SCREEN (PROFILE)
// ======================================================================

class SavedCardsScreen extends ConsumerWidget {
  const SavedCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final uid = authState.userId ?? '';
    final savedCardsAsync = ref.watch(savedCardsProvider(uid));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Saved Payment Cards',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: GradientBackgroundWrapper(
        child: SafeArea(
          child: savedCardsAsync.when(
            data: (cards) {
              if (cards.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.credit_card_off_rounded, size: 54, color: Color(0xFFD4AF37)),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No Saved Payment Cards',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D103E),
                            fontFamily: 'PlayfairDisplay',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cards saved during venue checkout will appear here for fast 1-click payments.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // Security Info Header Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.security_rounded, color: Color(0xFFD4AF37), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PCI-DSS Encrypted Vault',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2D103E)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Your saved payment credentials are encrypted and stored safely for instant venue checkout.',
                                style: TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...cards.map((card) => _buildLuxuryCreditCard(context, uid, card)),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryCreditCard(BuildContext context, String uid, SavedCard card) {
    final brandUpper = card.brand.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D103E), Color(0xFF1F092B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D103E).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            brandUpper,
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.nfc_rounded, color: Color(0xFFD4AF37), size: 22),
                      ],
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Remove Card?'),
                            content: const Text('Are you sure you want to remove this saved card?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await deleteSavedCard(uid, card.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card removed from saved cards.')));
                          }
                        }
                      },
                    ),
                  ],
                ),
                Text(
                  card.maskedNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3.5,
                    fontFamily: 'Courier',
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CARDHOLDER',
                          style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.cardholderName.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'EXPIRES',
                          style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.expiryDate,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
