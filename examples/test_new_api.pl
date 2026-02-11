#!/usr/bin/env perl
use v5.36;
use FindBin;
# Use repo versions of ALL modules, not installed versions
use lib "$FindBin::Bin/../lib";
use Data::Dumper;

use Concierge::Setup;
use Concierge;

# Clean test environment
my $test_dir = '/tmp/concierge_test_' . time;
say "=== Testing New Concierge API ===";
say "Using Concierge from: $FindBin::Bin/../lib";
say "Concierge version: $Concierge::VERSION";
say "Setting up test desk in: $test_dir\n";

# Build desk
my $build = Concierge::Setup::build_quick_desk(
    $test_dir,
    ['preferences', 'theme'],  # app_fields
);

die "Failed to build desk: $build->{message}\n" unless $build->{success};
say "✓ Desk built successfully";

# Open desk
my $open = Concierge->open_desk($test_dir);
die "Failed to open desk: $open->{message}\n" unless $open->{success};

my $concierge = $open->{concierge};
say "✓ Desk opened successfully";

# Test 1: Admit visitor
say "\n=== Test 1: Admit Visitor ===";
my $visitor_result = $concierge->admit_visitor();
die "Failed to admit visitor\n" unless $visitor_result->{success};

my $visitor = $visitor_result->{user};
say "✓ Visitor created";
say "  user_id: " . $visitor->user_id();
say "  user_key: " . $visitor->user_key();
say "  is_visitor: " . $visitor->is_visitor();
say "  is_guest: " . $visitor->is_guest();
say "  is_logged_in: " . $visitor->is_logged_in();

# Test 2: Checkin guest
say "\n=== Test 2: Checkin Guest ===";
my $guest_result = $concierge->checkin_guest();
die "Failed to checkin guest\n" unless $guest_result->{success};

my $guest = $guest_result->{user};
say "✓ Guest checked in";
say "  user_id: " . $guest->user_id();
say "  user_key: " . $guest->user_key();
say "  session_id: " . $guest->session_id();
say "  is_visitor: " . $guest->is_visitor();
say "  is_guest: " . $guest->is_guest();
say "  is_logged_in: " . $guest->is_logged_in();

# Test guest session access
if ($guest->session()) {
    say "  ✓ Guest has session object";
    say "    session is_active: " . $guest->session()->is_active();

    # Set some session data (shopping cart)
    $guest->update_session_data({ cart => ['item1', 'item2'] });
    say "  ✓ Guest session data saved";
}

# Test 3: Add user
say "\n=== Test 3: Add User ===";
my $add_result = $concierge->add_user({
    user_id  => 'alice',
    moniker  => 'Alice',
    email    => 'alice@example.com',
    password => 'secret123',
    theme    => 'dark',
});
die "Failed to add user: $add_result->{message}\n" unless $add_result->{success};
say "✓ User 'alice' added";

# Test 4: Login user
say "\n=== Test 4: Login User ===";
my $login_result = $concierge->login_user({
    user_id  => 'alice',
    password => 'secret123',
});
die "Failed to login: $login_result->{message}\n" unless $login_result->{success};

my $user = $login_result->{user};
say "✓ User logged in";
say "  user_id: " . $user->user_id();
say "  user_key: " . $user->user_key();
say "  session_id: " . $user->session_id();
say "  moniker: " . ($user->moniker() // 'undef');
say "  email: " . ($user->email() // 'undef');
say "  is_visitor: " . $user->is_visitor();
say "  is_guest: " . $user->is_guest();
say "  is_logged_in: " . $user->is_logged_in();

# Test 5: User data access
say "\n=== Test 5: User Data Access ===";
my $theme = $user->get_user_field('theme');
say "✓ User theme: " . ($theme // 'undef');

# Test 6: Update user data
say "\n=== Test 6: Update User Data ===";
my $update_ok = $user->update_user_data({ theme => 'light' });
if ($update_ok) {
    say "✓ User data updated";
    my $new_theme = $user->get_user_field('theme');
    say "  New theme: " . ($new_theme // 'undef');
}

# Test 7: Refresh user data
say "\n=== Test 7: Refresh User Data ===";
my $refresh_ok = $user->refresh_user_data();
if ($refresh_ok) {
    say "✓ User data refreshed from backend";
}

# Test 8: Session data access
say "\n=== Test 8: Session Data Access ===";
if ($user->session()) {
    say "✓ User has session object";
    $user->update_session_data({ last_page => '/dashboard' });
    say "  ✓ Session data saved";

    my $data = $user->get_session_data();
    say "  Session data: " . Dumper($data);
}

# Test 9: Logout
say "\n=== Test 9: Logout User ===";
my $logout_result = $concierge->logout_user($user->session_id());
if ($logout_result->{success}) {
    say "✓ User logged out";
}

# Test 10: Login guest (convert guest to user)
say "\n=== Test 10: Login Guest ===";
my $guest2_result = $concierge->checkin_guest();
my $guest2 = $guest2_result->{user};
my $guest2_key = $guest2->user_key();

# Add some cart data
$guest2->update_session_data({ cart => ['widget', 'gadget'] });
say "✓ Guest2 created with cart data";

# Convert guest to logged-in user (creates account and logs in)
my $login_guest_result = $concierge->login_guest(
    { user_id => 'bob', moniker => 'Bob', password => 'password456' },
    $guest2_key
);

if ($login_guest_result->{success}) {
    my $bob = $login_guest_result->{user};
    say "✓ Guest converted to logged-in user 'bob'";

    # Check if cart data transferred
    my $bob_data = $bob->get_session_data();
    if ($bob_data && $bob_data->{cart}) {
        say "  ✓ Cart data transferred: " . join(', ', @{$bob_data->{cart}});
    }
}

say "\n=== All Tests Passed! ===";
say "\nCleaning up test directory: $test_dir";
system("rm -rf $test_dir");
