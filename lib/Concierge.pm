package Concierge v0.1.0;

use v5.40;
use Carp qw<carp croak>;
use JSON::PP qw< encode_json decode_json >;
use YAML;

# ABSTRACT: Service layer orchestrator for authentication, sessions, and users

# === COMPONENT MODULES ===
use Concierge::Auth;
use Concierge::Sessions;
use Concierge::Users;

our $VERSION = 'v0.1.0';

# ===========================================================================
# CONSTRUCTOR
# ===========================================================================

sub new {
    my ($class, %config) = @_;

    my $self = bless {
        config => \%config,
        # Component instances (optional, may not be set)
        auth => undef,
        users => undef,
        sessions => undef,  # App sessions (Sessions component)
        # Concierge's own internal session (always required)
        concierge_session => undef,
    }, $class;

    return $self;
}

# ===========================================================================
# SETUP AND LOAD METHODS
# ===========================================================================

=head1 setup

Class method to perform initial setup of Concierge and its components.

Creates all component backends, saves complete configuration to both JSON and YAML,
then returns a fully initialized Concierge object instantiated from that saved config.

DIES if setup fails (this is the only phase where fatal errors are allowed).

Parameters (hash):
  - concierge_config_file: (optional) Path for config files (default: ./concierge.json)
  - concierge_session: (optional) Hashref for Concierge's own session storage
  - auth: (optional) Hashref of Auth configuration
  - sessions: (optional) Hashref of Sessions configuration (for app user sessions)
  - users: (optional) Hashref of Users configuration

Returns: Fully initialized Concierge object

Example:
    my $concierge = Concierge->setup(
        concierge_config_file => '/var/app/concierge.json',
        concierge_session => {
            storage_dir => '/var/app/concierge',
            backend => 'SQLite',
        },
        auth => { auth_file => '/var/app/data/auth.pwd' },
        sessions => { storage_dir => '/var/app/sessions', backend => 'SQLite' },
        users => { storage_dir => '/var/app/users', backend => 'database' },
    );

=cut

sub setup {
    my ($class, %setup_args) = @_;

    # Step 1: Create a temporary Concierge object for setup
    my $self = $class->new(%setup_args);

    # Step 2: Initialize Concierge's own session FIRST (fatal if fails)
    $self->_init_concierge_session($setup_args{concierge_session});

    # Step 3: Configure each component that's present in setup args
    my @components = grep { exists $setup_args{$_} } qw(auth sessions users);

    my %component_configs;
    for my $component (@components) {
        my $method = "configure_$component";
        my $result = $self->$method(%{$setup_args{$component}});

        unless ($result->{success}) {
            croak "Setup failed for $component: " . $result->{message};
        }

        # Store successful config for saving
        $component_configs{$component} = { %{$setup_args{$component}} };

        # Add any returned config keys (like auth_file, users_config_file)
        if ($result->{config_file}) {
            $component_configs{$component}{config_file} = $result->{config_file};
        }
        if ($result->{auth_file}) {
            $component_configs{$component}{auth_file} = $result->{auth_file};
        }
        if ($result->{users_config_file}) {
            $component_configs{$component}{users_config_file} = $result->{users_config_file};
        }
        if ($result->{sessions_storage_dir}) {
            $component_configs{$component}{sessions_storage_dir} = $result->{sessions_storage_dir};
        }
    }

    # Step 4: Build complete config structure
    my $config_file = $setup_args{concierge_config_file}
        || './concierge.json';

    my $complete_config = {
        version => "$Concierge::VERSION",
        generated => time(),
        concierge => {
            %{ $setup_args{concierge_session} || {} },
            concierge_session_id => $self->{concierge_session}{session_id},
        },
        components_configured => \@components,
        %component_configs,
    };

    # Step 5: Save config to both JSON and YAML
    $self->_save_config($config_file, $complete_config);

    # Step 6: Load from saved config to get operational instance
    # This validates the config is viable
    my $operational_concierge = $class->load($config_file);

    return $operational_concierge;
}

=head1 load

Class method to instantiate Concierge from a saved configuration file.

DIES if config cannot be loaded or components cannot initialize.

Parameters:
  - config_file: Path to concierge.json config file

Returns: Fully operational Concierge object

Example:
    my $concierge = Concierge->load('/var/app/concierge.json');

=cut

