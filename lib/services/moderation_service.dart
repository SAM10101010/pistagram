import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/report_model.dart';
import 'firestore_service.dart';

class ModerationService {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  static const int autoFlagThreshold = 3; // Auto-flag after 3 reports

  /// Report content — auto-flag if report count exceeds threshold
  Future<void> reportContent({
    required String reporterUid,
    required String targetType, // user, reel, comment
    required String targetId,
    required String reason,
  }) async {
    final report = ReportModel(
      id: _uuid.v4(),
      reporterUid: reporterUid,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
    );
    await _firestoreService.createReport(report);

    // Auto-flag: check how many reports this target has
    final reports = await _db
        .collection('reports')
        .where('targetId', isEqualTo: targetId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (reports.docs.length >= autoFlagThreshold) {
      // Auto-action based on target type
      if (targetType == 'reel') {
        await removeContent(targetId);
      } else if (targetType == 'user') {
        await temporaryBan(targetId, const Duration(days: 7));
      }
    }
  }

  /// Suspend user indefinitely
  Future<void> suspendUser(String uid) async {
    await _firestoreService.updateUser(uid, {
      'accountStatus': 'suspended',
      'suspendedAt': Timestamp.now(),
    });
  }

  /// Unsuspend user
  Future<void> unsuspendUser(String uid) async {
    await _firestoreService.updateUser(uid, {
      'accountStatus': 'active',
      'suspendedAt': null,
    });
  }

  /// Temporary ban — suspend with a duration
  Future<void> temporaryBan(String uid, Duration duration) async {
    final expiresAt = DateTime.now().add(duration);
    await _firestoreService.updateUser(uid, {
      'accountStatus': 'suspended',
      'suspendedAt': Timestamp.now(),
      'banExpiresAt': Timestamp.fromDate(expiresAt),
      'banType': 'temporary',
    });
  }

  /// Permanent ban
  Future<void> permanentBan(String uid) async {
    await _firestoreService.updateUser(uid, {
      'accountStatus': 'suspended',
      'suspendedAt': Timestamp.now(),
      'banType': 'permanent',
    });
  }

  /// Remove content (soft delete)
  Future<void> removeContent(String reelId) async {
    await _firestoreService.deleteReel(reelId);
  }

  /// Remove post content
  Future<void> removePost(String postId) async {
    await _firestoreService.deletePost(postId);
  }

  /// Get pending reports
  Future<List<ReportModel>> getPendingReports() async {
    return await _firestoreService.getPendingReports();
  }

  /// Resolve a report (accept or reject)
  Future<void> resolveReport(String reportId, String action) async {
    await _db.collection('reports').doc(reportId).update({
      'status': 'resolved',
      'action': action,
      'resolvedAt': Timestamp.now(),
    });
  }

  /// Get report count for a target
  Future<int> getReportCount(String targetId) async {
    final snap = await _db
        .collection('reports')
        .where('targetId', isEqualTo: targetId)
        .get();
    return snap.docs.length;
  }
}
