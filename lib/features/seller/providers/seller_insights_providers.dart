import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../domain/entities/seller_insights.dart';

typedef SellerInsightsLoader = Future<SellerInsights> Function(int? days);

final sellerInsightsLoaderProvider = Provider<SellerInsightsLoader>((ref) {
  const database = SupabaseDatabaseService(supabaseService: SupabaseService());
  return (days) async {
    final result = await database.rpc(
      functionName: 'seller_insights',
      params: {'p_days': days},
    );
    return SellerInsights.fromMap(Map<String, dynamic>.from(result as Map));
  };
});

/// Insights for the signed-in seller's store over a window (null = all time).
final sellerInsightsProvider = FutureProvider.autoDispose
    .family<SellerInsights, int?>(
      (ref, days) => ref.watch(sellerInsightsLoaderProvider)(days),
    );
