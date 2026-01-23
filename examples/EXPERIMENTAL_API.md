# Concierge Experimental API Examples

This directory contains example scripts demonstrating the experimental Concierge API methods:
- `new_concierge()` - Minimal object creation
- `build_desk()` - Install and configure a Concierge instance
- `open_desk()` - Open an existing Concierge instance

## Overview

The experimental methods provide a simplified approach to Concierge setup:

1. **One-time installation**: Use `build_desk()` to create and configure a new Concierge
2. **Normal operation**: Use `open_desk()` to instantiate the Concierge in your application

These methods differ from the standard `setup()`/`load()` methods in several ways:
- All three components (Auth, Sessions, Users) are always included
- Configuration is stored in Concierge's internal session (ID: `__concierge__`)
- Streamlined API with fewer options
- Fatal errors from components are passed directly to the calling app

## Example Scripts

### 1. install_concierge.pl

Demonstrates the first-time installation of a Concierge instance.

**What it does:**
- Creates a new Concierge using `build_desk()`
- Configures all three components (Auth, Users, Sessions)
- Stores configuration in Concierge's internal session
- Optionally tests opening the desk immediately

**Usage:**
```bash
./install_concierge.pl
```

**Key concepts:**
- One-time setup operation
- Creates storage directories and databases
- Returns desk location for future use

### 2. open_concierge.pl

Demonstrates how to open an existing Concierge instance.

**What it does:**
- Opens a previously installed Concierge using `open_desk()`
- Loads configuration from Concierge's internal session
- Inspects and displays Concierge object details
- Shows how to access component instances

**Usage:**
```bash
export CONCIERGE_DESK=/path/to/desk
./open_concierge.pl
```

Or edit the script to set the desk location directly.

**Key concepts:**
- Standard method for instantiating Concierge
- Loads saved configuration
- Provides access to all components

### 3. complete_workflow.pl

Demonstrates a complete workflow from installation to user operations.

**What it does:**
1. Installs Concierge (if not already installed)
2. Opens the Concierge
3. Creates a user
4. Adds user data
5. Retrieves user data
6. Creates a session
7. Stores session data
8. Retrieves session data
9. Authenticates the user

**Usage:**
```bash
./complete_workflow.pl
```

**Key concepts:**
- End-to-end workflow demonstration
- Integration with component operations
- Typical user management patterns

### 4. application_integration.pl

Demonstrates a typical application integration pattern.

**What it does:**
- Creates an application configuration file
- Installs Concierge for the application
- Opens Concierge on application startup
- Simulates application requests (registration, login, user lookup)
- Shows application shutdown

**Usage:**
```bash
./application_integration.pl
```

**Key concepts:**
- Integration with application configuration
- Concierge lifecycle management
- Typical web application patterns

## API Reference

### build_desk()

```perl
my $result = Concierge::build_desk(
    $storage_dir,           # Required: Directory for Sessions and Users data
    $auth_file,             # Required: Path to authentication password file
    $app_fields,            # Optional: Arrayref of custom user fields
    $user_session_fields,   # Optional: Arrayref of allowed session field names
);
```

**Parameters:**
- `$storage_dir` - Directory where session and user data will be stored
- `$auth_file` - Path to the password file (will be created if needed)
- `$app_fields` - Arrayref of custom field definitions for user records
- `$user_session_fields` - Arrayref of field names allowed in session data

**Returns:**
```perl
{
    success => 1,
    message => "Ready!",
    desk => '/path/to/storage_dir',  # Save this for open_desk()
}
```

**Example:**
```perl
my $result = Concierge::build_desk(
    './data/concierge',
    './data/passwords.pwd',
    [
        { field_name => 'display_name', type => 'text', indexed => 1 },
        { field_name => 'bio', type => 'text' },
    ],
    [ 'preferences', 'theme', 'language' ],
);

if ($result->{success}) {
    my $desk_location = $result->{desk};
    # Store $desk_location for future use
}
```

### open_desk()

```perl
my $result = Concierge->open_desk($desk_location);
```

**Parameters:**
- `$desk_location` - The storage directory path from `build_desk()`

**Returns:**
```perl
{
    success => 1,
    message => 'Welcome!',
    concierge => $concierge_object,  # Fully operational Concierge
}
```

**Example:**
```perl
my $result = Concierge->open_desk('./data/concierge');

if ($result->{success}) {
    my $concierge = $result->{concierge};

    # Access components
    my $auth = $concierge->{auth};
    my $users = $concierge->{users};
    my $sessions = $concierge->{sessions};
}
```

## Typical Usage Pattern

### Installation (one-time)

```perl
#!/usr/bin/env perl
use Concierge;

# Install Concierge
my $result = Concierge::build_desk(
    '/var/app/concierge',
    '/var/app/passwords.pwd',
    [ { field_name => 'display_name', type => 'text' } ],
    [ 'preferences', 'theme' ],
);

die "Installation failed" unless $result->{success};

# Save the desk location
my $desk_location = $result->{desk};
say "Concierge installed at: $desk_location";
```

### Application Startup (normal)

```perl
#!/usr/bin/env perl
use Concierge;

# Open Concierge
my $result = Concierge->open_desk('/var/app/concierge');

die "Failed to open Concierge" unless $result->{success};

my $concierge = $result->{concierge};

# Use Concierge
my $auth = $concierge->{auth};
my $users = $concierge->{users};
my $sessions = $concierge->{sessions};

# Your application logic here...
```

## Component Access

Once you have a Concierge object from `open_desk()`, access components:

```perl
# Authentication
my $auth_result = $concierge->{auth}->create_user($username, $password);
my $verify_result = $concierge->{auth}->authenticate_user($username, $password);

# User Data
my $add_result = $concierge->{users}->add_data($user_id, %data);
my $get_result = $concierge->{users}->get_user($user_id);

# Sessions
my $session_result = $concierge->{sessions}->new_session(user_id => $user_id);
my $session = $session_result->{session};
$session->set_data({ key => 'value' });
$session->save();
```

## Notes

- These are experimental methods and may change
- All components are included (no optional components)
- Configuration is stored in Concierge's session, not in external JSON/YAML files
- The concierge session ID is `__concierge__`
- Fatal errors from components are passed through (not caught)

## See Also

- Concierge main documentation
- Component documentation:
  - Concierge::Auth
  - Concierge::Sessions
  - Concierge::Users
