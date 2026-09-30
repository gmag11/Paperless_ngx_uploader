# Spec Delta

## Purpose

Allows the app to receive files from Android's "Abrir con" (open with) chooser for compatible types and process them with the same upload flow as shared files.

## ADDED Requirements

### Requirement: Registration as "Open with" target for supported types
On Android, the system SHALL offer the app in the "Abrir con" (open with) chooser for files whose type is among the document types the app supports (PDF and the supported image formats), and SHALL NOT be offered for other file types.

#### Scenario: Opening a PDF offers the app
- **WHEN** the user opens a PDF file from a file manager, downloads or another app and the system shows the "open with" chooser
- **THEN** the app is listed among the available destinations

#### Scenario: Opening a supported image offers the app
- **WHEN** the user opens a JPEG, PNG, TIFF, GIF or WebP image and the system shows the "open with" chooser
- **THEN** the app is listed among the available destinations

#### Scenario: Opening an unsupported type does not offer the app
- **WHEN** the user opens a file of a type the app does not support (e.g. a spreadsheet, audio or video file)
- **THEN** the app is not listed in the "open with" chooser

### Requirement: Opened files enter the shared-file intake pipeline
A file delivered to the app via "open with" SHALL be processed through the same intake pipeline as a file received via the system share action, producing identical downstream behavior (upload flow, optional per-upload tag prompt, default tags, result reporting and unsupported-type warnings).

#### Scenario: Opened file reaches the upload flow
- **WHEN** the user selects the app in the "open with" chooser for a supported PDF
- **THEN** the file appears in the app's upload flow exactly as if it had been shared to the app, including the tag prompt when the "ask for tags before upload" setting is enabled

#### Scenario: Tag prompt applies to opened files
- **WHEN** a file is opened with the app AND the "ask for tags before upload" setting is enabled for the active server
- **THEN** the tag selection dialog is shown before uploading, with the saved default tags preselected, and confirming/cancelling behaves the same as for shared files

#### Scenario: Default tags applied without prompt
- **WHEN** a file is opened with the app AND the "ask for tags before upload" setting is disabled
- **THEN** the upload proceeds with the server's saved default tags without prompting

### Requirement: Delivery in every app lifecycle state
The system SHALL accept an "open with" file whether the app is being cold-started by the intent or is already running in the background, and each opened file SHALL be delivered exactly once (no duplicate intake after the activity is recreated).

#### Scenario: Cold start
- **WHEN** the app is not running and the user opens a supported file choosing the app
- **THEN** the app starts and the file enters the intake pipeline once

#### Scenario: Warm start
- **WHEN** the app is already running in the background and the user opens a supported file choosing the app
- **THEN** the app comes to the foreground and the file enters the intake pipeline once

#### Scenario: Warm-start file is not lost before the UI is ready
- **WHEN** a supported file is opened while the app is running but the UI has not attached its listener yet
- **THEN** the file is still delivered to the intake pipeline exactly once when the UI becomes ready

#### Scenario: Activity recreation does not re-deliver
- **WHEN** the activity or the process is recreated after the opened file was already delivered (including a system-initiated process death while backgrounded, where Android restores the task with its original launch intent)
- **THEN** the same file is not delivered to the intake pipeline a second time

### Requirement: Unreadable files do not corrupt the flow
If a file delivered to the app (opened or shared) cannot be read (permission revoked, source removed, copy failure), the system SHALL NOT crash, SHALL NOT start an upload for that file, and MUST NOT report a successful upload. The system SHALL display a visible red error message (toast) identifying the file that could not be read.

#### Scenario: Source URI cannot be read
- **WHEN** the app is selected in the "open with" chooser but the file's content cannot be read
- **THEN** the app remains usable, no upload is started for that file, no success result is reported, and a red error toast identifying the file is displayed

#### Scenario: Partial batch failure
- **WHEN** several files are delivered together and some of them cannot be read
- **THEN** the readable files proceed through the intake pipeline and a single red error toast identifies the unreadable files

#### Scenario: Existing share behavior unchanged
- **WHEN** files are received via the system share action
- **THEN** their intake, validation and upload behavior is unchanged from the current implementation, except that unreadable shared files also trigger the red error feedback described above
