import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../auth/auth_controller.dart';
import '../circles/circle_models.dart';

class StatementLine {
  const StatementLine({required this.reference, required this.cycleNumber, required this.amountMinor, required this.verifiedAt});

  final String reference;
  final int cycleNumber;
  final int amountMinor;
  final DateTime verifiedAt;

  factory StatementLine.fromJson(Map<String, dynamic> j) => StatementLine(
        reference: j['reference'] as String,
        cycleNumber: (j['cycleNumber'] as num).toInt(),
        amountMinor: (j['amountMinor'] as num).toInt(),
        verifiedAt: DateTime.parse(j['verifiedAt'] as String).toLocal(),
      );
}

/// A snapshot of the member's verified savings, pinned to the ledger (FR-11).
class Statement {
  const Statement({
    required this.id,
    required this.verificationCode,
    required this.verifyUrl,
    required this.issuedAt,
    required this.contributions,
    required this.lines,
    required this.chainHeadHash,
  });

  final String id;
  final String verificationCode;
  final String verifyUrl;
  final DateTime issuedAt;
  final Total contributions;
  final List<StatementLine> lines;
  final String chainHeadHash;

  factory Statement.fromJson(Map<String, dynamic> j) => Statement(
        id: j['id'] as String,
        verificationCode: j['verificationCode'] as String,
        verifyUrl: j['verifyUrl'] as String,
        issuedAt: DateTime.parse(j['issuedAt'] as String).toLocal(),
        contributions: Total.fromJson(j['contributions'] as Map<String, dynamic>),
        lines: [for (final l in j['lines'] as List) StatementLine.fromJson(l as Map<String, dynamic>)],
        chainHeadHash: j['chainHeadHash'] as String,
      );
}

class StatementsApi {
  StatementsApi(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<List<Statement>> list(String circleId) => _call(() async {
        final r = await _dio.get<Map<String, dynamic>>('/circles/$circleId/statements');
        return [for (final s in r.data!['statements'] as List) Statement.fromJson(s as Map<String, dynamic>)];
      });

  Future<Statement> issue(String circleId) => _call(() async {
        final r = await _dio.post<Map<String, dynamic>>('/circles/$circleId/statements');
        return Statement.fromJson(r.data!);
      });

  /// The statement as a PDF (or CSV) file.
  Future<Uint8List> file(String statementId, {bool csv = false}) => _call(() async {
        final r = await _dio.get<List<int>>(
          '/statements/$statementId/file',
          queryParameters: {if (csv) 'format': 'csv'},
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(r.data!);
      });
}

final statementsApiProvider = Provider<StatementsApi>((ref) => StatementsApi(ref.watch(apiClientProvider)));

final statementsProvider = FutureProvider.autoDispose.family<List<Statement>, String>((ref, circleId) {
  ref.watch(authControllerProvider);
  return ref.watch(statementsApiProvider).list(circleId);
});
