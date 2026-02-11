# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Concierge is a Perl service layer orchestrator that coordinates three component modules:
- **Concierge::Auth** - Argon2 password authentication
- **Concierge::Sessions** - Session management with multiple storage backends
- **Concierge::Users** - User data operations with multiple storage backends

The project is under active development (v0.2.0) and represents a complete rewrite with no backward compatibility with previous Local::App::Concierge versions.

## Development Environment

- **Perl Version**: v5.42.0 (minimum v5.36)
- **Working Directory**: `/Volumes/Main/Development/Repositories/Concierge`
- **Local Component Modules**: Installed at `/Users/bw/.plenv/versions/5.42.0/lib/perl5/site_perl/5.42.0/Concierge/`

## Building and Testing

### Initial Setup
```bash
perl Makefile.PL
make
```

### Run All Tests
```bash
make test
```

### Run Single Test
```bash
perl -Ilib t/00-load.t
```

### Run Examples
Examples require lib paths to component modules:
```bash
perl -Ilib examples/concierge_cli.pl
```

## Architecture

### Service Layer Pattern
```
Application Layer (event-loop safe)
    ↓
Concierge (service layer - structured returns, no crashes)
    ↓ ↓ ↓
Concierge::Auth   Concierge::Sessions   Concierge::Users
```

### Core Concepts

**Desk Initialization**:
- `build_desk()` - Creates new Concierge desk with storage directory and component setup
- `open_desk()` - Opens existing desk, loading configuration from internal concierge session

**Internal Session Management**:
- Concierge maintains an admin session (`__concierge__`) that stores configuration and user_key mappings
- This session uses `admin_session => 1` flag and `session_timeout => 'indefinite'`
- Configuration and state stored in session data, not separate config files

**User Keys (External Keys)**:
- Applications receive `external_key` (user token) after successful login
- Concierge internally maps external_key → {user_id, session_id} in concierge session
- Applications use `*_for_key()` methods that accept external_key instead of user_id
- This abstraction prevents applications from directly accessing internal user_ids

### Parameter Filtering (Security Boundaries)

The module uses `Params::Filter` to enforce strict data segregation:

- **`$auth_data_filter`** - ONLY user_id + password (for authentication)
- **`$user_data_filter`** - Everything EXCEPT password (for user profiles)
- **`$session_data_filter`** - All fields except credentials (for session initialization)
- **`$user_update_filter`** - All fields except user_id and password (for profile updates)

These filters ensure credentials never leak into user data stores and user_id cannot be changed via updates.

### Method Patterns

**Direct Methods** (internal, use user_id):
```perl
$concierge->add_user({user_id => '...', password => '...', moniker => '...', ...})
$concierge->login_user({user_id => '...', password => '...'})
$concierge->get_user_data($user_id, @optional_fields)
$concierge->update_user_data($user_id, {field => 'value'})
$concierge->reset_password($user_id, $new_password)
$concierge->verify_password($user_id, $password)
$concierge->remove_user($user_id)
$concierge->logout_user($session_id)
```

**Application-Facing Methods** (use external_key/user_key):
```perl
$concierge->get_user_data_for_key($user_key, @optional_fields)
$concierge->update_user_data_for_key($user_key, {field => 'value'})
$concierge->reset_password_for_key($user_key, $new_password)
$concierge->verify_password_for_key($user_key, $password)
$concierge->logout_user_for_key($user_key)
$concierge->list_users_for_key($user_key, $filter, $options)
```

**Helper Methods**:
```perl
$concierge->get_user_for_key($external_key)  # Returns {success => 1, user_id => '...'}
$concierge->get_session_for_key($external_key)  # Returns {success => 1, session_id => '...'}
$concierge->user_data_to_session($user_id, $session_id)  # Sync user DB to session
```

### Response Structure

All methods return structured hashrefs:
```perl
# Success
{ success => 1, message => '...', ... }

# Failure
{ success => 0, message => 'error description' }
```

## Code Conventions

### Perl Modern Features
- Use `v5.36` or higher (enables strict, warnings, signatures, say)
- Subroutine signatures: `sub foo ($arg1, $arg2) { ... }`
- Postfix dereference: `$hashref->{foo}->@*`, `$arrayref->@*`

### Error Handling
- Never `croak` or `die` in service methods (they return structured results)
- Exception: `open_desk()` may croak if desk directory doesn't exist (early validation)
- Applications should check `$result->{success}` before using data

### Testing
- Component modules (Auth, Sessions, Users) have their own test suites
- Concierge tests focus on integration, coordination, and cross-component workflows
- Use Test2::V0 for all tests

## Common Workflows

### Setup New Desk
```perl
use Concierge;

my $result = Concierge::build_desk(
    '/path/to/storage',
    '/path/to/auth.pwd',
    ['custom_field1', 'custom_field2'],  # app_fields (user data)
    ['session_field1', 'session_field2'], # user_session_fields
);

my $open_result = Concierge::open_desk('Concierge', '/path/to/storage');
my $concierge = $open_result->{concierge};
```

### User Registration and Login
```perl
# Add user
my $result = $concierge->add_user({
    user_id  => 'alice',
    moniker  => 'Alice',
    email    => 'alice@example.com',
    password => 'secret123',
});

# Login
my $login = $concierge->login_user({
    user_id  => 'alice',
    password => 'secret123',
});

my $user_key = $login->{external_key};  # Give this to application
```

### Application Operations (using external_key)
```perl
# Get user profile
my $profile = $concierge->get_user_data_for_key($user_key);

# Update profile
$concierge->update_user_data_for_key($user_key, {
    email => 'newemail@example.com'
});

# Change password
$concierge->reset_password_for_key($user_key, 'newsecret');

# Logout
$concierge->logout_user_for_key($user_key);
```

## File Locations

### Main Module
- `lib/Concierge.pm` - All orchestration logic in single file

### Tests
- `t/00-load.t` - Module loading and method existence tests

### Examples
- `examples/concierge_cli.pl` - Full-featured CLI demonstrating all operations
- `examples/test_*.pl` - Individual feature test scripts

### Documentation
- `README.md` - Project overview and status
- `ARCHITECTURE_NOTES.md` - Detailed architecture decisions
- `ATP_implementation.md` - Application Token Pattern documentation

## Notes for Claude

- **No Backward Compatibility**: This is a fresh rewrite. Don't assume old Local::App::Concierge patterns apply.
- **Component Coordination**: Concierge coordinates existing components (Auth, Sessions, Users) - it doesn't reimplement their functionality.
- **Structured Returns**: All methods return hashrefs. Never assume success - always check `$result->{success}`.
- **Security Boundaries**: Respect the parameter filters. Passwords never go to Users component, user_id never changes after creation.
- **External Keys**: Applications should never see internal user_ids directly. Use `*_for_key()` methods when implementing application-facing APIs.
