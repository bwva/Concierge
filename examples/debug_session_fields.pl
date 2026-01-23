#!/usr/bin/env perl
use v5.36;
use lib "/Volumes/Main/Development/Repositories/Concierge/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Auth/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Sessions/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Users/lib";

use Concierge;
use Data::Dumper;

my $test_dir = "/tmp/concierge_debug";
`rm -rf $test_dir` if -d $test_dir;
mkdir $test_dir or die "Can't create $test_dir: $!";

my $user_session_fields = [qw(cart preferences last_view)];

say "Building concierge...";
my $build_result = Concierge::build_desk(
    $test_dir,
    "$test_dir/auth.db",
    [],
    $user_session_fields,
);

die "Build failed" unless $build_result->{success};

say "Opening concierge...";
my $open_result = Concierge->open_desk($test_dir);
die "Open failed" unless $open_result->{success};
print STDERR "INFO: After open_desk returns, marker defined: ", (defined &Concierge::Sessions::Session::get_app_data_injected ? "YES" : "NO"), "\n";

my $concierge = $open_result->{concierge};
print STDERR "INFO: After getting concierge object, marker defined: ", (defined &Concierge::Sessions::Session::get_app_data_injected ? "YES" : "NO"), "\n";

say "Creating user session...";
print STDERR "INFO: Before creating session, marker defined: ", (defined &Concierge::Sessions::Session::get_app_data_injected ? "YES" : "NO"), "\n";
my $session_result = $concierge->{sessions}->new_session(
    user_id => 'alice',
    data    => {
        cart       => ['item1', 'item2'],
        preferences => { theme => 'dark' },
        last_view  => '/products',
    },
);

die "Session creation failed" unless $session_result->{success};
my $session = $session_result->{session};

say "\nSession ID: " . $session->session_id();

say "\nDirect get_data() call:";
my $data_result = $session->get_data();
print Dumper($data_result);

say "\nCalling get_app_data():";
my $app_data = $session->get_app_data();
print Dumper($app_data);
