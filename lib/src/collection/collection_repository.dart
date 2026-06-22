import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../catalog/catalog_models.dart';
import '../core/local_storage_helper.dart';

abstract class CollectionRepository {
  Future<void> save(CollectionEntry entry);

  Future<void> delete(CollectionEntry entry);

  Future<List<CollectionEntry>> listForUser(String userId);

  Future<List<CollectionEntry>> listPublicForUser(String userId);

  Future<CollectionEntry?> fetch(String id);
}

bool _isFirebaseInitialized() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class FirestoreCollectionRepository implements CollectionRepository {
  FirestoreCollectionRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final List<CollectionEntry> _entries = [];
  bool _localLoaded = false;

  Future<void> _saveLocalToStorage() async {
    final List<Map<String, dynamic>> maps = _entries
        .where((e) => e.userId == 'local-user')
        .map((e) => {
              'id': e.id,
              ...e.toMap(),
            })
        .toList();
    await LocalStorage.setString('local_collection_entries', jsonEncode(maps));
  }

  Future<void> _loadLocalFromStorage() async {
    if (_localLoaded) return;
    _localLoaded = true;
    final jsonStr = await LocalStorage.getString('local_collection_entries');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List decoded = jsonDecode(jsonStr);
        _entries.clear();
        for (final item in decoded) {
          if (item is Map) {
            _entries.add(CollectionEntry(
              id: item['id'] as String? ?? '',
              userId: 'local-user',
              itemId: item['itemId'] as String? ?? '',
              status: CollectionStatus.values.firstWhere(
                (status) => status.name == item['status'],
                orElse: () => CollectionStatus.owned,
              ),
              condition: CollectionCondition.values.firstWhere(
                (condition) => condition.name == item['condition'],
                orElse: () => CollectionCondition.complete,
              ),
              quantity: item['quantity'] as int? ?? 1,
              notes: item['notes'] as String? ?? '',
              isPublic: item['visibility'] != 'private',
              updatedAt: _dateFromValue(item['updatedAt']),
            ));
          }
        }
      } catch (e) {
        print('Error loading local collection entries: $e');
      }
    }
  }

  FirebaseFirestore? get _db {
    if (!_isFirebaseInitialized()) {
      return null;
    }
    return _firestore ?? FirebaseFirestore.instance;
  }

  @override
  Future<void> save(CollectionEntry entry) async {
    if (entry.userId == 'local-user') {
      await _loadLocalFromStorage();
    }
    _entries.removeWhere((existing) => existing.id == entry.id);
    _entries.add(entry);

    final db = _db;
    if (db == null || entry.userId == 'local-user') {
      await _saveLocalToStorage();
      return;
    }

    final ref = db.collection('collectionEntries').doc(entry.id);
    final snapshot = await ref.get();
    final data = <String, Object?>{
      ...entry.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!snapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(data, SetOptions(merge: true));
  }

  @override
  Future<void> delete(CollectionEntry entry) async {
    if (entry.userId == 'local-user') {
      await _loadLocalFromStorage();
    }
    _entries.removeWhere((existing) => existing.id == entry.id);

    final db = _db;
    if (db == null || entry.userId == 'local-user') {
      await _saveLocalToStorage();
      return;
    }

    await db.collection('collectionEntries').doc(entry.id).delete();
  }

  @override
  Future<List<CollectionEntry>> listForUser(String userId) async {
    if (userId == 'local-user') {
      await _loadLocalFromStorage();
    }
    final db = _db;
    if (db != null && userId != 'local-user') {
      final snapshot = await db
          .collection('collectionEntries')
          .where('userId', isEqualTo: userId)
          .limit(120)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CollectionEntry(
          id: doc.id,
          userId: data['userId'] as String? ?? userId,
          itemId: data['itemId'] as String? ?? '',
          status: CollectionStatus.values.firstWhere(
            (status) => status.name == data['status'],
            orElse: () => CollectionStatus.owned,
          ),
          condition: CollectionCondition.values.firstWhere(
            (condition) => condition.name == data['condition'],
            orElse: () => CollectionCondition.complete,
          ),
          quantity: data['quantity'] as int? ?? 1,
          notes: data['notes'] as String? ?? '',
          isPublic: data['visibility'] != 'private',
          updatedAt: _dateFromValue(data['updatedAt']),
        );
      }).toList(growable: false);
    }

    return _entries
        .where((entry) => entry.userId == userId)
        .toList(growable: false);
  }

  @override
  Future<List<CollectionEntry>> listPublicForUser(String userId) async {
    if (userId == 'local-user') {
      await _loadLocalFromStorage();
    }
    final db = _db;
    if (db != null && userId != 'local-user') {
      final snapshot = await db
          .collection('collectionEntries')
          .where('userId', isEqualTo: userId)
          .where('visibility', isEqualTo: 'public')
          .limit(120)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CollectionEntry(
          id: doc.id,
          userId: data['userId'] as String? ?? userId,
          itemId: data['itemId'] as String? ?? '',
          status: CollectionStatus.values.firstWhere(
            (status) => status.name == data['status'],
            orElse: () => CollectionStatus.owned,
          ),
          condition: CollectionCondition.values.firstWhere(
            (condition) => condition.name == data['condition'],
            orElse: () => CollectionCondition.complete,
          ),
          quantity: data['quantity'] as int? ?? 1,
          notes: data['notes'] as String? ?? '',
          isPublic: data['visibility'] != 'private',
          updatedAt: _dateFromValue(data['updatedAt']),
        );
      }).toList(growable: false);
    }

    return _entries
        .where((entry) => entry.userId == userId && entry.isPublic)
        .toList(growable: false);
  }

  @override
  Future<CollectionEntry?> fetch(String id) async {
    await _loadLocalFromStorage();
    final db = _db;
    if (db != null) {
      try {
        final doc = await db.collection('collectionEntries').doc(id).get();
        if (doc.exists) {
          final data = doc.data()!;
          return CollectionEntry(
            id: doc.id,
            userId: data['userId'] as String? ?? '',
            itemId: data['itemId'] as String? ?? '',
            status: CollectionStatus.values.firstWhere(
              (status) => status.name == data['status'],
              orElse: () => CollectionStatus.owned,
            ),
            condition: CollectionCondition.values.firstWhere(
              (condition) => condition.name == data['condition'],
              orElse: () => CollectionCondition.complete,
            ),
            quantity: data['quantity'] as int? ?? 1,
            notes: data['notes'] as String? ?? '',
            isPublic: data['visibility'] != 'private',
            updatedAt: _dateFromValue(data['updatedAt']),
          );
        }
      } catch (e) {
        print('Error fetching collection entry $id: $e');
      }
    }

    try {
      return _entries.firstWhere((entry) => entry.id == id);
    } catch (_) {
      return null;
    }
  }
}

DateTime? _dateFromValue(Object? value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
