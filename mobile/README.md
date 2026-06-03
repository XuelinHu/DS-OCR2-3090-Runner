# DS OCR Mobile

Flutter Android client for `DS-OCR2-3090-Runner`.

## Scope

- Configure backend API base URL.
- Select image or PDF files from Android storage.
- Upload files through `POST /api/files`.
- Create OCR tasks through `POST /api/ocr/tasks`.
- Poll task status through `GET /api/ocr/tasks/{task_id}`.
- Display Markdown or text results.

## Local Backend URL

The default Android emulator URL is:

```text
http://10.0.2.2:8000
```

For a physical Android device, set the API base URL in the app settings to the
LAN address of the backend host.

## Commands

```bash
flutter pub get
flutter analyze
```

Do not use `flutter run` unless the backend and Android target are ready.
