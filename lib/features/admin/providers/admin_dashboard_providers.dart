import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_database_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../domain/entities/admin_dashboard_stats.dart';

/// Loads dashboard figures for a look-back window in days (null = all time).
typedef AdminStatsLoader = Future<AdminDashboardStats> Function(int? days);

final adminStatsLoaderProvider = Provider<AdminStatsLoader>((ref) {
  const database = SupabaseDatabaseService(supabaseService: SupabaseService());
  return (days) async {
    final result = await database.rpc(
      functionName: 'admin_dashboard_stats',
      params: {'p_days': days},
    );
    return AdminDashboardStats.fromMap(
      Map<String, dynamic>.from(result as Map),
    );
  };
});

/// Dashboard figures keyed by window (7, 30, or null for all time).
final adminDashboardStatsProvider = FutureProvider.autoDispose
    .family<AdminDashboardStats, int?>(
      (ref, days) => ref.watch(adminStatsLoaderProvider)(days),
    );
