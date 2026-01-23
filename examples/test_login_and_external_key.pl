#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

# Test script for login_user() and external_key functionality

use lib '/Volumes/Main/Development/Repositories/Concierge/lib';
use lib '/Volumes/Main/Development/Repositories/Concierge-Auth/lib';
use lib '/Volumes/Main/Development/Repositories/Concierge-Sessions/lib';
use lib '/Volumes/Main/Development/Repositories/Concierge-Users/lib';

use Concierge;
use File::Path qw(make_path remove_tree);
use File::Temp qw(tempdir);

# Test configuration
my $test_storage_dir = tempdir(CLEANUP => 1);
my $test_auth_file = "$test_storage_dir/test_auth.pwd";
my $test_user = 'testuser' . int(rand(10000));  # alphanumeric only
my $test_password = 'TestPassword123!';

say "=" x 70;
say "Testing Concierge login_user() and external_key functionality";
say "=" x 70;
say "";

# Step 1: Build the desk
say "Step 1: Building concierge desk...";
my $build_result = Concierge::build_desk(
    $test_storage_dir,
    $test_auth_file,
    ['app_field1', 'app_field2'],  # app_fields
    ['session_field1', 'session_field2'],  # user_session_fields
);

unless ($build_result->{success}) {
    die "Failed to build desk: $build_result->{message}";
}
say "✓ Desk built successfully";
say "";

# Step 2: Open the desk
say "Step 2: Opening concierge desk...";
my $open_result = Concierge::open_desk('Concierge', $test_storage_dir);
unless ($open_result->{success}) {
    die "Failed to open desk: $open_result->{message}";
}
my $concierge = $open_result->{concierge};
say "✓ Desk opened successfully";
say "";

# Step 3: Register a test user
say "Step 3: Registering test user '$test_user'...";
my $users = $concierge->{users};
my $auth = $concierge->{auth};

# Create user_id
my $user_id = 'user_' . int(rand(1000000));

# Register user
my $register_result = $users->register_user({
    user_id  => $user_id,
    moniker  => $test_user,  # display name
    email    => 'test@example.com',
});

unless ($register_result->{success}) {
    die "Failed to register user: $register_result->{message}";
}
say "✓ User registered with user_id: $user_id";

# Set password
my $setpwd_result = $auth->setPwd($user_id, $test_password);
unless ($setpwd_result) {
    die "Failed to set password";
}
say "✓ Password set for user";
say "";

# Step 4: Test login_user()
say "Step 4: Testing login_user()...";
my $login_result = $concierge->login_user($user_id, $test_password);

unless ($login_result->{success}) {
    die "Login failed: $login_result->{message}";
}
say "✓ Login successful!";
say "  - external_key: $login_result->{external_key}";
say "  - user_id: $login_result->{user_id}";
say "  - session_id: $login_result->{session_id}";

# Verify external_key format (should be 13 characters)
my $external_key = $login_result->{external_key};
if (length($external_key) != 13) {
    die "external_key has wrong length: " . length($external_key) . " (expected 13)";
}
say "  ✓ external_key has correct length (13 characters)";
say "";

# Step 5: Test duplicate login (creates new session, deletes old one)
say "Step 5: Testing duplicate login (creates new session)...";
my $login2_result = $concierge->login_user($user_id, $test_password);

unless ($login2_result->{success}) {
    die "Duplicate login failed: $login2_result->{message}";
}

# Backend enforces one-session-per-user by deleting old session
# So we get a new external_key and session_id
my $new_external_key = $login2_result->{external_key};
my $new_session_id = $login2_result->{session_id};

say "✓ Duplicate login creates new session";
say "  - New external_key: $new_external_key";
say "  - New session_id: $new_session_id";

# Verify old session no longer exists
my $old_session_check = $concierge->{sessions}->get_session($login_result->{session_id});
if ($old_session_check->{success}) {
    die "Old session should have been deleted!";
}
say "  ✓ Old session correctly deleted";

# Update for following tests
$external_key = $new_external_key;
say "";

# Step 6: Test get_user_for_key()
say "Step 6: Testing get_user_for_key()...";
my $user_lookup = $concierge->get_user_for_key($external_key);

unless ($user_lookup->{success}) {
    die "get_user_for_key failed: $user_lookup->{message}";
}
if ($user_lookup->{user_id} != $user_id) {
    die "user_id mismatch: got $user_lookup->{user_id}, expected $user_id";
}
say "✓ get_user_for_key() returned correct user_id: $user_lookup->{user_id}";
say "";

# Step 7: Test get_session_for_key()
say "Step 7: Testing get_session_for_key()...";
my $session_lookup = $concierge->get_session_for_key($external_key);

