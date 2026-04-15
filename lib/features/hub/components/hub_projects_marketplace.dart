// lib/features/hub/components/hub_projects_marketplace.dart
//
// Fetches the current user projects from client_projects table.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../features/portal/models/client_project_model.dart';
import '../constants/hub_colors.dart';

class HubProjectsMarketplace extends StatefulWidget {
  const HubProjectsMarketplace({super.key});

  @override
  State<HubProjectsMarketplace> createState() => _HubProjectsMarketplaceState();
}

class _HubProjectsMarketplaceState extends State<HubProjectsMarketplace> {
  final _supabase = Supabase.instance.client;
  List<ClientProjectModel> _projects = [];
  bool _loading = true;
  int _selected = 0;

  static const List<String> _statuses = ['All', 'Pending', 'Approved', 'In Progress', 'Completed', 'Rejected'];
  static const List<String> _statusValues = ['all', 'pending', 'approved', 'in_progress', 'completed', 'rejected'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) { setState(() => _loading = false); return; }
      final data = await _supabase
          .from('client_projects')
          .select()
          .eq('client_id', uid)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _projects = (data as List).map((e) => ClientProjectModel.fromMap(e)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ClientProjectModel> get _filtered {
    if (_selected == 0) return _projects;
    final val = _statusValues[_selected];
    return _projects.where((p) => p.status == val).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: HubColors.primary, strokeWidth: 2)),
      );
    }
    if (_projects.isEmpty) return const _EmptyProjects();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusBar(statuses: _statuses, statusValues: _statusValues, projects: _projects, selected: _selected, onSelect: (i) => setState(() => _selected = i)),
        const SizedBox(height: 14),
        _ProjectList(projects: _filtered),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  final List<String> statuses;
  final List<String> statusValues;
  final List<ClientProjectModel> projects;
  final int selected;
  final void Function(int) onSelect;
  const _StatusBar({required this.statuses, required this.statusValues, required this.projects, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = selected == i;
          final count = i == 0 ? projects.length : projects.where((p) => p.status == statusValues[i]).length;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: sel ? HubColors.primaryGrad : null,
                color: sel ? null : HubColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? Colors.transparent : HubColors.border),
                boxShadow: sel ? [BoxShadow(color: HubColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))] : null,
              ),
              child: Center(
                child: Text(
                  '${statuses[i]} ($count)',
                  style: TextStyle(color: sel ? Colors.white : HubColors.textSec, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  final List<ClientProjectModel> projects;
  const _ProjectList({required this.projects});

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(child: Text('No projects in this status.', style: TextStyle(color: HubColors.textSec, fontSize: 13))),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: projects.length,
      itemBuilder: (_, i) => _ProjectCard(project: projects[i]),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ClientProjectModel project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final statusColor = Color(int.parse('0xFF${project.statusColorHex}'));
    return GestureDetector(
      onTap: () => context.go('/portal'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HubColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HubColors.border),
          boxShadow: [BoxShadow(color: HubColors.primary.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(project.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: HubColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(project.statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(project.requestTypeLabel, style: const TextStyle(fontSize: 12, color: HubColors.textSec)),
            if (project.description != null && project.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(project.description!, style: const TextStyle(fontSize: 12.5, color: HubColors.textSec, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: project.progress / 100, backgroundColor: HubColors.border, color: statusColor, minHeight: 6),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${project.progress}% complete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                const Spacer(),
                if (project.adminNotes != null && project.adminNotes!.isNotEmpty) ...[
                  const Icon(Icons.message_rounded, size: 11, color: HubColors.textSec),
                  const SizedBox(width: 4),
                  const Text('Message from team', style: TextStyle(fontSize: 10, color: HubColors.textSec)),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(gradient: HubColors.primaryGrad, borderRadius: BorderRadius.circular(8)),
                  child: const Text('View Details', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.folder_open_rounded, size: 64, color: HubColors.primary.withOpacity(0.2)),
            const SizedBox(height: 14),
            const Text('No Projects Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: HubColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('Projects you submit will appear here.\nTrack status and progress in real time.',
                textAlign: TextAlign.center, style: TextStyle(color: HubColors.textSec, fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => context.go('/portal'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: HubColors.primaryGrad,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: HubColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Text('Submit a Project', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}