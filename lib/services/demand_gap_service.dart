// lib/services/demand_gap_service.dart
// Mirrors: SearchAdminController (/admin/search/demand-gaps), admin only

import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/demand_gap_models.dart';
import '../repositories/demand_gap_repository.dart';

class DemandGapService implements DemandGapRepository {
  final Dio _dio;

  DemandGapService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// GET /admin/search/demand-gaps?days=&min=
  @override
  Future<DemandGapReport> load({int days = 14, int min = 5}) async {
    try {
      final res = await _dio.get('/admin/search/demand-gaps', queryParameters: {'days': days, 'min': min});
      return DemandGapReport.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