sub load {
    my ($class, $config_file) = @_;

    # Load config (prefer JSON, fall back to YAML if JSON doesn't exist)
    my $config = $class->_load_config($config_file);

    # Create Concierge object
    my $self = $class->new(%$config);

    # Initialize Concierge's own session (fatal if fails)
    $self->_init_concierge_session($config->{concierge});

    # Directly instantiate components from saved config (NOT configure_* methods)
    for my $component (@{$config->{components_configured} || []}) {
        if ($component eq 'auth') {
            # Directly instantiate Auth from saved auth_file
            my $auth_file = $config->{auth}{auth_file}
                or croak "Config missing auth_file for Auth component";
            eval {
                $self->{auth} = Concierge::Auth->new({ file => $auth_file });
            };
            if ($@) {
                croak "Failed to instantiate Auth from config: $@";
            }
        }
        elsif ($component eq 'sessions') {
            # Directly instantiate Sessions from saved config
            my %sessions_config;
            $sessions_config{storage_dir} = $config->{sessions}{sessions_storage_dir}
                if $config->{sessions}{sessions_storage_dir};
            $sessions_config{backend} = $config->{sessions}{backend}
                || $config->{sessions}{sessions_backend};
            $sessions_config{session_timeout} = $config->{sessions}{session_timeout}
                if $config->{sessions}{session_timeout};

            eval {
                $self->{sessions} = Concierge::Sessions->new(%sessions_config);
            };
            if ($@) {
                croak "Failed to instantiate Sessions from config: $@";
            }
        }
        elsif ($component eq 'users') {
            # Directly instantiate Users from saved config_file
            my $users_config_file = $config->{users}{users_config_file}
                || $config->{users}{config_file}
                or croak "Config missing users_config_file for Users component";
            eval {
                $self->{users} = Concierge::Users->new($users_config_file);
            };
            if ($@) {
                croak "Failed to instantiate Users from config: $@";
            }
        }
    }

    return $self;
}

# ===========================================================================
# CONCIERGE INTERNAL SESSION MANAGEMENT
# ===========================================================================

=head1 _init_concierge_session

Initialize Concierge's internal session for tracking user_key mappings
and storing operational data.

This is ALWAYS called - Concierge must have its own session.
FATAL if session creation fails.

Parameters:
  - session_config: (optional) Hashref with storage_dir and backend for Concierge's session

=cut

sub _init_concierge_session {
    my ($self, $session_config) = @_;

    $session_config ||= {};

    # Build config for Concierge's own Sessions instance
    my %concierge_sessions_config;

    # Use provided config or defaults
    $concierge_sessions_config{storage_dir} = $session_config->{storage_dir}
        || $self->{config}{concierge_storage_dir}
        || './data/concierge';

    $concierge_sessions_config{backend} = $session_config->{backend}
        || 'SQLite';

    # Create Sessions instance specifically for Concierge's internal use
    my $concierge_sessions = eval {
        Concierge::Sessions->new(%concierge_sessions_config);
    };
    if ($@) {
        croak "FATAL: Failed to create Concierge's internal session: $@";
    }

    # Store for Concierge's use
    $self->{_concierge_sessions} = $concierge_sessions;

    # Create or load Concierge's session
    my $session_id = $session_config->{concierge_session_id};

    if ($session_id) {
        # Try to load existing session
        my $result = $concierge_sessions->get_session($session_id);
        if ($result->{success}) {
            $self->{concierge_session} = {
                session => $result->{session},
                session_id => $session_id,
            };
            return;
        }
        # If session doesn't exist, fall through to create new
    }

    # Create new session for Concierge
    my $result = $concierge_sessions->new_session(
        user_id => '__concierge_id__',
        session_timeout => 'indefinite',
    );

    unless ($result->{success}) {
        croak "FATAL: Failed to create Concierge's internal session: " . $result->{message};
    }

    $self->{concierge_session} = {
        session => $result->{session},
        session_id => $result->{session}{session_id},
    };
}

# ===========================================================================
# CONFIG SAVE/LOAD HELPERS
# ===========================================================================

