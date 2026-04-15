// lib/admin/models/service_model.dart
//
// UPDATED: Added price, price_label, duration fields so the
// marketplace can display real pricing from the admin panel.
//
// Supabase migration — run this in your Supabase SQL editor:
// ─────────────────────────────────────────────────────────────
// ALTER TABLE services
//   ADD COLUMN IF NOT EXISTS price        TEXT,
//   ADD COLUMN IF NOT EXISTS price_label  TEXT,
//   ADD COLUMN IF NOT EXISTS duration     TEXT;
// ─────────────────────────────────────────────────────────────
// price        → raw number string e.g. "1500"
// price_label  → display string e.g. "From QAR 1,500" or "Get Quote"
// duration     → e.g. "3–5 days", "1 week", "On-site"

class ServiceModel {
  final String   id;
  final String   title;
  final String?  description;
  final String?  category;
  final String?  tag;
  final String?  iconName;
  final String?  imageUrl;
  final bool     isActive;
  final DateTime createdAt;

  // ── NEW marketplace fields ──────────────────────────────────
  final String?  price;        // raw value e.g. "1500"
  final String?  priceLabel;   // display value e.g. "From QAR 1,500"
  final String?  duration;     // e.g. "3–5 days"

  ServiceModel({
    required this.id,
    required this.title,
    this.description,
    this.category,
    this.tag,
    this.iconName,
    this.imageUrl,
    required this.isActive,
    required this.createdAt,
    this.price,
    this.priceLabel,
    this.duration,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    return ServiceModel(
      id:          map['id']          ?? '',
      title:       map['title']       ?? '',
      description: map['description'],
      category:    map['category'],
      tag:         map['tag'],
      iconName:    map['icon_name'],
      imageUrl:    map['image_url'],
      isActive:    map['is_active']   ?? true,
      createdAt:   DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      price:       map['price'],
      priceLabel:  map['price_label'],
      duration:    map['duration'],
    );
  }

  Map<String, dynamic> toMap() => {
    'title':       title,
    'description': description,
    'category':    category,
    'tag':         tag,
    'icon_name':   iconName,
    'image_url':   imageUrl,
    'is_active':   isActive,
    'updated_at':  DateTime.now().toIso8601String(),
    'price':       price,
    'price_label': priceLabel,
    'duration':    duration,
  };

  /// Returns the best display price string for the marketplace card.
  /// Falls back gracefully if neither field is set.
  String get displayPrice {
    if (priceLabel != null && priceLabel!.isNotEmpty) return priceLabel!;
    if (price != null && price!.isNotEmpty) return 'QAR ${price!}';
    return 'Get Quote';
  }
}