# Backend Naming Consistency Update

## Date: 2026-01-28

## Change Summary

Updated Concierge::Sessions backend naming to be consistent with Concierge::Users. Both now use case-insensitive backend names with the same naming convention.

## Backend Name Changes

### Sessions Backends

**Old (case-sensitive):**
- `'SQLite'` - SQLite database backend
- `'File'` - File-based backend

**New (case-insensitive):**
- `'database'` - SQLite database backend (default)
- `'file'` - File-based backend (JSON files)

### Users Backends (Unchanged)

**Already case-insensitive:**
- `'database'` - SQLite database backend (default)
- `'yaml'` - YAML file backend
- `'file'` - CSV/TSV file backend

## Rationale

1. **Consistency**: Both Sessions and Users now use the same naming convention
2. **Simplicity**: Case-insensitive is more forgiving for users
3. **Clarity**: 'database' is clearer than 'SQLite' (implementation detail)
4. **Future-proof**: 'database' allows for PostgreSQL/MySQL addition without API changes

## Migration

### Code Changes Required

**Old code:**
```perl
my $result = Concierge::Setup::build_custom_desk({
    sessions => { backend => 'SQLite' },  # Old
    users => { backend => 'database' },
});
```

**New code:**
```perl
my $result = Concierge::Setup::build_custom_desk({
    sessions => { backend => 'database' },  # New
    users => { backend => 'database' },
});
```

### YAML Configuration Files

**Old:**
```yaml
sessions:
  backend: SQLite  # or 'File'
```

**New:**
```yaml
sessions:
  backend: database  # or 'file'
```

## Files Updated

### Core Module
- `lib/Concierge/Setup.pm`
  - Changed default from 'SQLite' to 'database'
  - Updated validation (now case-insensitive)
  - Updated comments and documentation

### Setup Script
- `examples/setup_concierge.pl`
  - Updated all template definitions
  - Updated interactive prompts
  - Updated validation
  - Updated generated config comments
  - Updated help text

### Test Scripts
- `examples/test_setup.pl`
  - Updated advanced setup test

### Documentation
- `TESTING_RESULTS.md` - Updated backend naming section
- `DESK_CONVENTION.md` - Updated examples

## Template Changes

### Minimal Template
- Sessions backend: `'File'` → `'file'`
- Description: "Text sessions" → "File sessions"

### Development Template
- Sessions backend: `'sqlite'` → `'database'`
- Description: "SQLite backends" → "Database backends"

### Production Template
- Sessions backend: `'sqlite'` → `'database'`
- Description: "SQLite backends" → "Database backends"

### Testing Template
- Sessions backend: `'File'` → `'file'`

## Validation Changes

**Old (case-sensitive):**
```perl
unless $backend =~ /^(SQLite|File)$/;
```

**New (case-insensitive):**
```perl
my $backend = lc $config->{sessions}{backend};
unless $backend =~ /^(database|file)$/;
```

## Testing

All tests pass with updated backend names:

✅ **test_setup.pl**
- Simple setup uses 'database' backend
- Advanced setup uses 'file' backend
- All 7 tests pass

✅ **setup_concierge.pl**
- Help text updated
- Generated configs use new names
- All templates updated

✅ **Validation**
- Case-insensitive validation works
- Error messages show correct backend options

## Configuration Examples

### Simple Setup (build_desk)
```perl
use Concierge::Setup;

# Uses database backend by default for both Sessions and Users
my $result = Concierge::Setup::build_desk(
    './desk',
    './desk/auth.pwd',
    ['membership_tier'],
    ['last_login'],
);
```

### Advanced Setup (build_custom_desk)
```perl
use Concierge::Setup;

# Explicit backend specification
my $result = Concierge::Setup::build_custom_desk({
    storage => { base_dir => './desk' },
    auth => { file => './desk/auth.pwd' },
    sessions => { backend => 'database' },  # or 'file'
    users => { backend => 'database' },     # or 'yaml' or 'file'
});
```

### YAML Configuration
```yaml
# Concierge Setup Configuration

storage:
  base_dir: ./desk

auth:
  file: ./desk/auth.pwd

sessions:
  backend: database  # 'database' or 'file' (case-insensitive)

users:
  backend: database  # 'database', 'yaml', or 'file' (case-insensitive)
```

## Benefits

1. **Consistency**: Same naming pattern for both components
2. **User-friendly**: Case-insensitive, more forgiving
3. **Future-proof**: 'database' doesn't commit to SQLite specifically
4. **Clearer**: Users don't need to know implementation details
5. **Simpler**: No need to remember which component is case-sensitive

## Backward Compatibility

**Breaking change:** Code using old backend names will need updates.

However, since Concierge is still in v0.2.0 (pre-1.0), breaking changes are acceptable and expected during the development phase.

## Notes

- Concierge::Sessions module itself was updated by the user (already installed)
- This document covers the updates to Concierge.pm and related files
- All tests passing with new backend names
- No changes to runtime operational API
