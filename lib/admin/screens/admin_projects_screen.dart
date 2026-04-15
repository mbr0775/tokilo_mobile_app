// lib/admin/screens/admin_projects_screen.dart
// This screen handles CLIENT-SUBMITTED project requests
// Route: /admin/client-projects  (was /admin/projects)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../features/portal/models/client_project_model.dart';
import 'admin_shell.dart';

class AdminProjectsScreen extends StatefulWidget {
  const AdminProjectsScreen({super.key});
  @override
  State<AdminProjectsScreen> createState() => _AdminProjectsScreenState();
}

class _AdminProjectsScreenState extends State<AdminProjectsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tab;
  List<ClientProjectModel> _all = [];
  bool _isLoading = true;
  int _tabIndex = 0;

  static const List<String> _statuses  = ['all','pending','approved','in_progress','completed','rejected'];
  static const List<String> _tabLabels = ['All','Pending','Approved','In Progress','Completed','Rejected'];

  List<ClientProjectModel> get _filtered {
    if (_tabIndex == 0) return _all;
    return _all.where((p) => p.status == _statuses[_tabIndex]).toList();
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _statuses.length, vsync: this)
      ..addListener(() { if (!_tab.indexIsChanging) setState(() => _tabIndex = _tab.index); });
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('client_projects').select().order('created_at', ascending: false);
      if (mounted) setState(() {
        _all = (data as List).map((e) => ClientProjectModel.fromMap(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); _snack('Load error: $e', error: true); }
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

  void _openEdit(ClientProjectModel p) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (_) => _AdminEditProjectSheet(project: p, onSaved: () { _load(); _snack('Project updated!'); }),
    );
  }

  Future<void> _quickApprove(ClientProjectModel p) async {
    try {
      await _supabase.from('client_projects').update({
        'status': 'approved', 'approved_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', p.id);
      _load(); _snack('Project approved!');
    } catch (e) { _snack('Error: $e', error: true); }
  }

  Future<void> _quickReject(ClientProjectModel p) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Reject Request'), content: Text('Reject "${p.title}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, minimumSize: Size.zero),
          child: const Text('Reject', style: TextStyle(color: Colors.white))),
      ],
    )) ?? false;
    if (!ok) return;
    try {
      await _supabase.from('client_projects').update({'status': 'rejected', 'updated_at': DateTime.now().toIso8601String()}).eq('id', p.id);
      _load(); _snack('Project rejected');
    } catch (e) { _snack('Error: $e', error: true); }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentPath: '/admin/client-projects',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AdminAppBar(
          title: 'Client Requests (${_all.length})',
          currentPath: '/admin/client-projects',
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.white))],
        ),
        body: Column(children: [
          Container(
            color: const Color(0xFF03404E),
            child: TabBar(
              controller: _tab, isScrollable: true,
              indicatorColor: AppColors.accent, labelColor: AppColors.accent,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              tabAlignment: TabAlignment.start,
              tabs: List.generate(_statuses.length, (i) {
                final count = _statuses[i] == 'all' ? _all.length : _all.where((p) => p.status == _statuses[i]).length;
                return Tab(text: '${_tabLabels[i]} ($count)');
              }),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty ? _emptyState()
                : RefreshIndicator(onRefresh: _load, child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _card(_filtered[i]))),
          ),
        ]),
      ),
    );
  }

  Widget _card(ClientProjectModel p) {
    final statusColor = Color(int.parse('0xFF${p.statusColorHex}'));
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8), _badge(p.statusLabel, statusColor),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.person_rounded, size: 12, color: AppColors.textHint), const SizedBox(width: 4),
          Expanded(child: Text('${p.clientName ?? 'Client'}  •  ${p.clientEmail}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(p.requestTypeLabel, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: p.progress / 100, backgroundColor: AppColors.border, color: statusColor, minHeight: 6))),
          const SizedBox(width: 8),
          Text('${p.progress}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(_fmtDate(p.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textHint))),
          if (p.status == 'pending') ...[
            _actionBtn('Approve', AppColors.success, Icons.check_rounded, () => _quickApprove(p)),
            const SizedBox(width: 8),
            _actionBtn('Reject', AppColors.error, Icons.close_rounded, () => _quickReject(p)),
            const SizedBox(width: 8),
          ],
          _actionBtn('Edit', AppColors.primary, Icons.edit_rounded, () => _openEdit(p)),
        ]),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );

  Widget _actionBtn(String label, Color color, IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color), const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.folder_open_rounded, size: 72, color: AppColors.primary.withOpacity(0.18)),
    const SizedBox(height: 16),
    const Text('No Client Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
    const SizedBox(height: 8),
    const Text('Client requests will appear here', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
  ]));

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month-1]} ${d.year}';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADMIN EDIT PROJECT SHEET (unchanged logic)
// ══════════════════════════════════════════════════════════════════════════════
class _AdminEditProjectSheet extends StatefulWidget {
  final ClientProjectModel project;
  final VoidCallback onSaved;
  const _AdminEditProjectSheet({required this.project, required this.onSaved});
  @override State<_AdminEditProjectSheet> createState() => _AdminEditProjectSheetState();
}

