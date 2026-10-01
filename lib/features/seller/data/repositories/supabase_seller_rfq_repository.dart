import '../../../../core/supabase/supabase_database_service.dart';
import '../../../../core/utils/failure.dart';
import '../../../wholesale/domain/entities/quote.dart';
import '../../../wholesale/domain/entities/rfq.dart';
import '../../domain/entities/quote_draft.dart';
import '../../domain/repositories/seller_rfq_repository.dart';
import '../seller_quote_failure_mapper.dart';

/// Supabase-backed [SellerRfqRepository].
///
/// Reads rely on RLS: `rfqs_owner_and_seller_select` only returns RFQs matched
/// to the seller. Quote writes are scoped by `quotes_seller_*` to the seller's
/// own `seller_profile_id`, which this repository resolves server-side from the
/// current profile — the UI never supplies ownership.
class SupabaseSellerRfqRepository implements SellerRfqRepository {
  SupabaseSellerRfqRepository({required SupabaseDatabaseService database})
    : _database = database;

  final SupabaseDatabaseService _database;

  static const String _rfqsTable = 'rfqs';
  static const String _quotesTable = 'quotes';
  static const String _sellerProfilesTable = 'seller_profiles';

  @override
  Future<String?> mySellerProfileId() async {
    final profileId = await _currentProfileId();
    if (profileId == null) return null;
    final rows = await _database.list(
      table: _sellerProfilesTable,
      columns: 'id, profile_id',
      filters: {'profile_id': profileId},
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as String;
    // Not an owner: a store where this user is staff with orders access.
    final store = await _database.rpc(
      functionName: 'my_seller_store',
      params: {'p_permission': 'orders'},
    );
    return store is String && store.isNotEmpty ? store : null;
  }

  @override
  Future<List<Rfq>> getInboxRfqs({int limit = 100, int offset = 0}) async {
    try {
      final sellerId = await _requireSellerProfileId();
      final rows = await _database.list(
        table: _rfqsTable,
        filters: {'seller_profile_id': sellerId},
        orderBy: 'created_at',
        ascending: false,
        limit: limit,
        offset: offset,
      );
      return rows
          .where((r) => r['deleted_at'] == null)
          .map(Rfq.fromMap)
          .toList();
    } catch (error) {
      throw SellerQuoteFailureMapper.map(error);
    }
  }

  @override
  Future<Rfq> getRfq(String rfqId) async {
    try {
      final rows = await _database.list(
        table: _rfqsTable,
        filters: {'id': rfqId},
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const Failure(message: 'Request not found.');
      }
      return Rfq.fromMap(rows.first);
    } catch (error) {
      throw SellerQuoteFailureMapper.map(error);
    }
  }

  @override
  Future<Quote?> getMyQuoteForRfq(String rfqId) async {
    try {
      final sellerId = await _requireSellerProfileId();
      final rows = await _database.list(
        table: _quotesTable,
        filters: {'rfq_id': rfqId, 'seller_profile_id': sellerId},
        limit: 1,
      );
      final visible = rows.where((r) => r['deleted_at'] == null).toList();
      if (visible.isEmpty) return null;
      return Quote.fromMap(visible.first);
    } catch (error) {
      throw SellerQuoteFailureMapper.map(error);
    }
  }

  @override
  Future<Quote> createQuote(String rfqId, QuoteDraft draft) async {
    try {
      final sellerId = await _requireSellerProfileId();
      final row = await _database.insert(
        table: _quotesTable,
        values: {
          'rfq_id': rfqId,
          // seller_profile_id is server-derived, never taken from the UI.
          'seller_profile_id': sellerId,
          ..._columns(draft),
        },
      );
      return Quote.fromMap(row);
    } catch (error) {
      throw SellerQuoteFailureMapper.map(error);
    }
  }

  @override
  Future<Quote> updateQuote(String quoteId, QuoteDraft draft) async {
    try {
      final row = await _database.update(
        table: _quotesTable,
        values: _columns(draft),
        matchColumn: 'id',
        matchValue: quoteId,
      );
      return Quote.fromMap(row);
    } catch (error) {
      throw SellerQuoteFailureMapper.map(error);
    }
  }

  @override
  Future<void> deleteQuote(String quoteId) async {
    try {
      await _database.delete(
        table: _quotesTable,
        matchColumn: 'id',
        matchValue: quoteId,
      );
    } catch (error) {
      throw SellerQuoteFailureMapper.map(error);
    }
  }

  Map<String, dynamic> _columns(QuoteDraft d) {
    return <String, dynamic>{
      'unit_price': d.unitPrice,
      'total_price': d.totalPrice,
      'minimum_order_quantity': d.minimumOrderQuantity,
      'currency': d.currency,
      'status': d.status,
      'lead_time_days': ?d.leadTimeDays,
      'valid_until': ?d.validUntil?.toUtc().toIso8601String(),
      'message': ?_clean(d.message),
    };
  }

  Future<String> _requireSellerProfileId() async {
    final sellerId = await mySellerProfileId();
    if (sellerId == null) {
      throw const Failure(message: 'You do not have a seller store yet.');
    }
    return sellerId;
  }

  Future<String?> _currentProfileId() async {
    final result = await _database.rpc(functionName: 'current_profile_id');
    if (result is String && result.isNotEmpty) return result;
    return null;
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
