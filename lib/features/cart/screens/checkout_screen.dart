import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/cart/cart_store.dart';
import '../../../core/constants/app_colors.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _supabase = Supabase.instance.client;
  final _noteCtrl = TextEditingController();
  bool _isPlacing = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final cart = CartStore.instance;
    if (cart.isEmpty) return;

    setState(() => _isPlacing = true);

    try {
      final uid   = _supabase.auth.currentUser?.id;
      final email = _supabase.auth.currentUser?.email;
      final meta  = _supabase.auth.currentUser?.userMetadata;
      final name  = meta?['full_name'] ?? email ?? 'User';

      // Build order items list
      final orderItems = cart.items.map((i) => {
        'product_id':   i.id,
        'product_name': i.name,
        'price':        i.price ?? 'Quote',
        'quantity':     i.quantity,
      }).toList();

      // Insert order into Supabase
      await _supabase.from('orders').insert({
        'user_id':     uid,
        'user_name':   name,
        'user_email':  email,
        'items':       orderItems,
        'total_items': cart.totalCount,
        'total_price': cart.totalPrice > 0
            ? cart.totalPrice.toStringAsFixed(2)
            : 'Quote',
        'note':        _noteCtrl.text.trim(),
        'status':      'pending',
      });

      cart.clear();

      if (mounted) context.pushReplacement('/order-success');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to place order: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart  = CartStore.instance;
    final meta  = _supabase.auth.currentUser?.userMetadata;
    final name  = meta?['full_name'] ??
        _supabase.auth.currentUser?.email ?? 'User';
    final email = _supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF03404E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Checkout',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Customer Info ─────────────────────────────────
            _SectionCard(
              title: 'Customer Details',
              icon: Icons.person_outline_rounded,
              child: Column(
                children: [
                  _InfoRow(label: 'Name', value: name),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Email', value: email),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Order Items ───────────────────────────────────
            _SectionCard(
              title: 'Order Items (${cart.totalCount})',
              icon: Icons.inventory_2_outlined,
              child: Column(
                children: cart.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 44, height: 44,
                          color: const Color(0xFFEFF9FB),
                          child: item.imageUrl != null &&
                                  item.imageUrl!.isNotEmpty
                              ? Image.network(item.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.devices_rounded,
                                          color: AppColors.primary,
                                          size: 20))
                              : const Icon(Icons.devices_rounded,
                                  color: AppColors.primary, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text('Qty: ${item.quantity}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      Text(
                        (item.price != null && item.price!.isNotEmpty)
                            ? item.price!
                            : 'Quote',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // ── Note ──────────────────────────────────────────
            _SectionCard(
              title: 'Additional Note (Optional)',
              icon: Icons.notes_rounded,
              child: TextField(
                controller: _noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Any special requirements...',
                  hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Price Summary ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF03404E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  Text(
                    cart.totalPrice > 0
                        ? 'QAR ${cart.totalPrice.toStringAsFixed(2)}'
                        : 'Price on Request',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Place Order Button ─────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPlacing ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.accent.withOpacity(0.6),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isPlacing
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Place Order',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Reusable Widgets ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF0F172A))),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF94A3B8))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A))),
          ),
        ],
      );
}