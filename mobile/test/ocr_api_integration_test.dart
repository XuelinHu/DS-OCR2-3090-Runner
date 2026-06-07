import 'dart:io';

import 'package:ds_ocr_mobile/src/api/ocr_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final backendUrl = Platform.environment['BACKEND_URL'] ?? '';
  final expectedResultContains =
      Platform.environment['EXPECTED_RESULT_CONTAINS'] ?? 'OCR Stub Result';

  test(
    'uploads file, creates OCR task, runs OCR worker, and reads result',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('ds_ocr_api_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final configuredImagePath = Platform.environment['TEST_IMAGE_PATH'] ?? '';
      final sample = configuredImagePath.isEmpty
          ? File('${tempDir.path}/sample.txt')
          : File(configuredImagePath);
      if (configuredImagePath.isEmpty) {
        await sample.writeAsString('DeepSeek OCR mock integration test.');
      }
      expect(await sample.exists(), isTrue);

      final api = OcrApi(baseUrl: backendUrl);
      final file = await api.uploadFile(sample);
      expect(file.id, startsWith('file_'));
      expect(file.originalName, sample.uri.pathSegments.last);

      final created = await api.createTask(fileId: file.id, priority: 0);
      expect(created.id, startsWith('task_'));
      expect(created.status, anyOf('queued', 'running'));

      final workerResult = await Process.run('.venv/bin/python', [
        '-m',
        'ds_ocr_runner.worker',
        '--once',
      ], workingDirectory: '..');
      expect(workerResult.exitCode, 0, reason: '${workerResult.stderr}');

      final completed = await api.getTask(created.id);
      expect(completed.status, 'succeeded');

      final result = await api.getResult(created.id);
      expect(result.taskId, created.id);
      expect(result.markdown, contains(expectedResultContains));
    },
    skip: backendUrl.isEmpty
        ? 'Set BACKEND_URL to run backend integration test.'
        : false,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
