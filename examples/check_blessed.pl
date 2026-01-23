#!/usr/bin/env perl
use v5.36;
use lib "/Volumes/Main/Development/Repositories/Concierge-Auth/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Sessions/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge-Users/lib";
use lib "/Volumes/Main/Development/Repositories/Concierge/lib";

use Concierge;

my $test_dir = "/tmp/test_blessed";
`rm -rf $test_dir` if -d $test_dir;
mkdir $test_dir;

my $result = Concierge::build_desk($test_dir, "$test_dir/auth.db", [], [qw(cart pref)]);
my $open = Concierge->open_desk($test_dir);
my $concierge = $open->{concierge};

my $s = $concierge->{sessions}->new_session(user_id => 'test', data => {cart => ['item1']});
my $session = $s->{session};

my $pkg = ref($session);
print "Session ref: $pkg\n";
print "Session blessed into: ", Scalar::Util::blessed($session), "\n";
my @isa = @{"Concierge::Sessions::Session::ISA"};
print "Session ISA: ", join(", ", @isa), "\n";

# Check if get_app_data is in the symbol table
print "get_app_data in symbol table: ", (defined &Concierge::Sessions::Session::get_app_data ? "YES" : "NO"), "\n";
print "Can call get_app_data: ", $session->can("get_app_data") ? "YES" : "NO", "\n";
