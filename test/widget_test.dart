import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadi_sphere/main.dart';
import 'package:shadi_sphere/core/routing/app_router.dart';
import 'package:shadi_sphere/features/consumer/presentation/consumer_providers.dart';
import 'package:shadi_sphere/features/vendor_dashboard/presentation/vendor_shell.dart';
import 'package:shadi_sphere/features/admin/presentation/admin_shell.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = MockHttpOverrides();
  });

  testWidgets('ShadiSphereApp starts and shows splash screen elements', (WidgetTester tester) async {
    goRouter.go('/');
    // Build our app and trigger a frame.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        allVendorsProvider.overrideWith((ref) => Stream.value(localDummyVendors)),
      ],
      child: const ShadiSphereApp(),
    ));

    // Verify that our splash screen text elements are rendered.
    expect(find.text('SS'), findsOneWidget);
    expect(find.text('Shadi\nSphere'), findsOneWidget);
    expect(find.text('Plan Perfect. Celebrate\nBeautifully.'), findsOneWidget);

    // Allow the 3-second navigation timer in SplashScreen to execute and finish
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('ShadiSphereApp navigates to DiscoverView and shows checklist and guides', (WidgetTester tester) async {
    goRouter.go('/');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        allVendorsProvider.overrideWith((ref) => Stream.value(localDummyVendors)),
      ],
      child: const ShadiSphereApp(),
    ));
    
    // Fast forward splash screen navigation to WelcomeScreen
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Tap Browse as Guest to navigate to DiscoverView
    final browseAsGuest = find.text('Browse as Guest');
    expect(browseAsGuest, findsOneWidget);
    await tester.tap(browseAsGuest);
    await tester.pumpAndSettle();

    // Verify we are on DiscoverView
    expect(find.text('Wedding Planning Checklist'), findsOneWidget);
    expect(find.text('Trending Guides & Ideas'), findsOneWidget);

    // Find checklist task and toggle it
    final taskText = find.text('Secure a dream venue');
    expect(taskText, findsOneWidget);
    
    // Find checkboxes and tap one
    final checkbox = find.byType(Checkbox).first;
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
  });

  testWidgets('ShadiSphereApp performs search on DiscoverView', (WidgetTester tester) async {
    goRouter.go('/');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        allVendorsProvider.overrideWith((ref) => Stream.value(localDummyVendors)),
      ],
      child: const ShadiSphereApp(),
    ));
    
    // Fast forward splash screen navigation to WelcomeScreen
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Tap Browse as Guest to navigate to DiscoverView
    final browseAsGuest = find.text('Browse as Guest');
    await tester.tap(browseAsGuest);
    await tester.pumpAndSettle();

    // Verify search bar is present and type a query
    final searchBar = find.byType(TextField).first;
    expect(searchBar, findsOneWidget);
    
    // Enter search text "marquee"
    await tester.enterText(searchBar, 'marquee');
    await tester.pumpAndSettle();

    // Verify search results are displayed
    expect(find.text('Search Results for "marquee"'), findsOneWidget);
    expect(find.text('Matching Vendors'), findsOneWidget);
    expect(find.text('Matching Guides & Ideas'), findsOneWidget);

    // Verify we can find a matching vendor
    expect(find.text('Royal Palace Marquee'), findsOneWidget);

    // Clear search
    final clearButton = find.text('Clear');
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    // Verify we are back on regular DiscoverView content
    expect(find.text('Wedding Planning Checklist'), findsOneWidget);
  });

  testWidgets('VendorShell loads and displays inquiries correctly, allows accepting and rejecting inquiries', (WidgetTester tester) async {
    goRouter.go('/vendor');
    await tester.pumpWidget(ProviderScope(
      child: const ShadiSphereApp(),
    ));
    await tester.pumpAndSettle();

    // Verify Vendor Dashboard is loaded
    expect(find.textContaining('Vendor Dashboard'), findsOneWidget);
    expect(find.text('Booking Inquiries'), findsOneWidget);

    // Verify inquiries are shown (from default state)
    expect(find.text('Ahmed Khan'), findsOneWidget);
    expect(find.text('Zara Sheikh'), findsOneWidget);

    // Tap Accept on the first inquiry ("Ahmed Khan")
    final acceptButton = find.descendant(
      of: find.widgetWithText(Card, 'Ahmed Khan'),
      matching: find.widgetWithText(ElevatedButton, 'Accept'),
    );
    expect(acceptButton, findsOneWidget);
    await tester.ensureVisible(acceptButton);
    await tester.tap(acceptButton);
    await tester.pumpAndSettle();

    // Verify Ahmed Khan's status changes to 'Accepted'
    expect(find.text('Accepted'), findsOneWidget);

    // Tap Reject on "Zara Sheikh"
    final rejectButton = find.descendant(
      of: find.widgetWithText(Card, 'Zara Sheikh'),
      matching: find.widgetWithText(TextButton, 'Reject'),
    );
    expect(rejectButton, findsOneWidget);
    await tester.ensureVisible(rejectButton);
    await tester.tap(rejectButton);
    await tester.pumpAndSettle();

    // Verify the dialog opens
    expect(find.text('Reject Inquiry'), findsOneWidget);
    
    // Tap the Reject button inside the dialog
    final confirmRejectButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Reject'),
    );
    await tester.tap(confirmRejectButton);
    await tester.pumpAndSettle();

    // Verify Zara Sheikh's status changes to 'Rejected'
    expect(find.text('Rejected'), findsOneWidget);

    // Navigate to Analytics tab to verify real-time computed updates
    final analyticsTab = find.descendant(
      of: find.byType(TabBar),
      matching: find.text('Analytics'),
    );
    await tester.tap(analyticsTab);
    await tester.pumpAndSettle();

    // Earnings: 1.45M + 450k = 1.90M
    expect(find.text('Rs. 1.90M'), findsOneWidget);
    // Completed Bookings: 12 + 1 = 13 Requests
    expect(find.text('13 Requests'), findsOneWidget);
    // Conversion Rate: 13 / 14 = 93%
    expect(find.text('93%'), findsOneWidget);
  });

  testWidgets('VendorShell catalog tab allows media upload and adding a package', (WidgetTester tester) async {
    goRouter.go('/vendor');
    await tester.pumpWidget(ProviderScope(
      child: const ShadiSphereApp(),
    ));
    await tester.pumpAndSettle();

    // Navigate to Catalog tab
    final catalogTab = find.descendant(
      of: find.byType(TabBar),
      matching: find.text('Catalog'),
    );
    await tester.tap(catalogTab);
    await tester.pumpAndSettle();

    // Verify catalog tab content loaded
    expect(find.text('Catalog & Packages'), findsOneWidget);
    expect(find.text('Simulate Media Upload'), findsOneWidget);

    // Tap Simulate Media Upload
    await tester.tap(find.text('Simulate Media Upload'));
    await tester.pumpAndSettle();

    // Verify bottom sheet shows up
    expect(find.text('Select Media to Upload (Mock)'), findsOneWidget);

    // Tap the first mock image item in the list inside bottom sheet
    final mockImage = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(GestureDetector),
    ).first;
    await tester.tap(mockImage);
    await tester.pumpAndSettle();

    // Verify Snackbar shows
    expect(find.text('High-res media uploaded to catalog!'), findsOneWidget);

    // Clear snackbars to prevent obscuring the button
    ScaffoldMessenger.of(tester.element(find.byType(VendorShell))).clearSnackBars();
    await tester.pumpAndSettle();

    // Verify Add Package Dialog
    final addPackageBtn = find.widgetWithText(ElevatedButton, 'Add Package Tier');
    await tester.ensureVisible(addPackageBtn);
    await tester.tap(addPackageBtn);
    await tester.pumpAndSettle();

    // Check Dialog
    expect(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Add Package Tier'),
    ), findsOneWidget);

    // Enter details
    final dialogTextFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogTextFields.at(0), 'Platinum Premium Tier');
    await tester.enterText(dialogTextFields.at(1), 'Rs. 7,000 / head');
    await tester.enterText(dialogTextFields.at(2), 'All inclusive luxury decoration and food');
    
    // Tap Add Tier button
    final addTierBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Add Tier'),
    );
    await tester.tap(addTierBtn);
    await tester.pumpAndSettle();

    // Verify package is added to the list
    expect(find.text('Platinum Premium Tier'), findsOneWidget);
    expect(find.text('Rs. 7,000 / head'), findsOneWidget);
  });

  testWidgets('VendorShell analytics and settings tabs display properly and support profile updates', (WidgetTester tester) async {
    goRouter.go('/vendor');
    await tester.pumpWidget(ProviderScope(
      child: const ShadiSphereApp(),
    ));
    await tester.pumpAndSettle();

    // Navigate to Analytics tab
    final analyticsTab = find.descendant(
      of: find.byType(TabBar),
      matching: find.text('Analytics'),
    );
    await tester.tap(analyticsTab);
    await tester.pumpAndSettle();

    // Verify analytics content
    expect(find.text('Business Analytics'), findsOneWidget);
    expect(find.text('Total Earnings'), findsOneWidget);
    expect(find.text('Rs. 1.45M'), findsOneWidget);
    expect(find.text('Monthly Revenue Growth'), findsOneWidget);

    // Navigate to Settings tab
    final settingsTab = find.descendant(
      of: find.byType(TabBar),
      matching: find.text('Settings'),
    );
    await tester.tap(settingsTab);
    await tester.pumpAndSettle();

    // Verify settings content
    expect(find.text('Business Profile settings'), findsOneWidget);
    
    // Enter text into the TextFields
    final settingsFields = find.descendant(
      of: find.byType(VendorSettingsView),
      matching: find.byType(TextField),
    );
    await tester.enterText(settingsFields.at(0), 'Grand Palace Events');
    await tester.enterText(settingsFields.at(1), 'Karachi, Pakistan');

    // Tap Save Profile button
    final saveBtn = find.descendant(
      of: find.byType(VendorSettingsView),
      matching: find.widgetWithText(ElevatedButton, 'Save Profile'),
    );
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Verify success snackbar
    expect(find.text('Business profile updated successfully!'), findsOneWidget);

    // Clear active snackbar to prevent blocking the log out button
    ScaffoldMessenger.of(tester.element(find.byType(VendorShell))).clearSnackBars();
    await tester.pumpAndSettle();

    // Find the Log Out button
    final logoutBtn = find.descendant(
      of: find.byType(VendorSettingsView),
      matching: find.widgetWithText(OutlinedButton, 'Log Out'),
    );
    expect(logoutBtn, findsOneWidget);

    // Tap the Log Out button
    await tester.ensureVisible(logoutBtn);
    await tester.tap(logoutBtn);
    await tester.pumpAndSettle();

    // Verify confirmation dialog shows up
    expect(find.text('Confirm Log Out'), findsOneWidget);

    // Tap confirm "Log Out" inside dialog
    final confirmLogoutBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Log Out'),
    );
    await tester.tap(confirmLogoutBtn);
    await tester.pumpAndSettle();

    // Verify user is navigated back to the Welcome Screen
    expect(find.text('Welcome to'), findsOneWidget);
  });

  testWidgets('AdminShell loads metrics, switches tabs, reviews warnings, and checks transaction logs', (WidgetTester tester) async {
    goRouter.go('/admin');
    await tester.pumpWidget(ProviderScope(
      child: const ShadiSphereApp(),
    ));
    await tester.pumpAndSettle();

    // Verify Admin Shell is loaded
    expect(find.text('System Metrics Overview'), findsOneWidget);
    expect(find.text('Total Consumers'), findsOneWidget);
    expect(find.text('14,230'), findsOneWidget);

    // Switch to Purgatory Queue
    final purgatoryTab = find.text('Purgatory Queue');
    expect(purgatoryTab, findsOneWidget);
    await tester.tap(purgatoryTab);
    await tester.pumpAndSettle();

    // Verify moderation queue screen
    expect(find.text('Governance & Moderation'), findsOneWidget);
    expect(find.text('Royal Palace Marquee'), findsOneWidget);

    // Tap dismiss on "Royal Palace Marquee"
    final dismissBtn = find.widgetWithText(OutlinedButton, 'Dismiss').first;
    await tester.ensureVisible(dismissBtn);
    await tester.pumpAndSettle();
    await tester.tap(dismissBtn);
    await tester.pumpAndSettle();

    // Verify dialog opens
    expect(find.text('Pardon Violation'), findsOneWidget);
    
    // Confirm restore
    final confirmRestoreBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Confirm Restore'),
    );
    await tester.tap(confirmRestoreBtn);
    await tester.pumpAndSettle();

    // Verify snackbar/dismissed row is gone
    expect(find.text('Violations dismissed successfully.'), findsOneWidget);
    expect(find.text('Royal Palace Marquee'), findsNothing);

    // Clear active snackbar to prevent blocking the tab bar or other clicks
    ScaffoldMessenger.of(tester.element(find.byType(AdminShell))).clearSnackBars();
    await tester.pumpAndSettle();

    // Switch to Transaction Logs
    final transactionTab = find.text('Transaction Logs');
    await tester.tap(transactionTab);
    await tester.pumpAndSettle();

    // Verify Transaction logs screen
    expect(find.text('Monitor system checkout logs and vendor settlements.'), findsOneWidget);
    expect(find.textContaining('TX-8821'), findsOneWidget);

    // Search for TX-8824
    final searchBar = find.byType(TextField);
    await tester.enterText(searchBar, 'TX-8824');
    await tester.pumpAndSettle();

    // Verify filtered result matches Fatima Noor and hides others
    expect(find.text('Bridal Studio'), findsOneWidget);
    expect(find.text('Luxury Rides'), findsNothing);

    // Tap on row item to show details modal
    await tester.tap(find.text('Bridal Studio'));
    await tester.pumpAndSettle();

    // Verify details sheet loads
    expect(find.text('EasyPaisa'), findsOneWidget);
    expect(find.text('Dismiss Details'), findsOneWidget);

    // Tap dismiss in details sheet
    await tester.tap(find.text('Dismiss Details'));
    await tester.pumpAndSettle();
  });

  testWidgets('AuthScreen renders fields, switches between Customer/Vendor and Login/SignUp, and logs in consumer', (WidgetTester tester) async {
    goRouter.go('/welcome');
    await tester.pumpWidget(ProviderScope(
      child: const ShadiSphereApp(),
    ));
    await tester.pumpAndSettle();

    // Tap "Get Started / Log In" on welcome screen
    final getStartedBtn = find.text('Get Started / Log In');
    expect(getStartedBtn, findsOneWidget);
    await tester.tap(getStartedBtn);
    await tester.pumpAndSettle();

    // Verify on AuthScreen, Customer tab is active by default
    expect(find.text('Welcome to ShadiSphere'), findsOneWidget);
    expect(find.text('Sign in to access your dashboard'), findsOneWidget);

    // Try to click Log In with empty fields to trigger validation
    final loginBtn = find.widgetWithText(ElevatedButton, 'Log In');
    await tester.tap(loginBtn);
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);

    // Switch to Sign Up mode
    final signUpToggle = find.widgetWithText(TextButton, 'Sign Up');
    await tester.ensureVisible(signUpToggle);
    await tester.tap(signUpToggle);
    await tester.pumpAndSettle();
    expect(find.text('Join ShadiSphere'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Phone Number'), findsOneWidget);

    // Switch to Vendor tab
    final vendorTab = find.text('Vendor');
    await tester.tap(vendorTab);
    await tester.pumpAndSettle();
    expect(find.text('Business Name'), findsOneWidget);
    expect(find.text('Business Category'), findsOneWidget);

    // Toggle back to Login
    final loginToggle = find.widgetWithText(TextButton, 'Log In');
    await tester.ensureVisible(loginToggle);
    await tester.tap(loginToggle);
    await tester.pumpAndSettle();

    // Enter login details and submit
    final emailField = find.widgetWithText(TextFormField, 'Email Address').first;
    final passwordField = find.widgetWithText(TextFormField, 'Password').first;
    await tester.enterText(emailField, 'test@shadisphere.com');
    await tester.enterText(passwordField, 'password123');
    await tester.pumpAndSettle();

    final submitBtn = find.widgetWithText(ElevatedButton, 'Log In');
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify successful login navigates to consumer discovery view
    expect(find.text('Wedding Planning Checklist'), findsOneWidget);
  });

  testWidgets('AuthScreen logs in admin and navigates to admin portal', (WidgetTester tester) async {
    goRouter.go('/welcome');
    await tester.pumpWidget(ProviderScope(
      child: const ShadiSphereApp(),
    ));
    await tester.pumpAndSettle();

    // Tap "Get Started / Log In" on welcome screen
    final getStartedBtn = find.text('Get Started / Log In');
    await tester.tap(getStartedBtn);
    await tester.pumpAndSettle();

    // Enter admin login details and submit
    final emailField = find.widgetWithText(TextFormField, 'Email Address').first;
    final passwordField = find.widgetWithText(TextFormField, 'Password').first;
    await tester.enterText(emailField, 'admin@shadisphere.com');
    await tester.enterText(passwordField, 'admin123');
    await tester.pumpAndSettle();

    final submitBtn = find.widgetWithText(ElevatedButton, 'Log In');
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify successful login navigates to admin shell overview
    expect(find.text('System Metrics Overview'), findsOneWidget);
  });
}

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUrl || invocation.memberName == #openUrl) {
      return Future.value(MockHttpClientRequest());
    }
    return null;
  }
}

class MockHttpClientRequest implements HttpClientRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #close) {
      return Future.value(MockHttpClientResponse());
    }
    if (invocation.memberName == #headers) {
      return MockHttpHeaders();
    }
    return null;
  }
}

class MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockHttpClientResponse implements HttpClientResponse {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #statusCode) return 200;
    if (invocation.memberName == #compressionState) {
      return HttpClientResponseCompressionState.notCompressed;
    }
    if (invocation.memberName == #contentLength) return transparentImage.length;
    if (invocation.memberName == #listen) {
      final Function onData = invocation.positionalArguments[0];
      final Function? onDone = invocation.namedArguments[#onDone];
      final Function? onError = invocation.namedArguments[#onError];
      final bool? cancelOnError = invocation.namedArguments[#cancelOnError];
      
      return Stream<List<int>>.fromIterable([transparentImage]).listen(
        onData as void Function(List<int>)?,
        onError: onError,
        onDone: onDone as void Function()?,
        cancelOnError: cancelOnError,
      );
    }
    return null;
  }
}

final List<int> transparentImage = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82
];
