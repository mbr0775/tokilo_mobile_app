// lib/features/home/screens/components/home_showcase_section.dart
//
// FIXED: "View All" and card taps now navigate to /portfolio correctly.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/portal/models/client_project_model.dart';

class HomeShowcaseSection extends StatefulWidget {
  const HomeShowcaseSection({super.key});

  @override
  State<HomeShowcaseSection> createState() => _HomeShowcaseSectionState();
}

class _HomeShowcaseSectionState extends State<HomeShowcaseSection> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _showcase   = [];
  List<ClientProjectModel>   _myProjects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final showcaseData = await _supabase
          .from('project_showcase')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      final uid = _supabase.auth.currentUser?.id;
      List<ClientProjectModel> myProjects = [];
      if (uid != null) {
        final myData = await _supabase
            .from('client_projects')
            .select()
            .eq('client_id', uid)
            .order('created_at', ascending: false)
            .limit(10);
        myProjects = (myData as List)
            .map((e) => ClientProjectModel.fromMap(e))
            .toList();
      }

      if (mounted) {
        setState(() {
          _showcase   = List<Map<String, dynamic>>.from(showcaseData);
          _myProjects = myProjects;
          _loading    = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2)),
      );
    }

    if (_showcase.isEmpty && _myProjects.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4, height: 20,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('Project Showcase',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ],
                ),
                GestureDetector(
                  onTap: () => context.go('/portfolio'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View All',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 10, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_showcase.isNotEmpty)
            SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _showcase.length,
                itemBuilder: (_, i) => _ShowcaseCard(item: _showcase[i]),
              ),
            ),

          if (_myProjects.isNotEmpty) ...[
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_rounded,
                            color: Colors.white, size: 13),
                        SizedBox(width: 5),
                        Text('Your Projects',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_myProjects.length} project${_myProjects.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 155,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _myProjects.length,
                itemBuilder: (_, i) =>
                    _MyProjectCard(project: _myProjects[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ShowcaseCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item['image_url'] as String?;
    final title    = item['title'] ?? 'Project';
    final subtitle = item['subtitle'] as String?;

    return GestureDetector(
      onTap: () => context.go('/portfolio'),
      child: Container(
        width: 270,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback())
                  : _fallback(),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14, right: 14, bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (subtitle != null && subtitle.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(subtitle,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Positioned(
                top: 12, right: 12,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.open_in_new_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF03404E), Color(0xFF06768D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
            child: Icon(Icons.work_rounded,
                color: Colors.white24, size: 48)),
      );
}

class _MyProjectCard extends StatelessWidget {
  final ClientProjectModel project;
  const _MyProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        Color(int.parse('0xFF${project.statusColorHex}'));

    return GestureDetector(
      onTap: () => context.go('/portal'),
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(project.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(project.statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(project.requestTypeLabel,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: project.progress / 100,
                backgroundColor: AppColors.border,
                color: statusColor,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progress',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textHint)),
                Text('${project.progress}%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}