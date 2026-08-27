import 'dart:convert';

import 'package:dio/dio.dart';

/// Parses a `text/event-stream` response body into individual `data:` payloads.
///
/// Handles CRLF, multi-line events, and trailing partial chunks. Only `data:`
/// lines are surfaced — event names are redundant for OpenAI/Anthropic/Gemini
/// because their JSON payloads carry the event type.
Stream<String> parseSseDataStream(Stream<List<int>> byteStream) async* {
  var buffer = '';
  await for (final chunk in byteStream) {
    final text = utf8.decode(chunk, allowMalformed: true);
    buffer += text.replaceAll('\r\n', '\n');
    int idx;
    while ((idx = buffer.indexOf('\n\n')) >= 0) {
      final rawEvent = buffer.substring(0, idx);
      buffer = buffer.substring(idx + 2);
      for (final line in rawEvent.split('\n')) {
        if (line.startsWith('data:')) {
          final data = line.substring(5).trim();
          if (data.isNotEmpty) yield data;
        }
      }
    }
  }
  // Flush any trailing event without a blank-line terminator.
  for (final line in buffer.split('\n')) {
    if (line.startsWith('data:')) {
      final data = line.substring(5).trim();
      if (data.isNotEmpty) yield data;
    }
  }
}

/// Convenience: decode each payload as JSON, skipping `[DONE]` sentinels.
Stream<Map<String, dynamic>> parseSseJsonStream(
  Stream<List<int>> byteStream,
) async* {
  await for (final data in parseSseDataStream(byteStream)) {
    if (data == '[DONE]') return;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) yield decoded;
    } on FormatException {
      // Skip keep-alive comments / malformed payloads.
    }
  }
}

/// Reads a human-readable error message out of a [DioException] response,
/// supporting both JSON objects and streamed response bodies.
Future<String> readDioErrorMessage(DioException e) async {
  final res = e.response;
  if (res == null) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout =>
        'Connection timed out. Check the base URL and network.',
      DioExceptionType.connectionError =>
        'Could not connect to host. Check base URL or network.',
      _ => e.message ?? 'Network request failed',
    };
  }

  String? rawText;
  final data = res.data;
  if (data is ResponseBody) {
    try {
      final bytes = await data.stream.toList();
      final flat = bytes.expand((b) => b).toList();
      rawText = utf8.decode(flat, allowMalformed: true);
    } catch (_) {}
  } else if (data is String) {
    rawText = data;
  } else if (data is Map) {
    final error = data['error'];
    if (error is Map && error['message'] != null) {
      return error['message'].toString();
    }
    if (data['message'] != null) return data['message'].toString();
  }

  if (rawText != null && rawText.isNotEmpty) {
    try {
      final decoded = jsonDecode(rawText);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] != null) {
          return error['message'].toString();
        }
        if (decoded['message'] != null) return decoded['message'].toString();
      }
    } catch (_) {}
    if (rawText.length < 300) return rawText;
  }

  final code = res.statusCode;
  final msg = res.statusMessage;
  return 'HTTP ${code ?? 400}: ${msg ?? "Request failed"}';
}

/// Synchronous fallback for legacy callers.
String dioErrorMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final error = data['error'];
    if (error is Map && error['message'] != null) {
      return error['message'].toString();
    }
    if (data['message'] != null) return data['message'].toString();
  }
  if (data is String && data.isNotEmpty && data.length < 300) return data;
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout =>
      'Connection timed out. Check the base URL and network.',
    DioExceptionType.connectionError =>
      'Could not connect. Check the base URL and network.',
    _ => e.message ?? 'Network error',
  };
}
