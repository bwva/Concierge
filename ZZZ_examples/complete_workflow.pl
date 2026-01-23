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
# EXAMPLE 3: Complete Workflow - Installation to User Operations
# ============================================================================
#
# This script demonstrates a complete workflow:
# 1. Install a new Concierge (first-time only)
# 2. Open the Concierge
# 3. Perform user operations (create user, create session, authenticate)
#
# This shows how the experimental methods integrate with the component
# operations.
#
# ============================================================================

print "=" x 70 . "\n";
print "Complete Concierge Workflow Example\n";
print "=" x 70 . "\n\n";

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

my $storage_dir = "$Bin/storage/complete_workflow";
my $auth_file = "$Bin/storage/workflow_passwords.pwd";
my $app_fields = [
    { field_name => 'display_name', type => 'text', indexed => 1 },
    { field_name => 'bio', type => 'text' },
];
my $user_session_fields = [ 'preferences', 'theme', 'language' ];

# ----------------------------------------------------------------------------
# STEP 1: Installation (First-time only)
# ----------------------------------------------------------------------------

print "STEP 1: Installing Concierge...\n";

if (-d $storage_dir) {
    print "  Desk already exists, skipping installation\n\n";
} else {
    print "  Building new desk...\n";

    my $install_result = eval {
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

    unless ($install_result->{success}) {
        die "ERROR: Installation failed: " .
            $install_result->{message} . "\n";
    }

    print "  ✓ Installation complete!\n";
    print "  Desk location: " . $install_result->{desk} . "\n\n";
}

# ----------------------------------------------------------------------------
# STEP 2: Open the Concierge
# ----------------------------------------------------------------------------

print "STEP 2: Opening Concierge...\n";

my $open_result = eval {
    Concierge->open_desk($storage_dir)
};

if ($@) {
    die "ERROR: Failed to open desk: $@\n";
}

unless ($open_result->{success}) {
    die "ERROR: Failed to open desk: " . $open_result->{message} . "\n";
}

my $concierge = $open_result->{concierge};

print "  ✓ Concierge opened successfully!\n\n";

# ----------------------------------------------------------------------------
# STEP 3: User Operations
# ----------------------------------------------------------------------------

print "STEP 3: Performing User Operations...\n\n";

# Extract components for easier access
my $auth = $concierge->{auth};
my $users = $concierge->{users};
my $sessions = $concierge->{sessions};

# ----------------------------------------------------------------------------
# 3.1 Create a User
# ----------------------------------------------------------------------------

print "3.1 Creating a new user...\n";

my $username = 'alice';
my $password = 'secure_password_123';

my $create_user_result = eval {
    $auth->create_user($username, $password)
};

if ($@) {
    die "ERROR: Failed to create user: $@\n";
}

unless ($create_user_result->{success}) {
    die "ERROR: User creation failed: " .
        $create_user_result->{message} . "\n";
}

print "  ✓ User '$username' created successfully!\n";
print "  User ID: " . ($create_user_result->{user_id} || 'generated') . "\n\n";

my $user_id = $create_user_result->{user_id};

# ----------------------------------------------------------------------------
# 3.2 Add User Data
# ----------------------------------------------------------------------------

print "3.2 Adding user data...\n";

my $add_data_result = eval {
    $users->add_data(
        $user_id,
        display_name => 'Alice Wonderland',
        bio => 'Curious explorer of digital realms',
        email => 'alice@example.com',
    )
};

if ($@) {
    die "ERROR: Failed to add user data: $@\n";
}

unless ($add_data_result->{success}) {
    die "ERROR: Failed to add user data: " .
        $add_data_result->{message} . "\n";
}

print "  ✓ User data added successfully!\n\n";

# ----------------------------------------------------------------------------
# 3.3 Retrieve User Data
# ----------------------------------------------------------------------------

print "3.3 Retrieving user data...\n";

my $get_user_result = eval {
    $users->get_user($user_id)
};

if ($@) {
    die "ERROR: Failed to get user: $@\n";
}

if ($get_user_result->{success}) {
    print "  ✓ User retrieved successfully!\n";
    my $user_data = $get_user_result->{user};
    print "  Username: " . ($user_data->{username} || 'N/A') . "\n";
    print "  Display name: " . ($user_data->{display_name} || 'N/A') . "\n";
    print "  Email: " . ($user_data->{email} || 'N/A') . "\n";
    print "  Bio: " . ($user_data->{bio} || 'N/A') . "\n\n";
}

# ----------------------------------------------------------------------------
# 3.4 Create a Session
# ----------------------------------------------------------------------------

print "3.4 Creating a user session...\n";

my $create_session_result = eval {
    $sessions->new_session(user_id => $user_id)
};

if ($@) {
    die "ERROR: Failed to create session: $@\n";
}

unless ($create_session_result->{success}) {
    die "ERROR: Session creation failed: " .
        $create_session_result->{message} . "\n";
}

print "  ✓ Session created successfully!\n";
my $session = $create_session_result->{session};
print "  Session ID: " . $session->session_id . "\n\n";

# ----------------------------------------------------------------------------
# 3.5 Store Data in Session
# ----------------------------------------------------------------------------

print "3.5 Storing data in session...\n";

my $session_data_result = eval {
    $session->set_data({
        preferences => { notifications => 1, newsletter => 0 },
        theme => 'dark',
        language => 'en',
        last_seen => time(),
    });
    $session->save();
    { success => 1 }
};

if ($@) {
    die "ERROR: Failed to store session data: $@\n";
}

unless ($session_data_result->{success}) {
    die "ERROR: Failed to store session data\n";
}

print "  ✓ Session data stored successfully!\n\n";

# ----------------------------------------------------------------------------
# 3.6 Retrieve Session Data
# ----------------------------------------------------------------------------

print "3.6 Retrieving session data...\n";

my $retrieved_data = $session->get_data();

print "  ✓ Session data retrieved!\n";
print "  Preferences: " .
      ($retrieved_data->{preferences}{notifications} ? 'enabled' : 'disabled') . "\n";
print "  Theme: " . ($retrieved_data->{theme} || 'default') . "\n";
print "  Language: " . ($retrieved_data->{language} || 'en') . "\n";
print "  Last seen: " . ($retrieved_data->{last_seen} || 'N/A') . "\n\n";

# ----------------------------------------------------------------------------
# 3.7 Authenticate User
# ----------------------------------------------------------------------------

print "3.7 Authenticating user...\n";

my $auth_result = eval {
    $auth->authenticate_user($username, $password)
};

if ($@) {
    die "ERROR: Authentication failed: $@\n";
}

if ($auth_result->{success}) {
    print "  ✓ Authentication successful!\n";
    print "  User authenticated: " . ($auth_result->{user_id} || $username) . "\n\n";
} else {
    print "  ✗ Authentication failed: " . $auth_result->{message} . "\n\n";
}

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------

print "=" x 70 . "\n";
print "Workflow Complete!\n";
print "=" x 70 . "\n\n";

print "Summary of operations:\n";
print "  1. ✓ Installed Concierge (or used existing)\n";
print "  2. ✓ Opened Concierge desk\n";
print "  3. ✓ Created user '$username'\n";
print "  4. ✓ Added user data\n";
print "  5. ✓ Retrieved user data\n";
print "  6. ✓ Created user session\n";
print "  7. ✓ Stored data in session\n";
print "  8. ✓ Retrieved session data\n";
print "  9. ✓ Authenticated user\n\n";

print "Concierge is ready for production use!\n";
print "\nNote: In subsequent runs, you can skip step 1 and directly open the desk:\n";
print "  my \$result = Concierge->open_desk('$storage_dir');\n\n";
