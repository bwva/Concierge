#!/usr/bin/env perl
#
# show_file_contents.pl
#
# Displays the contents of key files created by the storage_formats_demo.pl script.
# This shows the actual formats used by Concierge and its components.

use v5.40;
use strict;
use warnings;
use JSON::PP qw(decode_json);
use YAML;

my $STORAGE_BASE = './storage';

print "=" x 80 . "\n";
print "Concierge File Format Examples\n";
print "=" x 80 . "\n\n";

# ==============================================================================
# DESK1: SQLite + Database backends
# ==============================================================================

print "-" x 80 . "\n";
print "DESK1: SQLite + Database backends\n";
print "-" x 80 . "\n\n";

print "---[ concierge.json ]---\n";
show_file("$STORAGE_BASE/desk1/concierge.json", 'json');

print "\n---[ concierge.yaml ]---\n";
show_file("$STORAGE_BASE/desk1/concierge.yaml", 'yaml');

print "\n---[ auth.pwd (password file) ]---\n";
show_file("$STORAGE_BASE/desk1/auth.pwd", 'text');

print "\n---[ users/users-config.json ]---\n";
show_file("$STORAGE_BASE/desk1/users/users-config.json", 'json');

print "\n---[ users/users-config.yaml ]---\n";
show_file("$STORAGE_BASE/desk1/users/users-config.yaml", 'yaml');

# Query SQLite sessions database to show all sessions
my $sessions_db_path = "$STORAGE_BASE/desk1/concierge-internal/sessions.db";
if (-e $sessions_db_path) {
    print "\n---[ SQLite sessions database contents ]---\n";
    show_sqlite_sessions($sessions_db_path);
}

my $app_sessions_db_path = "$STORAGE_BASE/desk1/sessions/sessions.db";
if (-e $app_sessions_db_path) {
    print "\n---[ App user sessions database contents ]---\n";
    show_sqlite_sessions($app_sessions_db_path);
}

# ==============================================================================
# DESK2: File-based backends
# ==============================================================================

print "\n\n";
print "-" x 80 . "\n";
print "DESK2: File-based backends (All file storage)\n";
print "-" x 80 . "\n\n";

print "---[ concierge.yaml ]---\n";
show_file("$STORAGE_BASE/desk2/concierge.yaml", 'yaml');

print "\n---[ auth.pwd ]---\n";
show_file("$STORAGE_BASE/desk2/auth.pwd", 'text');

print "\n---[ users/users.tsv (Tab-separated values) ]---\n";
show_file("$STORAGE_BASE/desk2/users/users.tsv", 'text');

# Find and show multiple session files
my @session_files = glob("$STORAGE_BASE/desk2/concierge-internal/*.json");
if (@session_files) {
    print "\n---[ concierge-internal session files (showing up to 3) ]---\n";
    my $count = 0;
    for my $session_file (@session_files) {
        last if $count >= 3;  # Show max 3 files
        print "\n  File: " . substr($session_file, rindex($session_file, '/') + 1) . "\n";
        show_file($session_file, 'json');
        $count++;
    }
    if (@session_files > 3) {
        print "\n  ... (" . (@session_files - 3) . " more session files not shown)\n";
    }
}

# Show app user sessions
my @app_session_files = glob("$STORAGE_BASE/desk2/sessions/*.json");
if (@app_session_files) {
    print "\n---[ app user session files (showing up to 3) ]---\n";
    my $count = 0;
    for my $session_file (@app_session_files) {
        last if $count >= 3;  # Show max 3 files
        print "\n  File: " . substr($session_file, rindex($session_file, '/') + 1) . "\n";
        show_file($session_file, 'json');
        $count++;
    }
    if (@app_session_files > 3) {
        print "\n  ... (" . (@app_session_files - 3) . " more session files not shown)\n";
    }
}

# ==============================================================================
# DESK3: Mixed backends
# ==============================================================================

print "\n\n";
print "-" x 80 . "\n";
print "DESK3: Mixed backends (SQLite sessions + YAML users)\n";
print "-" x 80 . "\n\n";

print "---[ users/users-config.yaml ]---\n";
show_file("$STORAGE_BASE/desk3/users/users-config.yaml", 'yaml');

# Find YAML user files
my @yaml_files = glob("$STORAGE_BASE/desk3/users/users_*.yaml");
for my $yaml_file (@yaml_files) {
    next if $yaml_file =~ /users-config\.yaml$/;  # Skip config file
    print "\n---[ users YAML data file ]---\n";
    show_file($yaml_file, 'yaml');
    last;  # Just show one example
}

print "\n\n";
print "=" x 80 . "\n";
print "Format Explanations\n";
print "=" x 80 . "\n\n";

print "AUTH.PWD FORMAT:\n";
print "  Tab-separated format: user_id<TAB>encrypted_password\n";
print "  - Password is encrypted using Argon2 (with Bcrypt validation support)\n";
print "  - Each line is a separate user\n";
print "  - File permissions are set to 0600 (owner read/write only)\n";
print "\n";

