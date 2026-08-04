# ShadiSphere

ShadiSphere is a comprehensive, multi-platform wedding planning and vendor management application built with Flutter. It streamlines the wedding planning process by connecting customers with venues, caterers, and various other vendors all in one unified ecosystem.

## 🌟 Features

ShadiSphere is built with a role-based architecture, offering tailored experiences and distinct portals for different types of users:

*   **Consumer Portal (Customer)**: 
    *   **Discover**: Browse and discover top-rated venues, caterers, and vendors.
    *   **Planner**: Manage your wedding timeline and tasks.
    *   **Ledger**: Keep track of your wedding budget and expenses.
    *   **Bookings**: Manage active, pending, and past bookings.
*   **Vendor Portals (Venue, Caterer, General Vendor)**:
    *   Dedicated dashboards to manage Pricing, Bookings, Messages, Promotions & Deals, Availability, Analytics, and Reviews.
*   **Admin Portal**:
    *   Centralized dashboard for platform analytics, user management, and vendor approvals.
*   **Real-time Notifications**: Integrated with OneSignal to provide seamless push notifications across platforms.

## 💻 Tech Stack

*   **Frontend Framework**: [Flutter](https://flutter.dev/) (Web, iOS, Android)
*   **Backend & Database**: [Firebase](https://firebase.google.com/) (Authentication, Cloud Firestore)
*   **State Management**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod`)
*   **Routing**: [GoRouter](https://pub.dev/packages/go_router)
*   **Push Notifications**: [OneSignal](https://onesignal.com/)

## 🚀 Getting Started

Follow these steps to get the project up and running on your local machine.

### Prerequisites

*   Flutter SDK (latest stable version recommended)
*   Dart SDK
*   A Firebase project setup

### Installation

1.  **Clone the repository**
    ```bash
    git clone https://github.com/luqmanaslam28/ShadiSphere.git
    cd ShadiSphere
    ```

2.  **Install dependencies**
    ```bash
    flutter pub get
    ```

3.  **Environment Variables & Secrets**
    *   Create a `.env` file in the `assets/` directory and add your GCP API keys or other required secrets (e.g., `GCP_API_KEY=your_key_here`). *Note: `.env` is intentionally ignored by git to protect your credentials.*
    *   **Push Notifications:** Open `lib/core/services/notification_service.dart` and replace the placeholder `YOUR_REST_API_KEY_HERE` with your actual OneSignal REST API key for local testing. Do not commit your API keys.

4.  **Firebase Configuration**
    *   Ensure your `lib/firebase_options.dart` is correctly configured for your specific Firebase project environments (Web, Android, iOS).

5.  **Run the app**
    ```bash
    flutter run -d chrome
    ```

## 🔐 Security Note

Please ensure you do not commit sensitive API keys or credentials. Use `.env` files and `.gitignore` to keep your secrets local.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
