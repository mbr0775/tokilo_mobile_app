enum FeedPostType {
  project,
  news,
  offer,
  feature,
}

class FeedPostModel {
  final String id;
  final FeedPostType type;
  final String title;
  final String? subtitle;
  final String? body;
  final String? imageUrl;
  final String? buttonLabel;
  final String? buttonRoute;
  final String? category;
  final DateTime createdAt;

  const FeedPostModel({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.body,
    this.imageUrl,
    this.buttonLabel,
    this.buttonRoute,
    this.category,
    required this.createdAt,
  });

  String get uploaderName => 'Tokilo';

  String get typeLabel {
    switch (type) {
      case FeedPostType.project:
        return 'Project';
      case FeedPostType.news:
        return 'News';
      case FeedPostType.offer:
        return 'Offer';
      case FeedPostType.feature:
        return 'Update';
    }
  }

  factory FeedPostModel.fromProjectShowcase(Map<String, dynamic> map) {
    return FeedPostModel(
      id: 'project_${map['id'] ?? ''}',
      type: FeedPostType.project,
      title: map['title']?.toString() ?? 'Tokilo Project',
      subtitle: map['subtitle']?.toString() ?? map['category']?.toString() ?? 'Project showcase',
      body: map['description']?.toString(),
      imageUrl: map['image_url']?.toString(),
      buttonLabel: 'View Project',
      buttonRoute: '/portfolio',
      category: map['category']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  factory FeedPostModel.fromHomeBanner(Map<String, dynamic> map) {
    return FeedPostModel(
      id: 'banner_${map['id'] ?? ''}',
      type: FeedPostType.news,
      title: map['title']?.toString() ?? 'Tokilo Update',
      subtitle: map['subtitle']?.toString(),
      body: map['subtitle']?.toString(),
      imageUrl: map['image_url']?.toString(),
      buttonLabel: map['button_label']?.toString(),
      buttonRoute: map['button_route']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  factory FeedPostModel.fromHomePromo(Map<String, dynamic> map) {
    return FeedPostModel(
      id: 'promo_${map['id'] ?? ''}',
      type: FeedPostType.offer,
      title: map['title']?.toString() ?? 'Tokilo Offer',
      subtitle: map['subtitle']?.toString(),
      body: map['subtitle']?.toString(),
      imageUrl: map['image_url']?.toString(),
      buttonLabel: map['button_label']?.toString(),
      buttonRoute: map['button_url']?.toString(),
      category: map['promo_type']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  factory FeedPostModel.fromHomeFeature(Map<String, dynamic> map) {
    return FeedPostModel(
      id: 'feature_${map['id'] ?? ''}',
      type: FeedPostType.feature,
      title: map['label']?.toString() ?? 'Why Tokilo',
      subtitle: 'Tokilo update',
      body: map['label']?.toString(),
      imageUrl: null,
      buttonLabel: null,
      buttonRoute: null,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}