import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'report_models.dart';
import 'report_sheet.dart';

bool _isFirebaseInitialized() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class ReportService {
  ReportService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore? get _db {
    if (!_isFirebaseInitialized()) {
      return null;
    }

    return _firestore ?? FirebaseFirestore.instance;
  }

  Future<String> createReport(UserReport report) async {
    final db = _db;
    if (db == null || report.reporterId == 'local-user') {
      return report.id;
    }

    await db.collection('reports').doc(report.id).set(report.toMap());
    return report.id;
  }

  Future<List<UserReport>> listReports() async {
    final db = _db;
    if (db == null) {
      return const <UserReport>[];
    }

    try {
      final snapshot = await db.collection('reports').get();
      final reports = snapshot.docs
          .map((doc) => UserReport.fromMap(doc.id, doc.data()))
          .toList();
      return reports..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return const <UserReport>[];
    }
  }

  Future<void> updateStatus(String id, ReportStatus status) async {
    final db = _db;
    if (db == null) {
      return;
    }

    await db.collection('reports').doc(id).update({'status': status.name});
  }

  Future<void> deleteReport(String id) async {
    final db = _db;
    if (db == null) {
      return;
    }

    await db.collection('reports').doc(id).delete();
  }

  Stream<List<UserReport>> watchReportsForUser(String reporterId) {
    final db = _db;
    if (db == null || reporterId == 'local-user') {
      return Stream.value([]);
    }
    return db
        .collection('reports')
        .where('reporterId', isEqualTo: reporterId)
        .snapshots()
        .map((snapshot) {
          final reports = snapshot.docs
              .map((doc) => UserReport.fromMap(doc.id, doc.data()))
              .toList();
          return reports..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
  }
}

extension UserReportDraftMapper on ReportDraft {
  UserReport toUserReport({
    required String id,
    required String reporterId,
  }) {
    return UserReport(
      id: id,
      reporterId: reporterId,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      status: ReportStatus.open,
      details: details,
    );
  }
}
