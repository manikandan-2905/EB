library;

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/eb_record.dart';

class ApiService {
  // ── Base URL ──────────────────────────────────────────────────────────────
  // For Android emulator use 10.0.2.2 to reach the host machine's localhost.
  // For a physical device replace with your machine's local IP (e.g. 192.168.1.X).
  static const String _baseUrl = 'http://10.0.2.2:5000/api';

  static const Duration _timeout = Duration(seconds: 15);

  // ─────────────────────────────────────────────────────────────────────────
  // GET /api/eb-records/check-eb?ebNumber=...  — check for duplicate
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> checkEbExists(String ebNumber) async {
    try {
      final uri = Uri.parse('$_baseUrl/eb-records/check-eb')
          .replace(queryParameters: {'ebNumber': ebNumber.trim()});

      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['exists'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST /api/eb-records  — create unique record (duplicate not allowed)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<EbRecord> saveRecord(EbRecord record) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/eb-records'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(record.toJson()),
          )
          .timeout(_timeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return EbRecord.fromJson(body['data'] as Map<String, dynamic>);
      }

      final errors = body['errors'] as List<dynamic>?;
      final message = errors != null && errors.isNotEmpty
          ? (errors.first as Map)['msg'] as String
          : body['message'] as String? ?? 'Save failed.';
      throw ApiException(message, statusCode: response.statusCode);
    } on SocketException {
      throw const ApiException('No internet connection or server is unreachable.');
    } on TimeoutException {
      throw const ApiException('Request timed out. Check your network connection.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATCH /api/eb-records/:id/schedule  — set/update visit schedule
  // ─────────────────────────────────────────────────────────────────────────
  static Future<EbRecord> updateSchedule(
    String id, {
    DateTime? scheduledDate,
    String? visitStatus,
  }) async {
    try {
      final payload = <String, dynamic>{};
      payload['scheduledDate'] = scheduledDate?.toIso8601String();
      if (visitStatus != null) {
        payload['visitStatus'] = visitStatus;
      }

      final response = await http
          .patch(
            Uri.parse('$_baseUrl/eb-records/$id/schedule'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return EbRecord.fromJson(body['data'] as Map<String, dynamic>);
      }

      throw ApiException(
        body['message'] as String? ?? 'Failed to update schedule.',
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw const ApiException('No internet connection or server is unreachable.');
    } on TimeoutException {
      throw const ApiException('Request timed out. Check your network connection.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET /api/eb-records/scheduled?date=YYYY-MM-DD  — get scheduled visits
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<EbRecord>> fetchScheduledRecords({DateTime? date}) async {
    try {
      final params = <String, String>{};
      if (date != null) {
        params['date'] =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }

      final uri = Uri.parse('$_baseUrl/eb-records/scheduled')
          .replace(queryParameters: params.isNotEmpty ? params : null);

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>;
        return data
            .map((e) => EbRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw ApiException('Failed to load schedule.', statusCode: response.statusCode);
    } on SocketException {
      throw const ApiException('No internet connection or server is unreachable.');
    } on TimeoutException {
      throw const ApiException('Request timed out. Check your network connection.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET /api/eb-records  — latest 50 records
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<EbRecord>> fetchLatestRecords() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/eb-records'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>;
        return data
            .map((e) => EbRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw ApiException('Failed to load records.', statusCode: response.statusCode);
    } on SocketException {
      throw const ApiException('No internet connection or server is unreachable.');
    } on TimeoutException {
      throw const ApiException('Request timed out. Check your network connection.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET /api/eb-records/search?query=...  — search records
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<EbRecord>> searchRecords(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/eb-records/search')
          .replace(queryParameters: {'query': query});

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>;
        return data
            .map((e) => EbRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw ApiException('Search failed.', statusCode: response.statusCode);
    } on SocketException {
      throw const ApiException('No internet connection or server is unreachable.');
    } on TimeoutException {
      throw const ApiException('Request timed out. Check your network connection.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE /api/eb-records/:id  — delete a record
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> deleteRecord(String id) async {
    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/eb-records/$id'))
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw ApiException('Delete failed.', statusCode: response.statusCode);
      }
    } on SocketException {
      throw const ApiException('No internet connection or server is unreachable.');
    } on TimeoutException {
      throw const ApiException('Request timed out. Check your network connection.');
    }
  }
}

/// Custom exception for API errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Re-export TimeoutException for convenience within this service file.
class TimeoutException implements Exception {
  const TimeoutException();
  @override
  String toString() => 'TimeoutException';
}
