import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/consumer/presentation/consumer_providers.dart';

final translationProvider = Provider<String Function(String)>((ref) {
  return (String text) => text;
});

// A simple dictionary containing key UI phrases mapped to Urdu
const Map<String, String> _urduTranslations = {
  // Navigation Tabs
  'Home': 'ہوم',
  'Planner': 'پلانر',
  'Ledger': 'لیجر',
  'Profile': 'پروفائل',
  
  // Discover Header & Titles
  'Discover': 'دریافت کریں',
  'Select Your City': 'اپنا شہر منتخب کریں',
  'Select City': 'شہر منتخب کریں',
  
  // Profile View
  'Guest User': 'مہمان صارف',
  'Browsing without an account': 'بغیر اکاؤنٹ کے براؤزنگ',
  'Unlock Full Access': 'مکمل رسائی حاصل کریں',
  'Sign in to save vendors, manage bookings, access your ledger, and get personalized recommendations.': 'وینڈرز کو محفوظ کرنے، بکنگز کا انتظام کرنے اور لیجر تک رسائی کے لیے سائن ان کریں۔',
  'Sign In / Create Account': 'سائن ان / اکاؤنٹ بنائیں',
  'Saved Vendors': 'محفوظ کردہ وینڈرز',
  'My Bookings': 'میری بکنگز',
  'Settings': 'ترتیبات',
  'Log Out': 'لاگ آؤٹ',
  
  // Settings View
  'ACCOUNT': 'اکاؤنٹ',
  'PREFERENCES': 'ترجیحات',
  'Push Notifications': 'پش اطلاعات',
  'Receive updates about vendors & bookings': 'وینڈرز اور بکنگز کے بارے میں اپڈیٹس حاصل کریں',
  'Language': 'زبان',
  
  // Extra specific strings
  'Browsing as Guest': 'بطور مہمان',
  'Limited access mode': 'محدود رسائی',
  'Sign In': 'سائن ان',
  'Create Account': 'اکاؤنٹ بنائیں',
  
  // Settings additions
  'SYSTEM': 'سسٹم',
  'About ShadiSphere': 'شادی سفیئر کے بارے میں',
  'Privacy Policy': 'پرائیویسی پالیسی',
  'Terms of Service': 'سروس کی شرائط',
  'Confirm Log Out': 'لاگ آؤٹ کی تصدیق کریں',
  'Are you sure you want to log out from ShadiSphere?': 'کیا آپ واقعی شادی سفیئر سے لاگ آؤٹ کرنا چاہتے ہیں؟',
  'Cancel': 'منسوخ کریں',
  'Close': 'بند کریں',
  'PORTAL ACCESS': 'پورٹل تک رسائی',
  'Switch to Vendor Panel': 'وینڈر پینل پر جائیں',
  'Manage your vendor dashboard': 'اپنے وینڈر ڈیش بورڈ کا نظم کریں',
  'Switch to Admin Panel': 'ایڈمن پینل پر جائیں',
  'Access admin controls': 'ایڈمن کنٹرولز تک رسائی حاصل کریں',
  'CONSUMER': 'صارف',
  'VENDOR': 'وینڈر',
  'ADMIN': 'ایڈمن',
};
