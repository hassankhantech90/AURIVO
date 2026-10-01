import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/supabase/supabase_storage_service.dart';
import '../data/supabase_dispute_repository.dart';
import '../domain/entities/dispute.dart';
import '../domain/repositories/dispute_repository.dart';

final disputeRepositoryProvider = Provider<DisputeRepository>((ref) {
  const service = SupabaseService();
  return const SupabaseDisputeRepository(
    database: SupabaseDatabaseService(supabaseService: service),
    storage: SupabaseStorageService(supabaseService: service),
  );
});

/// Latest dispute for an order (null when none) — for the order screens.
final orderDisputeProvider = FutureProvider.autoDispose
    .family<Dispute?, String>(
      (ref, orderId) =>
          ref.watch(disputeRepositoryProvider).latestForOrder(orderId),
    );

/// Admin dispute centre list for a status ('open', 'resolved', 'withdrawn').
final adminDisputesProvider = FutureProvider.autoDispose
    .family<List<Dispute>, String>(
      (ref, status) => ref.watch(disputeRepositoryProvider).listByStatus(status),
    );

/// A dispute with its visible messages and the viewer's profile id.
class DisputeThread {
  const DisputeThread({
    required this.dispute,
    required this.messages,
    this.myProfileId,
  });

  final Dispute dispute;
  final List<DisputeMessage> messages;
  final String? myProfileId;

  bool isMine(DisputeMessage m) => m.authorProfileId == myProfileId;
  bool get openedByMe => dispute.openedBy == myProfileId;
}

final disputeThreadProvider = StateNotifierProvider.autoDispose
    .family<DisputeThreadNotifier, AsyncValue<DisputeThread>, String>(
      (ref, disputeId) =>
          DisputeThreadNotifier(ref.watch(disputeRepositoryProvider), disputeId),
    );

class DisputeThreadNotifier extends StateNotifier<AsyncValue<DisputeThread>> {
  DisputeThreadNotifier(this._repository, this._disputeId)
    : super(const AsyncValue.loading()) {
    load();
  }

  final DisputeRepository _repository;
  final String _disputeId;

  Future<void> load() async {
    final next = await AsyncValue.guard(() async {
      final dispute = await _repository.getDispute(_disputeId);
      final messages = await _repository.getMessages(_disputeId);
      final me = await _repository.currentProfileId();
      return DisputeThread(dispute: dispute, messages: messages, myProfileId: me);
    });
    if (mounted) state = next;
  }

  /// Sends a message with optional evidence images ((bytes, extension)).
  /// Returns null on success or a user-facing message.
  Future<String?> send(
    String body, {
    bool internal = false,
    List<(Uint8List, String)> images = const [],
  }) => _act(() async {
    final paths = <String>[
      for (final (bytes, ext) in images)
        await _repository.uploadEvidence(
          disputeId: _disputeId,
          bytes: bytes,
          extension: ext,
        ),
    ];
    await _repository.sendMessage(
      disputeId: _disputeId,
      body: body,
      internal: internal,
      attachments: paths,
    );
  });

  Future<String?> withdraw() => _act(() => _repository.withdraw(_disputeId));

  Future<String?> resolve({
    required String resolution,
    double? refundAmount,
    required String note,
  }) => _act(
    () => _repository.resolve(
      _disputeId,
      resolution: resolution,
      refundAmount: refundAmount,
      note: note,
    ),
  );

  Future<String?> _act(Future<void> Function() action) async {
    try {
      await action();
      await load();
      return null;
    } catch (error) {
      return error.toString();
    }
  }
}
