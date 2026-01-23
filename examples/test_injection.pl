#!/usr/bin/env perl
use strict;
use warnings;

# Test if glob assignment persists

package Test::Session;

sub original_method {
    return "original";
}

package main;

print "Before injection: ", Test::Session->original_method(), "\n";

{
    no strict 'refs';
    *Test::Session::original_method = sub {
        return "injected";
    };
}

print "After injection: ", Test::Session->original_method(), "\n";
