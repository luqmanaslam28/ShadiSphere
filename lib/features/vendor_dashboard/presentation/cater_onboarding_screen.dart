import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../admin/presentation/admin_providers.dart';
import 'vendor_providers.dart';
import 'mock_payment_screen.dart';

class CateringDishItem {
  final String id;
  final String name;
  final double pricePerPlate;
  final int minQuantity;
  final String category;

  CateringDishItem({
    required this.id,
    required this.name,
    required this.pricePerPlate,
    required this.minQuantity,
    this.category = 'Main Course',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'pricePerPlate': pricePerPlate,
    'minQuantity': minQuantity,
    'category': category,
  };
}

class CateringPackageItem {
  final String id;
  final String name;
  final double pricePerPlate;
  final int minGuests;
  final List<String>? items;

  CateringPackageItem({
    required this.id,
    required this.name,
    required this.pricePerPlate,
    required this.minGuests,
    this.items,
  });

  List<String> get safeItems => items ?? [];

  String get description => safeItems.join(', ');

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'pricePerPlate': pricePerPlate,
    'minGuests': minGuests,
    'items': safeItems,
    'description': description,
  };
}

class CaterOnboardingScreen extends ConsumerStatefulWidget {
  const CaterOnboardingScreen({super.key});

  @override
  ConsumerState<CaterOnboardingScreen> createState() => _CaterOnboardingScreenState();
}

