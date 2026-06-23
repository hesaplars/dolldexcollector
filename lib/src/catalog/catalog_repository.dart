import 'catalog_models.dart';

abstract class CatalogRepository {
  Future<List<CatalogEntry>> search({
    String query = '',
    CatalogItemType? type,
  });

  Future<void> saveDraft(CatalogEntry entry);
  Future<void> delete(String id);
}

class InMemoryCatalogRepository implements CatalogRepository {
  InMemoryCatalogRepository({
    List<CatalogEntry>? seedEntries,
  }) : _entries = [...?seedEntries];

  final List<CatalogEntry> _entries;

  @override
  Future<List<CatalogEntry>> search({
    String query = '',
    CatalogItemType? type,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();

    return _entries.where((entry) {
      final matchesType = type == null || entry.type == type;
      final matchesQuery = normalizedQuery.isEmpty ||
          entry.name.toLowerCase().contains(normalizedQuery) ||
          entry.subtitle.toLowerCase().contains(normalizedQuery) ||
          entry.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));

      return matchesType && matchesQuery;
    }).toList(growable: false);
  }

  @override
  Future<void> saveDraft(CatalogEntry entry) async {
    _entries.removeWhere((existing) => existing.id == entry.id);
    _entries.add(entry);
  }

  @override
  Future<void> delete(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
  }
}

const fallbackCatalogRepositorySeed = [
  CatalogEntry(
    id: 'template-character',
    name: 'Character Profile',
    type: CatalogItemType.character,
    subtitle: 'Wiki entry template',
    imageUrls: [],
    tags: ['character', 'wiki'],
    description: 'Character pages will connect dolls, pets and accessories.',
  ),
  CatalogEntry(
    id: 'template-doll',
    name: 'Doll Release',
    type: CatalogItemType.doll,
    subtitle: 'Owned, wanted, trade',
    imageUrls: [],
    tags: ['doll', 'release'],
    description: 'Doll releases will be tracked as collection pieces.',
  ),
  CatalogEntry(
    id: 'template-pet',
    name: 'Pet Companion',
    type: CatalogItemType.pet,
    subtitle: 'Linked to character',
    imageUrls: [],
    tags: ['pet'],
    description: 'Pets can connect to characters and doll releases.',
  ),
  CatalogEntry(
    id: 'template-accessory',
    name: 'Accessory Piece',
    type: CatalogItemType.accessory,
    subtitle: 'Set completion item',
    imageUrls: [],
    tags: ['accessory', 'completion'],
    description: 'Accessories help users complete detailed sets.',
  ),
];

final fallbackCatalogRepository = InMemoryCatalogRepository(
  seedEntries: fallbackCatalogRepositorySeed,
);
