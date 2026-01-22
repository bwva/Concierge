#!/usr/bin/env perl

use strict;
use warnings;
use Test2::V0;

use lib 'lib';

# Test 1: Module loads (if this fails, test will die)
use Concierge;

# Test 2: Version is defined
ok($Concierge::VERSION, "Concierge version is defined");

# Test 3: Can instantiate
my $concierge;
ok(lives {
    $concierge = Concierge->new();
}, "Can instantiate Concierge object") or note($@);

isa_ok($concierge, 'Concierge');

# Test 4: Component configuration methods exist
my @methods = qw(
    configure_auth
    configure_sessions
    configure_users
);

can_ok($concierge, $_) for @methods;

# Test 5: Class methods setup() and load() exist
my @class_methods = qw(
    setup
    load
);

can_ok('Concierge', $_) for @class_methods;

done_testing();
