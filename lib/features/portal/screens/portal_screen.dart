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
  final _supabase = Supabase.instance.client;

  List<ClientProjectModel> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) { setState(() => _isLoading = false); return; }

      final data = await _supabase
          .from('client_projects')
          .select()
          .eq('client_id', uid)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _projects  = (data as List).map((e) => ClientProjectModel.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Failed to load projects: $e', error: true);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _openRequestSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _ProjectRequestSheet(
        onSubmitted: () {
          _loadProjects();
          _snack('Project request submitted! We will review it shortly.');
        },
      ),
    );
  }

  void _openProjectDetail(ClientProjectModel project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _ProjectDetailSheet(project: project),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Portal',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: AppColors.primary), onPressed: _loadProjects),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            onPressed: _openRequestSheet,
            tooltip: 'Request a Project',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadProjects,
              color: AppColors.primary,
              child: _projects.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildSummaryHeader(),
                        const SizedBox(height: 20),
                        ..._projects.map((p) => _buildProjectCard(p)),
                      ],
                    ),
            ),
      floatingActionButton: _projects.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openRequestSheet,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New Request',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
    );
  }

  Widget _buildSummaryHeader() {
    final total     = _projects.length;
    final pending   = _projects.where((p) => p.status == 'pending').length;
    final active    = _projects.where((p) => p.status == 'in_progress' || p.status == 'approved').length;
    final completed = _projects.where((p) => p.status == 'completed').length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.folder_special_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text('$total Project${total == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _statChip('$pending Pending', 'F59E0B'),
            const SizedBox(width: 8),
            _statChip('$active Active', '3B82F6'),
            const SizedBox(width: 8),
            _statChip('$completed Done', '10B981'),
          ]),
        ],
      ),
    );
  }

  Widget _statChip(String label, String hex) {
    final color = Color(int.parse('0xFF$hex'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildProjectCard(ClientProjectModel p) {
    final statusColor = Color(int.parse('0xFF${p.statusColorHex}'));
    return GestureDetector(
      onTap: () => _openProjectDetail(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(p.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              _statusBadge(p.statusLabel, statusColor),
            ]),
            const SizedBox(height: 6),
            Text(p.requestTypeLabel,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (p.description != null && p.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(p.description!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: p.progress / 100,
                  backgroundColor: AppColors.border,
                  color: statusColor,
                  minHeight: 6,
                ),
              )),
              const SizedBox(width: 10),
              Text('${p.progress}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
            ]),
            if ((p.adminNotes != null && p.adminNotes!.isNotEmpty) || p.invoiceUrl != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (p.adminNotes != null && p.adminNotes!.isNotEmpty)
                  _iconTag(Icons.message_rounded, 'Note from Tokilo', AppColors.accent),
                if (p.invoiceUrl != null) ...[
                  const SizedBox(width: 8),
                  _iconTag(Icons.receipt_long_rounded, p.invoiceLabel ?? 'Invoice', AppColors.primary),
                ],
              ]),
            ],
            const SizedBox(height: 10),
            Text('Submitted ${_formatDate(p.createdAt)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );

  Widget _iconTag(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color), const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ],
  );

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          const SizedBox(height: 40),
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.07), shape: BoxShape.circle),
            child: Icon(Icons.folder_open_rounded, size: 54, color: AppColors.primary.withOpacity(0.4)),
          ),
          const SizedBox(height: 24),
          const Text('No Projects Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          const Text(
            'Submit your first project request and track it right here. We\'ll review and update you every step of the way.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _openRequestSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('Request a Project',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16)),
            child: const Row(children: [
              Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Chat with Tokilo Team',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 2),
                Text('Get real-time support from our experts',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
            ]),
          ),
        ]),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ══════════════════════════════════════════════════════════════
// PROJECT DETAIL SHEET
// ══════════════════════════════════════════════════════════════
class _ProjectDetailSheet extends StatelessWidget {
  final ClientProjectModel project;
  const _ProjectDetailSheet({required this.project});

