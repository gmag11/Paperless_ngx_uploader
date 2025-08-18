# Legacy Configuration Migration Guide

This guide documents the process for migrating from the legacy single-server configuration format to the new multi-server configuration system.

## Overview

The migration service automatically converts legacy configuration stored in FlutterSecureStorage to the new ServerConfig format. This is a one-time process that preserves all existing settings and credentials.

## Legacy Keys Migrated

The following legacy keys are automatically detected and migrated:

- `server_url` → Server URL
- `auth_method` → Authentication method
- `username` → Username (for username/password auth)
- `password` → Password (for username/password auth)
- `api_token` → API token (for API token auth)
- `allow_self_signed_certificates` → SSL certificate setting
- `selected_tags` → Default tag IDs

## Migration Process

### 1. Automatic Detection

The migration is triggered automatically when the app starts. The system checks for legacy configuration using `LegacyMigrationService.hasLegacyConfiguration()`.

### 2. Migration Execution

When legacy configuration is detected:

1. All legacy data is read and validated
2. A new ServerConfig object is created with the migrated data
3. The configuration is saved to the new multi-server storage
4. Legacy data is cleaned up (deleted) after successful migration

### 3. Error Handling

The migration process includes comprehensive error handling:

- Missing required fields are detected and reported
- Invalid authentication data is handled gracefully
- JSON parsing errors are logged
- Migration failures do not affect existing new-format configurations

## Manual Migration Testing

You can test the migration process manually:

```dart
import 'package:your_app/services/legacy_migration_service.dart';
import 'package:your_app/providers/server_manager.dart';

// Check if legacy configuration exists
final hasLegacy = await LegacyMigrationService.hasLegacyConfiguration();
print('Has legacy config: $hasLegacy');

// Get migration summary
final summary = await LegacyMigrationService.getMigrationSummary();
print('Migration summary: $summary');

// Perform migration manually
final migratedConfig = await LegacyMigrationService.migrateLegacyConfiguration();
if (migratedConfig != null) {
  // Add to server manager
  await ServerManager.instance.addServer(migratedConfig);
  
  // Clean up legacy data
  await LegacyMigrationService.cleanupLegacyConfiguration();
}
```

## Fallback Behavior

If migration fails:

- The app continues to work normally
- Users can manually configure servers through the UI
- No data is lost (legacy configuration remains until manually cleaned)
- Error messages are logged for debugging

## Troubleshooting

### Common Issues

1. **"Invalid credentials" error during migration**
   - Check if username/password or API token are correctly stored
   - Verify the server URL is accessible

2. **"Invalid server URL" error**
   - Ensure the URL includes protocol (http:// or https://)
   - Check for trailing slashes or special characters

3. **Migration appears to hang**
   - Check network connectivity
   - Verify SSL certificate settings match server requirements

### Debug Logging

Enable debug logging to see detailed migration information:
```dart
import 'dart:developer' as developer;

// Migration logs will appear with tag 'LegacyMigrationService'
developer.log('Migration started', name: 'LegacyMigrationService');
```

## Post-Migration Cleanup

After successful migration, legacy keys are automatically deleted from FlutterSecureStorage. The following keys are removed:

- `server_url`
- `auth_method`
- `username`
- `password`
- `api_token`
- `allow_self_signed_certificates`
- `selected_tags`

## Rollback Strategy

If you need to rollback a migration:

1. Stop the app
2. Manually restore legacy keys to FlutterSecureStorage
3. Remove the migrated server from ServerManager
4. Restart the app to trigger migration again

## Security Considerations

- All credentials are handled securely during migration
- No sensitive data is logged
- Legacy data is only deleted after successful migration
- The migration process follows the same security standards as the new configuration system