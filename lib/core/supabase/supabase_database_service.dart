import 'supabase_exceptions.dart';
import 'supabase_service.dart';

/// Generic Supabase PostgreSQL helpers. Table-specific repositories should wrap these later.
class SupabaseDatabaseService {
  const SupabaseDatabaseService({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  Future<List<Map<String, dynamic>>> select({
    required String table,
    String columns = '*',
    Map<String, Object?> filters = const {},
  }) async {
    try {
      dynamic query = _supabaseService.client.from(table).select(columns);
      for (final filter in filters.entries) {
        query = query.eq(filter.key, filter.value);
      }
      final response = await query;
      return List<Map<String, dynamic>>.from(response as List<dynamic>);
    } catch (error) {
      throw SupabaseExceptionMapper.database(error);
    }
  }

  /// Read helper for list/detail queries that need ordering, pagination, or
  /// `IN` filters (the plain [select] only supports equality filters).
  ///
  /// [columns] may include PostgREST embeds. [filters] are equality filters,
  /// [whereIn] are `IN` filters. When [limit] is provided, results are ranged
  /// starting at [offset] (defaults to 0). RLS still applies to every read.
  Future<List<Map<String, dynamic>>> list({
    required String table,
    String columns = '*',
    Map<String, Object?> filters = const {},
    Map<String, List<Object>> whereIn = const {},
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic query = _supabaseService.client.from(table).select(columns);
      for (final filter in filters.entries) {
        query = query.eq(filter.key, filter.value as Object);
      }
      for (final entry in whereIn.entries) {
        query = query.inFilter(entry.key, entry.value);
      }
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }
      if (limit != null) {
        final start = offset ?? 0;
        query = query.range(start, start + limit - 1);
      }
      final response = await query;
      return List<Map<String, dynamic>>.from(response as List<dynamic>);
    } catch (error) {
      throw SupabaseExceptionMapper.database(error);
    }
  }

  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> values,
  }) async {
    try {
      final response = await _supabaseService.client
          .from(table)
          .insert(values)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    } catch (error) {
      throw SupabaseExceptionMapper.database(error);
    }
  }

  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required String matchColumn,
    required Object matchValue,
  }) async {
    try {
      final response = await _supabaseService.client
          .from(table)
          .update(values)
          .eq(matchColumn, matchValue)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    } catch (error) {
      throw SupabaseExceptionMapper.database(error);
    }
  }

  Future<void> delete({
    required String table,
    required String matchColumn,
    required Object matchValue,
  }) async {
    try {
      await _supabaseService.client
          .from(table)
          .delete()
          .eq(matchColumn, matchValue);
    } catch (error) {
      throw SupabaseExceptionMapper.database(error);
    }
  }

  Stream<List<Map<String, dynamic>>> stream({
    required String table,
    required List<String> primaryKey,
  }) {
    try {
      return _supabaseService.client
          .from(table)
          .stream(primaryKey: primaryKey)
          .map((rows) => rows.map(Map<String, dynamic>.from).toList());
    } catch (error) {
      throw SupabaseExceptionMapper.database(error);
    }
  }

  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic> params = const {},
  }) async {
    try {
      return await _supabaseService.client.rpc(functionName, params: params);
    } catch (error) {
      throw SupabaseExceptionMapper.database(error);
    }
  }
}
