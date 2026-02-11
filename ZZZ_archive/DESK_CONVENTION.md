# The `./desk` Convention

## Overview

Concierge automatically uses `./desk` as the storage directory when you provide `.` or an empty string. This prevents cluttering your application root directory with database files.

## Behavior

### Automatic Conversion

```perl
use Concierge::Setup;

# These all create storage in './desk':
Concierge::Setup::build_desk('.', './auth.pwd', [], []);
Concierge::Setup::build_desk('', './auth.pwd', [], []);
Concierge::Setup::build_desk('./', './auth.pwd', [], []);

# Result: Files created in ./desk/
#   ./desk/sessions.db
#   ./desk/users.db
#   ./desk/users-config.json
#   ./desk/users-config.yaml
```

You'll see a warning message:
```
Storage directory set to './desk' (convention: avoid cluttering application root)
```

### Custom Paths Still Work

```perl
# Explicit paths are respected:
Concierge::Setup::build_desk('./data', './data/auth.pwd', [], []);
Concierge::Setup::build_desk('/var/lib/myapp', '/var/lib/myapp/auth.pwd', [], []);

# These use the exact path you specify
```

## Recommended Project Structure

```
./                          # Application root
├── app.pl                  # Main application
├── lib/                    # Your modules
│   └── MyApp/
├── templates/              # Web templates
├── static/                 # Static files
└── desk/                   # Concierge storage (auto-created)
    ├── sessions.db         # Session data
    ├── users.db            # User data
    ├── users-config.json   # User fields config
    ├── users-config.yaml   # Human-readable config
    └── auth.pwd            # Password file
```

## Setup Examples

### Simple Setup with Convention

```perl
use Concierge::Setup;

# Just use '.' - it becomes './desk'
my $result = Concierge::Setup::build_desk(
    '.',                    # → './desk'
    './desk/auth.pwd',
    ['membership_tier'],    # app fields
    ['last_login'],         # session fields
);
```

### Runtime Usage

```perl
use Concierge;

# Open the desk
my $desk = Concierge->open_desk('./desk');
my $concierge = $desk->{concierge};

# Use normally
my $login = $concierge->login_user({...});
```

## Setup Script

The setup script also defaults to `./desk`:

```bash
# Interactive mode - defaults to ./desk
perl examples/setup_concierge.pl

# Generated configs show ./desk
perl examples/setup_concierge.pl --generate-config > config.yaml
```

Example generated config:
```yaml
storage:
  base_dir: ./desk  # Convention: './desk' keeps app root uncluttered

auth:
  file: ./desk/auth.pwd
```

## Advanced: Separate Component Directories

Even with the convention, you can separate component storage:

```perl
use Concierge::Setup;

my $result = Concierge::Setup::build_custom_desk({
    storage => {
        base_dir     => './desk',
        sessions_dir => './desk/sessions',
        users_dir    => './desk/users',
    },
    auth => {
        file => './desk/auth/passwords.pwd',
    },
    sessions => { backend => 'database' },
    users => { backend => 'database' },
});
```

Result:
```
./desk/
├── auth/
│   └── passwords.pwd
├── sessions/
│   └── sessions.db
└── users/
    ├── users.db
    ├── users-config.json
    └── users-config.yaml
```

## Why This Convention?

1. **Clean Application Root**: Database files don't clutter your main directory
2. **Easy Backups**: `tar czf backup.tar.gz ./desk` backs up everything
3. **Easy Cleanup**: `rm -rf ./desk` removes all Concierge data
4. **Consistent**: All developers use the same structure
5. **Obvious**: `./desk` clearly indicates "Concierge lives here"

## Overriding the Convention

If you truly want to use the current directory (not recommended):

```perl
use Cwd qw/getcwd/;
use Concierge::Setup;

# Use absolute path to current directory
my $cwd = getcwd();
my $result = Concierge::Setup::build_desk($cwd, "$cwd/auth.pwd", [], []);
```

But really, just use `./desk`. It's cleaner.

## Migration from Old Code

If you have existing code using `.`:

```perl
# Old way (cluttered root)
my $result = Concierge::Setup::build_desk('.', './auth.pwd', [], []);
# Created: ./sessions.db, ./users.db, etc. in app root

# New way (automatic)
my $result = Concierge::Setup::build_desk('.', './desk/auth.pwd', [], []);
# Creates: ./desk/sessions.db, ./desk/users.db, etc.

# Update open_desk calls:
my $desk = Concierge->open_desk('./desk');  # Was: '.'
```

## Testing

The convention is tested in `examples/test_desk_convention.pl`:

```bash
perl -Ilib examples/test_desk_convention.pl
```

All tests pass:
- ✓ '.' becomes './desk'
- ✓ Empty string becomes './desk'
- ✓ Files created in correct location
- ✓ Explicit paths still work
- ✓ Custom paths respected
