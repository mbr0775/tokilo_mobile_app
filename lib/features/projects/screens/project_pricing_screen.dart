// lib/features/projects/screens/project_pricing_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';

Color _colorFromHex(String? rawHex) {
  final clean = (rawHex ?? '').replaceAll('#', '').trim();

  if (clean.length == 6) {
    try {
      return Color(int.parse('0xFF$clean'));
    } catch (_) {
      return AppColors.primary;
    }
  }

  return AppColors.primary;
}

class ProjectPricingScreen extends StatefulWidget {
  const ProjectPricingScreen({super.key});

  @override
  State<ProjectPricingScreen> createState() => _ProjectPricingScreenState();
}

class _ProjectPricingScreenState extends State<ProjectPricingScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  int _selectedCategory = 0;

  final List<String> _categories = const [
    'All',
    'Software Development',
    'AI & Automation',
    'Cloud, DevOps & SRE',
    'API & Systems Integration',
    'Digital Marketing & Growth',
    'Maintenance & Support',
  ];

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    setState(() => _isLoading = true);

    try {
      final data = await _supabase
          .from('service_pricing')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      if (!mounted) return;

      setState(() {
        _items = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _items = [];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    final selected = _categories[_selectedCategory];

    if (selected == 'All') return _items;

    return _items.where((item) {
      return item['category']?.toString() == selected;
    }).toList();
  }

  void _openDetails(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return _PricingDetailsSheet(
          item: item,
          onRequest: () {
            Navigator.pop(context);
            context.go('/portal');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadPricing,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(onRequest: () => context.go('/portal')),
            ),
            SliverToBoxAdapter(
              child: _CategoryScroller(
                categories: _categories,
                selectedIndex: _selectedCategory,
                onChanged: (index) {
                  setState(() => _selectedCategory = index);
                },
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(onRefresh: _loadPricing),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];

                    return _PricingSquareCard(
                      item: item,
                      onTap: () => _openDetails(item),
                      onRequest: () => context.go('/portal'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onRequest;

  const _Header({required this.onRequest});

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Built for your business.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore services and find your starting point.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRequest,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Need a custom solution?'),
          ),
        ],
      ),
    ),
  );
}

class _CategoryScroller extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _CategoryScroller({
    required this.categories,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;

          return GestureDetector(
            onTap: () => onChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                categories[index],
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PricingSquareCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onRequest;

  const _PricingSquareCard({
    required this.item,
    required this.onTap,
    required this.onRequest,
  });

  Color get _color {
    return _colorFromHex(item['color_hex']?.toString());
  }

  IconData get _icon {
    final key = item['icon_key']?.toString() ?? 'code';

    switch (key) {
      case 'web':
        return Icons.language_rounded;
      case 'mobile':
        return Icons.phone_android_rounded;
      case 'ai':
        return Icons.smart_toy_rounded;
      case 'cloud':
        return Icons.cloud_rounded;
      case 'api':
        return Icons.hub_rounded;
      case 'marketing':
        return Icons.campaign_rounded;
      case 'maintenance':
        return Icons.handyman_rounded;
      default:
        return Icons.code_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final title = item['title']?.toString().trim() ?? 'Service';
    final category = item['category']?.toString().trim() ?? '';
    final price = item['price_label']?.toString().trim() ?? '';
    final duration = item['duration_label']?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.3,
                            ),
                          ),
                          if (category.isNotEmpty)
                            Text(
                              category,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (price.isNotEmpty)
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      color: color,
                      letterSpacing: -.5,
                    ),
                  ),
                if (duration.isNotEmpty)
                  Text(
                    duration,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: [
                    TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      label: const Text('Package details'),
                    ),
                    TextButton.icon(
                      onPressed: onRequest,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Request'),
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

class _PricingDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRequest;

  const _PricingDetailsSheet({required this.item, required this.onRequest});

  Color get _color {
    return _colorFromHex(item['color_hex']?.toString());
  }

  List<String> get _features {
    final raw = item['features'];

    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }

    return [];
  }

  IconData get _icon {
    final key = item['icon_key']?.toString() ?? 'code';

    switch (key) {
      case 'web':
        return Icons.language_rounded;
      case 'mobile':
        return Icons.phone_android_rounded;
      case 'ai':
        return Icons.smart_toy_rounded;
      case 'cloud':
        return Icons.cloud_rounded;
      case 'api':
        return Icons.hub_rounded;
      case 'marketing':
        return Icons.campaign_rounded;
      case 'maintenance':
        return Icons.handyman_rounded;
      default:
        return Icons.code_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final color = _color;

    final title = item['title']?.toString().trim() ?? 'Service';
    final category = item['category']?.toString().trim() ?? '';
    final description = item['short_description']?.toString().trim() ?? '';
    final price = item['price_label']?.toString().trim() ?? '';
    final duration = item['duration_label']?.toString().trim() ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 14, 20, bottomSafe + 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(_icon, color: color, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 21,
                            height: 1.12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (category.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            category,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textHint,
                      size: 28,
                    ),
                  ),
                ],
              ),
              if (price.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.72)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          price,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (duration.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            duration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (_features.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Text(
                  'What is included',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ..._features.map((feature) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: color,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onRequest,
                child: Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Text(
                      'Request This Service',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.payments_outlined,
              color: AppColors.primary.withValues(alpha: 0.25),
              size: 80,
            ),
            const SizedBox(height: 16),
            const Text(
              'No pricing packages yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add pricing packages from the Admin Panel.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRefresh, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}
