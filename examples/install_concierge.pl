#!/usr/bin/env perl
use v5.36;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Auth/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Sessions/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Users/lib";

use Concierge;

# ============================================================================
# EXAMPLE 1: Installing a New Concierge (First-Time Setup)
# ============================================================================
#
# This script demonstrates how to use the build_desk() method to install
# a new Concierge instance.
#
# The build_desk() method:
# - Creates all necessary components (Auth, Sessions, Users)
# - Stores the complete configuration in Concierge's internal session
# - Returns the desk location for future use with open_desk()
#
# This is a ONE-TIME installation. After installation, use open_desk()
# to instantiate the Concierge in subsequent runs.
#
# ============================================================================

print "=" x 70 . "\n";
print "Concierge Installation Example\n";
print "=" x 70 . "\n\n";

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

# Directory where Concierge will store data
# This will contain:
#   - Session data (SQLite database in ./data/sessions/)
#   - User database (SQLite database in ./data/users/)
#   - User configuration file
my $storage_dir = "$Bin/storage/concierge_desk";

# Authentication file containing password hashes
# TODO: Put in $storage_dir if only filename provided
my $auth_file = "$Bin/storage/passwords.pwd";

# Application-specific fields to add to user records
# These fields will be available in addition to standard user fields
my $app_fields = [
    {
        field_name => 'display_name',
        type       => 'text',
        indexed    => 1,
    },
    {
        field_name => 'bio',
        type       => 'text',
    },
    {
        field_name => 'website',
        type       => 'text',
    },
];

# Fields allowed in user session data (for use with $session->set_data/get_data)
# This provides a whitelist of what data can be stored in sessions
my $user_session_fields = [
    'preferences',
    'theme',
    'language',
    'last_seen',
];

# ----------------------------------------------------------------------------
# Installation
# ----------------------------------------------------------------------------

print "Installing Concierge...\n";
print "  Storage directory: $storage_dir\n";
print "  Auth file:         $auth_file\n";
print "  App fields:        " . scalar(@$app_fields) . " custom fields\n";
print "  Session fields:    " . scalar(@$user_session_fields) . " fields\n\n";

# Build the desk (one-time installation)
my $installation_result = eval {
    Concierge::build_desk(
        $storage_dir,
        $auth_file,
        $app_fields,
        $user_session_fields
    )
};

if ($@) {
    die "ERROR: Installation failed: $@\n";
}

# ----------------------------------------------------------------------------
# Verify Installation
# ----------------------------------------------------------------------------

unless ($installation_result->{success}) {
    die "ERROR: Installation reported failure: " .
        ($installation_result->{message} || 'Unknown error') . "\n";
}

print "✓ Installation successful!\n";
print "  Message: " . $installation_result->{message} . "\n";
print "  Desk location: " . $installation_result->{desk} . "\n\n";

# Store the desk location for future use
my $desk_location = $installation_result->{desk};

print "=" x 70 . "\n";
print "Installation Complete!\n";
print "=" x 70 . "\n\n";

print "Next steps:\n";
print "  1. Save the desk location: $desk_location\n";
print "  2. Use Concierge->open_desk('$desk_location') in your application\n";
print "  3. See open_concierge.pl for an example\n\n";

# Optional: Test opening the desk immediately
print "Would you like to test opening the desk immediately? (y/n): ";
my $response = <STDIN>;
chomp $response;

if ($response =~ /^y/i) {
    print "\nTesting open_desk()...\n";

    my $open_result = eval {
        Concierge->open_desk($desk_location)
    };

    if ($@) {
        die "ERROR: Failed to open desk: $@\n";
    }

    if ($open_result->{success}) {
        print "✓ Desk opened successfully!\n";
        print "  Message: " . $open_result->{message} . "\n";

        my $concierge = $open_result->{concierge};
        print "  Concierge object: " . ref($concierge) . "\n";
        print "  Has Auth: " . ($concierge->{auth} ? 'Yes' : 'No') . "\n";
        print "  Has Users: " . ($concierge->{users} ? 'Yes' : 'No') . "\n";
        print "  Has Sessions: " . ($concierge->{sessions} ? 'Yes' : 'No') . "\n";
    } else {
        print "✗ Failed to open desk: " . $open_result->{message} . "\n";
    }
}

print "\nDone!\n";
