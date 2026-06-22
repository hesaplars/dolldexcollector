enum CatalogItemType {
  character,
  doll,
  set,
  pet,
  accessory,
}

enum CollectionStatus {
  owned,
  wanted,
  trade,
  selling,
}

enum CollectionCondition {
  boxed,
  unboxed,
  complete,
  incomplete,
  damaged,
}

class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.name,
    required this.type,
    required this.subtitle,
    required this.imageUrls,
    this.year,
    this.characterIds = const [],
    this.setIds = const [],
    this.tags = const [],
    this.description = '',
    this.averagePrice = 1200.0,
    this.parentId,
    this.series,
  });

  final String id;
  final String name;
  final CatalogItemType type;
  final String subtitle;
  final List<String> imageUrls;
  final int? year;
  final List<String> characterIds;
  final List<String> setIds;
  final List<String> tags;
  final String description;
  final double averagePrice;
  final String? parentId;
  final String? series;

  String get primaryImageUrl => imageUrls.isEmpty ? '' : imageUrls.first;

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'type': type.name,
      'subtitle': subtitle,
      'imageUrls': imageUrls,
      'year': year,
      'characterIds': characterIds,
      'setIds': setIds,
      'tags': tags,
      'description': description,
      'averagePrice': averagePrice,
      'parentId': parentId,
      'series': series,
    };
  }

  factory CatalogEntry.fromMap(String id, Map<String, Object?> map) {
    final nameVal = map['name'];
    final subtitleVal = map['subtitle'];
    final descVal = map['description'];

    // Robust year parsing
    int? parsedYear;
    final rawYear = map['year'];
    if (rawYear is num) {
      parsedYear = rawYear.toInt();
    } else if (rawYear is String) {
      parsedYear = int.tryParse(rawYear.trim());
    }

    // Robust imageUrls parsing supporting legacy/alternative field 'imageUrl'
    final List<String> parsedUrls = [];
    final rawUrls = map['imageUrls'] ?? map['imageUrl'];
    if (rawUrls is List) {
      for (final val in rawUrls) {
        if (val != null) {
          final str = val.toString().trim();
          if (str.isNotEmpty) {
            parsedUrls.add(str);
          }
        }
      }
    } else if (rawUrls is String) {
      parsedUrls.addAll(
        rawUrls
            .split(',')
            .map((u) => u.trim())
            .where((u) => u.isNotEmpty),
      );
    }

    final rawPrice = map['averagePrice'];
    double parsedPrice = 1200.0;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice is String) {
      parsedPrice = double.tryParse(rawPrice.trim()) ?? 1200.0;
    }

    return CatalogEntry(
      id: id,
      name: nameVal?.toString() ?? '',
      type: CatalogItemType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => CatalogItemType.doll,
      ),
      subtitle: subtitleVal?.toString() ?? '',
      imageUrls: parsedUrls,
      year: parsedYear,
      characterIds: _stringList(map['characterIds']),
      setIds: _stringList(map['setIds']),
      tags: _stringList(map['tags']),
      description: descVal?.toString() ?? '',
      averagePrice: parsedPrice,
      parentId: map['parentId'] as String?,
      series: map['series'] as String?,
    );
  }
}

class CollectionEntry {
  const CollectionEntry({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.status,
    required this.condition,
    required this.quantity,
    this.notes = '',
    this.isPublic = true,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String itemId;
  final CollectionStatus status;
  final CollectionCondition condition;
  final int quantity;
  final String notes;
  final bool isPublic;
  final DateTime? updatedAt;

  Map<String, Object?> toMap() {
    return {
      'userId': userId,
      'itemId': itemId,
      'status': status.name,
      'condition': condition.name,
      'quantity': quantity,
      'notes': notes,
      'visibility': isPublic ? 'public' : 'private',
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return List<String>.from(
      value.map((e) => e?.toString().trim() ?? '').where((s) => s.isNotEmpty),
    );
  }
  if (value is String) {
    return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
  return const [];
}
