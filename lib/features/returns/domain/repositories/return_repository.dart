import '../entities/return_request.dart';

/// Return requests for an order. Reads are RLS-scoped (buyer, the order's
/// sellers, admin); every write is a server RPC that enforces who may do what.
abstract class ReturnRepository {
  /// The most recent return request for [orderId], or null.
  Future<ReturnRequest?> latestForOrder(String orderId);

  /// Buyer: request a return (delivered order, within the return window).
  Future<ReturnRequest> request({
    required String orderId,
    required String reason,
    String? details,
  });

  /// Buyer: withdraw a request that hasn't been decided yet.
  Future<ReturnRequest> cancel(String returnId);

  /// Seller/admin: approve or reject (a note is required to reject).
  Future<ReturnRequest> decide(String returnId, {required bool approve, String? note});

  /// Seller/admin: the returned item arrived.
  Future<ReturnRequest> markReceived(String returnId);

  /// Admin: the refund was paid (manual for COD).
  Future<ReturnRequest> markRefunded(String returnId, {String? note});
}
