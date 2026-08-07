import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_exceptions.dart';
import 'supabase_service.dart';

/// Supabase Storage service for image upload, deletion, and public URLs.
class SupabaseStorageService {
  const SupabaseStorageService({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  final SupabaseService _supabaseService;

  Future<String> uploadImage({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String? contentType,
    bool upsert = false,
  }) async {
    try {
      return await _supabaseService.client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: upsert),
          );
    } catch (error) {
      throw SupabaseExceptionMapper.storage(error);
    }
  }

  Future<void> deleteImage({
    required String bucket,
    required String path,
  }) async {
    try {
      await _supabaseService.client.storage.from(bucket).remove([path]);
    } catch (error) {
      throw SupabaseExceptionMapper.storage(error);
    }
  }

  String getPublicUrl({required String bucket, required String path}) {
    try {
      return _supabaseService.client.storage.from(bucket).getPublicUrl(path);
    } catch (error) {
      throw SupabaseExceptionMapper.storage(error);
    }
  }
}