class _CaterOnboardingScreenState extends ConsumerState<CaterOnboardingScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  
  // Step 1 Controllers
  late TextEditingController _businessNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _descriptionController;

  List<String> _dishPictures = [];
  List<String> _setupPictures = [];
  
  bool _isUploadingDishes = false;
  bool _isUploadingSetups = false;
  bool _isSubmitting = false;

  // Step 2 Catering Menu State (Dishes & Packages)
  final List<CateringDishItem> _dishes = [];

  final List<CateringPackageItem> _packages = [];

  // Step 3 Subscription
  String _selectedPlan = 'free';

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    final profile = ref.read(vendorProfileProvider);
    
    _businessNameController = TextEditingController(text: profile.businessName);
    _ownerNameController = TextEditingController(text: profile.ownerName.isEmpty ? (auth.displayName ?? '') : profile.ownerName);
    _addressController = TextEditingController(text: profile.location);
    _cityController = TextEditingController(text: profile.city.isEmpty ? (auth.city ?? '') : profile.city);
    _descriptionController = TextEditingController(text: profile.bio);
    
    _dishPictures = List.from(profile.outsidePictures);
    _setupPictures = List.from(profile.insidePictures);
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImages(bool isDish) async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isEmpty) return;

    if (isDish) {
      setState(() => _isUploadingDishes = true);
    } else {
      setState(() => _isUploadingSetups = true);
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
      if (isDish) {
        _dishPictures.addAll(uploadedUrls);
        _isUploadingDishes = false;
      } else {
        _setupPictures.addAll(uploadedUrls);
        _isUploadingSetups = false;
      }
    });
  }

  void _removeImage(bool isDish, int index) {
    setState(() {
      if (isDish) {
        _dishPictures.removeAt(index);
      } else {
        _setupPictures.removeAt(index);
      }
    });
  }

  void _proceedToMenuSetup() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_dishPictures.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload at least 2 photos of your signature dishes')));
      return;
    }
    
    if (_setupPictures.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload at least 3 photos of your catering setups/buffets')));
      return;
    }

    setState(() {
      _currentStep = 1;
    });
  }

  void _proceedToSubscription() {
    if (_dishes.isEmpty && _packages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one dish item or package to proceed.')),
      );
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
    setState(() => _isSubmitting = true);
    
    try {
      double minPrice = 100.0;
      double maxPrice = 100.0;
      if (_dishes.isNotEmpty) {
        minPrice = _dishes.map((d) => d.pricePerPlate).reduce((a, b) => a < b ? a : b);
        maxPrice = _dishes.map((d) => d.pricePerPlate).reduce((a, b) => a > b ? a : b);
      }

      await ref.read(vendorProfileProvider.notifier).updateProfile(
        businessName: _businessNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        capacity: 0,
        location: _addressController.text.trim(),
        city: _cityController.text.trim(),
        bio: _descriptionController.text.trim(),
        price: minPrice,
        weekendPrice: maxPrice,
        specialPrices: {},
        outsidePictures: _dishPictures,
        insidePictures: _setupPictures,
        subscriptionTier: _selectedPlan,
        isSetupComplete: true,
      );
      
      final auth = ref.read(authProvider);
      final docId = (auth.isAuthenticated && auth.role == 'vendor') ? auth.userId! : 'profile_details';
      
      final dishesData = _dishes.map((d) => d.toMap()).toList();
      final packagesData = _packages.map((p) => p.toMap()).toList();

      await FirebaseFirestore.instance.collection('vendor_profile').doc(docId).set({
        'cateringDishes': dishesData,
        'cateringPackages': packagesData,
      }, SetOptions(merge: true));
      
      await FirebaseFirestore.instance.collection('vendors').doc(docId).set({
        'cateringDishes': dishesData,
        'cateringPackages': packagesData,
      }, SetOptions(merge: true));

      if (_selectedPlan != 'free') {
        final expiry = DateTime.now().add(const Duration(days: 30)).toIso8601String();
        await FirebaseFirestore.instance.collection('vendor_profile').doc(docId).set({'subscriptionExpiry': expiry}, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('vendors').doc(docId).set({'subscriptionExpiry': expiry}, SetOptions(merge: true));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving details: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showAddDishDialog({CateringDishItem? existingDish}) {
    final nameCtrl = TextEditingController(text: existingDish?.name ?? '');
    final priceCtrl = TextEditingController(text: existingDish != null ? existingDish.pricePerPlate.toStringAsFixed(0) : '');
    final minQtyCtrl = TextEditingController(text: existingDish != null ? existingDish.minQuantity.toString() : '20');
    String selectedCategory = existingDish?.category ?? 'Main Course';

    final categories = ['Main Course', 'Appetizer', 'Dessert', 'Beverage', 'Sides / Breads'];

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
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Luxury Emerald & Gold Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF064E3B), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.restaurant_rounded, color: Color(0xFFD4AF37), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                existingDish == null ? 'Add Catering Dish' : 'Edit Catering Dish',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                existingDish == null ? 'Add a signature food item to your menu' : 'Update dish rate & order details',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  
                  // Form Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dish Name Field
                        const Text('DISH NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: nameCtrl,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'e.g. Special Chicken Biryani',
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

                        // Rate & Min Quantity Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('RATE PER PLATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
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

                        // Category Dropdown
                        const Text('CATEGORY / COURSE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 14),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFFD4AF37), size: 18),
                            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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

                        // Action Buttons
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
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Luxury Gold & Emerald Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFB48A1D), Color(0xFFD4AF37)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
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

                    // Form Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Package Name Field
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

                          // Rate & Min Guests Row
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

                          // Included Menu Items List / Bullets Section
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

                          // Action Buttons
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

  Widget _buildImageSection(String title, bool isDish, int minRequired) {
    final images = isDish ? _dishPictures : _setupPictures;
    final isUploading = isDish ? _isUploadingDishes : _isUploadingSetups;
    
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
                      onTap: () => _removeImage(isDish, entry.key),
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
                onTap: () => _pickAndUploadImages(isDish),
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
          const Text('Welcome to ShadiSphere Catering!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
          const SizedBox(height: 8),
          const Text('Step 1: Catering Business Details\nProvide key information about your catering service and upload showcase photos for clients.', style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4)),
          const SizedBox(height: 32),
          
          TextFormField(
            controller: _businessNameController,
            decoration: const InputDecoration(labelText: 'Catering Service / Company Name', border: OutlineInputBorder()),
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
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Kitchen / Operating Address', border: OutlineInputBorder()),
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
            decoration: const InputDecoration(labelText: 'Catering Bio & Cuisine Specialties', border: OutlineInputBorder(), alignLabelWithHint: true),
            maxLines: 4,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 32),
          
          _buildImageSection('Signature Dishes Photos', true, 2),
          const SizedBox(height: 24),
          _buildImageSection('Buffet & Catering Setup Photos', false, 3),
          
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isUploadingDishes || _isUploadingSetups ? null : _proceedToMenuSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF064E3B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Next: Add Dishes & Packages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Pricing() {
    final Map<String, List<CateringDishItem>> groupedDishes = {};
    for (var dish in _dishes) {
      groupedDishes.putIfAbsent(dish.category, () => []).add(dish);
    }

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
            const Expanded(
              child: Text('Step 2: Add Menu Dishes & Packages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Add your dishes with dish names (e.g. Biryani), per plate rates, and minimum order quantities. You can also create complete catering menu packages.',
          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 32),
        
        // --- Dishes Section Header ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('Signature Dishes (${_dishes.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddDishDialog(),
              icon: const Icon(Icons.restaurant_menu, size: 16),
              label: const Text('Add Dish', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: const Color(0xFF064E3B),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_dishes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              children: [
                Icon(Icons.restaurant_outlined, color: Colors.grey, size: 40),
                SizedBox(height: 8),
                Text('No dishes added yet.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                SizedBox(height: 4),
                Text('Click "+ Add Dish" to add items like Biryani, Karahi, etc.', style: TextStyle(color: Colors.grey, fontSize: 12)),
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

        // --- Packages Section Header ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('Catering Packages (${_packages.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
            ),
            OutlinedButton.icon(
              onPressed: () => _showAddPackageDialog(),
              icon: const Icon(Icons.card_giftcard, size: 16),
              label: const Text('Add Package', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF064E3B),
                side: const BorderSide(color: Color(0xFF064E3B)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_packages.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
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
        
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _proceedToSubscription,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF064E3B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Next: Choose Subscription Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                'Step 3: Boost Your Catering Business',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
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
                    Text('Why upgrade your plan?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.brown)),
                    SizedBox(height: 4),
                    Text(
                      'Top-tier caterers are featured on the front page for clients booking wedding food & banquets. Receive priority inquiry alerts and up to 5x more bookings!',
                      style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        _buildPlanCard(
          id: 'free',
          name: 'Basic (Free)',
          price: 0,
          colorHex: '9E9E9E',
          iconName: 'check_circle_outline',
          features: ['Standard listing', 'Basic analytics', 'Limited food gallery'],
        ),
        const SizedBox(height: 16),
        
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
                'Top priority catering listing',
                'Featured badge on food profile',
                'Advanced analytics dashboard',
                'Priority client support'
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
              backgroundColor: const Color(0xFF064E3B),
              foregroundColor: Colors.white,
              alignment: Alignment.center,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSubmitting 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Center(
                  child: Text(
                    'Finish Setup & Go To Catering Dashboard',
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
          color: isSelected ? color.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected 
            ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Catering Profile', style: TextStyle(color: Colors.black)),
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
