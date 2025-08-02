class Tag {
  final int id;
  final String slug;
  final String name;
  final String? color; // maxLength: 7
  final String textColor;
  final String? match; // maxLength: 256
  final int? matchingAlgorithm; // min: 0, max: 2147483647
  final bool? isInsensitive;
  final bool? isInboxTag;
  final int documentCount;
  final int? owner;
  final bool userCanChange;

  Tag({
    required this.id,
    required this.slug,
    required this.name,
    this.color,
    required this.textColor,
    this.match,
    this.matchingAlgorithm,
    this.isInsensitive,
    this.isInboxTag,
    required this.documentCount,
    this.owner,
    required this.userCanChange,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    // Handle legacy field names and provide fallbacks
    return Tag(
      id: json['id'] ?? 0,
      slug: json['slug'] ?? json['name']?.toLowerCase().replaceAll(' ', '-') ?? '',
      name: json['name'] ?? json['slug'] ?? 'Unknown Tag',
      color: json['color'] ?? json['backgroundColor'] ?? '#000000',
      textColor: json['text_color'] ?? json['textColor'] ?? '#ffffff',
      match: json['match'],
      matchingAlgorithm: json['matching_algorithm'] ?? json['algorithm'],
      isInsensitive: json['is_insensitive'] ?? json['isInsensitive'] ?? false,
      isInboxTag: json['is_inbox_tag'] ?? json['isInboxTag'] ?? false,
      documentCount: json['document_count'] ?? json['count'] ?? 0,
      owner: json['owner'],
      userCanChange: json['user_can_change'] ?? json['canChange'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'name': name,
      'color': color,
      'text_color': textColor,
      'match': match,
      'matching_algorithm': matchingAlgorithm,
      'is_insensitive': isInsensitive,
      'is_inbox_tag': isInboxTag,
      'document_count': documentCount,
      'owner': owner,
      'user_can_change': userCanChange,
    };
  }

  @override
  String toString() => name;
}