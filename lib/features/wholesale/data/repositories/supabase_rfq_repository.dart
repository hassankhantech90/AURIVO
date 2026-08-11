import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/utils/failure.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/rfq.dart';
import '../../domain/entities/rfq_detail.dart';
import '../../domain/entities/rfq_status.dart';
import '../../domain/repositories/rfq_repository.dart';
import '../rfq_failure_mapper.dart';

/// Supabase-backed [RFQRepository].
///
/// RFQ writes are plain, RLS-governed table operations. The buyer identity is
/// always resolved from `current_profile_id()` and set as `buyer_profile_id` —
/// the UI never supplies it. Quotes are read-only to the buyer.
class SupabaseRfqRepository implements RFQRepository {
  SupabaseRfqRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _rfqsTable = 'rfqs';
  static const String _quotesTable = 'quotes';

  @override
  Future<Rfq> createRfq({
    required int quantity,
    String? productId,
    String? productVariantId,
    String? sellerProfileId,
    String? businessProfileId,
    double? targetPrice,
    String currency = 'PKR',
    String? message,
  }) async {
    try {
      final buyerProfileId = await _requireProfileId();
      final values = <String, dynamic>{
        // buyer_profile_id is server-derived, never taken from the UI.
        'buyer_profile_id': buyerProfileId,
        'quantity': quantity,
        'currency': currency,
        'product_id': ?productId,
        'product_variant_id': ?productVariantId,
        'seller_profile_id': ?sellerProfileId,
        'business_profile_id': ?businessProfileId,
        'target_price': ?targetPrice,
        'message': ?_clean(message),
      };
      final row = await _database.insert(table: _rfqsTable, values: values);
      return Rfq.fromMap(row);
    } catch (error) {
      throw RfqFailureMapper.map(error);
    }
  }

  @override
  Future<List<Rfq>> getMyRfqs({int limit = 50, int offset = 0}) async {
    try {
      final buyerProfileId = await _requireProfileId();
      final rows = await _database.list(
        table: _rfqsTable,
        filters: {'buyer_profile_id': buyerProfileId},
        orderBy: 'created_at',
        ascending: false,
        limit: limit,
        offset: offset,
      );
      return rows.map(Rfq.fromMap).toList();
    } catch (error) {
      throw RfqFailureMapper.map(error);
    }
  }

  @override
  Future<RfqDetail> getRfq(String rfqId) async {
    try {
      final rfqRows = await _database.list(
        table: _rfqsTable,
        filters: {'id': rfqId},
        limit: 1,
      );
      if (rfqRows.isEmpty) {
        throw const Failure(message: 'Request not found.');
      }
      final rfq = Rfq.fromMap(rfqRows.first);

      final quoteRows = await _database.list(
        table: _quotesTable,
        filters: {'rfq_id': rfqId},
        orderBy: 'created_at',
        ascending: false,
      );
      return RfqDetail(rfq: rfq, quotes: quoteRows.map(Quote.fromMap).toList());
    } catch (error) {
      throw RfqFailureMapper.map(error);
    }
  }

  @override
  Future<Rfq> cancelRfq(String rfqId) async {
    try {
      // RLS scopes the update to the owning buyer; status is the only field the
      // buyer changes here.
      final row = await _database.update(
        table: _rfqsTable,
        values: {'status': RfqStatus.cancelled},
        matchColumn: 'id',
        matchValue: rfqId,
      );
      return Rfq.fromMap(row);
    } catch (error) {
      throw RfqFailureMapper.map(error);
    }
  }

  Future<String> _requireProfileId() async {
    final result = await _database.rpc(functionName: 'current_profile_id');
    if (result is String && result.isNotEmpty) return result;
    throw const Failure(message: 'Please sign in to request a quote.');
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
