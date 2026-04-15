// lib/admin/models/portfolio_model.dart

class PortfolioModel {
  final String   id;
  final String   title;
  final String?  clientName;
  final String?  category;
  final String?  description;
  final String?  imageUrl;
  final String?  originalPrice;
  final String?  agreedPrice;
  final String?  technologies;
  final String   status;
  final String?  completedAt;
  final bool     isActive;
  final DateTime createdAt;

  PortfolioModel({
    required this.id,
    required this.title,
    this.clientName,
    this.category,
    this.description,
    this.imageUrl,
    this.originalPrice,
    this.agreedPrice,
    this.technologies,
    this.status = 'completed',
    this.completedAt,
    required this.isActive,
    required this.createdAt,
  });

  factory PortfolioModel.fromMap(Map<String, dynamic> map) {
    return PortfolioModel(
      id:            map['id']             ?? '',
      title:         map['title']          ?? '',
      clientName:    map['client_name'],
      category:      map['category'],
      description:   map['description'],
      imageUrl:      map['image_url'],
      originalPrice: map['original_price'],
      agreedPrice:   map['agreed_price'],
      technologies:  map['technologies'],
      status:        map['status']         ?? 'completed',
      completedAt:   map['completed_at'],
      isActive:      map['is_active']      ?? true,
      createdAt:     DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title':          title,
    'client_name':    clientName,
    'category':       category,
    'description':    description,
    'image_url':      imageUrl,
    'original_price': originalPrice,
    'agreed_price':   agreedPrice,
    'technologies':   technologies,
    'status':         status,
    'completed_at':   completedAt,
    'is_active':      isActive,
    'updated_at':     DateTime.now().toIso8601String(),
  };

  String get statusLabel {
    switch (status) {
      case 'ongoing':  return 'Ongoing';
      case 'upcoming': return 'Upcoming';
      default:         return 'Completed';
    }
  }

  String get statusColorHex {
    switch (status) {
      case 'ongoing':  return '3B82F6';
      case 'upcoming': return 'F59E0B';
      default:         return '10B981';
    }
  }
}