sub _save_config {
    my ($self, $config_file, $config) = @_;

    # Determine file paths
    my $yaml_file = $config_file;
    $yaml_file =~ s/\.json$/.yaml/i;
    $yaml_file = $config_file . '.yaml' unless $yaml_file ne $config_file;

    # Ensure directory exists
    my $dir = $config_file;
    $dir =~ s{/[^/]*$}{};
    if ($dir && !-d $dir) {
        eval {
            require File::Path;
            File::Path::make_path($dir);
        };
        croak "Cannot create config directory: $dir\nError: $@" if $@;
    }

    # Save JSON
    eval {
        my $json = JSON::PP->new->utf8->canonical->pretty;
        open my $fh, '>', $config_file or croak "Cannot write $config_file: $!";
        print {$fh} $json->encode($config);
        close $fh;
    };
    if ($@) {
        croak "Failed to save JSON config: $@";
    }

    # Save YAML
    eval {
        open my $fh, '>', $yaml_file or croak "Cannot write $yaml_file: $!";
        print {$fh} YAML::Dump($config);
        close $fh;
    };
    if ($@) {
        croak "Failed to save YAML config: $@";
    }
}

sub _load_config {
    my ($class, $config_file) = @_;

    # Determine YAML file path
    my $yaml_file = $config_file;
    $yaml_file =~ s/\.json$/.yaml/i;
    $yaml_file = $config_file . '.yaml' unless $yaml_file ne $config_file;

    # Load config (prefer JSON, fall back to YAML if JSON doesn't exist)
    my $config;
    if (-f $config_file) {
        $config = $class->_load_json_config($config_file);
    } elsif (-f $yaml_file) {
        $config = $class->_load_yaml_config($yaml_file);
    } else {
        croak "Config file not found: $config_file (or $yaml_file)";
    }

    return $config;
}

sub _load_json_config {
    my ($class, $config_file) = @_;

    my $config_json;
    eval {
        open my $fh, '<', $config_file or croak "Cannot open $config_file: $!";
        local $/;
        $config_json = <$fh>;
        close $fh;
    };
    croak "Failed to read JSON config file: $config_file\nError: $@" if $@;

    my $config;
    eval {
        $config = decode_json($config_json);
    };
    croak "Failed to parse JSON config file: $config_file\nError: $@" if $@;

    return $config;
}

sub _load_yaml_config {
    my ($class, $yaml_file) = @_;

    my $config;
    eval {
        open my $fh, '<', $yaml_file or croak "Cannot open $yaml_file: $!";
        local $/;
        $config = YAML::Load($fh);
        close $fh;
    };
    croak "Failed to read YAML config file: $yaml_file\nError: $@" if $@;

    return $config;
}

# ===========================================================================
# AUTH RESPONSE NORMALIZATION
# ===========================================================================

=head1 _normalize_auth_response

Normalize Auth module's (success, message) return to hashref format.

Parameters:
  - success: 1 or 0
  - message: Response message
  - extra: (optional) Hashref of additional key-value pairs

Returns: { success => 1|0, message => "...", extra_key => value }

=cut

sub _normalize_auth_response {
    my ($self, $success, $message, $extra) = @_;

    my $response = {
        success => $success ? 1 : 0,
        message => $message || ($success ? "Success" : "Operation failed"),
    };

    # Add any extra keys
    if ($extra) {
        $response->{$_} = $extra->{$_} for keys %$extra;
    }

    return $response;
}

# ===========================================================================
# COMPONENT CONFIGURATION
# ===========================================================================

=head1 configure_auth

Configure the Concierge::Auth component.

Parameters (hash):
  - auth_file: (required) Path to password file

The auth_file will be created if it doesn't exist.

Returns: { success => 1|0, auth_file => $path, message => "..." }

=cut

sub configure_auth {
    my ($self, %config) = @_;

    my $auth_file = $config{auth_file}
        or return { success => 0, message => "auth_file parameter required" };

    eval {
        $self->{auth} = Concierge::Auth->new({ file => $auth_file });
    };
    if ($@) {
        return { success => 0, message => "Failed to initialize Auth: $@" };
    }

    $self->{config}{auth_file} = $auth_file;

    return {
        success => 1,
        auth_file => $auth_file,
        message => "Auth component configured successfully"
    };
}

=head1 configure_sessions

Configure the Concierge::Sessions component (for app user sessions).

This is separate from Concierge's own internal session.

Parameters (hash):
  - sessions_storage_dir: (optional) Directory for session storage
  - sessions_backend: (optional) 'SQLite' (default) or 'File'
  - session_timeout: (optional) Default timeout in seconds (default: 3600)

Returns: { success => 1|0, sessions_storage_dir => $path, message => "..." }

=cut

