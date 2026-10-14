// lib/admin/screens/admin_pricing_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import 'admin_shell.dart';

class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];

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
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Load failed: $e', error: true);
    }
  }

  void _openForm({Map<String, dynamic>? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _PricingFormSheet(
        item: item,
        onSaved: () {
          _loadPricing();
          _snack(item == null ? 'Pricing added' : 'Pricing updated');
        },
      ),
    );
  }

  Future<void> _delete(String id) async {
    try {
      await _supabase.from('service_pricing').delete().eq('id', id);
      _snack('Pricing deleted');
      _loadPricing();
    } catch (e) {
      _snack('Delete failed: $e', error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentPath: '/admin/pricing',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AdminAppBar(
          title: 'Service Pricing',
          currentPath: '/admin/pricing',
          actions: [
            IconButton(
              onPressed: _loadPricing,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Add Pricing',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _items.isEmpty
            ? const Center(
          child: Text(
            'No pricing packages yet',
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadPricing,
          color: AppColors.primary,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _PricingAdminCard(
                item: item,
                onEdit: () => _openForm(item: item),
                onDelete: () => _delete(item['id'].toString()),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Admin Card ─────────────────────────────────────────────────────────────

class _PricingAdminCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PricingAdminCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _color {
    final raw = item['color_hex']?.toString() ?? '06768D';
    return Color(int.parse('0xFF${raw.replaceAll('#', '')}'));
  }

  @override
  Widget build(BuildContext context) {
    final color    = _color;
    final title    = item['title']?.toString() ?? 'Service';
    final category = item['category']?.toString() ?? '';
    final price    = item['price_label']?.toString() ?? '';
    final active   = item['is_active'] == true;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.payments_rounded, color: color, size: 26),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      price,
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      active ? 'Active' : 'Hidden',
                      style: TextStyle(
                        color: active ? AppColors.success : AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_rounded, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

// ─── Pricing Form Sheet ──────────────────────────────────────────────────────

class _PricingFormSheet extends StatefulWidget {
  final Map<String, dynamic>? item;
  final VoidCallback onSaved;

  const _PricingFormSheet({this.item, required this.onSaved});

  @override
  State<_PricingFormSheet> createState() => _PricingFormSheetState();
}

class _PricingFormSheetState extends State<_PricingFormSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _featuresCtrl;
  late TextEditingController _sortCtrl;
  late TextEditingController _colorCtrl;

  String _category = 'Software Development';
  String _iconKey  = 'code';
  bool _isPopular  = false;
  bool _isActive   = true;
  bool _isSaving   = false;

  final List<String> _categories = const [
    'Software Development',
    'AI & Automation',
    'Cloud, DevOps & SRE',
    'API & Systems Integration',
    'Digital Marketing & Growth',
    'Maintenance & Support',
  ];

  final List<String> _icons = const [
    'code', 'web', 'mobile', 'ai', 'cloud', 'api', 'marketing', 'maintenance',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.item;

    _titleCtrl    = TextEditingController(text: item?['title']?.toString() ?? '');
    _descCtrl     = TextEditingController(text: item?['short_description']?.toString() ?? '');
    _priceCtrl    = TextEditingController(text: item?['price_label']?.toString() ?? '');
    _durationCtrl = TextEditingController(text: item?['duration_label']?.toString() ?? '');
    _sortCtrl     = TextEditingController(text: (item?['sort_order'] ?? 0).toString());
    _colorCtrl    = TextEditingController(text: item?['color_hex']?.toString() ?? '06768D');

    final rawFeatures = item?['features'];
    _featuresCtrl = TextEditingController(
      text: rawFeatures is List
          ? rawFeatures.map((e) => e.toString()).join('\n')
          : '',
    );

    _category  = item?['category']?.toString() ?? _category;
    _iconKey   = item?['icon_key']?.toString() ?? _iconKey;
    _isPopular = item?['is_popular'] == true;
    _isActive  = item?['is_active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _featuresCtrl.dispose();
    _sortCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final features = _featuresCtrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final payload = {
        'title':             _titleCtrl.text.trim(),
        'category':          _category,
        'short_description': _descCtrl.text.trim(),
        'price_label':       _priceCtrl.text.trim(),
        'duration_label':    _durationCtrl.text.trim(),
        'features':          features,
        'icon_key':          _iconKey,
        'color_hex':         _colorCtrl.text.trim().replaceAll('#', ''),
        'is_popular':        _isPopular,
        'is_active':         _isActive,
        'sort_order':        int.tryParse(_sortCtrl.text.trim()) ?? 0,
        'updated_at':        DateTime.now().toIso8601String(),
      };

      if (widget.item == null) {
        await _supabase.from('service_pricing').insert(payload);
      } else {
        await _supabase
            .from('service_pricing')
            .update(payload)
            .eq('id', widget.item!['id']);
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe    = MediaQuery.of(context).viewPadding.bottom;
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 14, 20, keyboardBottom + bottomSafe + 28),
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
                  Expanded(
                    child: Text(
                      widget.item == null ? 'Add Pricing' : 'Edit Pricing',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _field('Title *', _titleCtrl, required: true),
              const SizedBox(height: 12),
              _dropdown('Category', _category, _categories, (v) => setState(() => _category = v)),
              const SizedBox(height: 12),
              _field('Short Description', _descCtrl, maxLines: 3),
              const SizedBox(height: 12),
              _field('Price Label *', _priceCtrl, required: true),
              const SizedBox(height: 12),
              _field('Duration Label', _durationCtrl),
              const SizedBox(height: 12),
              _field('Features - one per line', _featuresCtrl, maxLines: 5),
              const SizedBox(height: 12),
              _dropdown('Icon', _iconKey, _icons, (v) => setState(() => _iconKey = v)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field('Color Hex', _colorCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Sort Order', _sortCtrl)),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isPopular,
                onChanged: (v) => setState(() => _isPopular = v),
                title: const Text('Mark as Popular'),
              ),
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('Visible to Users'),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _isSaving ? null : _save,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      _isSaving ? 'Saving...' : 'Save Pricing',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
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

  Widget _field(
      String label,
      TextEditingController controller, {
        bool required = false,
        int maxLines = 1,
      }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: required
          ? (value) => (value == null || value.trim().isEmpty) ? '$label is required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _dropdown(
      String label,
      String value,
      List<String> items,
      ValueChanged<String> onChanged,
      ) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      items: items
          .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) { if (value != null) onChanged(value); },
    );
  }
}