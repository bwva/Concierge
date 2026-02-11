#!/usr/bin/env perl
use v5.40;
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Auth/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Sessions/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Users/lib";
use Data::Dumper;

use Concierge;

# ============================================================================
# EXAMPLE 2: Opening an Existing Concierge
# ============================================================================
#
# This script demonstrates how to use the open_desk() method to instantiate
# a Concierge that was previously installed using build_desk().
#
# The open_desk() method:
# - Reads the configuration from Concierge's internal session
# - Instantiates all components (Auth, Sessions, Users)
# - Returns a fully operational Concierge object
#
# This is the NORMAL method for instantiating Concierge in your application
# after the initial installation.
#
# ============================================================================

print "=" x 70 . "\n";
print "Concierge Open Desk Example\n";
print "=" x 70 . "\n\n";

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

# The desk location from the initial installation
# In a real application, this might come from:
#   - A configuration file
#   - Environment variables
#   - Command-line arguments
#   - Application config
my $desk_location = $ENV{CONCIERGE_DESK} || "$Bin/storage/concierge_desk";

print "Opening Concierge desk...\n";
print "  Desk location: $desk_location\n\n";

# ----------------------------------------------------------------------------
# Verify Desk Exists
# ----------------------------------------------------------------------------

unless (-d $desk_location) {
    die "ERROR: Desk location does not exist: $desk_location\n\n" .
        "Please run install_concierge.pl first to create the desk.\n";
}

# ----------------------------------------------------------------------------
# Open the Desk
# ----------------------------------------------------------------------------

my $open_result = eval {
    Concierge->open_desk($desk_location)
};

if ($@) {
    die "ERROR: Failed to open desk: $@\n";
}

# ----------------------------------------------------------------------------
# Verify Success
# ----------------------------------------------------------------------------

unless ($open_result->{success}) {
    die "ERROR: Failed to open desk: " .
        ($open_result->{message} || 'Unknown error') . "\n";
}

print "✓ Desk opened successfully!\n";
print "  Message: " . $open_result->{message} . "\n\n";

# ----------------------------------------------------------------------------
# Access the Concierge Object
# ----------------------------------------------------------------------------

my $concierge = $open_result->{concierge};

print "Concierge Object Details:\n";
print "  Type: " . ref($concierge) . "\n";
print "  Has Auth component:     " . ($concierge->{auth} ? 'Yes' : 'No') . "\n";
print "  Has Users component:    " . ($concierge->{users} ? 'Yes' : 'No') . "\n";
print "  Has Sessions component: " . ($concierge->{sessions} ? 'Yes' : 'No') . "\n";
print "  Has Concierge session:  " .
      ($concierge->{concierge_session} ? 'Yes' : 'No') . "\n\n";

# ----------------------------------------------------------------------------
# Inspect Concierge's Internal Session
# ----------------------------------------------------------------------------

print "Concierge Session Data:\n";
my $session_data = $concierge->{concierge_session}->get_data();

if ($session_data->{concierge_config}) {
    my $config = $session_data->{concierge_config};
    print "  Storage dir:    " . ($config->{storage_dir} || 'N/A') . "\n";
    print "  Auth file:      " . ($config->{auth_file} || 'N/A') . "\n";
    print "  Users config:   " . ($config->{users_config_file} || 'N/A') . "\n";
    print "  Session fields: " .
          ($config->{user_session_fields} ?
           scalar(@{$config->{user_session_fields}}) . " defined" :
           'None defined') . "\n";
}
print "\n";

# ----------------------------------------------------------------------------
# Demonstrate Component Access
# ----------------------------------------------------------------------------

print "Component Access Examples:\n\n";

# Auth component
if ($concierge->{auth}) {
    print "1. Auth Component:\n";
    print "   Type: " . ref($concierge->{auth}) . "\n";
    # Can now call Auth methods, e.g.:
    # my $result = $concierge->{auth}->create_user($username, $password);
    print "   Ready for authentication operations\n\n";
}

# Users component
if ($concierge->{users}) {
    print "2. Users Component:\n";
    print "   Type: " . ref($concierge->{users}) . "\n";
    print "   Config file: " . $concierge->{users}{config_file} . "\n";
    # Can now call Users methods, e.g.:
    # my $user = $concierge->{users}->get_user($user_id);
    print "   Ready for user data operations\n\n";
}

# Sessions component
if ($concierge->{sessions}) {
    print "3. Sessions Component:\n";
    print "   Type: " . ref($concierge->{sessions}) . "\n";
    print "   Storage dir: " . $concierge->{sessions}{storage_dir} . "\n";
    print "   Backend: " . $concierge->{sessions}{backend} . "\n";
    # Can now call Sessions methods, e.g.:
    # my $session = $concierge->{sessions}->new_session(user_id => $user_id);
    print "   Ready for session management\n\n";
}

print "=" x 70 . "\n";
print "Concierge is Ready for Use!\n";
print "=" x 70 . "\n\n";

print "You can now use the Concierge object to:\n";
print "  - Create and authenticate users\n";
print "  - Manage user sessions\n";
print "  - Store and retrieve user data\n\n";

print "Example usage:\n";
print "  my \$auth = \$concierge->{auth};\n";
print "  my \$users = \$concierge->{users};\n";
print "  my \$sessions = \$concierge->{sessions};\n\n";
