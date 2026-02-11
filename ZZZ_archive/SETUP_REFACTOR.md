# Concierge Setup Refactoring Summary

## Date: 2026-01-28

## Overview

Separated setup/configuration logic from runtime operations by creating a dedicated `Concierge::Setup` module.

## Changes Made

### 1. Created `lib/Concierge/Setup.pm`

**Purpose**: One-time desk initialization and configuration

**Methods**:
- `build_desk($storage_dir, $auth_file, $app_fields, $user_session_fields)`
  - Simple setup with opinionated defaults
  - SQLite backends for sessions and users
  - All standard user fields included
  - Co-located storage

- `build_custom_desk($config)`
  - Advanced setup with full configuration control
  - Separate storage directories per component
  - Full Users.pm field configuration (include_standard_fields, field_overrides, app_fields)
  - Custom backend selection

- `validate_setup_config($config)`
  - Validates configuration before execution
  - Checks required fields and backend values

### 2. Updated `lib/Concierge.pm`

**Removed**: `build_desk()` method (moved to Concierge::Setup)

**Retained**: All runtime operational methods
- `open_desk()` - Load existing desk
- User operations: `add_user()`, `login_user()`, `logout_user()`, etc.
- User data methods: `get_user_data_for_key()`, `update_user_data_for_key()`, etc.
- Session management
- Password operations
- All `*_for_key()` application-facing methods

### 3. Created `examples/setup_concierge.pl`

**Purpose**: Comprehensive CLI tool for Concierge desk setup

**Operating Modes**:

1. **Interactive Mode** (default)
   - Prompts for basic configuration
   - Simple mode only
   - Uses Term::ReadLine

2. **Template Mode** (`--template <name>`)
   - Pre-configured setups: minimal, development, production, testing
   - Quick start without prompts

3. **Config File Mode** (`--config <file>`)
   - Load from YAML configuration file
   - Supports simple and advanced configurations
   - `--validate-only` flag for validation

4. **Generate Config Mode** (`--generate-config`)
   - Creates YAML template for editing
   - Shows commented examples of advanced features
   - Can base on existing template

**Templates**:
- `minimal` - File sessions, YAML users, core fields only
- `development` - SQLite backends, all standard fields, app fields
- `production` - SQLite backends, all standard fields, app fields
- `testing` - Temporary paths, throwaway setup

### 4. Updated Context Documentation

Updated `CLAUDE_CONC_CONTEXT.md` to include instruction to read `CLAUDE.md` automatically.

## Benefits

1. **Cleaner Separation**: Setup vs operations are distinct lifecycles
2. **Lighter Runtime**: Applications don't load setup code
3. **Better Organization**: Setup logic/templates grouped together
4. **Easier Maintenance**: Template changes don't affect runtime
5. **Clear API Boundaries**: Import what you need when you need it

## Usage Examples

### Simple Setup (Setup Time)

```perl
use Concierge::Setup;

my $result = Concierge::Setup::build_desk(
    '/var/lib/myapp',
    '/var/lib/myapp/auth.pwd',
    ['custom_field1', 'custom_field2'],  # app_fields
    ['last_login', 'theme'],             # user_session_fields
);
```

### Advanced Setup (Setup Time)

```perl
use Concierge::Setup;

my $result = Concierge::Setup::build_custom_desk({
    storage => {
        base_dir     => '/var/lib/myapp',
        sessions_dir => '/var/lib/myapp/sessions',
        users_dir    => '/var/lib/myapp/users',
    },
    auth => {
        file => '/var/lib/myapp/auth.pwd',
    },
    sessions => {
        backend => 'sqlite',
    },
    users => {
        backend => 'database',
        include_standard_fields => ['email', 'phone', 'first_name'],
        app_fields => [
            {
                field_name => 'membership_tier',
                type => 'enum',
                options => ['*Bronze', 'Silver', 'Gold'],
                required => 1,
            },
        ],
        field_overrides => [
            {
                field_name => 'email',
                required => 1,
                must_validate => 1,
            },
        ],
    },
    user_session_fields => ['last_login', 'theme'],
});
```

### Runtime Operations

```perl
use Concierge;

my $result = Concierge->open_desk('/var/lib/myapp');
my $concierge = $result->{concierge};

my $login = $concierge->login_user({
    user_id => 'alice',
    password => 'secret123',
});

my $user_key = $login->{external_key};
```

## CLI Usage

```bash
# Interactive setup
perl examples/setup_concierge.pl

# Quick template
perl examples/setup_concierge.pl --template development

# Generate config for customization
perl examples/setup_concierge.pl --generate-config --template production > myapp.yaml

# Edit myapp.yaml, then:
perl examples/setup_concierge.pl --config myapp.yaml

# Validate without executing
perl examples/setup_concierge.pl --config myapp.yaml --validate-only
```

## Testing Status

✓ Modules load successfully
- `Concierge v0.2.0`
- `Concierge::Setup v0.1.0`

✓ Setup script runs
- `--help` works
- `--generate-config` works
- All templates defined

⏳ Integration testing needed
- Test `build_desk()` with actual setup
- Test `build_custom_desk()` with advanced config
- Test setup script end-to-end

## Next Steps

1. Test simple setup path with a temporary directory
2. Test advanced setup path with field configurations
3. Update existing examples to use `Concierge::Setup` for setup code
4. Add tests to test suite
5. Update documentation/README

## Notes

- The `build_desk()` signature remains unchanged for backward compatibility
- Applications using `Concierge::build_desk()` need to change to `Concierge::Setup::build_desk()`
- All runtime operations in Concierge.pm remain unchanged
- The setup script defers "fancy CLI stuff" - advanced configs use YAML files
