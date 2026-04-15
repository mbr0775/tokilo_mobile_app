// lib/features/hub/components/hub_services_marketplace.dart
//
// Shows BOTH:
//   1. portfolio table        — admin manually added projects
//   2. client_projects table  — admin approved client requests
//        (status = 'approved' | 'in_progress' | 'completed')
//
// Layout: Horizontal PageView slider — side by side cards with snap

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../admin/models/portfolio_model.dart';
import '../constants/hub_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UNIFIED DISPLAY MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _DisplayProject {
  final String  id;
  final String  title;
  final String? clientName;
  final String? category;
  final String? description;
  final String? imageUrl;
  final String? originalPrice;
  final String? agreedPrice;
  final String? technologies;
  final String  status;
  final String? completedAt;
  final DateTime createdAt;
  final bool    isClientRequest;

  const _DisplayProject({
    required this.id,
    required this.title,
    this.clientName,
    this.category,
    this.description,
    this.imageUrl,
    this.originalPrice,
    this.agreedPrice,
    this.technologies,
    required this.status,
    this.completedAt,
    required this.createdAt,
    required this.isClientRequest,
  });

  factory _DisplayProject.fromPortfolio(PortfolioModel p) => _DisplayProject(
        id: p.id, title: p.title, clientName: p.clientName,
        category: p.category, description: p.description,
        imageUrl: p.imageUrl, originalPrice: p.originalPrice,
        agreedPrice: p.agreedPrice, technologies: p.technologies,
        status: p.status, completedAt: p.completedAt,
        createdAt: p.createdAt, isClientRequest: false,
      );

  factory _DisplayProject.fromClientProject(Map<String, dynamic> m) =>
      _DisplayProject(
        id: m['id'] ?? '', title: m['title'] ?? '',
        clientName: m['client_name'] ?? m['client_email'],
        category: m['category'],
        description: m['description'] ?? m['admin_notes'],
        imageUrl: m['image_url'], originalPrice: null, agreedPrice: null,
        technologies: m['technologies'], status: m['status'] ?? 'approved',
        completedAt: m['completed_at'],
        createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
        isClientRequest: true,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class HubServicesMarketplace extends StatefulWidget {
  const HubServicesMarketplace({super.key});

  @override
  State<HubServicesMarketplace> createState() => _HubServicesMarketplaceState();
}

class _HubServicesMarketplaceState extends State<HubServicesMarketplace> {
  final _supabase    = Supabase.instance.client;
  final _pageCtrl    = PageController(viewportFraction: 0.82);

  List<_DisplayProject> _all        = [];
  bool                  _loading    = true;
  int                   _selected   = 0; // category index
  int                   _currentPage = 0;
  List<String>          _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _load();
    _pageCtrl.addListener(() {
      final page = _pageCtrl.page?.round() ?? 0;
      if (page != _currentPage) setState(() => _currentPage = page);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final portfolioData = await _supabase
          .from('portfolio').select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final portfolioProjects = (portfolioData as List)
          .map((e) => _DisplayProject.fromPortfolio(PortfolioModel.fromMap(e)))
          .toList();

      final clientData = await _supabase
          .from('client_projects').select()
          .inFilter('status', ['approved', 'in_progress', 'completed'])
          .order('created_at', ascending: false);

      final clientProjects = (clientData as List)
          .map((e) => _DisplayProject.fromClientProject(e))
          .toList();

      final merged = [...portfolioProjects, ...clientProjects]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final cats = <String>{'All'};
      for (final p in merged) {
        if (p.category != null && p.category!.isNotEmpty) cats.add(p.category!);
      }

      if (mounted) {
        setState(() {
          _all        = merged;
          _categories = cats.toList();
          _loading    = false;
          _currentPage = 0;
        });
        // Reset slider to first card when data loads
        if (_pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(0);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_DisplayProject> get _filtered {
    if (_selected == 0 || _selected >= _categories.length) return _all;
    final cat = _categories[_selected];
    return _all.where((p) => p.category == cat).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF06768D), Color(0xFF0A9CB5)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                    SizedBox(width: 5),
                    Text('PORTFOLIO',
                        style: TextStyle(color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Our Projects',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                          color: Color(0xFF0D1B2A), letterSpacing: -0.8, height: 1.1)),
                  if (!_loading && _all.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06768D).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF06768D).withOpacity(0.2)),
                      ),
                      child: Text('${_filtered.length} total',
                          style: const TextStyle(fontSize: 11,
                              color: Color(0xFF06768D), fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Real work. Real results. See what we\'ve built.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
            ],
          ),
        ),

        if (_loading)
          _ShimmerSlider()
        else if (_all.isEmpty)
          const _EmptyState()
        else ...[
          // ── Category chips ──────────────────────────────
          HubCategoryBar(
            categories: _categories,
            selected: _selected,
            onSelect: (i) {
              setState(() {
                _selected    = i;
                _currentPage = 0;
              });
              _pageCtrl.jumpToPage(0);
            },
          ),
          const SizedBox(height: 18),

          // ── HORIZONTAL SLIDER ───────────────────────────
          SizedBox(
            height: 380,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: _filtered.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (_, i) => _ProjectCard(
                project: _filtered[i],
                isActive: i == _currentPage,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Dot indicators ──────────────────────────────
          if (_filtered.length > 1)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_filtered.length, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF06768D)
                          : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

          const SizedBox(height: 12),

          // ── Legend ──────────────────────────────────────
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendDot(color: const Color(0xFF06768D), label: 'Our Work'),
                const SizedBox(width: 16),
                _LegendDot(color: const Color(0xFF8B5CF6), label: 'Client Projects'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEGEND DOT
// ─────────────────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF),
          fontWeight: FontWeight.w500)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY BAR
// ─────────────────────────────────────────────────────────────────────────────
class HubCategoryBar extends StatelessWidget {
  final List<String> categories;
  final int selected;
  final void Function(int) onSelect;

  const HubCategoryBar({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = selected == i;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: sel ? const LinearGradient(
                    colors: [Color(0xFF03404E), Color(0xFF06768D)]) : null,
                color: sel ? null : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: sel ? Colors.transparent : const Color(0xFFE5E7EB),
                    width: 1.5),
                boxShadow: sel
                    ? [BoxShadow(color: const Color(0xFF06768D).withOpacity(0.35),
                        blurRadius: 12, offset: const Offset(0, 4))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.04),
                        blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Center(
                child: Text(categories[i],
                    style: TextStyle(
                        color: sel ? Colors.white : const Color(0xFF6B7280),
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROJECT CARD — snapping slide card
// ─────────────────────────────────────────────────────────────────────────────
class _ProjectCard extends StatelessWidget {
  final _DisplayProject project;
  final bool isActive;
  const _ProjectCard({required this.project, required this.isActive});

  LinearGradient _gradientForCategory(String? cat) {
    switch (cat) {
      case 'Software Development':
        return const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF2D6A9F)]);
      case 'Retail Technology':
        return const LinearGradient(colors: [Color(0xFF1A3C34), Color(0xFF2D7A5F)]);
      case 'IT Infrastructure':
        return const LinearGradient(colors: [Color(0xFF03404E), Color(0xFF06768D)]);
      case 'Cyber Security':
        return const LinearGradient(colors: [Color(0xFF2D1B4E), Color(0xFF5B3B8A)]);
      case 'Physical Security':
        return const LinearGradient(colors: [Color(0xFF3D1A1A), Color(0xFF8A3B3B)]);
      case 'Cloud & DevOps':
        return const LinearGradient(colors: [Color(0xFF1A2D4E), Color(0xFF2D4E8A)]);
      case 'AI & Automation':
        return const LinearGradient(colors: [Color(0xFF1A1A3D), Color(0xFF3B2D8A)]);
      default:
        return const LinearGradient(colors: [Color(0xFF03404E), Color(0xFF06768D)]);
    }
  }

  IconData _iconForCategory(String? cat) {
    switch (cat) {
      case 'Software Development': return Icons.code_rounded;
      case 'Retail Technology':    return Icons.storefront_rounded;
      case 'IT Infrastructure':    return Icons.router_rounded;
      case 'Cyber Security':       return Icons.security_rounded;
      case 'Physical Security':    return Icons.videocam_rounded;
      case 'Cloud & DevOps':       return Icons.cloud_rounded;
      case 'AI & Automation':      return Icons.smart_toy_rounded;
      default:                     return Icons.work_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'in_progress':
      case 'ongoing':   return const Color(0xFF3B82F6);
      case 'approved':  return const Color(0xFF10B981);
      case 'upcoming':  return const Color(0xFFF59E0B);
      default:          return const Color(0xFF10B981);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress': return '● In Progress';
      case 'ongoing':     return '● Ongoing';
      case 'approved':    return '✓ Approved';
      case 'upcoming':    return '◆ Upcoming';
      default:            return '✓ Completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p           = project;
    final gradient    = _gradientForCategory(p.category);
    final hasOriginal = p.originalPrice != null && p.originalPrice!.isNotEmpty;
    final hasAgreed   = p.agreedPrice   != null && p.agreedPrice!.isNotEmpty;
    final statusColor = _statusColor(p.status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(
        left: 8, right: 8,
        top: isActive ? 0 : 16,      // inactive cards appear lower
        bottom: isActive ? 0 : 0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: p.isClientRequest
              ? const Color(0xFF8B5CF6).withOpacity(0.3)
              : const Color(0xFFE5E7EB),
          width: p.isClientRequest ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8)),
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8,  offset: const Offset(0, 2)),
              ]
            : [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // ── Hero ────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image or gradient
                  p.imageUrl != null && p.imageUrl!.isNotEmpty
                      ? Image.network(p.imageUrl!, fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) => progress == null
                              ? child
                              : Container(decoration: BoxDecoration(gradient: gradient),
                                  child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
                          errorBuilder: (_, __, ___) =>
                              _GradientBanner(gradient: gradient, icon: _iconForCategory(p.category)))
                      : _GradientBanner(gradient: gradient, icon: _iconForCategory(p.category)),

                  // Bottom fade
                  Positioned(bottom: 0, left: 0, right: 0,
                      child: Container(height: 70,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xBB000000)])))),

                  // Category badge — top left
                  Positioned(top: 10, left: 10,
                      child: _GlassBadge(
                        label: p.category ?? 'Project',
                        color: p.isClientRequest ? const Color(0xFF8B5CF6) : const Color(0xFF06768D),
                        icon: p.isClientRequest ? Icons.person_rounded : Icons.verified_rounded,
                      )),

                  // Status — top right
                  Positioned(top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: statusColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))]),
                        child: Text(_statusLabel(p.status),
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      )),
                ],
              ),
            ),

            // ── Info ────────────────────────────────────────
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(p.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                            color: Color(0xFF0D1B2A), letterSpacing: -0.3, height: 1.2),
                        maxLines: 1, overflow: TextOverflow.ellipsis),

                    // Client
                    if (p.clientName != null && p.clientName!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.business_rounded, size: 12,
                            color: p.isClientRequest ? const Color(0xFF8B5CF6) : const Color(0xFF9CA3AF)),
                        const SizedBox(width: 5),
                        Expanded(child: Text(p.clientName!,
                            style: TextStyle(fontSize: 12,
                                color: p.isClientRequest ? const Color(0xFF8B5CF6) : const Color(0xFF6B7280),
                                fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ],

                    // Description
                    if (p.description != null && p.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(p.description!,
                            style: const TextStyle(fontSize: 11.5,
                                color: Color(0xFF9CA3AF), height: 1.4),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ] else
                      const Spacer(),

                    // Divider
                    Container(margin: const EdgeInsets.symmetric(vertical: 8),
                        height: 1, color: const Color(0xFFF3F4F6)),

                    // Price + date
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hasAgreed) ...[
                          if (hasOriginal) ...[
                            Text('QAR ${p.originalPrice}',
                                style: const TextStyle(fontSize: 10,
                                    color: Color(0xFFD1D5DB),
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Color(0xFFD1D5DB))),
                            const SizedBox(width: 4),
                          ],
                          Text('QAR ${p.agreedPrice}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                                  color: Color(0xFF06768D), letterSpacing: -0.2)),
                        ] else
                          const SizedBox.shrink(),

                        const Spacer(),

                        if (p.completedAt != null && p.completedAt!.isNotEmpty)
                          Row(children: [
                            const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 3),
                            Text(p.completedAt!,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w500)),
                          ]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRADIENT BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _GradientBanner extends StatelessWidget {
  final LinearGradient gradient;
  final IconData icon;
  const _GradientBanner({required this.gradient, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(children: [
        Positioned(top: -30, right: -30,
            child: Container(width: 120, height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06)))),
        Positioned(bottom: -20, left: -20,
            child: Container(width: 90, height: 90,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04)))),
        Center(child: Container(width: 56, height: 56,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.2))),
            child: Icon(icon, color: Colors.white.withOpacity(0.9), size: 26))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _GlassBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _GlassBadge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      constraints: const BoxConstraints(maxWidth: 160),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w600, letterSpacing: 0.2),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER SLIDER LOADING
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerSlider extends StatefulWidget {
  @override
  State<_ShimmerSlider> createState() => _ShimmerSliderState();
}

