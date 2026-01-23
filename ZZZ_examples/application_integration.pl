#!/usr/bin/env perl
use v5.40;
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Auth/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Sessions/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Users/lib";
use Config::Tiny;

use Concierge;

# ============================================================================
# EXAMPLE 4: Application Integration Pattern
# ============================================================================
#
# This script demonstrates a typical application integration pattern where:
# - Configuration is stored in an application config file
# - Concierge is opened on application startup
# - Concierge is used throughout the application lifecycle
#
# This pattern is suitable for web applications, daemons, and long-running
# services.
#
# ============================================================================

print "=" x 70 . "\n";
print "Application Integration Example\n";
print "=" x 70 . "\n\n";

# ----------------------------------------------------------------------------
# Simulated Application Configuration
# ----------------------------------------------------------------------------

my $config_file = "$Bin/storage/app.ini";

# Create a sample config file if it doesn't exist
unless (-f $config_file) {
    print "Creating sample application config...\n";

    my $config = Config::Tiny->new;

    # Concierge section
    $config->{concierge} = {
        desk_location => "$Bin/storage/app_concierge",
    };

    # Application-specific settings
    $config->{app} = {
        name => 'My Application',
        version => '1.0.0',
        debug => 1,
    };

    # Save config
    $config->write($config_file);

    print "  ✓ Config created: $config_file\n\n";

    # Install Concierge for this application
    print "Installing Concierge for application...\n";

    my $install_result = eval {
        Concierge::build_desk(
            "$Bin/storage/app_concierge",
            "$Bin/storage/app_passwords.pwd",
            [ { field_name => 'display_name', type => 'text' } ],
            [ 'preferences', 'theme' ],
        )
    };

    if ($@) {
        die "ERROR: Installation failed: $@\n";
    }

    print "  ✓ Concierge installed\n\n";
}

# ----------------------------------------------------------------------------
# Load Application Configuration
# ----------------------------------------------------------------------------

print "Loading application configuration...\n";

my $app_config = Config::Tiny->read($config_file);

unless ($app_config) {
    die "ERROR: Failed to read config: " . Config::Tiny->errstr . "\n";
}

print "  ✓ Configuration loaded\n";
print "  Application: " . $app_config->{app}{name} . "\n";
print "  Version: " . $app_config->{app}{version} . "\n\n";

# ----------------------------------------------------------------------------
# Application Startup - Open Concierge
# ----------------------------------------------------------------------------

print "Application startup: Opening Concierge...\n";

my $desk_location = $app_config->{concierge}{desk_location};

unless ($desk_location) {
    die "ERROR: Concierge desk_location not found in config\n";
}

my $open_result = eval {
    Concierge->open_desk($desk_location)
};

if ($@) {
    die "ERROR: Failed to open Concierge: $@\n";
}

unless ($open_result->{success}) {
    die "ERROR: Failed to open Concierge: " . $open_result->{message} . "\n";
}

my $concierge = $open_result->{concierge};

print "  ✓ Concierge ready\n\n";

# ----------------------------------------------------------------------------
# Application: Use Concierge
# ----------------------------------------------------------------------------

print "=" x 70 . "\n";
print "Application Running\n";
print "=" x 70 . "\n\n";

# Simulate application requests
my @requests = (
    {
        name => 'User Registration',
        action => sub {
            my $username = 'bob';
            my $password = 'bob_password_456';

            my $result = $concierge->{auth}->create_user($username, $password);

            if ($result->{success}) {
                my $user_id = $result->{user_id};
                $concierge->{users}->add_data(
                    $user_id,
                    display_name => 'Bob Builder',
                    email => 'bob@example.com',
                );
                return "Created user $username (ID: $user_id)";
            }

            return "Failed: " . $result->{message};
        },
    },
    {
        name => 'User Login',
        action => sub {
            my $username = 'bob';
            my $password = 'bob_password_456';

            my $result = $concierge->{auth}->authenticate_user($username, $password);

            if ($result->{success}) {
                # Create session
                my $session_result = $concierge->{sessions}->new_session(
                    user_id => $result->{user_id}
                );

                if ($session_result->{success}) {
                    my $session = $session_result->{session};
                    return "User $username logged in, session: " . $session->session_id;
                }
            }

            return "Login failed: " . $result->{message};
        },
    },
    {
        name => 'Get User Info',
        action => sub {
            my $username = 'bob';

            # Get user by username
            my $result = $concierge->{users}->find_user(username => $username);

            if ($result->{success}) {
                my $user = $result->{user};
                return "User: " . ($user->{display_name} || $username) .
                       " <" . ($user->{email} || 'no email') . ">";
            }

            return "User not found: " . $result->{message};
        },
    },
);

# Process each request
for my $request (@requests) {
    print "Request: " . $request->{name} . "\n";

    my $result = eval {
        $request->{action}()
    };

    if ($@) {
        print "  ERROR: $@\n";
    } else {
        print "  Result: $result\n";
    }

    print "\n";
}

# ----------------------------------------------------------------------------
# Application Shutdown
# ----------------------------------------------------------------------------

print "=" x 70 . "\n";
print "Application Shutdown\n";
print "=" x 70 . "\n\n";

print "Concierge object goes out of scope...\n";
print "All components will be cleaned up automatically.\n\n";

print "Application configuration preserved in: $config_file\n";
print "Concierge data preserved in: $desk_location\n\n";

print "Next application start will open the same Concierge instance.\n\n";
