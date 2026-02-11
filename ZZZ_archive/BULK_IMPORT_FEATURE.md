# Bulk User Import Feature

**Version:** Concierge v0.2.1, Concierge::Setup v0.2.0
**Date:** 2026-01-29

## Overview

Added bulk user import functionality to Concierge::Setup for migrating users from legacy systems. Imported users are registered in the Users data store without authentication credentials - they must set passwords via the application's password reset flow.

## Key Design Decisions

### 1. No Passwords on Import
- Import registers users in Users.pm only
- No Auth.pm entries created
- Users cannot login until they set a password
- Simplest, most secure approach

### 2. Source Tracking
- Added 'source' field to track user provenance
- Values like: 'legacy_db_2026-01-29', 'api_integration', 'web_registration'
- Currently implemented as app_field (will become system field in future Users.pm update)

### 3. User Status: 'Eligible'
- Imported users get user_status = 'Eligible'
- After password set, application updates to user_status = 'OK'
- Clear indication of import status

### 4. User IDs Preserved
- Original user_ids always preserved (no transformations)
- If collision occurs, import fails with clear error
- Application can pre-process data if transformations needed

### 5. One User at a Time
- `import_user()` imports single user record
- Application loops for bulk operations
- Allows custom error handling and progress tracking

## Implementation

### New Methods in Concierge::Setup

#### `new_importer($config)`
Creates an importer object for bulk user registration.

```perl
my $importer = Concierge::Setup->new_importer({
    concierge => $desk->{concierge},
    source_label => 'legacy_db_2026-01-29',  # Optional, defaults to 'import-YYYY-MM-DD'
    user_status => 'Eligible',               # Optional, defaults to 'Eligible'
});
```

#### `import_user($user_data)`
Import a single user record.

```perl
my $result = $importer->import_user({
    user_id => 'alice',
    moniker => 'AliceSmith',
    email => 'alice@example.com',
    role => 'admin',
    # ... other fields matching desk configuration
});
```

Returns: `{ success => 0|1, message => '...', user_id => '...', source => '...', user_status => '...' }`

#### `summary()`
Get import statistics.

```perl
my $summary = $importer->summary();
# Returns: { imported => N, failed => N, errors => [...], success => 0|1 }
```

### Modified: Concierge.pm

#### `reset_password()` - Now uses `setPwd()` instead of `resetPwd()`

This change allows `reset_password()` to work for both:
- **Password changes**: Existing users with Auth entries
- **Initial password setting**: Imported users without Auth entries

```perl
# Works for imported users setting initial password
$concierge->reset_password($user_id, $new_password);
```

## Complete Import Workflow

### 1. Setup Desk with 'source' Field

```perl
use Concierge::Setup;

my $result = Concierge::Setup::build_desk(
    './desk',
    './desk/auth.pwd',
    ['source', 'role', 'department'],  # app_fields (source is key for imports)
    [],                                 # user_session_fields
);
```

### 2. Transform Legacy Data

Application transforms legacy data to match configured field names.

```perl
my @legacy_users = (
    { user_id => 'alice', moniker => 'AliceSmith', email => 'alice@example.com', ... },
    { user_id => 'bob', moniker => 'BobJones', email => 'bob@example.com', ... },
);
```

### 3. Create Importer

```perl
use Concierge;

my $desk = Concierge->open_desk('./desk');
my $importer = Concierge::Setup->new_importer({
    concierge => $desk->{concierge},
    source_label => 'legacy_system_2026-01-29',
});
```

### 4. Import Users

```perl
foreach my $user (@legacy_users) {
    my $result = $importer->import_user($user);

    if ($result->{success}) {
        print "✓ Imported: $result->{user_id}\n";
    } else {
        warn "✗ Failed: $result->{message}\n";
    }
}

my $summary = $importer->summary();
print "Imported: $summary->{imported}, Failed: $summary->{failed}\n";
```

### 5. Notify Users

Application notifies users they need to set passwords (email, dashboard message, etc.)

### 6. Password Reset Flow

When user attempts login without password:

```perl
# In application login handler
my $login = $concierge->login_user({
    user_id => $user_id,
    password => $password,
});

if (!$login->{success}) {
    # Check if it's an imported user
    my $user_data = $concierge->get_user_data($user_id);

    if ($user_data->{user}{user_status} eq 'Eligible') {
        # Redirect to "Set Your Password" page
        return redirect_to('/set-password', { user_id => $user_id });
    }
}
```

### 7. User Sets Password

```perl
# Application's "Set Password" handler
my $result = $concierge->reset_password($user_id, $new_password);

if ($result->{success}) {
    # Update status
    $concierge->update_user_data($user_id, { user_status => 'OK' });

    # Auto-login
    my $login = $concierge->login_user({
        user_id => $user_id,
        password => $new_password,
    });

    return redirect_to('/dashboard');
}
```

## Example Script

Complete working example: `examples/test_bulk_import.pl`

Demonstrates:
- Setup with 'source' field
- Creating importer
- Importing users
- Verifying no auth entries exist
- User setting initial password
- Multiple importers with different source labels
- Error handling (duplicates, validation)
- Import summary reporting

## Testing

Run: `perl -Ilib examples/test_bulk_import.pl`

All 10 test scenarios pass:
1. ✓ Setup desk with 'source' field
2. ✓ Open desk and create importer
3. ✓ Import valid users
4. ✓ Verify imported users exist in Users.pm
5. ✓ Verify no auth entries exist (can't login yet)
6. ✓ Attempt to import duplicate user (correctly rejected)
7. ✓ Attempt to import user without user_id (correctly rejected)
8. ✓ Get import summary
9. ✓ Simulate user setting password (application flow)
10. ✓ Create second importer with different source

## Installation

```bash
cd /Volumes/Main/Development/Repositories/Concierge
perl Makefile.PL
make
make test  # 32 tests pass
make install
```

Installed versions:
- **Concierge**: v0.2.1 (reset_password now uses setPwd)
- **Concierge::Setup**: v0.2.0 (added bulk import)

## Future Enhancements

### 'source' as System Field
Currently 'source' must be added as an app_field during setup. In future:
- Add 'source' to Concierge::Users system fields
- Automatically available in all desks
- No setup configuration needed

### Gradual/Lazy Migration
For seamless migration without user notification:
- Keep old auth system accessible
- On first login, capture credentials
- Migrate user transparently
- Requires old system API integration

## Notes

- **Field mapping is pre-setup**: Application responsible for transforming legacy data to match Concierge field names
- **User IDs always preserved**: No transformations, prefixes, or mappings - keep it simple
- **No email in Concierge**: Applications handle their own notification systems
- **One-time operation**: Import is typically done once per legacy system migration
- **Error handling is straightforward**: Import fails → clear error message → application decides what to do

## Architecture Benefits

1. **Clean separation**: Import is setup-time, not runtime
2. **Security first**: No temporary passwords, no password distribution issues
3. **Application control**: App decides notification and password-setting flows
4. **Simple API**: Three methods, clear purpose, minimal configuration
5. **Flexible**: Works with any notification strategy (email, dashboard, SMS, etc.)