sub configure_sessions {
    my ($self, %config) = @_;

    my %sessions_config;

    # storage_dir - optional (Sessions has defaults)
    $sessions_config{storage_dir} = $config{sessions_storage_dir}
        if $config{sessions_storage_dir};

    # backend - optional (Sessions.pm handles default)
    $sessions_config{backend} = $config{sessions_backend}
        if $config{sessions_backend};

    # session_timeout - optional (Sessions.pm handles default)
    $sessions_config{session_timeout} = $config{session_timeout}
        if $config{session_timeout};

    eval {
        $self->{sessions} = Concierge::Sessions->new(%sessions_config);
    };
    if ($@) {
        return { success => 0, message => "Failed to initialize Sessions: $@" };
    }

    $self->{config}{sessions_storage_dir} = $sessions_config{storage_dir} // '';

    return {
        success => 1,
        sessions_storage_dir => $self->{config}{sessions_storage_dir},
        message => "Sessions component configured successfully"
    };
}

=head1 configure_users

Configure the Concierge::Users component.

Parameters (hash):
  - users_storage_dir: (required) Directory for user data storage
  - users_backend: (required) 'database', 'file', or 'yaml'
  - users_fields: (optional) Arrayref of field names
  - users_field_definitions: (optional) Hashref of field definitions

Returns: { success => 1|0, users_config_file => $path, message => "..." }

=cut

sub configure_users {
    my ($self, %config) = @_;

    my $users_setup_config = {};

    $users_setup_config->{storage_dir} = $config{users_storage_dir}
        or return { success => 0, message => "users_storage_dir parameter required" };

    $users_setup_config->{backend} = $config{users_backend} || 'database';

    # Add any Users-specific config options if provided
    $users_setup_config->{fields} = $config{users_fields}
        if $config{users_fields};
    $users_setup_config->{field_definitions} = $config{users_field_definitions}
        if $config{users_field_definitions};

    # Call Users setup() - returns hashref
    my $setup_result = eval { Concierge::Users->setup($users_setup_config) };
    if ($@) {
        return { success => 0, message => "Users setup failed: $@" };
    }

    return $setup_result unless $setup_result->{success};

    # Create Users object for runtime operations
    eval {
        $self->{users} = Concierge::Users->new($setup_result->{config_file});
    };
    if ($@) {
        return { success => 0, message => "Failed to initialize Users object: $@" };
    }

    # Store config file path
    $self->{config}{users_config_file} = $setup_result->{config_file};

    return {
        success => 1,
        users_config_file => $setup_result->{config_file},
        message => "Users component configured successfully"
    };
}

# ===========================================================================
# EVOLVING TODO LIST
# ===========================================================================

=head1 EVOLVING TODO LIST

This section tracks planned development work. Items will be added/removed as
the project evolves.

## Immediate (Current Phase)

=over 4

=item * Complete setup() and load() methods (DONE)

=item * Test setup() and load() with real config files

=item * Add basic examples for setup and operations

=item * Implement sign_in method (Auth + Sessions integration)

=item * Implement session tracking with user_key

=back

## Short Term

=over 4

=item * Authentication flow methods (sign_out, set_password, reset_password, etc.)

=item * Session management methods (update_session, session_status, etc.)

=item * User data methods (register_user, get_user, update_user, delete_user, etc.)

=item * Generator methods (gen_uuid, gen_random_token, etc.)

=back

## Medium Term

=over 4

=item * Component self-disclosure mechanism (Perl introspection tools)

=item * Plugin/replacement component architecture

=item * Advanced configuration validation

=item * Comprehensive integration test suite

=back

## Long Term

=over 4

=item * Cross-component transaction support

=item * Advanced session features (session recovery, audit trails)

=item * Performance optimizations and caching

=item * Complete API documentation with examples

=back

# ===========================================================================
# DOCUMENTATION
# ===========================================================================

=head1 NAME

Concierge - Service layer orchestrator for authentication, sessions, and users

=head1 SYNOPSIS

    use Concierge;

    # Initial setup (one-time)
    my $concierge = Concierge->setup(
        concierge_config_file => '/var/app/concierge.json',
        concierge_session => {
            storage_dir => '/var/app/concierge',
            backend => 'SQLite',
        },
        auth => { auth_file => '/var/app/data/auth.pwd' },
        sessions => { storage_dir => '/var/app/sessions', backend => 'SQLite' },
        users => { storage_dir => '/var/app/users', backend => 'database' },
    );

    # Later, load from saved config
    my $concierge = Concierge->load('/var/app/concierge.json');

    # Use Concierge's API (methods to be implemented)
    # ...

