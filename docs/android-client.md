# Android Client Plan

## Stack

- Kotlin
- Jetpack Compose
- MVVM with repository layer
- Hilt for dependency injection
- Retrofit and OkHttp for HTTP
- Room for local OCR history cache
- DataStore for auth and user preferences
- CameraX for camera capture
- WorkManager for background upload and retry

## Screens

- Home: recent OCR tasks, capture, import image, import PDF.
- Scanner: CameraX preview, crop, rotate, page confirmation.
- Upload progress: pending, uploading, queued, running, failed.
- Result: original preview, Markdown, plain text, copy, share.
- History: search, status filter, delete local record.
- Settings: API base URL, upload quality, local cache cleanup.

## API Flow

```text
Select or capture file
  -> POST /api/files
  -> POST /api/ocr/tasks
  -> poll GET /api/ocr/tasks/{task_id}
  -> GET /api/ocr/tasks/{task_id}/result
```

## Local Data Model

```text
OcrTaskEntity
- id
- fileId
- localUri
- mode
- status
- markdown
- text
- createdAt
- updatedAt
```

## Error Handling

- Network failures are retried by WorkManager.
- Failed OCR tasks remain visible for manual retry.
- Local files are retained until upload succeeds or the user deletes the task.
- The app should never call `/internal/*` endpoints.

