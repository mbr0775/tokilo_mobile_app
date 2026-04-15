// lib/admin/constants/admin_constants.dart

class AdminConstants {
  // ✅ Admin email — navigates to Admin Panel on login
  static const String adminEmail = 'mubassirnasar@gmail.com';

  // Supabase storage bucket
  static const String storageBucket = 'tokilo-media';

  // Storage folders
  static const String servicesFolder  = 'services';
  static const String productsFolder  = 'products';

  // Service categories
  static const List<String> serviceCategories = [
    'Digital',
    'IT Services',
    'Consultation',
    'Hardware',
    'Software',
    'Infrastructure',
  ];

  // Product categories
  static const List<String> productCategories = [
    'Surveillance',
    'Networking',
    'Cabling',
    'Hardware',
    'Power',
    'Accessories',
  ];

  // Service tags
  static const List<String> serviceTags = [
    'Popular',
    'Hot',
    'New',
    'Featured',
  ];
}