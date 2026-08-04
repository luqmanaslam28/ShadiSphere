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

// Data models are imported from vendor_providers.dart

// ── Onboarding Screen ────────────────────────────────────────────────────────

class GenericOnboardingScreen extends ConsumerStatefulWidget {
  const GenericOnboardingScreen({super.key});

  @override
  ConsumerState<GenericOnboardingScreen> createState() => _GenericOnboardingScreenState();
}

class _GenericOnboardingScreenState extends ConsumerState<GenericOnboardingScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 1 Controllers
  late TextEditingController _businessNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _descriptionController;

  List<String> _portfolioPictures = [];
  bool _isUploadingPictures = false;
  bool _isSubmitting = false;

  // Step 2 Products & Packages
  final List<GenericSingleProduct> _singleProducts = [];
  final List<GenericServicePackage> _servicePackages = [];

  // Step 3 Subscription
  String _selectedPlan = 'free';

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    final profile = ref.read(vendorProfileProvider);

    _businessNameController = TextEditingController(text: profile.businessName);
    _ownerNameController = TextEditingController(
      text: profile.ownerName.isEmpty ? (auth.displayName ?? '') : profile.ownerName,
    );
    _addressController = TextEditingController(text: profile.location);
    _cityController = TextEditingController(
      text: profile.city.isEmpty ? (auth.city ?? '') : profile.city,
    );
    _descriptionController = TextEditingController(text: profile.bio);

    _portfolioPictures = List.from(profile.outsidePictures);
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

  // ── Image Upload (Cloudinary) ──────────────────────────────────────────────

  Future<String?> _uploadSingleImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    try {
      final bytes = await image.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/isuedugk/image/upload'),
      );
      request.fields['upload_preset'] = 'shadi_sphere_uploads';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: image.name));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final jsonMap = jsonDecode(String.fromCharCodes(responseData));

      if (response.statusCode == 200) {
        return jsonMap['secure_url'];
      }
    } catch (e) {
      print('Error uploading image: $e');
    }
    return null;
  }

  Future<void> _pickPortfolioImages() async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    setState(() => _isUploadingPictures = true);

    List<String> uploadedUrls = [];
    for (var image in images) {
      try {
        final bytes = await image.readAsBytes();
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/isuedugk/image/upload'),
        );
        request.fields['upload_preset'] = 'shadi_sphere_uploads';
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: image.name));

        final response = await request.send();
        final responseData = await response.stream.toBytes();
        final jsonMap = jsonDecode(String.fromCharCodes(responseData));

        if (response.statusCode == 200) {
          uploadedUrls.add(jsonMap['secure_url']);
        }
      } catch (e) {
        print('Error uploading image: $e');
      }
    }

    setState(() {
      _portfolioPictures.addAll(uploadedUrls);
      _isUploadingPictures = false;
    });
  }

  void _removePortfolioImage(int index) {
    setState(() => _portfolioPictures.removeAt(index));
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _proceedToProducts() {
    if (!_formKey.currentState!.validate()) return;

    if (_portfolioPictures.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least 5 portfolio pictures')),
      );
      return;
    }

    setState(() => _currentStep = 1);
  }

  void _proceedToSubscription() {
    if (_singleProducts.isEmpty && _servicePackages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product or package to proceed.')),
      );
      return;
    }
    setState(() => _currentStep = 2);
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
              Navigator.pop(context);
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
      double minPrice = 0;
      if (_singleProducts.isNotEmpty) {
        minPrice = _singleProducts.map((p) => p.price).reduce((a, b) => a < b ? a : b);
      } else if (_servicePackages.isNotEmpty) {
        minPrice = _servicePackages.map((p) => p.price).reduce((a, b) => a < b ? a : b);
      }

      await ref.read(vendorProfileProvider.notifier).updateProfile(
        businessName: _businessNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        capacity: 0,
        location: _addressController.text.trim(),
        city: _cityController.text.trim(),
        bio: _descriptionController.text.trim(),
        price: minPrice,
        weekendPrice: minPrice,
        specialPrices: {},
        outsidePictures: _portfolioPictures,
        insidePictures: [],
        subscriptionTier: _selectedPlan,
        isSetupComplete: true,
        singleProducts: _singleProducts,
        servicePackages: _servicePackages,
      );

      if (_selectedPlan != 'free') {
        final auth = ref.read(authProvider);
        final docId = (auth.isAuthenticated && auth.role == 'vendor') ? auth.userId! : 'profile_details';
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

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showAddProductDialog({GenericSingleProduct? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toStringAsFixed(0) : '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String currentImageUrl = existing?.imageUrl ?? '';
    bool isUploading = false;

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
                    // Emerald & Gold Header
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
                            child: const Icon(Icons.sell_rounded, color: Color(0xFFD4AF37), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existing == null ? 'Add Product / Service' : 'Edit Product / Service',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  existing == null ? 'List an individual service item' : 'Update product details',
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
                          const Text('PRODUCT / SERVICE NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameCtrl,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'e.g. Bridal Stage Decor',
                              prefixIcon: const Icon(Icons.label_outline, color: Color(0xFF064E3B), size: 18),
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

                          const Text('PRICE (RS.)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '50000',
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
                          const SizedBox(height: 16),

                          const Text('DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: descCtrl,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Describe what this service includes...',
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

                          // Image Upload
                          const Text('PRODUCT IMAGE (REQUIRED)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          if (currentImageUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(currentImageUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 4, right: 4,
                                    child: GestureDetector(
                                      onTap: () => setDlgState(() => currentImageUrl = ''),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isUploading)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator(color: Color(0xFF064E3B))),
                            )
                          else if (currentImageUrl.isEmpty)
                            OutlinedButton.icon(
                              onPressed: () async {
                                setDlgState(() => isUploading = true);
                                final url = await _uploadSingleImage();
                                setDlgState(() {
                                  if (url != null) currentImageUrl = url;
                                  isUploading = false;
                                });
                              },
                              icon: const Icon(Icons.add_a_photo, color: Color(0xFF064E3B), size: 18),
                              label: const Text('Upload Image', style: TextStyle(color: Color(0xFF064E3B))),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          const SizedBox(height: 24),

                          // Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                label: Text(existing == null ? 'Save Product' : 'Update Product', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF064E3B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  elevation: 2,
                                  shadowColor: const Color(0xFF064E3B).withValues(alpha: 0.3),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: isUploading ? null : () {
                                  final name = nameCtrl.text.trim();
                                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                                  if (name.isEmpty || price <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid name and price')));
                                    return;
                                  }
                                  if (currentImageUrl.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a product image')));
                                    return;
                                  }
                                  setState(() {
                                    if (existing != null) {
                                      final idx = _singleProducts.indexWhere((p) => p.id == existing.id);
                                      if (idx != -1) {
                                        _singleProducts[idx] = GenericSingleProduct(
                                          id: existing.id, name: name, price: price,
                                          description: descCtrl.text.trim(), imageUrl: currentImageUrl,
                                        );
                                      }
                                    } else {
                                      _singleProducts.add(GenericSingleProduct(
                                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                                        name: name, price: price,
                                        description: descCtrl.text.trim(), imageUrl: currentImageUrl,
                                      ));
                                    }
                                  });
                                  Navigator.pop(ctx);
                                },
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

  void _showAddPackageDialog({GenericServicePackage? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toStringAsFixed(0) : '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final itemInputCtrl = TextEditingController();
    String currentImageUrl = existing?.imageUrl ?? '';
    bool isUploading = false;

    List<String> dlgItems = List.from(existing?.items ?? []);

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
                    // Gold & Emerald Header
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
                            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                            child: const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existing == null ? 'Create Service Package' : 'Edit Service Package',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  existing == null ? 'Bundle services into a complete deal' : 'Update package details',
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
                          const Text('PACKAGE NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameCtrl,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'e.g. Complete Baraat Decor Package',
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

                          const Text('PACKAGE PRICE (RS.)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '150000',
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
                          const SizedBox(height: 16),

                          const Text('DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: descCtrl,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Describe what this package covers...',
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

                          // Included Items
                          const Text('INCLUDED ITEMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: itemInputCtrl,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  decoration: InputDecoration(
                                    hintText: 'Add item (e.g. Stage Flowers)',
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
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Text('No items added yet.', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                            )
                          else
                            ...dlgItems.asMap().entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.fiber_manual_record, size: 6, color: Color(0xFFD4AF37)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                  GestureDetector(
                                    onTap: () => setDlgState(() => dlgItems.removeAt(entry.key)),
                                    child: const Icon(Icons.close, size: 14, color: Colors.red),
                                  ),
                                ],
                              ),
                            )),
                          const SizedBox(height: 16),

                          // Image Upload
                          const Text('PACKAGE IMAGE (REQUIRED)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF064E3B), letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          if (currentImageUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(currentImageUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 4, right: 4,
                                    child: GestureDetector(
                                      onTap: () => setDlgState(() => currentImageUrl = ''),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isUploading)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
                            )
                          else if (currentImageUrl.isEmpty)
                            OutlinedButton.icon(
                              onPressed: () async {
                                setDlgState(() => isUploading = true);
                                final url = await _uploadSingleImage();
                                setDlgState(() {
                                  if (url != null) currentImageUrl = url;
                                  isUploading = false;
                                });
                              },
                              icon: const Icon(Icons.add_a_photo, color: Color(0xFFD4AF37), size: 18),
                              label: const Text('Upload Image', style: TextStyle(color: Color(0xFFD4AF37))),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          const SizedBox(height: 24),

                          // Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                  label: Text(existing == null ? 'Save Package' : 'Update Package', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF064E3B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    elevation: 2,
                                    shadowColor: const Color(0xFF064E3B).withValues(alpha: 0.3),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: isUploading ? null : () {
                                    final name = nameCtrl.text.trim();
                                    final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                                    if (name.isEmpty || price <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid name and price')));
                                      return;
                                    }
                                    if (currentImageUrl.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a package image')));
                                      return;
                                    }
                                    setState(() {
                                      if (existing != null) {
                                        final idx = _servicePackages.indexWhere((p) => p.id == existing.id);
                                        if (idx != -1) {
                                          _servicePackages[idx] = GenericServicePackage(
                                            id: existing.id, name: name, price: price,
                                            description: descCtrl.text.trim(), items: dlgItems, imageUrl: currentImageUrl,
                                          );
                                        }
                                      } else {
                                        _servicePackages.add(GenericServicePackage(
                                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                                          name: name, price: price,
                                          description: descCtrl.text.trim(), items: dlgItems, imageUrl: currentImageUrl,
                                        ));
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

  // ── Build Steps ────────────────────────────────────────────────────────────

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('Portfolio Pictures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(width: 8),
            Text('(Min 5)', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._portfolioPictures.asMap().entries.map((entry) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(entry.value, width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2, right: 2,
                    child: GestureDetector(
                      onTap: () => _removePortfolioImage(entry.key),
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
            if (_isUploadingPictures)
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: CircularProgressIndicator()),
              )
            else
              GestureDetector(
                onTap: _pickPortfolioImages,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
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
          const Text('Welcome to ShadiSphere!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
          const SizedBox(height: 8),
          const Text(
            'Step 1: Business Details\nBefore you can access your dashboard, we need some essential details about your business. These details will be shown to customers.',
            style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: _businessNameController,
            decoration: const InputDecoration(labelText: 'Business Name', border: OutlineInputBorder()),
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
            decoration: const InputDecoration(labelText: 'Business Description', border: OutlineInputBorder(), alignLabelWithHint: true),
            maxLines: 4,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 32),

          _buildImageSection(),

          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isUploadingPictures ? null : _proceedToProducts,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF064E3B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Next: Add Your Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Products() {
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
              child: Text('Step 2: Your Services', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Add the services you offer. You can list individual products, bundled packages, or both. At least one is required.',
          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 32),

        // ── Single Products Section ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('Single Products (${_singleProducts.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
            ),
            OutlinedButton.icon(
              onPressed: () => _showAddProductDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Product', style: TextStyle(fontSize: 13)),
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

        if (_singleProducts.isEmpty)
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
                Icon(Icons.sell_outlined, color: Colors.grey, size: 40),
                SizedBox(height: 8),
                Text('No single products added yet.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                SizedBox(height: 4),
                Text('Add individual services like "DJ for 4 Hours" or "Photo Booth Setup".', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _singleProducts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final prod = _singleProducts[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF064E3B).withValues(alpha: 0.2)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(prod.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF064E3B))),
                          const SizedBox(height: 4),
                          Text('Rs. ${prod.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF064E3B), size: 18),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      onPressed: () => _showAddProductDialog(existing: prod),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      onPressed: () => setState(() => _singleProducts.removeAt(index)),
                    ),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 32),

        // ── Service Packages Section ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('Service Packages (${_servicePackages.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
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

        if (_servicePackages.isEmpty)
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
                Text('Packages let you bundle multiple services into a complete deal.', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _servicePackages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pkg = _servicePackages[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(pkg.imageUrl, width: 70, height: 70, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF064E3B))),
                          const SizedBox(height: 4),
                          Text('Rs. ${pkg.price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                          if (pkg.items.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...pkg.items.take(3).map((it) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.fiber_manual_record, size: 6, color: Color(0xFFD4AF37)),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(it, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500))),
                                ],
                              ),
                            )),
                            if (pkg.items.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('+${pkg.items.length - 3} more items', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFFD4AF37), size: 18),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          onPressed: () => _showAddPackageDialog(existing: pkg),
                        ),
                        const SizedBox(height: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          onPressed: () => setState(() => _servicePackages.removeAt(index)),
                        ),
                      ],
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
                'Step 3: Boost Your Business',
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
                      'Premium vendors are featured at the very top of search results. You get significantly higher visibility, priority support, and up to 5x more bookings than basic vendors!',
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
          features: ['Standard listing', 'Basic analytics', 'Limited portfolio'],
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
                'Top priority listing',
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
              backgroundColor: const Color(0xFF064E3B),
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

  // ── Build ──────────────────────────────────────────────────────────────────

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
              : (_currentStep == 1 ? _buildStep2Products() : _buildStep3Subscription()),
          ),
        ),
      ),
    );
  }
}