class _AdminEditProjectSheetState extends State<_AdminEditProjectSheet> {
  final _supabase = Supabase.instance.client;
  late TextEditingController _notesCtrl, _invoiceUrlCtrl, _invoiceLabelCtrl;
  late String _status;
  late double _progress;
  bool _isSaving = false;

  static const List<String> _sVals   = ['pending','approved','in_progress','completed','rejected'];
  static const List<String> _sLabels = ['Pending Review','Approved','In Progress','Completed','Rejected'];
  static const List<String> _sHex    = ['F59E0B','3B82F6','8B5CF6','10B981','EF4444'];

  @override
  void initState() {
    super.initState();
    _status           = widget.project.status;
    _progress         = widget.project.progress.toDouble();
    _notesCtrl        = TextEditingController(text: widget.project.adminNotes ?? '');
    _invoiceUrlCtrl   = TextEditingController(text: widget.project.invoiceUrl ?? '');
    _invoiceLabelCtrl = TextEditingController(text: widget.project.invoiceLabel ?? '');
  }

  @override
  void dispose() { _notesCtrl.dispose(); _invoiceUrlCtrl.dispose(); _invoiceLabelCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'status': _status, 'progress': _progress.round(),
        'admin_notes':   _notesCtrl.text.trim().isEmpty   ? null : _notesCtrl.text.trim(),
        'invoice_url':   _invoiceUrlCtrl.text.trim().isEmpty   ? null : _invoiceUrlCtrl.text.trim(),
        'invoice_label': _invoiceLabelCtrl.text.trim().isEmpty ? null : _invoiceLabelCtrl.text.trim(),
        'updated_at':    DateTime.now().toIso8601String(),
      };
      if (_status == 'approved')  payload['approved_at']  = DateTime.now().toIso8601String();
      if (_status == 'completed') payload['completed_at'] = DateTime.now().toIso8601String();
      await _supabase.from('client_projects').update(payload).eq('id', widget.project.id);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $e'), backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16),
      ));
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Update Client Request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(widget.project.title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textHint)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text((widget.project.clientName ?? widget.project.clientEmail).substring(0,1).toUpperCase(),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.project.clientName ?? 'Client', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              Text(widget.project.clientEmail, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
              child: Text(widget.project.requestTypeLabel, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600))),
          ]),
        ),
        const SizedBox(height: 20),
        const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: List.generate(_sVals.length, (i) {
          final val      = _sVals[i];
          final label    = _sLabels[i];
          final color    = Color(int.parse('0xFF${_sHex[i]}'));
          final selected = _status == val;
          return GestureDetector(
            onTap: () => setState(() => _status = val),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.12) : AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1)),
              child: Text(label, style: TextStyle(color: selected ? color : AppColors.textSecondary, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ),
          );
        })),
        const SizedBox(height: 20),
        Row(children: [
          const Text('Progress', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          Text('${_progress.round()}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ]),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(activeTrackColor: AppColors.primary, inactiveTrackColor: AppColors.border, thumbColor: AppColors.primary, overlayColor: AppColors.primary.withOpacity(0.1), trackHeight: 6),
          child: Slider(value: _progress, min: 0, max: 100, divisions: 20, onChanged: (v) => setState(() => _progress = v)),
        ),
        const SizedBox(height: 16),
        const Text('Message to Client', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Visible to the client in their portal.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        _textField(_notesCtrl, 'e.g. Your project has been approved. We will begin next Monday.', maxLines: 3),
        const SizedBox(height: 16),
        const Text('Invoice / Document', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        _textField(_invoiceLabelCtrl, 'Label e.g. Invoice #001', label: 'Document Label'),
        const SizedBox(height: 10),
        _textField(_invoiceUrlCtrl, 'https://...', label: 'Document URL', prefix: const Icon(Icons.link_rounded, color: AppColors.textHint, size: 20)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _isSaving ? null : _save,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: _isSaving ? LinearGradient(colors: [AppColors.primary.withOpacity(0.5), AppColors.accent.withOpacity(0.5)]) : AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _isSaving ? [] : [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
            child: Center(child: _isSaving
              ? const Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  SizedBox(width: 10), Text('Saving...', style: TextStyle(color: Colors.white, fontSize: 15))])
              : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
          ),
        ),
      ])),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, {String? label, int maxLines = 1, Widget? prefix}) => TextField(
    controller: ctrl, maxLines: maxLines,
    decoration: InputDecoration(
      hintText: hint, labelText: label, prefixIcon: prefix,
      filled: true, fillColor: AppColors.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.all(14),
    ),
  );
}