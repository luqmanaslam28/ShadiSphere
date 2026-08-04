import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../admin/presentation/admin_providers.dart';
import 'vendor_providers.dart';
import 'mock_payment_screen.dart';
class VenueOnboardingScreen extends ConsumerStatefulWidget {
  const VenueOnboardingScreen({super.key});

  @override
  ConsumerState<VenueOnboardingScreen> createState() => _VenueOnboardingScreenState();
}

class _VenueOnboardingScreenState extends ConsumerState<VenueOnboardingScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  
  // Step 1 Controllers
  late TextEditingController _venueNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _capacityController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _descriptionController;

  List<String> _outsidePictures = [];
  List<String> _insidePictures = [];
  
  bool _isUploadingOutside = false;
  bool _isUploadingInside = false;
  bool _isSubmitting = false;

  // Step 2 Pricing State
  late TextEditingController _weekdayPriceController;
  late TextEditingController _weekendPriceController;
  Map<String, double> _specialPrices = {};
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  
  // Step 3 Subscription
  String _selectedPlan = 'free';

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    final profile = ref.read(vendorProfileProvider);
    
    _venueNameController = TextEditingController(text: profile.businessName);
    _ownerNameController = TextEditingController(text: profile.ownerName.isEmpty ? (auth.displayName ?? '') : profile.ownerName);
    _capacityController = TextEditingController(text: profile.capacity > 0 ? profile.capacity.toString() : '');
    _addressController = TextEditingController(text: profile.location);
    _cityController = TextEditingController(text: profile.city.isEmpty ? (auth.city ?? '') : profile.city);
    _descriptionController = TextEditingController(text: profile.bio);
    
    _outsidePictures = List.from(profile.outsidePictures);
    _insidePictures = List.from(profile.insidePictures);

    _weekdayPriceController = TextEditingController(text: profile.price > 0 ? profile.price.toStringAsFixed(0) : '');
    _weekendPriceController = TextEditingController(text: profile.weekendPrice > 0 ? profile.weekendPrice.toStringAsFixed(0) : '');
    _specialPrices = Map.from(profile.specialPrices);
    
    // Listen to changes to rebuild calendar instantly
    _weekdayPriceController.addListener(() => setState(() {}));
    _weekendPriceController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _venueNameController.dispose();
    _ownerNameController.dispose();
    _capacityController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    _weekdayPriceController.dispose();
    _weekendPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImages(bool isOutside) async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isEmpty) return;

    if (isOutside) {
      setState(() => _isUploadingOutside = true);
    } else {
      setState(() => _isUploadingInside = true);
    }

    List<String> uploadedUrls = [];
    
    for (var image in images) {
      try {
        final bytes = await image.readAsBytes();
        
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/isuedugk/image/upload'),
        );
        
        request.fields['upload_preset'] = 'shadi_sphere_uploads';
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: image.name,
          ),
        );

        final response = await request.send();
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        
        if (response.statusCode == 200) {
          uploadedUrls.add(jsonMap['secure_url']);
        } else {
          print('Cloudinary error: ${jsonMap['error']['message']}');
        }
      } catch (e) {
        print('Error uploading image: $e');
      }
    }

    setState(() {
      if (isOutside) {
        _outsidePictures.addAll(uploadedUrls);
        _isUploadingOutside = false;
      } else {
        _insidePictures.addAll(uploadedUrls);
        _isUploadingInside = false;
      }
    });
  }

  void _removeImage(bool isOutside, int index) {
    setState(() {
      if (isOutside) {
        _outsidePictures.removeAt(index);
      } else {
        _insidePictures.removeAt(index);
      }
    });
  }

  void _proceedToPricing() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_outsidePictures.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload at least 2 outside pictures')));
      return;
    }
    
    if (_insidePictures.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload at least 3 inside pictures')));
      return;
    }

    setState(() {
      _currentStep = 1;
    });
  }

  void _proceedToSubscription() {
    final weekdayPrice = double.tryParse(_weekdayPriceController.text.trim()) ?? 0.0;
    if (weekdayPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set a valid Weekday Base Price')));
      return;
    }
    setState(() {
      _currentStep = 2;
    });
  }

  void _handleFinishOrPayment() {
    if (_selectedPlan == 'free') {
      _finishSetup();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MockPaymentScreen(
            planId: _selectedPlan,
            onPaymentSuccess: () {
              Navigator.pop(context); // Close payment screen
              _finishSetup();
            },
          ),
        ),
      );
    }
  }

  Future<void> _finishSetup() async {
    final weekdayPrice = double.tryParse(_weekdayPriceController.text.trim()) ?? 0.0;

    setState(() => _isSubmitting = true);
    
    try {
      await ref.read(vendorProfileProvider.notifier).updateProfile(
        businessName: _venueNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        capacity: int.tryParse(_capacityController.text.trim()) ?? 0,
        location: _addressController.text.trim(),
        city: _cityController.text.trim(),
        bio: _descriptionController.text.trim(),
        price: weekdayPrice,
        weekendPrice: double.tryParse(_weekendPriceController.text.trim()) ?? weekdayPrice,
        specialPrices: _specialPrices,
        outsidePictures: _outsidePictures,
        insidePictures: _insidePictures,
        subscriptionTier: _selectedPlan,
        isSetupComplete: true,
      );
      
      // Manually set 30-day expiry if paid plan is chosen
      if (_selectedPlan != 'free') {
        final auth = ref.read(authProvider);
        final docId = (auth.isAuthenticated && auth.role == 'vendor') ? auth.userId! : 'profile_details';
        final expiry = DateTime.now().add(const Duration(days: 30)).toIso8601String();
        await FirebaseFirestore.instance.collection('vendor_profile').doc(docId).set({'subscriptionExpiry': expiry}, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('vendors').doc(docId).set({'subscriptionExpiry': expiry}, SetOptions(merge: true));
      }
      
      // Once isSetupComplete is true, the shell will automatically switch views
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving details: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSpecialPriceDialog(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    final existingPrice = _specialPrices[dateString];
    final controller = TextEditingController(text: existingPrice != null ? existingPrice.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Custom Price for ${DateFormat('MMM d, yyyy').format(date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set a specific price for this date, overriding the default weekday/weekend price.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (Rs.)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (existingPrice != null)
            TextButton(
              onPressed: () {
                setState(() => _specialPrices.remove(dateString));
                Navigator.pop(ctx);
              },
              child: const Text('Clear Custom Price', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              setState(() {
                if (val != null && val > 0) {
                  _specialPrices[dateString] = val;
                } else {
                  _specialPrices.remove(dateString);
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(String title, bool isOutside, int minRequired) {
    final images = isOutside ? _outsidePictures : _insidePictures;
    final isUploading = isOutside ? _isUploadingOutside : _isUploadingInside;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            Text('(Min $minRequired)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...images.asMap().entries.map((entry) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(entry.value, width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => _removeImage(isOutside, entry.key),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              );
            }),
            if (isUploading)
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: CircularProgressIndicator()),
              )
            else
              GestureDetector(
                onTap: () => _pickAndUploadImages(isOutside),
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: const Center(child: Icon(Icons.add_a_photo, color: Colors.grey)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep1Details() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome to ShadiSphere!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C0B3E))),
          const SizedBox(height: 8),
          const Text('Step 1: Venue Details\nBefore you can access your dashboard, we need a few compulsory details about your venue. These details will be shown to customers.', style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4)),
          const SizedBox(height: 32),
          
          TextFormField(
            controller: _venueNameController,
            decoration: const InputDecoration(labelText: 'Venue Name', border: OutlineInputBorder()),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ownerNameController,
            decoration: const InputDecoration(labelText: 'Owner Name', border: OutlineInputBorder()),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _capacityController,
            decoration: const InputDecoration(labelText: 'Capacity (Guests)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            validator: (v) => v == null || v.isEmpty || int.tryParse(v) == null ? 'Invalid number' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Complete Address', border: OutlineInputBorder()),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Venue Description', border: OutlineInputBorder(), alignLabelWithHint: true),
            maxLines: 4,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 32),
          
          _buildImageSection('Outside Pictures', true, 2),
          const SizedBox(height: 24),
          _buildImageSection('Inside Pictures', false, 3),
          
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isUploadingOutside || _isUploadingInside ? null : _proceedToPricing,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C0B3E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Next: Set Pricing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Pricing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _currentStep = 0),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            const Text('Step 2: Dynamic Pricing', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C0B3E))),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Set your base prices. Tap any date on the calendar to set a special custom price for that day.', style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4)),
        const SizedBox(height: 32),
        
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weekdayPriceController,
                decoration: const InputDecoration(labelText: 'Weekday Base Price (Rs.)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _weekendPriceController,
                decoration: const InputDecoration(labelText: 'Weekend Base Price (Rs.)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        _buildCalendarGrid(),
        
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _proceedToSubscription,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C0B3E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Next: Choose Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Subscription() {
    final plans = ref.watch(subscriptionPlansProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _currentStep = 1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Step 3: Boost Your Venue',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C0B3E)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Why upgrade?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown)),
                    SizedBox(height: 4),
                    Text(
                      'Premium venues are featured at the very top of search results. You get significantly higher visibility, priority support, and up to 5x more bookings than basic venues!',
                      style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // Free Plan Option
        _buildPlanCard(
          id: 'free',
          name: 'Basic (Free)',
          price: 0,
          colorHex: '9E9E9E',
          iconName: 'check_circle_outline',
          features: ['Standard listing', 'Basic analytics', 'Limited images'],
        ),
        const SizedBox(height: 16),
        
        // Dynamic Plans
        ...plans.map((plan) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildPlanCard(
              id: plan.id,
              name: plan.name,
              price: plan.price,
              colorHex: plan.colorHex,
              iconName: plan.iconName,
              features: [
                'Top of search results',
                'Featured badge on profile',
                'Advanced analytics dashboard',
                'Priority customer support'
              ],
            ),
          );
        }),
        
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleFinishOrPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C0B3E),
              foregroundColor: Colors.white,
              alignment: Alignment.center,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSubmitting 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Center(
                  child: Text(
                    'Finish Setup & Go To Dashboard',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String id,
    required String name,
    required double price,
    required String colorHex,
    required String iconName,
    required List<String> features,
  }) {
    final isSelected = _selectedPlan == id;
    final color = Color(int.parse('0xFF$colorHex'));
    
    IconData getIcon(String name) {
      switch (name) {
        case 'star': return Icons.star_rounded;
        case 'diamond': return Icons.diamond_rounded;
        default: return Icons.stars_rounded;
      }
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected 
            ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
            : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(getIcon(iconName), color: color, size: 28),
                const SizedBox(width: 12),
                Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                const Spacer(),
                if (price > 0)
                  Text('Rs. ${price.toStringAsFixed(0)} /mo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (price == 0)
                  const Text('Free forever', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check, color: color, size: 16),
                  const SizedBox(width: 8),
                  Text(f, style: const TextStyle(color: Colors.black87)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun
    
    // Offset for grid to start at Sunday (0) instead of Monday (1) if needed.
    // Let's use Monday as first day of week for simpler math, or Sunday.
    // In Dart, weekday 1 is Monday, 7 is Sunday.
    // Let's build a Sunday-first calendar.
    int emptyCells = startingWeekday % 7;

    final weekdayPrice = double.tryParse(_weekdayPriceController.text.trim()) ?? 0.0;
    final weekendPrice = double.tryParse(_weekendPriceController.text.trim()) ?? weekdayPrice;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Month Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1)),
                ),
                Text(DateFormat('MMMM yyyy').format(_focusedMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1)),
                ),
              ],
            ),
          ),
          // Days of Week Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((d) => 
                Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey))))
              ).toList(),
            ),
          ),
          const Divider(height: 1),
          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: emptyCells + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              if (index < emptyCells) return const SizedBox.shrink();
              
              final dayNum = index - emptyCells + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
              final dateString = DateFormat('yyyy-MM-dd').format(date);
              
              final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
              final hasSpecialPrice = _specialPrices.containsKey(dateString);
              
              double displayPrice = weekdayPrice;
              if (hasSpecialPrice) {
                displayPrice = _specialPrices[dateString]!;
              } else if (isWeekend) {
                displayPrice = weekendPrice;
              }

              return InkWell(
                onTap: () => _showSpecialPriceDialog(date),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200, width: 0.5),
                    color: hasSpecialPrice ? Colors.yellow.shade50 : (isWeekend ? Colors.grey.shade50 : Colors.white),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$dayNum', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      if (displayPrice > 0)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Rs. ${displayPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: hasSpecialPrice ? Colors.red.shade700 : Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Your Profile', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _currentStep == 0 
              ? _buildStep1Details() 
              : (_currentStep == 1 ? _buildStep2Pricing() : _buildStep3Subscription()),
          ),
        ),
      ),
    );
  }
}
