import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/ocr_api.dart';
import '../models/ocr_models.dart';
import '../settings/settings_store.dart';

class OcrHomePage extends StatefulWidget {
  const OcrHomePage({super.key});

  @override
  State<OcrHomePage> createState() => _OcrHomePageState();
}

class _OcrHomePageState extends State<OcrHomePage> {
  final _settings = SettingsStore();
  final _baseUrlController = TextEditingController();
  final List<OcrJob> _jobs = [];

  PlatformFile? _selectedFile;
  OcrTask? _currentTask;
  OcrResult? _result;
  bool _busy = false;
  String _baseUrl = SettingsStore.defaultBaseUrl;
  String _stage = 'Idle';
  String? _error;
  int _resultTab = 0;

  OcrApi get _api => OcrApi(baseUrl: _baseUrl);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final baseUrl = await _settings.loadBaseUrl();
    if (!mounted) {
      return;
    }
    setState(() {
      _baseUrl = baseUrl;
      _baseUrlController.text = baseUrl;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: false,
    );

    final file = result?.files.single;
    if (file == null) {
      return;
    }

    setState(() {
      _selectedFile = file;
      _currentTask = null;
      _result = null;
      _error = null;
      _stage = 'Ready';
    });
  }

  Future<void> _submit() async {
    final path = _selectedFile?.path;
    if (path == null) {
      setState(() => _error = 'Select a file first.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _stage = 'Uploading';
    });

    try {
      final api = _api;
      final file = await api.uploadFile(File(path));
      setState(() => _stage = 'Creating task');

      var task = await api.createTask(fileId: file.id);
      _rememberJob(file, task);
      setState(() {
        _currentTask = task;
        _stage = task.status;
      });

      task = await _pollTask(api, task.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentTask = task;
        _stage = task.status;
      });
      _updateJob(task);

      if (task.status == 'succeeded') {
        final result = await api.getResult(task.id);
        if (!mounted) {
          return;
        }
        setState(() {
          _result = result;
          _stage = 'Completed';
        });
      } else if (task.errorMessage != null) {
        setState(() => _error = task.errorMessage);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _stage = 'Failed';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<OcrTask> _pollTask(OcrApi api, String taskId) async {
    var task = await api.getTask(taskId);
    for (var i = 0; i < 120 && !task.isTerminal; i++) {
      if (!mounted) {
        return task;
      }
      setState(() {
        _currentTask = task;
        _stage = task.status;
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      task = await api.getTask(taskId);
    }
    return task;
  }

  void _rememberJob(OcrFile file, OcrTask task) {
    final job = OcrJob(
      fileName: file.originalName,
      fileId: file.id,
      taskId: task.id,
      status: task.status,
      createdAt: DateTime.now(),
    );
    setState(() => _jobs.insert(0, job));
  }

  void _updateJob(OcrTask task) {
    final index = _jobs.indexWhere((job) => job.taskId == task.id);
    if (index == -1) {
      return;
    }
    setState(() => _jobs[index] = _jobs[index].copyWith(status: task.status));
  }

  Future<void> _saveBaseUrl() async {
    final value = _baseUrlController.text.trim();
    if (value.isEmpty) {
      return;
    }
    await _settings.saveBaseUrl(value);
    if (!mounted) {
      return;
    }
    setState(() => _baseUrl = value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DS OCR'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _TaskPanel(
              selectedFile: _selectedFile,
              busy: _busy,
              stage: _stage,
              task: _currentTask,
              onPickFile: _pickFile,
              onSubmit: _submit,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 12),
            _ResultPanel(
              result: _result,
              selectedIndex: _resultTab,
              onTabChanged: (index) => setState(() => _resultTab = index),
            ),
            const SizedBox(height: 12),
            _HistoryPanel(jobs: _jobs),
          ],
        ),
      ),
    );
  }

  void _openSettings() {
    _baseUrlController.text = _baseUrl;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Backend', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'API base URL',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saveBaseUrl,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskPanel extends StatelessWidget {
  const _TaskPanel({
    required this.selectedFile,
    required this.busy,
    required this.stage,
    required this.task,
    required this.onPickFile,
    required this.onSubmit,
  });

  final PlatformFile? selectedFile;
  final bool busy;
  final String stage;
  final OcrTask? task;
  final VoidCallback onPickFile;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final file = selectedFile;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.document_scanner_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'OCR Task',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusChip(label: stage),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      file?.name ?? 'No file selected',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (task != null)
              Text(
                'Task ${task!.id} - attempts ${task!.attempts}/${task!.maxAttempts}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (task != null) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onPickFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Select'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onSubmit,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('Run OCR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  final OcrResult? result;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final content = result == null
        ? ''
        : selectedIndex == 0
        ? result!.markdown
        : result!.text;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.article_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Result',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.notes),
                      label: Text('MD'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.text_fields),
                      label: Text('TXT'),
                    ),
                  ],
                  selected: {selectedIndex},
                  onSelectionChanged: (value) => onTabChanged(value.first),
                  showSelectedIcon: false,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 220),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: result == null
                  ? const Center(
                      child: Icon(Icons.description_outlined, size: 40),
                    )
                  : SingleChildScrollView(
                      child: SelectableText(
                        content.isEmpty ? '(empty)' : content,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.jobs});

  final List<OcrJob> jobs;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.history),
                const SizedBox(width: 8),
                Text('Recent', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (jobs.isEmpty)
              const SizedBox(height: 72, child: Center(child: Text('No tasks')))
            else
              for (final job in jobs.take(8))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    job.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    job.taskId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _StatusChip(label: job.status),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label.toLowerCase()) {
      'succeeded' || 'completed' => Colors.green,
      'failed' => Colors.red,
      'running' || 'uploading' || 'creating task' => Colors.blue,
      'queued' => Colors.orange,
      _ => Colors.grey,
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.08),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
