#!/usr/bin/env perl
use strict;
use warnings;

# Test the exact pattern from Concierge.pm

package Test::Session;

sub get_app_data {
    warn "get_app_data must be implemented";
    return {};
}

sub test_injection {
    my $class = shift;

    {
        no strict 'refs';
        unless (defined &Test::Session::get_app_data_injected) {
            warn "Injecting methods\n";
            *Test::Session::get_app_data = sub {
                return "injected";
            };

            *Test::Session::get_app_data_injected = sub { 1 };
            warn "Marker set\n";
        }
    }
}

package main;

print "Before injection: ", Test::Session->get_app_data(), "\n";

Test::Session->test_injection();

print "After injection: ", Test::Session->get_app_data(), "\n";

print "Marker defined: ", (defined &Test::Session::get_app_data_injected ? "YES" : "NO"), "\n";
