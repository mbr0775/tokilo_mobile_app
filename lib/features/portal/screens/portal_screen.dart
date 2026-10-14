// lib/features/portal/screens/portal_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../models/client_project_model.dart';

class PortalScreen extends StatefulWidget {
  const PortalScreen({super.key});

  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends State<PortalScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ClientProjectModel> _projects = [];
  bool _isLoading = true;
  int _selectedFilter = 0;

  static const List<_StatusFilter> _filters = [
    _StatusFilter(label: 'All', value: 'all'),
    _StatusFilter(label: 'Pending', value: 'pending'),
    _StatusFilter(label: 'Approved', value: 'approved'),
    _StatusFilter(label: 'Progress', value: 'in_progress'),
    _StatusFilter(label: 'Done', value: 'completed'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  List<ClientProjectModel> get _filteredProjects {
    final selected = _filters[_selectedFilter].value;

    if (selected == 'all') {
      return _projects;
    }

    return _projects.where((project) => project.status == selected).toList();
  }

  int get _pendingCount {
    return _projects.where((project) => project.status == 'pending').length;
  }

  int get _activeCount {
    return _projects
        .where(
          (project) =>
              project.status == 'approved' || project.status == 'in_progress',
        )
        .length;
  }

  int get _completedCount {
    return _projects.where((project) => project.status == 'completed').length;
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);

    try {
      final uid = _supabase.auth.currentUser?.id;

      if (uid == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final data = await _supabase
          .from('client_projects')
          .select()
          .eq('client_id', uid)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _projects = (data as List)
            .map((item) => ClientProjectModel.fromMap(item))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _snack('Failed to load requests: $e', error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openRequestSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) {
        return _ProjectRequestSheet(
          onSubmitted: () {
            _loadProjects();
            _snack('Project request submitted successfully');
          },
        );
      },
    );
  }

  void _openDetails(ClientProjectModel project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return _ProjectDetailsSheet(project: project);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProjects;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRequestSheet,
        backgroundColor: AppColors.primary,
        elevation: 8,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Request',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProjects,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                total: _projects.length,
                pending: _pendingCount,
                active: _activeCount,
                completed: _completedCount,
                onCreate: _openRequestSheet,
              ),
            ),
            SliverToBoxAdapter(
              child: _FilterBar(
                filters: _filters,
                selectedIndex: _selectedFilter,
                onChanged: (index) {
                  setState(() => _selectedFilter = index);
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
                child: _EmptyState(
                  hasAnyProjects: _projects.isNotEmpty,
                  onCreate: _openRequestSheet,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final project = filtered[index];

                    return _ProjectCard(
                      project: project,
                      onTap: () => _openDetails(project),
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
  final int total;
  final int pending;
  final int active;
  final int completed;
  final VoidCallback onCreate;

  const _Header({
    required this.total,
    required this.pending,
    required this.active,
    required this.completed,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your projects.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'From first idea to the next milestone.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('New project request'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                _MiniStat(value: '$total', label: 'Total'),
                _MiniStat(value: '$pending', label: 'Pending'),
                _MiniStat(value: '$active', label: 'Active'),
                _MiniStat(value: '$completed', label: 'Done'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _FilterBar extends StatelessWidget {
  final List<_StatusFilter> filters;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _FilterBar({
    required this.filters,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.only(top: 14),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = selectedIndex == index;

          return GestureDetector(
            onTap: () => onChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
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
                filter.label,
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

class _ProjectCard extends StatelessWidget {
  final ClientProjectModel project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

  Color get _statusColor {
    return Color(int.parse('0xFF${project.statusColorHex}'));
  }

  IconData get _icon {
    final title = project.title.toLowerCase();

    if (title.contains('mobile') || title.contains('app')) {
      return Icons.phone_android_rounded;
    }

    if (title.contains('web') || title.contains('website')) {
      return Icons.language_rounded;
    }

    if (title.contains('maintenance') || title.contains('support')) {
      return Icons.handyman_rounded;
    }

    if (title.contains('pos')) {
      return Icons.point_of_sale_rounded;
    }

    if (title.contains('crm') || title.contains('erp')) {
      return Icons.dashboard_customize_rounded;
    }

    return Icons.code_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final progress = project.progress.clamp(0, 100) / 100;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(_icon, color: color, size: 27),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _StatusBadge(
                            label: project.statusLabel,
                            color: color,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _dateLabel(project.createdAt),
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: AppColors.textHint,
                ),
              ],
            ),
            if (project.description != null &&
                project.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  project.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.border,
                color: color,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Text(
                  '${project.progress}% complete',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (project.adminNotes != null &&
                    project.adminNotes!.trim().isNotEmpty) ...[
                  Icon(Icons.mark_chat_unread_rounded, size: 15, color: color),
                  const SizedBox(width: 4),
                  Text(
                    'Team update',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasAnyProjects;
  final VoidCallback onCreate;

  const _EmptyState({required this.hasAnyProjects, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: AppColors.primary,
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasAnyProjects ? 'No requests in this filter' : 'No requests yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasAnyProjects
                ? 'Try another status filter to view your project requests.'
                : 'Submit your first project request and track progress here.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (!hasAnyProjects) ...[
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onCreate,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Create Request',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectRequestSheet extends StatefulWidget {
  final VoidCallback onSubmitted;

  const _ProjectRequestSheet({required this.onSubmitted});

  @override
  State<_ProjectRequestSheet> createState() => _ProjectRequestSheetState();
}

class _ProjectRequestSheetState extends State<_ProjectRequestSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _budgetCtrl = TextEditingController();

  int _selectedCategory = 0;
  bool _isSubmitting = false;

  static const List<_RequestCategory> _categories = [
    _RequestCategory(
      title: 'Website',
      value: 'website',
      icon: Icons.language_rounded,
      color: Color(0xFF06768D),
    ),
    _RequestCategory(
      title: 'Mobile App',
      value: 'mobile_app',
      icon: Icons.phone_android_rounded,
      color: Color(0xFF10B981),
    ),
    _RequestCategory(
      title: 'CRM / ERP',
      value: 'crm_erp',
      icon: Icons.dashboard_customize_rounded,
      color: Color(0xFF8B5CF6),
    ),
    _RequestCategory(
      title: 'POS',
      value: 'pos',
      icon: Icons.point_of_sale_rounded,
      color: Color(0xFFF59E0B),
    ),
    _RequestCategory(
      title: 'Maintenance',
      value: 'maintenance',
      icon: Icons.handyman_rounded,
      color: Color(0xFFEF4444),
    ),
    _RequestCategory(
      title: 'Custom',
      value: 'custom',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF3B82F6),
    ),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = _supabase.auth.currentUser;
      final uid = user?.id;
      final email = user?.email ?? '';
      final meta = user?.userMetadata;
      final name = meta?['full_name'] ?? email;

      if (uid == null) {
        throw Exception('User not logged in');
      }

      final category = _categories[_selectedCategory];

      final notes = [
        'Category: ${category.title}',
        if (_budgetCtrl.text.trim().isNotEmpty)
          'Budget: ${_budgetCtrl.text.trim()}',
        if (_notesCtrl.text.trim().isNotEmpty)
          'Notes: ${_notesCtrl.text.trim()}',
      ].join('\n');

      await _supabase.from('client_projects').insert({
        'client_id': uid,
        'client_email': email,
        'client_name': name,
        'request_type': category.value,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'custom_notes': notes,
        'status': 'pending',
        'progress': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      widget.onSubmitted();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submit failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          keyboardBottom + bottomSafe + 30,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'New Project Request',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
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
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose what you want to build or maintain.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _CategorySelector(
                categories: _categories,
                selectedIndex: _selectedCategory,
                onChanged: (index) {
                  setState(() => _selectedCategory = index);
                },
              ),
              const SizedBox(height: 22),
              _InputField(
                label: 'Project Title *',
                controller: _titleCtrl,
                hint: 'e.g. Restaurant Ordering App',
                icon: Icons.title_rounded,
                required: true,
              ),
              const SizedBox(height: 16),
              _InputField(
                label: 'Project Details *',
                controller: _descCtrl,
                hint: 'Describe your idea, features, users and goal...',
                icon: Icons.notes_rounded,
                required: true,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              _InputField(
                label: 'Budget / Price Range',
                controller: _budgetCtrl,
                hint: 'e.g. QAR 5,000 - 10,000',
                icon: Icons.payments_rounded,
              ),
              const SizedBox(height: 16),
              _InputField(
                label: 'Additional Notes',
                controller: _notesCtrl,
                hint: 'Timeline, reference app, special requests...',
                icon: Icons.edit_note_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _isSubmitting ? null : _submit,
                child: Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: _isSubmitting
                        ? LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.55),
                              AppColors.accent.withValues(alpha: 0.55),
                            ],
                          )
                        : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _isSubmitting
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _isSubmitting
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Submitting...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Submit Request',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
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

class _CategorySelector extends StatelessWidget {
  final List<_RequestCategory> categories;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _CategorySelector({
    required this.categories,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: categories.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final item = categories[index];
        final selected = selectedIndex == index;

        return GestureDetector(
          onTap: () => onChanged(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected
                  ? item.color.withValues(alpha: 0.10)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? item.color : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(height: 9),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? item.color : AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool required;
  final int maxLines;

  const _InputField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.required = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '$label is required';
                  }

                  return null;
                }
              : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: maxLines > 1 ? 72 : 0),
              child: Icon(icon, color: AppColors.textHint, size: 22),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectDetailsSheet extends StatelessWidget {
  final ClientProjectModel project;

  const _ProjectDetailsSheet({required this.project});

  Color get _statusColor {
    return Color(int.parse('0xFF${project.statusColorHex}'));
  }

  Future<void> _openInvoice(BuildContext context) async {
    final url = project.invoiceUrl;

    if (url == null || url.trim().isEmpty) return;

    final uri = Uri.tryParse(url);

    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open invoice'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    final color = _statusColor;

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
                  Expanded(
                    child: Text(
                      project.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
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
              const SizedBox(height: 12),
              _StatusBadge(label: project.statusLabel, color: color),
              const SizedBox(height: 22),
              _DetailProgress(progress: project.progress, color: color),
              const SizedBox(height: 22),
              if (project.description != null &&
                  project.description!.trim().isNotEmpty)
                _InfoBlock(
                  title: 'Description',
                  body: project.description!,
                  icon: Icons.notes_rounded,
                ),
              if (project.customNotes != null &&
                  project.customNotes!.trim().isNotEmpty)
                _InfoBlock(
                  title: 'Request Notes',
                  body: project.customNotes!,
                  icon: Icons.edit_note_rounded,
                ),
              if (project.adminNotes != null &&
                  project.adminNotes!.trim().isNotEmpty)
                _InfoBlock(
                  title: 'Team Update',
                  body: project.adminNotes!,
                  icon: Icons.support_agent_rounded,
                  color: AppColors.primary,
                ),
              const SizedBox(height: 4),
              _MetaRow(
                icon: Icons.calendar_today_rounded,
                label: 'Submitted',
                value:
                    '${project.createdAt.day}/${project.createdAt.month}/${project.createdAt.year}',
              ),
              const SizedBox(height: 10),
              _MetaRow(
                icon: Icons.update_rounded,
                label: 'Last Updated',
                value:
                    '${project.updatedAt.day}/${project.updatedAt.month}/${project.updatedAt.year}',
              ),
              if (project.invoiceUrl != null &&
                  project.invoiceUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: () => _openInvoice(context),
                  child: Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        project.invoiceLabel?.isNotEmpty == true
                            ? project.invoiceLabel!
                            : 'Open Invoice',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailProgress extends StatelessWidget {
  final int progress;
  final Color color;

  const _DetailProgress({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0, 100) / 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$progress%',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 9,
              color: color,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color? color;

  const _InfoBlock({
    required this.title,
    required this.body,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final blockColor = color ?? AppColors.textSecondary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: blockColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: blockColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textHint, size: 18),
        const SizedBox(width: 9),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusFilter {
  final String label;
  final String value;

  const _StatusFilter({required this.label, required this.value});
}

class _RequestCategory {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _RequestCategory({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