=head1 DESCRIPTION

Concierge is a service layer orchestrator that provides a unified API for
authentication, session management, and user data operations.

=head2 Architecture

Concierge sits between your application and three component modules:

    Your Application
          ↓
    Concierge (service layer)
          ↓
    Concierge::Auth   Concierge::Sessions   Concierge::Users

Concierge maintains its own internal session for tracking and bookkeeping,
separate from any application user sessions.

=head2 Design Philosophy

=over 4

=item * Service Layer Pattern - No method croaks after initialization

=item * Structured Returns - All methods return hashrefs with success/message keys

=item * Event-Loop Safe - Safe for use in event-driven applications

=item * Component Coordination - Handles setup and configuration of components

=item * No Backward Compatibility - Complete rewrite, fresh start

=back

=head1 SETUP AND CONFIGURATION

=head2 Initial Setup

Use the C<setup()> class method for initial configuration:

    my $concierge = Concierge->setup(
        # Where to save Concierge config
        concierge_config_file => '/var/app/concierge.json',

        # Concierge's own session storage (optional, has defaults)
        concierge_session => {
            storage_dir => '/var/app/concierge',
            backend => 'SQLite',
        },

        # Component configurations (all optional)
        auth => {
            auth_file => '/var/app/data/auth.pwd',
        },
        sessions => {
            storage_dir => '/var/app/sessions',
            backend => 'SQLite',
            session_timeout => 3600,
        },
        users => {
            storage_dir => '/var/app/users',
            backend => 'database',
        },
    );

This method:
- Creates all backends and configurations
- Saves complete config to both JSON and YAML
- Returns a fully initialized Concierge object
- DIES if setup fails

=head2 Loading from Config

Use the C<load()> class method for normal operations:

    my $concierge = Concierge->load('/var/app/concierge.json');

This method:
- Loads saved configuration
- Initializes all components
- Creates Concierge's internal session
- DIES if config cannot be loaded

=head1 COMPONENT CONFIGURATION

Each component can be configured independently (if not using setup):

=head2 Auth Configuration

    $concierge->configure_auth(
        auth_file => '/path/to/passwords.pwd'
    );

The password file will be created if it doesn't exist.

=head2 Sessions Configuration (for app user sessions)

    $concierge->configure_sessions(
        sessions_storage_dir => '/path/to/sessions',  # optional
        sessions_backend => 'SQLite',                  # optional, default: SQLite
        session_timeout => 3600,                       # optional, default: 3600
    );

Note: This is separate from Concierge's own internal session.

=head2 Users Configuration

    $concierge->configure_users(
        users_storage_dir => '/path/to/users',         # required
        users_backend => 'database',                   # required: database|file|yaml
        users_fields => [ ... ],                       # optional
        users_field_definitions => { ... },            # optional
    );

=head1 USAGE

This module is under active development. The API will evolve rapidly.

Current functionality:
- Setup and load from configuration
- Component configuration methods
- Concierge internal session management

Planned functionality (see TODO list above):
- Authentication operations
- Session management
- User data operations
- Full API for all component features

=head1 ERROR HANDLING

=over 4

=item * Setup phase: Methods may croak/die if configuration fails

=item * Operations phase: All methods return hashrefs with success/message

=item * After successful initialization: No method will croak

=back

All operational methods return hashrefs:

    {
        success => 1|0,
        message => "descriptive message",
        # ... additional keys specific to each method
    }

=head1 INTERNAL STRUCTURE

The Concierge object stores:

    $self->{auth}               # Auth component instance (if configured)
    $self->{users}              # Users component instance (if configured)
    $self->{sessions}           # Sessions for app users (if configured)
    $self->{concierge_session}  # Concierge's own internal session (always)
    $self->{_concierge_sessions} # Sessions instance for Concierge's session (always)

=head1 SEE ALSO

L<Concierge::Auth>
L<Concierge::Sessions>
L<Concierge::Users>

=head1 AUTHOR

Concierge Development Team

=head1 LICENSE

To be determined.

=head1 ACKNOWLEDGEMENTS

Developed as a complete rewrite of Local::App::Concierge with fresh
architecture and no backward compatibility constraints.

=cut

1;
