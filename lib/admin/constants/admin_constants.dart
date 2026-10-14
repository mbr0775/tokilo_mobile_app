// lib/admin/constants/admin_constants.dart

class AdminConstants {
  // Admin email — navigates to Admin Panel on login
  static const String adminEmail = 'mubassirnasar@gmail.com';

  // Supabase storage bucket
  static const String storageBucket = 'tokilo-media';

  // Storage folders
  static const String servicesFolder = 'services';
  static const String projectsFolder = 'projects';
  static const String showcaseFolder = 'showcase';

  // Software / project service categories
  static const List<String> serviceCategories = [
    'Website Development',
    'Mobile App Development',
    'E-Commerce Development',
    'CRM / ERP System',
    'POS Software',
    'Backend & API Development',
    'UI/UX Design',
    'Cloud & DevOps',
    'AI & Automation',
    'Project Maintenance',
  ];

  // Portfolio / project categories
  static const List<String> projectCategories = [
    'Website',
    'Mobile App',
    'E-Commerce',
    'CRM / ERP',
    'POS Software',
    'Maintenance',
    'Custom Software',
  ];

  // Service tags
  static const List<String> serviceTags = [
    'Popular',
    'New',
    'Featured',
    'Maintenance',
  ];
}