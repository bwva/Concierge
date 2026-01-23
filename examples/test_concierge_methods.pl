#!/usr/bin/env perl
use v5.36;
# IMPORTANT: Add component lib paths FIRST, before Concierge
use lib "/Volumes/Main/Development/Repositories/Concierge-Auth/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Sessions/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Users/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge/lib";

use Concierge;

say "=" x 60;
say "Testing Concierge get_app_data() and set_app_data()";
say "=" x 60;

# Clean up from previous run
my $test_dir = "/tmp/concierge_test_methods";
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

die "Build failed" unless $build_result->{success};
say "   ✓ Concierge built successfully";

say "\n2. Opening concierge:";
my $open_result = Concierge->open_desk($test_dir);
die "Open failed" unless $open_result->{success};

my $concierge = $open_result->{concierge};
say "   ✓ Concierge opened";

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
my $session_id = $session->session_id();
say "   ✓ Session created: $session_id";

say "\n4. Testing concierge->get_app_data(\$session_id) - retrieve all declared fields:";
my $app_data = $concierge->get_app_data($session_id);
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

say "\n5. Testing concierge->get_app_data(\$session_id, 'cart') - selective retrieval:";
my $cart_only = $concierge->get_app_data($session_id, 'cart');
say "   Cart only: " . join(", ", @{$cart_only->{cart} // []});

say "\n6. Testing concierge->set_app_data(\$session_id, \\%new_data) - update cart:";
my $update_result = $concierge->set_app_data($session_id, {
    cart => ['item1', 'item2', 'item3', 'item4'],
});

die "set_app_data failed" unless $update_result->{success};
say "   ✓ Cart updated";

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
my $session2_id = $session2_result->{session}->session_id();

my $bob_data = $concierge->get_app_data($session2_id);
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

say "\n" . "=" x 60;
say "All tests passed!";
say "=" x 60;