unless ($session_lookup->{success}) {
    die "get_session_for_key failed: $session_lookup->{message}";
}
if ($session_lookup->{session_id} ne $new_session_id) {
    die "session_id mismatch";
}
say "✓ get_session_for_key() returned correct session_id: $session_lookup->{session_id}";
say "";

# Step 8: Test invalid external_key
say "Step 8: Testing invalid external_key...";
my $invalid_lookup = $concierge->get_user_for_key('invalid_key_123');
if ($invalid_lookup->{success}) {
    die "Invalid external_key should fail!";
}
say "✓ Invalid external_key correctly rejected: $invalid_lookup->{message}";
say "";

# Step 9: Test login with wrong password
say "Step 9: Testing login with wrong password...";
my $wrong_login = $concierge->login_user($user_id, 'WrongPassword123!');
if ($wrong_login->{success}) {
    die "Login with wrong password should fail!";
}
say "✓ Wrong password correctly rejected: $wrong_login->{message}";
say "";

# Step 10: Test login with non-existent user
say "Step 10: Testing login with non-existent user...";
my $nonexist_login = $concierge->login_user('nonexistent_user', $test_password);
if ($nonexist_login->{success}) {
    die "Login with non-existent user should fail!";
}
say "✓ Non-existent user correctly rejected: $nonexist_login->{message}";
say "";

# Step 11: Verify external_key is stored in session metadata (not data)
say "Step 11: Verifying external_key is in session metadata...";
my $session_result = $concierge->{sessions}->get_session($new_session_id);
unless ($session_result->{success}) {
    die "Failed to retrieve session: $session_result->{message}";
}
my $session = $session_result->{session};

# Check external_key accessor
my $retrieved_ext_key = $session->external_key();
if ($retrieved_ext_key ne $external_key) {
    die "external_key from session accessor doesn't match!";
}
say "✓ external_key correctly accessible via session->external_key()";

# Check that external_key is NOT in the mutable data area
my $session_data = $session->get_data()->{value};
if (exists $session_data->{external_key}) {
    die "external_key should NOT be in mutable session data!";
}
say "✓ external_key is NOT in mutable session data (correctly separated)";
say "";

# Step 12: Test that external_key persists across concierge restart
say "Step 12: Testing external_key persistence across concierge restart...";
my $current_session_id = $new_session_id;  # Save for verification after restart

# Close and reopen concierge
undef $concierge;
my $reopen_result = Concierge::open_desk('Concierge', $test_storage_dir);
unless ($reopen_result->{success}) {
    die "Failed to reopen desk: $reopen_result->{message}";
}
$concierge = $reopen_result->{concierge};

# Try to lookup the external_key again
my $persist_lookup = $concierge->get_user_for_key($external_key);
unless ($persist_lookup->{success}) {
    die "external_key lookup failed after restart: $persist_lookup->{message}";
}
if ($persist_lookup->{user_id} ne $user_id) {
    die "user_id changed after restart!";
}

# Verify session_id also persists
my $persist_session = $concierge->get_session_for_key($external_key);
unless ($persist_session->{success}) {
    die "session lookup failed after restart";
}
if ($persist_session->{session_id} ne $current_session_id) {
    die "session_id changed after restart!";
}

say "✓ external_key mapping persists across concierge restart";
say "  - user_id: $persist_lookup->{user_id}";
say "  - session_id: $persist_session->{session_id}";
say "";

# Step 13: Test user_data_to_session() option
say "Step 13: Testing user_data_to_session() with login...";
# First, let's logout the current session
$concierge->{sessions}->delete_session($current_session_id);

# Now login with include_user_data option
my $login_with_data = $concierge->login_user(
    $user_id,
    $test_password,
    { include_user_data => 1 }
);

unless ($login_with_data->{success}) {
    die "Login with user data failed: $login_with_data->{message}";
}
say "✓ Login with include_user_data succeeded";

# Verify user data is in session
my $data_session_result = $concierge->{sessions}->get_session($login_with_data->{session_id});
my $data_session = $data_session_result->{session};
my $session_data_with_user = $data_session->get_data()->{value};

if (!exists $session_data_with_user->{moniker} || $session_data_with_user->{moniker} ne $test_user) {
    die "User data not properly added to session!";
}
say "✓ User database data added to session";
say "  - Moniker in session: $session_data_with_user->{moniker}";
say "  - Email in session: $session_data_with_user->{email}";
say "";

say "=" x 70;
say "All tests passed! ✓";
say "=" x 70;
say "";
say "Summary:";
say "  - external_key generated and stored correctly (13 characters)";
say "  - external_key stored in session metadata, not mutable data";
say "  - Concierge maintains external_key => {user_id, session_id} mapping";
say "  - Duplicate login creates new session (one-session-per-user enforced)";
say "  - Lookup helpers work correctly";
say "  - Invalid keys/rejected logins handled properly";
say "  - Mapping persists across concierge restart";
say "  - User data can be added to session on login";
say "";