  @override
  Widget build(BuildContext context) {
    final statusColor = Color(int.parse('0xFF${project.statusColorHex}'));
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text(project.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
            _badge(project.statusLabel, statusColor),
          ]),
          const SizedBox(height: 4),
          Text(project.requestTypeLabel,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          _sectionLabel('Progress'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: project.progress / 100, backgroundColor: Colors.grey.shade200,
                color: statusColor, minHeight: 10),
            )),
            const SizedBox(width: 12),
            Text('${project.progress}%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor)),
          ]),
          const SizedBox(height: 20),
          if (project.description != null && project.description!.isNotEmpty) ...[
            _sectionLabel('Description'), const SizedBox(height: 8),
            Text(project.description!,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 20),
          ],
          if (project.adminNotes != null && project.adminNotes!.isNotEmpty) ...[
            _sectionLabel('Message from Tokilo'), const SizedBox(height: 8),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.06), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withOpacity(0.25))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.support_agent_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(project.adminNotes!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.5))),
              ]),
            ),
            const SizedBox(height: 20),
          ],
          if (project.invoiceUrl != null) ...[
            _sectionLabel('Invoice & Documents'), const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(project.invoiceUrl!);
                if (uri != null && await canLaunchUrl(uri)) launchUrl(uri);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.25))),
                child: Row(children: [
                  const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Text(project.invoiceLabel ?? 'View Invoice',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14))),
                  const Icon(Icons.open_in_new_rounded, color: AppColors.primary, size: 16),
                ]),
              ),
            ),
            const SizedBox(height: 20),
          ],
          _sectionLabel('Timeline'), const SizedBox(height: 10),
          _timelineRow(Icons.send_rounded, 'Submitted', _fmtDate(project.createdAt), AppColors.textSecondary),
          if (project.status != 'pending')
            _timelineRow(Icons.check_circle_rounded, 'Status Updated', _fmtDate(project.updatedAt), statusColor),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary));

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  );

  Widget _timelineRow(IconData icon, String label, String date, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, size: 16, color: color), const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      const Spacer(),
      Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]),
  );

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ══════════════════════════════════════════════════════════════
// PROJECT REQUEST SHEET
// ══════════════════════════════════════════════════════════════
class _ProjectRequestSheet extends StatefulWidget {
  final VoidCallback onSubmitted;
  const _ProjectRequestSheet({required this.onSubmitted});

  @override
  State<_ProjectRequestSheet> createState() => _ProjectRequestSheetState();
}

