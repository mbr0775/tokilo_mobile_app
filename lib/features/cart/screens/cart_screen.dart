import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/cart/cart_store.dart';
import '../../../core/constants/app_colors.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    CartStore.instance.addListener(_rebuild);
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    CartStore.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _showClearDialog() {
    // ✅ CRITICAL FIX: capture the outer context's navigator BEFORE showDialog
    // The dialog's builder(_) gives a new context that may not resolve
    // the correct Navigator — using rootNavigator: true ensures it always works
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from your cart?'),
        actions: [
          TextButton(
            // ✅ FIX: use rootNavigator: true so the dialog always closes
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              CartStore.instance.clear();
              // ✅ FIX: use rootNavigator: true to reliably close dialog
              Navigator.of(dialogContext, rootNavigator: true).pop();
            },
            child: const Text('Clear',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartStore.instance;

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
        title: const Text('My Cart',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: _showClearDialog, // ✅ calls the fixed method
              child: const Text('Clear',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
        ],
      ),
      body: cart.isEmpty ? _emptyCart() : _cartBody(cart),
    );
  }

  Widget _emptyCart() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('Your cart is empty',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            const Text('Add products to get started',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF94A3B8))),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/marketplace'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Browse Products',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _cartBody(CartStore cart) => Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _CartItemTile(item: cart.items[i]),
            ),
          ),
          _OrderSummary(cart: cart),
        ],
      );
}

// ── Cart Item Tile ──────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 70, height: 70,
              color: const Color(0xFFEFF9FB),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.devices_rounded,
                          color: AppColors.primary, size: 30))
                  : const Icon(Icons.devices_rounded,
                      color: AppColors.primary, size: 30),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0F172A)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  (item.price != null && item.price!.isNotEmpty)
                      ? item.price!
                      : 'Get Quote',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: (item.price != null && item.price!.isNotEmpty)
                        ? AppColors.primary
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Quantity controls
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Remove button
              GestureDetector(
                onTap: () => CartStore.instance.remove(item.id),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 18),
              ),
              const SizedBox(height: 8),
              // +/- Row
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _QtyBtn(
                      icon: Icons.remove_rounded,
                      onTap: () => CartStore.instance.decrement(item.id),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${item.quantity}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                    _QtyBtn(
                      icon: Icons.add_rounded,
                      onTap: () => CartStore.instance.increment(item.id),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF0F172A)),
        ),
      );
}

// ── Order Summary ───────────────────────────────────────────────────────────

class _OrderSummary extends StatelessWidget {
  final CartStore cart;
  const _OrderSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    final hasPrice = cart.items.any(
        (i) => i.price != null && i.price!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 20, offset: const Offset(0, -6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${cart.totalCount} item(s)',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF64748B))),
              if (hasPrice)
                Text(
                  'Total: QAR ${cart.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A)),
                )
              else
                const Text('Price on request',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/checkout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF03404E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Proceed to Checkout',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}