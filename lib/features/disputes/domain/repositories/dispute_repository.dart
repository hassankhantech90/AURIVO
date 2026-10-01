import 'dart:typed_data';

import '../entities/dispute.dart';

/// Disputes and their message threads. Reads are RLS-scoped to participants
/// (the order's buyer and sellers, admins); state changes are server RPCs.
abstract class DisputeRepository {
  Future<String?> currentProfileId();

  /// The most recent dispute for [orderId], or null.
  Future<Dispute?> latestForOrder(String orderId);

  Future<Dispute> getDispute(String disputeId);

  /// Admin dispute centre: disputes with [status] (newest first).
  Future<List<Dispute>> listByStatus(String status);

  Future<List<DisputeMessage>> getMessages(String disputeId);

  /// Buyer or seller on the order; the first message is [description].
  Future<Dispute> openDispute({
    required String orderId,
    required String reason,
    required String description,
  });

  Future<Dispute> withdraw(String disputeId);

  /// Admin only. [refundAmount] is required for a partial refund.
  Future<Dispute> resolve(
    String disputeId, {
    required String resolution,
    double? refundAmount,
    required String note,
  });

  Future<void> sendMessage({
    required String disputeId,
    required String body,
    bool internal = false,
    List<String> attachments = const [],
  });

  /// Uploads an evidence image and returns its storage path.
  Future<String> uploadEvidence({
    required String disputeId,
    required Uint8List bytes,
    required String extension,
  });

  /// Short-lived URL to view a private evidence file.
  Future<String> evidenceUrl(String path);
}
