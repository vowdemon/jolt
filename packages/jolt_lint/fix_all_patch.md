# Fix All In File Temporary Workaround Guide

## Overview

Due to a bug in the `analysis_server_plugin` package, the Fix All In File feature does not work properly. Even with correct configuration of `CorrectionApplicability.acrossSingleFile`, `multiFixKind`, and `DartFixKindPriority.inFile`, only single fixes are available.

This document provides a temporary workaround to fix this bug.

### Limitations

⚠️ **Important Notes**:
- These modifications require directly editing third-party package files in `pub cache`
- File location (Windows example): `C:\Users\<username>\AppData\Local\Pub\Cache\hosted\pub.dev\analysis_server_plugin-<version>\`
- **These modifications will be overwritten the next time you run `pub get` or `flutter pub get`**
- This is a temporary solution; we recommend waiting for an official fix

## Fix Steps

You need to modify 3 files in the following order:

### Step 1: Modify `fix_in_file_processor.dart`

**File location**: `lib/src/fixes/fix_in_file_processor.dart`

#### 1.1 Add Field

Find the `FixInFileProcessor` class and add the field:

```dart
final class FixInFileProcessor {
  final DartFixContext _fixContext;
  final Set<String>? alreadyCalculated;
  final List<Diagnostic>? additionalDiagnostics;  // ← New field
```

#### 1.2 Modify Constructor

Find the constructor and add the parameter:

```dart
FixInFileProcessor(
  this._fixContext, {
  this.alreadyCalculated,
  this.additionalDiagnostics,  // ← New parameter
});
```

#### 1.3 Modify Diagnostic Retrieval Logic

Find the diagnostic retrieval code (usually in the `compute` method) and modify it:

**Before:**
```dart
var diagnostics = _fixContext.unitResult.diagnostics.where(
  (e) => diagnostic.diagnosticCode.name == e.diagnosticCode.name,
);
```

**After:**
```dart
var allDiagnostics = [
  ..._fixContext.unitResult.diagnostics,
  ...?additionalDiagnostics,
];

var diagnostics = allDiagnostics.where(
  (e) => diagnostic.diagnosticCode.name == e.diagnosticCode.name,
);
```

### Step 2: Modify `fix_processor.dart`

**File location**: `lib/src/fixes/fix_processor.dart`

#### 2.1 Add Import (if not present)

Add at the top of the file:

```dart
import 'package:analyzer/diagnostic/diagnostic.dart';
```

#### 2.2 Modify `computeFixes` Function

Find the `computeFixes` function and modify the function signature and call:

**Before:**
```dart
Future<List<Fix>> computeFixes(
  DartFixContext context, {
  FixPerformance? performance,
  Set<String>? skipAlreadyCalculatedIfNonNull,
}) async {
  return [
    ...await FixProcessor(...).compute(),
    ...await FixInFileProcessor(
      context,
      alreadyCalculated: skipAlreadyCalculatedIfNonNull,
    ).compute(),
  ];
}
```

**After:**
```dart
Future<List<Fix>> computeFixes(
  DartFixContext context, {
  FixPerformance? performance,
  Set<String>? skipAlreadyCalculatedIfNonNull,
  List<Diagnostic>? additionalDiagnostics,  // ← New parameter
}) async {
  return [
    ...await FixProcessor(...).compute(),
    ...await FixInFileProcessor(
      context,
      alreadyCalculated: skipAlreadyCalculatedIfNonNull,
      additionalDiagnostics: additionalDiagnostics,  // ← Pass parameter
    ).compute(),
  ];
}
```

### Step 3: Modify `plugin_server.dart`

**File location**: `lib/src/server/plugin_server.dart`

#### 3.1 Extract All Plugin Diagnostics

In the `handleEditGetFixes` method, find the code that retrieves `recentState` and add after it:

```dart
var (:analysisContext, :errors) = recentState;

// Extract all plugin diagnostics for use in bulk fixes.
var allPluginDiagnostics = errors.map((e) => e.diagnostic).toList();
```

#### 3.2 Add Deduplication Set

Find where `errorFixesList` is created and add:

```dart
var errorFixesList = <protocol.AnalysisErrorFixes>[];
var alreadyCalculated = <String>{};  // ← New
```

#### 3.3 Modify `computeFixes` Call

Find where `computeFixes` is called and modify it:

**Before:**
```dart
List<Fix> fixes;
try {
  fixes = await computeFixes(context);
} on InconsistentAnalysisException {
  fixes = [];
}
```

**After:**
```dart
List<Fix> fixes;
try {
  fixes = await computeFixes(
    context,
    skipAlreadyCalculatedIfNonNull: alreadyCalculated,
    additionalDiagnostics: allPluginDiagnostics,  // ← Pass plugin diagnostics
  );
} on InconsistentAnalysisException {
  fixes = [];
}
```

## Verify the Fix

After applying the fix, when a file contains 2 or more diagnostics of the same type:

1. ✅ Single fixes still work
2. ✅ "Fix all setup this issues" option appears in the fix menu
3. ✅ Bulk fix resolves all diagnostics of the same type in the file
