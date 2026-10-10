import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../auth/auth_controller.dart';

class ReminderPreferences {
  const ReminderPreferences({
    required this.enabled,
    required this.daysBefore,
    required this.channels,
    required this.suggestedDaysBefore,
    required this.emailVerified,
  });

  /// Off until the member turns it on (U-06).
  final bool enabled;
  final List<int> daysBefore;

  /// 'sms' and/or 'email'; in-app reminders need neither.
  final List<String> channels;
  final List<int> suggestedDaysBefore;
  final bool emailVerified;

  factory ReminderPreferences.fromJson(Map<String, dynamic> j) => ReminderPreferences(
        enabled: j['enabled'] as bool? ?? false,
        daysBefore: [for (final d in j['daysBefore'] as List? ?? const []) (d as num).toInt()],
        channels: [for (final c in j['channels'] as List? ?? const []) c as String],
        suggestedDaysBefore: [for (final d in j['suggestedDaysBefore'] as List? ?? const []) (d as num).toInt()],
        emailVerified: j['emailVerified'] as bool? ?? false,
      );
}

class RemindersApi {
  RemindersApi(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<ReminderPreferences> get(String circleId) => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/circles/$circleId/reminders');
        return ReminderPreferences.fromJson(r.data!);
      });

  Future<ReminderPreferences> set(
    String circleId, {
    required bool enabled,
    required List<int> daysBefore,
    required List<String> channels,
  }) =>
      _call(() async {
        final r = await _dio.put<Map<String, dynamic>>(
          '/circles/$circleId/reminders',
          data: {'enabled': enabled, 'daysBefore': daysBefore, 'channels': channels},
        );
        return ReminderPreferences.fromJson(r.data!);
      });

  /// Organizer's reminder to one unpaid member.
  Future<void> nudge(String circleId, String userId) => _call(() async {
        await _dio.post<void>('/circles/$circleId/members/$userId/remind');
      });
}

final remindersApiProvider = Provider<RemindersApi>((ref) => RemindersApi(ref.watch(apiClientProvider)));

final reminderPreferencesProvider = FutureProvider.autoDispose.family<ReminderPreferences, String>((ref, circleId) {
  ref.watch(authControllerProvider);
  return ref.watch(remindersApiProvider).get(circleId);
});
