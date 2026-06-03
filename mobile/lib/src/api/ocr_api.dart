import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ocr_models.dart';

class OcrApi {
  OcrApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Future<OcrFile> uploadFile(File file) async {
    final request = http.MultipartRequest('POST', _uri('/api/files'));
    request.files.add(await http.MultipartFile.fromPath('upload', file.path));

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response);
    return OcrFile.fromJson(_decode(response));
  }

  Future<OcrTask> createTask({
    required String fileId,
    String mode = 'document_markdown',
    int priority = 100,
  }) async {
    final response = await _client.post(
      _uri('/api/ocr/tasks'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'file_id': fileId,
        'mode': mode,
        'priority': priority,
        'options': {'preserve_layout': true, 'table': true, 'formula': true},
      }),
    );
    _ensureSuccess(response);
    return OcrTask.fromJson(_decode(response));
  }

  Future<OcrTask> getTask(String taskId) async {
    final response = await _client.get(_uri('/api/ocr/tasks/$taskId'));
    _ensureSuccess(response);
    return OcrTask.fromJson(_decode(response));
  }

  Future<OcrResult> getResult(String taskId) async {
    final response = await _client.get(_uri('/api/ocr/tasks/$taskId/result'));
    _ensureSuccess(response);
    return OcrResult.fromJson(_decode(response));
  }

  Future<OcrTask> cancelTask(String taskId) async {
    final response = await _client.post(_uri('/api/ocr/tasks/$taskId/cancel'));
    _ensureSuccess(response);
    return OcrTask.fromJson(_decode(response));
  }

  Map<String, dynamic> _decode(http.Response response) {
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = response.body;
    try {
      final decoded = _decode(response);
      message = decoded['detail']?.toString() ?? message;
    } catch (_) {
      // Keep the raw body when the backend does not return JSON.
    }
    throw OcrApiException(response.statusCode, message);
  }
}

class OcrApiException implements Exception {
  OcrApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'HTTP $statusCode: $message';
}
