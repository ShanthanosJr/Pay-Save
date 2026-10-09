import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../auth/auth_controller.dart';
import 'payout_models.dart';

/// The signed-in member's own payment details ("how I get paid").
class PayoutsApi {
  PayoutsApi(this._dio);

  final Dio _dio;

  Future<List<PayoutMethod>> _methods(Future<Response<Map<String, dynamic>>> req) async {
    try {
      final r = await req;
      return [for (final m in r.data!['methods'] as List) PayoutMethod.fromJson(m as Map<String, dynamic>)];
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<List<PayoutMethod>> list() => _methods(_dio.get('/users/me/payout-methods'));

  Future<List<PayoutMethod>> add(PayoutDetails details, {bool makeDefault = false}) =>
      _methods(_dio.post('/users/me/payout-methods', data: {...details.toJson(), 'makeDefault': makeDefault}));

  Future<List<PayoutMethod>> makeDefault(String id) => _methods(_dio.post('/users/me/payout-methods/$id/default'));

  Future<List<PayoutMethod>> remove(String id) => _methods(_dio.delete('/users/me/payout-methods/$id'));
}

final payoutsApiProvider = Provider<PayoutsApi>((ref) => PayoutsApi(ref.watch(apiClientProvider)));

final myPayoutMethodsProvider = FutureProvider.autoDispose<List<PayoutMethod>>((ref) {
  ref.watch(authControllerProvider);
  return ref.watch(payoutsApiProvider).list();
});
