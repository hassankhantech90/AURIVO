import 'dart:typed_data';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_storage_service.dart';
import '../domain/entities/dispute.dart';
import '../domain/repositories/dispute_repository.dart';
import 'dispute_failure_mapper.dart';

/// Supabase-backed [DisputeRepository]. Evidence lives in the private
/// `dispute-evidence` bucket under `<disputeId>/...` (participant-only RLS).
class SupabaseDisputeRepository implements DisputeRepository {
  const SupabaseDisputeRepository({
    required SupabaseDatabaseService database,
    required SupabaseStorageService storage,
  }) : _database = database,
       _storage = storage;

  final SupabaseDatabaseService _database;
  final SupabaseStorageService _storage;

  static const _bucket = 'dispute-evidence';

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (error) {
      throw DisputeFailureMapper.map(error);
    }
  }

  @override
  Future<String?> currentProfileId() => _guard(() async {
    final result = await _database.rpc(functionName: 'current_profile_id');
    return result is String && result.isNotEmpty ? result : null;
  });

  @override
  Future<Dispute?> latestForOrder(String orderId) => _guard(() async {
    final rows = await _database.list(
      table: 'disputes',
      filters: {'order_id': orderId},
      orderBy: 'created_at',
      ascending: false,
      limit: 1,
    );
    return rows.isEmpty ? null : Dispute.fromMap(rows.first);
  });

  @override
  Future<Dispute> getDispute(String disputeId) => _guard(() async {
    final rows = await _database.list(
      table: 'disputes',
      filters: {'id': disputeId},
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Dispute not found.');
    return Dispute.fromMap(rows.first);
  });

  @override
  Future<List<Dispute>> listByStatus(String status) => _guard(() async {
    final rows = await _database.list(
      table: 'disputes',
      filters: {'status': status},
      orderBy: 'created_at',
      ascending: false,
    );
    return rows.map(Dispute.fromMap).toList();
  });

  @override
  Future<List<DisputeMessage>> getMessages(String disputeId) => _guard(() async {
    final rows = await _database.list(
      table: 'dispute_messages',
      filters: {'dispute_id': disputeId},
      orderBy: 'created_at',
    );
    return rows.map(DisputeMessage.fromMap).toList();
  });

  Future<Dispute> _rpc(String fn, Map<String, dynamic> params) => _guard(
    () async => Dispute.fromMap(
      Map<String, dynamic>.from(
        await _database.rpc(functionName: fn, params: params) as Map,
      ),
    ),
  );

  @override
  Future<Dispute> openDispute({
    required String orderId,
    required String reason,
    required String description,
  }) => _rpc('open_dispute', {
    'p_order_id': orderId,
    'p_reason': reason,
    'p_description': description,
  });

  @override
  Future<Dispute> withdraw(String disputeId) =>
      _rpc('withdraw_dispute', {'p_dispute_id': disputeId});

  @override
  Future<Dispute> resolve(
    String disputeId, {
    required String resolution,
    double? refundAmount,
    required String note,
  }) => _rpc('resolve_dispute', {
    'p_dispute_id': disputeId,
    'p_resolution': resolution,
    'p_refund_amount': refundAmount,
    'p_note': note,
  });

  @override
  Future<void> sendMessage({
    required String disputeId,
    required String body,
    bool internal = false,
    List<String> attachments = const [],
  }) => _guard(() async {
    final profileId = await currentProfileId();
    await _database.insertVoid(
      table: 'dispute_messages',
      values: {
        'dispute_id': disputeId,
        'author_profile_id': profileId,
        'body': body.trim(),
        'is_internal': internal,
        'attachments': attachments,
      },
    );
  });

  @override
  Future<String> uploadEvidence({
    required String disputeId,
    required Uint8List bytes,
    required String extension,
  }) => _guard(() async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final path = '$disputeId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _storage.uploadImage(
      bucket: _bucket,
      path: path,
      bytes: bytes,
      contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
    );
    return path;
  });

  @override
  Future<String> evidenceUrl(String path) =>
      _guard(() => _storage.createSignedUrl(bucket: _bucket, path: path));
}
