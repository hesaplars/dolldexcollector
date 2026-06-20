import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'catalog_models.dart';
import 'catalog_repository.dart';

bool _isFirebaseInitialized() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class FirestoreCatalogRepository implements CatalogRepository {
  FirestoreCatalogRepository({
    FirebaseFirestore? firestore,
  })  : _firestore = firestore,
        _fallback = InMemoryCatalogRepository(
          seedEntries: fallbackCatalogRepositorySeed,
        );

  final FirebaseFirestore? _firestore;
  final InMemoryCatalogRepository _fallback;

  FirebaseFirestore? get _db {
    if (!_isFirebaseInitialized()) {
      return null;
    }
    return _firestore ?? FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>>? get _items =>
      _db?.collection('items');

  @override
  Future<List<CatalogEntry>> search({
    String query = '',
    CatalogItemType? type,
  }) async {
    final items = _items;
    if (items == null) {
      return _fallback.search(query: query, type: type);
    }

    try {
      // Fetch all items without ordering/filtering on the server to prevent composite index errors
      final snapshot = await items.get();
      final firestoreItems = <CatalogEntry>[];
      for (final doc in snapshot.docs) {
        try {
          firestoreItems.add(CatalogEntry.fromMap(doc.id, doc.data()));
        } catch (e) {
          print('Error parsing firestore catalog item ${doc.id}: $e');
        }
      }

      final fallbackItems = await _fallback.search(query: query, type: type);

      final Map<String, CatalogEntry> mergedMap = {};
      for (final item in fallbackItems) {
        mergedMap[item.id] = item;
      }
      for (final item in firestoreItems) {
        mergedMap[item.id] = item;
      }

      final normalizedQuery = query.trim().toLowerCase();
      final filteredList = mergedMap.values.where((entry) {
        final matchesType = type == null || entry.type == type;
        if (!matchesType) {
          return false;
        }

        if (normalizedQuery.isEmpty) {
          return true;
        }

        return entry.name.toLowerCase().contains(normalizedQuery) ||
            entry.subtitle.toLowerCase().contains(normalizedQuery) ||
            entry.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
      }).toList();

      // Sort alphabetically by name in memory
      filteredList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return filteredList;
    } catch (error) {
      print('Firestore catalog search error: $error');
      return _fallback.search(query: query, type: type);
    }
  }

  @override
  Future<void> saveDraft(CatalogEntry entry) async {
    // Keep local memory fallback cache in sync
    await _fallback.saveDraft(entry);

    final items = _items;
    if (items == null) {
      return;
    }

    final doc = entry.id.isEmpty ? items.doc() : items.doc(entry.id);
    final snapshot = await doc.get();
    final data = <String, Object?>{
      ...entry.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'published',
    };
    if (!snapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await doc.set(data, SetOptions(merge: true));
  }

  @override
  Future<void> delete(String id) async {
    // Keep local memory fallback cache in sync
    await _fallback.delete(id);

    final items = _items;
    if (items == null) {
      return;
    }
    await items.doc(id).delete();
  }
}
