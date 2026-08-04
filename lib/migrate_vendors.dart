import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final vendors = await FirebaseFirestore.instance.collection('vendors').get();
  for (var doc in vendors.docs) {
    await doc.reference.update({'hasAcceptedTerms': true});
  }
  
  final vendorProfiles = await FirebaseFirestore.instance.collection('vendor_profile').get();
  for (var doc in vendorProfiles.docs) {
    await doc.reference.update({'hasAcceptedTerms': true});
  }
  print('Migration complete!');
}
