// lib/admin/models/product_model.dart

class ProductModel {
  final String   id;
  final String   name;
  final String?  brand;
  final String?  category;
  final String?  description;
  final String?  price;
  final String?  imageUrl;
  final bool     inStock;
  final bool     isActive;
  final DateTime createdAt;

  ProductModel({
    required this.id,
    required this.name,
    this.brand,
    this.category,
    this.description,
    this.price,
    this.imageUrl,
    required this.inStock,
    required this.isActive,
    required this.createdAt,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id:          map['id']          ?? '',
      name:        map['name']        ?? '',
      brand:       map['brand'],
      category:    map['category'],
      description: map['description'],
      price:       map['price'],
      imageUrl:    map['image_url'],
      inStock:     map['in_stock']    ?? true,
      isActive:    map['is_active']   ?? true,
      createdAt:   DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':        name,
    'brand':       brand,
    'category':    category,
    'description': description,
    'price':       price,
    'image_url':   imageUrl,
    'in_stock':    inStock,
    'is_active':   isActive,
    'updated_at':  DateTime.now().toIso8601String(),
  };
}