print "CONCIERGE.JSON/YAML FORMAT:\n";
print "  Contains complete configuration for Concierge and all components:\n";
print "  - version: Concierge module version\n";
print "  - generated: Unix timestamp of creation\n";
print "  - concierge: Concierge's internal session configuration\n";
print "  - auth: Auth component configuration (auth_file path)\n";
print "  - sessions: Sessions component configuration\n";
print "  - users: Users component configuration (config_file path)\n";
print "  - components_configured: List of active components\n";
print "\n";

print "USERS-CONFIG.JSON/YAML FORMAT:\n";
print "  Contains Users component configuration:\n";
print "  - version: Users module version\n";
print "  - backend_module: Full module name (e.g., Concierge::Users::Database)\n";
print "  - backend_config: Backend-specific configuration\n";
print "  - fields: Array of field definitions\n";
print "  - field_definitions: Hash of detailed field specifications\n";
print "\n";

print "SESSION FILES (File backend):\n";
print "  JSON files containing:\n";
print "  - session_id: Unique session identifier\n";
print "  - user_id: User ID for the session\n";
print "  - created: Creation timestamp\n";
print "  - expires: Expiration timestamp\n";
print "  - data: User-defined session data (hashref)\n";
print "\n";

print "USERS.TSV FORMAT (File backend):\n";
print "  Tab-separated values file:\n";
print "  - First line: Field names (headers)\n";
print "  - Subsequent lines: User records\n";
print "  - System fields: user_id, moniker, created_date, last_mod_date\n";
print "  - Custom fields: email, role, etc.\n";
print "\n";

print "SQLITE DATABASES:\n";
print "  - Binary format (view with sqlite3 command)\n";
print "  - Contains structured tables for sessions, users, etc.\n";
print "  - Supports indexes and efficient queries\n";
print "\n";

print "=" x 80 . "\n";

# ==============================================================================
# SUBROUTINES
# ==============================================================================

sub show_file {
    my ($filepath, $format) = @_;

    unless (-e $filepath) {
        print "  [File not found: $filepath]\n";
        return;
    }

    open my $fh, '<', $filepath or die "Cannot open $filepath: $!";
    local $/;
    my $content = <$fh>;
    close $fh;

    if ($format eq 'json') {
        eval {
            my $parsed = decode_json($content);
            print JSON::PP->new->utf8->canonical->pretty->encode($parsed);
        };
        if ($@) {
            print "  [Failed to parse JSON: $@]\n";
            print "  Raw content:\n";
            print "  " . join("\n  ", split(/\n/, $content)) . "\n";
        }
    }
    elsif ($format eq 'yaml') {
        eval {
            my $parsed = YAML::Load($content);
            print YAML::Dump($parsed);
        };
        if ($@) {
            print "  [Failed to parse YAML: $@]\n";
            print "  Raw content:\n";
            print "  " . join("\n  ", split(/\n/, $content)) . "\n";
        }
    }
    else {
        # Text format
        print "  " . join("\n  ", split(/\n/, $content)) . "\n";
    }
}

sub show_sqlite_sessions {
    my ($db_path) = @_;

    # Use sqlite3 command if available
    my $sqlite3 = `which sqlite3 2>/dev/null`;
    chomp $sqlite3;

    if ($sqlite3 && -x $sqlite3) {
        # Use sqlite3 command-line tool
        my $output = `sqlite3 "$db_path" "SELECT session_id, user_id, session_timeout, expires_at, datetime(created_at, 'unixepoch') as created FROM sessions;" 2>&1`;
        if ($output) {
            my @lines = split(/\n/, $output);
            my $header = shift @lines;
            print "  $header\n";
            for my $line (@lines) {
                my @fields = split(/\|/, $line);
                # Truncate session_id for display
                $fields[0] = substr($fields[0], 0, 8) . '...' if length($fields[0]) > 8;
                $line = join(' | ', @fields);
                print "  $line\n";
            }
            return;
        }
    }

    # Fallback: just show that the database exists
    print "  SQLite database: $db_path\n";
    print "  (Install sqlite3 CLI to view contents: 'apt install sqlite3' or 'brew install sqlite3')\n";
}

=head1 DESCRIPTION

This script displays the contents of key files created by storage_formats_demo.pl
to show the actual formats used by Concierge and its components.

=head2 USAGE

    cd examples
    perl show_file_contents.pl

=head2 WHAT IT SHOWS

=over 4

=item * Concierge configuration files (JSON and YAML)

=item * Auth password file format

=item * Users configuration files (JSON and YAML)

=item * TSV file format (tab-separated values)

=item * Session file format (JSON)

=item * YAML user data format

=back

=head1 SEE ALSO

L<storage_formats_demo.pl>

=cut