class _ShimmerSliderState extends State<_ShimmerSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer = LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end:   Alignment(_anim.value + 1, 0),
          colors: const [Color(0xFFEEEEEE), Color(0xFFF8F8F8), Color(0xFFEEEEEE)],
        );
        return SizedBox(
          height: 380,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            itemBuilder: (_, __) => Container(
              width: MediaQuery.of(context).size.width * 0.78,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Column(children: [
                Expanded(flex: 5, child: Container(
                    decoration: BoxDecoration(gradient: shimmer,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))))),
                Expanded(flex: 4, child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 16, width: 180, decoration: BoxDecoration(gradient: shimmer, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 10),
                    Container(height: 11, width: 120, decoration: BoxDecoration(gradient: shimmer, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(height: 11, width: double.infinity, decoration: BoxDecoration(gradient: shimmer, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(height: 11, width: 160, decoration: BoxDecoration(gradient: shimmer, borderRadius: BorderRadius.circular(4))),
                  ]),
                )),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Center(child: Column(children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF03404E), Color(0xFF06768D)]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: const Color(0xFF06768D).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.work_outline_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        const Text('No Projects Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0D1B2A))),
        const SizedBox(height: 8),
        const Text('Our completed projects will\nappear here soon.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.5)),
      ])),
    );
  }
}