class _ProjectRequestSheetState extends State<_ProjectRequestSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _supabase = Supabase.instance.client;

  // Services tab
  List<Map<String, dynamic>> _services = [];
  Map<String, dynamic>? _selectedService;
  String? _selectedServiceCategory; // NEW: tracks which category was tapped

  // Products tab
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic>? _selectedProduct;

  // Custom tab
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedCategory;

  static const List<String> _categories = [
    'Software Development',
    'Retail Technology',
    'IT Infrastructure',
    'Cyber Security',
    'Physical Security',
    'Cloud & DevOps',
    'AI & Automation',
  ];

  static const List<IconData> _categoryIcons = [
    Icons.code_rounded,
    Icons.storefront_rounded,
    Icons.router_rounded,
    Icons.security_rounded,
    Icons.videocam_rounded,
    Icons.cloud_rounded,
    Icons.smart_toy_rounded,
  ];

  static const List<String> _categoryColorHex = [
    '6366F1',
    '0EA5E9',
    '06768D',
    'EF4444',
    '8B5CF6',
    '10B981',
    'F59E0B',
  ];

  // Shared
  final _notesForServiceCtrl = TextEditingController();
  final _notesForProductCtrl = TextEditingController();
  bool _isSaving  = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);

    // Reset service category selection when switching away from Services tab
    _tab.addListener(() {
      if (_tab.index != 0) {
        setState(() {
          _selectedServiceCategory = null;
          _selectedService = null;
        });
      }
    });

    _loadData();
  }

  @override
  void dispose() {
    _tab.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    _notesForServiceCtrl.dispose();
    _notesForProductCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final svc = await _supabase
          .from('services')
          .select('id,title,description,category,price_label,duration')
          .eq('is_active', true)
          .order('title');
      final prd = await _supabase
          .from('it_products')
          .select('id,name,description,category,price')
          .eq('is_active', true)
          .order('name');
      if (mounted) {
        setState(() {
          _services  = List<Map<String, dynamic>>.from(svc);
          _products  = List<Map<String, dynamic>>.from(prd);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final name = user.userMetadata?['full_name'] as String?;

    Map<String, dynamic> payload;

    switch (_tab.index) {
      case 0:
        if (_selectedService == null) { _snack('Please select a service', error: true); return; }
        payload = {
          'client_id': user.id, 'client_email': user.email, 'client_name': name,
          'request_type': 'service', 'service_id': _selectedService!['id'],
          'title': _selectedService!['title'], 'description': _selectedService!['description'],
          'custom_notes': _notesForServiceCtrl.text.trim().isEmpty ? null : _notesForServiceCtrl.text.trim(),
          'status': 'pending', 'progress': 0,
        };
        break;

      case 1:
        if (_selectedProduct == null) { _snack('Please select a product', error: true); return; }
        payload = {
          'client_id': user.id, 'client_email': user.email, 'client_name': name,
          'request_type': 'product', 'product_id': _selectedProduct!['id'],
          'title': _selectedProduct!['name'], 'description': _selectedProduct!['description'],
          'custom_notes': _notesForProductCtrl.text.trim().isEmpty ? null : _notesForProductCtrl.text.trim(),
          'status': 'pending', 'progress': 0,
        };
        break;

      default:
        if (_titleCtrl.text.trim().isEmpty) { _snack('Please enter a project title', error: true); return; }
        payload = {
          'client_id': user.id, 'client_email': user.email, 'client_name': name,
          'request_type': 'custom',
          'title': _titleCtrl.text.trim(),
          'category': _selectedCategory,
          'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'custom_notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          'status': 'pending', 'progress': 0,
        };
    }

    setState(() => _isSaving = true);
    try {
      await _supabase.from('client_projects').insert(payload);
      widget.onSubmitted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Submit failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final screenH   = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardH),
      child: Container(
        constraints: BoxConstraints(maxHeight: screenH * 0.92),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                const Text('Request a Project',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textHint)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [Tab(text: 'Services'), Tab(text: 'Products'), Tab(text: 'Custom')],
                ),
              ),
            ),
            const SizedBox(height: 4),

            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : TabBarView(
                      controller: _tab,
                      children: [
                        _buildServicesTab(),
                        _buildProductsTab(),
                        _buildCustomTab(),
                      ],
                    ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: GestureDetector(
                onTap: _isSaving ? null : _submit,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: _isSaving
                        ? LinearGradient(colors: [AppColors.primary.withOpacity(0.5), AppColors.accent.withOpacity(0.5)])
                        : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _isSaving ? [] : [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Center(
                    child: _isSaving
                        ? const Row(mainAxisSize: MainAxisSize.min, children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Submitting...', style: TextStyle(color: Colors.white, fontSize: 15)),
                          ])
                        : const Text('Submit Request',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SERVICES TAB — Step 1: category grid, Step 2: filtered list
  // ══════════════════════════════════════════════════════════════
  Widget _buildServicesTab() {
    // Step 1: No category selected yet → show 7 division tiles
    if (_selectedServiceCategory == null) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final color = Color(int.parse('0xFF${_categoryColorHex[i]}'));
          return GestureDetector(
            onTap: () => setState(() => _selectedServiceCategory = _categories[i]),
            child: Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.25), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_categoryIcons[i], color: color, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _categories[i],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Step 2: Category chosen → show back button + filtered services
    final catIndex = _categories.indexOf(_selectedServiceCategory!);
    final color    = catIndex >= 0
        ? Color(int.parse('0xFF${_categoryColorHex[catIndex]}'))
        : AppColors.primary;
    final icon     = catIndex >= 0 ? _categoryIcons[catIndex] : Icons.design_services_rounded;

    final filtered = _services
        .where((s) => (s['category'] ?? '') == _selectedServiceCategory)
        .toList();

    return Column(
      children: [
        // ── Back + category header ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _selectedServiceCategory = null;
                  _selectedService = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios_rounded, size: 12, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text('Back', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedServiceCategory!,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.border),

        // ── Services list or empty state ────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded,
                          size: 48, color: AppColors.textHint.withOpacity(0.35)),
                      const SizedBox(height: 12),
                      const Text('No services in this category',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  children: [
                    ...filtered.map((s) {
                      final selected = _selectedService?['id'] == s['id'];
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedService = selected ? null : s),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withOpacity(0.06)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: selected ? color : AppColors.border,
                                width: selected ? 1.5 : 1),
                          ),
                          child: Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['title'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textPrimary)),
                                  if ((s['price_label'] ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(s['price_label'],
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: color,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                  if ((s['duration'] ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(children: [
                                      const Icon(Icons.schedule_rounded,
                                          size: 10,
                                          color: AppColors.textSecondary),
                                      const SizedBox(width: 3),
                                      Text(s['duration'],
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary)),
                                    ]),
                                  ],
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle_rounded,
                                  color: color, size: 22),
                          ]),
                        ),
                      );
                    }),
                    if (_selectedService != null) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesForServiceCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText:
                              'Any additional notes or requirements... (optional)',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PRODUCTS TAB (unchanged)
  // ══════════════════════════════════════════════════════════════
  Widget _buildProductsTab() {
    if (_products.isEmpty) {
      return const Center(
          child: Text('No products available',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      children: [
        ..._products.map((p) {
          final selected = _selectedProduct?['id'] == p['id'];
          return GestureDetector(
            onTap: () => setState(() => _selectedProduct = selected ? null : p),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF8B5CF6).withOpacity(0.06)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected
                        ? const Color(0xFF8B5CF6)
                        : AppColors.border,
                    width: selected ? 1.5 : 1),
              ),
              child: Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.devices_rounded,
                        color: Color(0xFF8B5CF6), size: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(p['name'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary)),
                      if ((p['category'] ?? '').isNotEmpty)
                        Text(p['category'],
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      if (p['price'] != null &&
                          p['price'].toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(p['price'].toString(),
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8B5CF6),
                                fontWeight: FontWeight.w600)),
                      ],
                    ])),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF8B5CF6), size: 22),
              ]),
            ),
          );
        }),
        if (_selectedProduct != null) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _notesForProductCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Quantity, specifications, or any notes... (optional)',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CUSTOM TAB (unchanged)
  // ══════════════════════════════════════════════════════════════
  Widget _buildCustomTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Service Category',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedCategory != null
                    ? AppColors.primary
                    : AppColors.border,
                width: _selectedCategory != null ? 1.5 : 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                hint: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text('Select a category...',
                      style: TextStyle(
                          color: AppColors.textHint, fontSize: 13)),
                ),
                icon: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary),
                ),
                borderRadius: BorderRadius.circular(14),
                items: List.generate(_categories.length, (i) {
                  final cat   = _categories[i];
                  final color = Color(int.parse('0xFF${_categoryColorHex[i]}'));
                  final icon  = _categoryIcons[i];
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(cat,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ]),
                    ),
                  );
                }),
                onChanged: (val) => setState(() => _selectedCategory = val),
                selectedItemBuilder: (_) =>
                    List.generate(_categories.length, (i) {
                  final cat   = _categories[i];
                  final color = Color(int.parse('0xFF${_categoryColorHex[i]}'));
                  final icon  = _categoryIcons[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(children: [
                      Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(icon, color: color, size: 15)),
                      const SizedBox(width: 8),
                      Text(cat,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ]),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _field('Project Title *', _titleCtrl,
              'e.g. Office Network Setup', maxLines: 1),
          const SizedBox(height: 12),
          _field('Description', _descCtrl,
              'Describe your project or requirements...', maxLines: 3),
          const SizedBox(height: 12),
          _field('Additional Notes', _notesCtrl,
              'Timeline, budget, special requests...', maxLines: 2),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }
}