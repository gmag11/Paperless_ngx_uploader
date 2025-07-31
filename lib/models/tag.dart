class Tag {
  final int id;
  final String name;
  final String? color;
  final String? match;
  final int? matchingAlgorithm;
  final bool? isInsensitive;
  final bool? isInboxTag;

  Tag({
    required this.id,
    required this.name,
    this.color,
    this.match,
    this.matchingAlgorithm,
    this.isInsensitive,
    this.isInboxTag,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'],
      name: json['name'],
      color: json['color'],
      match: json['match'],
      matchingAlgorithm: json['matching_algorithm'],
      isInsensitive: json['is_insensitive'],
      isInboxTag: json['is_inbox_tag'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'match': match,
      'matching_algorithm': matchingAlgorithm,
      'is_insensitive': isInsensitive,
      'is_inbox_tag': isInboxTag,
    };
  }

  @override
  String toString() => name;
}