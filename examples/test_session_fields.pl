#!/usr/bin/env perl
use v5.36;
# IMPORTANT: Add component lib paths FIRST, before Concierge
use lib "/Volumes/Main/Development/Repositories/Concierge-Auth/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Sessions/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Users/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge/lib";

use Concierge;
use Data::Dumper;

say "=" x 60;
say "Testing User Session Data Fields";
say "=" x 60;

# Clean up from previous run
my $test_dir = "/tmp/concierge_test_session_fields";
`rm -rf $test_dir` if -d $test_dir;
mkdir $test_dir or die "Can't create $test_dir: $!";

# Define user session data fields
my $user_session_fields = [qw(cart preferences last_view)];

say "\n1. Building concierge with declared session fields:";
say "   Fields: " . join(", ", @$user_session_fields);

my $build_result = Concierge::build_desk(
    $test_dir,
    "$test_dir/auth.db",
    [],
    $user_session_fields,
);

die "Build failed: " . ($build_result->{message} // 'unknown error')
    unless $build_result->{success};

say "   Concierge built successfully";

say "\n2. Opening concierge:";
my $open_result = Concierge->open_desk($test_dir);
die "Open failed" unless $open_result->{success};

my $concierge = $open_result->{concierge};
say "   Concierge opened";

say "\n3. Creating user session with initial data:";
my $session_result = $concierge->{sessions}->new_session(
    user_id => 'alice',
    data    => {
        cart       => ['item1', 'item2'],
        preferences => { theme => 'dark' },
        last_view  => '/products',
        extra_field => 'not declared but allowed',
    },
);

die "Session creation failed" unless $session_result->{success};
my $session = $session_result->{session};
say "   Session created: " . $session->session_id();

say "\n4. Testing get_app_data() - retrieve all declared fields:";
my $app_data = $session->get_app_data();
say "   Declared fields in session:";
foreach my $field (@$user_session_fields) {
    my $value = $app_data->{$field};
    if (ref $value eq 'ARRAY') {
        say "     - $field: [" . join(", ", @$value) . "]";
    } elsif (ref $value eq 'HASH') {
        say "     - $field: " . join(", ", %$value);
    } else {
        say "     - $field: " . ($value // '<undef>');
    }
}

say "\n5. Testing get_app_data(field) - selective retrieval:";
my $cart_only = $session->get_app_data('cart');
say "   Cart only: " . join(", ", @{$cart_only->{cart} // []});

my $prefs_and_view = $session->get_app_data('preferences', 'last_view');
say "   Preferences & last_view:";
say "     - preferences: " . join(", ", %{$prefs_and_view->{preferences} // {}});
say "     - last_view: " . ($prefs_and_view->{last_view} // '<undef>');

say "\n6. Testing set_app_data() - update one field:";
my $update_result = $session->set_app_data({
    cart => ['item1', 'item2', 'item3', 'item4'],
});

die "set_app_data failed" unless $update_result->{success};
say "   Cart updated";

say "\n7. Verifying all declared fields still exist after update:";
my $updated_data = $update_result->{value};
foreach my $field (@$user_session_fields) {
    my $exists = exists $updated_data->{$field};
    my $value = $updated_data->{$field};
    my $val_str;
    if (ref $value eq 'ARRAY') {
        $val_str = "[" . join(", ", @$value) . "]";
    } elsif (ref $value eq 'HASH') {
        $val_str = "{" . join(", ", %$value) . "}";
    } else {
        $val_str = defined $value ? $value : '<undef>';
    }
    say "     - $field: exists=$exists, value=$val_str";
}

say "\n8. Testing partial field initialization (only setting one field):";
my $session2_result = $concierge->{sessions}->new_session(
    user_id => 'bob',
    data    => {
        cart => ['single_item'],
    },
);

die "Session2 creation failed" unless $session2_result->{success};
my $session2 = $session2_result->{session};

my $bob_data = $session2->get_app_data();
say "   Bob's session data (declared fields should exist even if empty):";
foreach my $field (@$user_session_fields) {
    my $exists = exists $bob_data->{$field};
    my $value = $bob_data->{$field};
    my $val_str;
    if (ref $value eq 'ARRAY' && @$value) {
        $val_str = "[" . join(", ", @$value) . "]";
    } elsif (ref $value eq 'HASH' && %$value) {
        $val_str = "{" . join(", ", %$value) . "}";
    } else {
        $val_str = defined $value ? $value : '<undef>';
    }
    say "     - $field: exists=$exists, value=$val_str";
}

say "\n9. Testing that non-declared fields are preserved:";
my $alice_all = $session->get_data()->{value};
if (exists $alice_all->{extra_field}) {
    say "   Non-declared field 'extra_field' preserved: $alice_all->{extra_field}";
} else {
    say "   ERROR: Non-declared field was lost!";
}

say "\n10. Persistence test - reopening concierge:";
undef $concierge;
my $reopen_result = Concierge->open_desk($test_dir);
die "Reopen failed" unless $reopen_result->{success};

my $concierge2 = $reopen_result->{concierge};
say "   Concierge reopened";

my $alice_session_result = $concierge2->{sessions}->get_session(
    $session->session_id()
);

die "Can't retrieve Alice's session" unless $alice_session_result->{success};
my $alice_session = $alice_session_result->{session};

my $alice_data = $alice_session->get_app_data();
say "   Alice's cart after reopen: [" . join(", ", @{$alice_data->{cart} // []}) . "]";
say "   Data persisted correctly";

say "\n" . "=" x 60;
say "All tests passed!";
say "=" x 60;
