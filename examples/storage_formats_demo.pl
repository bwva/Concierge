#!/usr/bin/env perl
#
# storage_formats_demo.pl
#
# Demonstrates the file and configuration formats used by Concierge
# and its component modules with multiple backend variations.
#
# This script creates multiple Concierge instances in separate subdirectories
# under the examples/storage directory to show different configuration options.

use v5.40;
use strict;
use warnings;
use lib '../lib', '../../lib';

use Concierge;
use Data::Dumper;
use File::Path qw(make_path);

# ==============================================================================
# CONFIGURATION
# ==============================================================================

my $STORAGE_BASE = './storage';
my @DESKS = (
    {   name => 'desk1',
        desc => 'SQLite + Database backends (Default configuration)',
        config => {
            concierge_session => { backend => 'SQLite' },
            sessions         => { backend => 'SQLite' },
            users            => { backend => 'database' },
        }
    },
    {   name => 'desk2',
        desc => 'File-based backends (All file storage)',
        config => {
            concierge_session => { backend => 'File' },
            sessions         => { backend => 'File' },
            users            => { backend => 'file' },
        }
    },
    {   name => 'desk3',
        desc => 'Mixed backends (SQLite sessions, YAML users)',
        config => {
            concierge_session => { backend => 'SQLite' },
            sessions         => { backend => 'SQLite' },
            users            => { backend => 'yaml' },
        }
    },
    {   name => 'desk4',
        desc => 'File sessions + Database users (Hybrid)',
        config => {
            concierge_session => { backend => 'File' },
            sessions         => { backend => 'File' },
            users            => { backend => 'database' },
        }
    },
);

# ==============================================================================
# MAIN SCRIPT
# ==============================================================================

print "=" x 80 . "\n";
print "Concierge Storage Formats Demonstration\n";
print "=" x 80 . "\n\n";

print "This script demonstrates the file formats used by Concierge and its\n";
print "component modules (Auth, Sessions, Users) with various backends.\n\n";

print "Storage base directory: $STORAGE_BASE\n";
print "Creating " . scalar(@DESKS) . " Concierge instances with different configurations...\n\n";

# Ensure storage base directory exists
make_path($STORAGE_BASE) unless -d $STORAGE_BASE;

# Create each desk
for my $desk (@DESKS) {
    print "-" x 80 . "\n";
    print "Creating: $desk->{name}\n";
    print "Description: $desk->{desc}\n";
    print "-" x 80 . "\n";

    my $desk_path = "$STORAGE_BASE/$desk->{name}";

    # Create desk subdirectory
    make_path($desk_path) unless -d $desk_path;

    # Setup Concierge instance
    my $concierge = eval {
        Concierge->setup(
            concierge_config_file => "$desk_path/concierge.json",

            # Concierge's own internal session
            concierge_session => {
                storage_dir => "$desk_path/concierge-internal",
                %{ $desk->{config}{concierge_session} || {} },
            },

            # Auth component (password file)
            auth => {
                auth_file => "$desk_path/auth.pwd",
            },

            # Sessions component (for app user sessions)
            sessions => {
                sessions_storage_dir => "$desk_path/sessions",
                backend     => $desk->{config}{sessions}{backend} || 'SQLite',
                session_timeout => 7200,  # 2 hours
            },

            # Users component
            users => {
                users_storage_dir => "$desk_path/users",
                users_backend     => $desk->{config}{users}{backend} || 'database',
            },
        );
    };

    if ($@) {
        print "ERROR: Failed to create $desk->{name}: $@\n";
        next;
    }

    print "✓ Concierge instance created successfully\n";

    # Perform some operations to generate files
    _demo_operations($concierge, $desk_path);

    # List created files
    _list_files($desk_path);

    print "\n";
}

# Summary
print "=" x 80 . "\n";
print "Summary\n";
print "=" x 80 . "\n";
print "Created " . scalar(@DESKS) . " Concierge instances in: $STORAGE_BASE/\n\n";

print "File Format Overview:\n";
print "\n";
print "  Concierge Config Files:\n";
print "    - concierge.json    - Machine-readable config (JSON)\n";
print "    - concierge.yaml    - Human-readable config (YAML)\n";
print "\n";
print "  Auth Component:\n";
print "    - auth.pwd         - Password file (tab-separated: user_id<TAB>encrypted_password)\n";
print "                        (Argon2/Bcrypt encrypted)\n";
print "\n";
print "  Sessions Component:\n";
print "    SQLite backend:\n";
print "      - sessions.db    - SQLite database containing session records\n";
print "    File backend:\n";
print "      - *.json         - Individual session files (one per session)\n";
print "\n";
print "  Users Component:\n";
print "    - users-config.json  - Machine-readable config (JSON)\n";
print "    - users-config.yaml  - Human-readable config (YAML)\n";
print "    Database backend:\n";
print "      - users.db         - SQLite database with user records\n";
print "      - users.db-journal - SQLite transaction journal\n";
print "    File backend (TSV):\n";
print "      - users.tsv        - Tab-separated values file\n";
print "      - users-index.tsv  - User ID index file\n";
print "    YAML backend:\n";
print "      - users.yaml       - YAML format user records\n";
print "      - users-index.yaml - User ID index in YAML\n";
print "\n";
print "  Concierge Internal Session:\n";
print "    SQLite backend:\n";
print "      - concierge.db      - SQLite database for Concierge's internal session\n";
print "    File backend:\n";
print "      - *.json            - JSON files for Concierge's internal session\n";
print "\n";
print "=" x 80 . "\n";

# ==============================================================================
# SUBROUTINES
# ==============================================================================

sub _demo_operations {
    my ($concierge, $desk_path) = @_;

    print "\nPerforming demo operations...\n";

    # Define test users
    my @test_users = (
        { user_id => 'alice', password => 'SecurePass123!', moniker => 'alice_in_wonderland', email => 'alice@example.com' },
        { user_id => 'bob',   password => 'BobPass456!',     moniker => 'bob_the_builder',      email => 'bob@example.com' },
        { user_id => 'carol', password => 'CarolPass789!',   moniker => 'carol_sings',          email => 'carol@example.com' },
        { user_id => 'dave',  password => 'DavePass012!',    moniker => 'davy_jones',           email => 'dave@example.com' },
    );

    # 1. Create auth entries for all users
    my $auth = $concierge->{auth};
    if ($auth) {
        for my $user (@test_users) {
            my ($success, $msg) = $auth->setPwd($user->{user_id}, $user->{password});
            if ($success) {
                print "  ✓ Created auth entry for user: $user->{user_id}\n";
            }
        }
    }

    # 2. Create user records in Users component
    my $users = $concierge->{users};
    if ($users) {
        for my $user (@test_users) {
            my $result = $users->register_user({
                user_id => $user->{user_id},
                moniker => $user->{moniker},
                email   => $user->{email},
                role    => 'member',
            });

            if ($result->{success}) {
                print "  ✓ Registered user in Users component: $user->{user_id}\n";
            }
        }
    }

    # 3. Create multiple sessions for different users
    my $sessions = $concierge->{sessions};
    if ($sessions) {
        # Create one session per user
        for my $user (@test_users) {
            my $result = $sessions->new_session(
                user_id => $user->{user_id},
                data    => {
                    username    => $user->{user_id},
                    login_time  => time(),
                    preferences => {
                        theme => $user->{user_id} eq 'alice' ? 'dark' : 'light',
                        lang  => 'en',
                    },
                },
            );

            if ($result->{success}) {
                my $session_id = $result->{session}{session_id} || 'unknown';
                my $session_id_short = substr($session_id, 0, 8) . '...';
                print "  ✓ Created session for $user->{user_id}: $session_id_short\n";
            }
        }

        # Create an additional session for alice (simulating multiple devices)
        my $alice_session2 = $sessions->new_session(
            user_id => 'alice',
            data    => {
                username    => 'alice',
                device      => 'mobile',
                login_time  => time(),
                preferences => { theme => 'light', lang => 'es' },
            },
        );

        if ($alice_session2->{success}) {
            my $session_id = $alice_session2->{session}{session_id} || 'unknown';
            my $session_id_short = substr($session_id, 0, 8) . '...';
            print "  ✓ Created second session for alice (mobile): $session_id_short\n";
        }
    }

    # 4. Concierge's internal session is created automatically
    my $concierge_session_id = $concierge->{concierge_session}{session_id};
    my $session_id_short = $concierge_session_id ? substr($concierge_session_id, 0, 8) . '...' : 'N/A';
    print "  ✓ Concierge internal session: $session_id_short\n";
}

sub _list_files {
    my ($desk_path) = @_;

    print "\nFiles created in $desk_path:\n";

    # Recursively find all files
    my @files;
    _find_files_recursive($desk_path, $desk_path, \@files);

    # Sort and display
    @files = sort { $a->{rel} cmp $b->{rel} } @files;

    if (@files) {
        for my $file (@files) {
            my $size_str = sprintf("%6d bytes", $file->{size});
            printf "  %-50s %s\n", $file->{rel}, $size_str;
        }
        printf "  %-50s %s\n", "Total files:", scalar(@files);
    } else {
        print "  (No files found)\n";
    }
}

sub _find_files_recursive {
    my ($base_path, $current_path, $files_ref) = @_;

    opendir(my $dh, $current_path) or die "Cannot open $current_path: $!";
    while (my $entry = readdir($dh)) {
        next if $entry =~ /^\.\.?$/;  # Skip . and ..

        my $full_path = "$current_path/$entry";
        if (-d $full_path) {
            _find_files_recursive($base_path, $full_path, $files_ref);
        } else {
            push @$files_ref, {
                path => $full_path,
                rel  => substr($full_path, length($base_path) + 1),
                size => -s $full_path,
            };
        }
    }
    closedir($dh);
}

=head1 DESCRIPTION

This demonstration script creates multiple Concierge instances with different
backend configurations to show the various file formats used.

=head2 WHAT IT CREDES

For each desk (desk1, desk2, desk3, desk4), the script:

1. Creates a separate subdirectory under examples/storage/
2. Configures Concierge with specific backends
3. Performs basic operations (create user, create session)
4. Lists all generated files with their sizes

=head2 FILE FORMATS DEMONSTRATED

=over 4

=item * Concierge Config (JSON + YAML)

=item * Auth Password File (Tab-separated, Argon2/Bcrypt encrypted)

=item * Sessions (SQLite database OR JSON files)

=item * Users (Config JSON/YAML + Database/TSV/YAML data files)

=item * Concierge Internal Session (SQLite OR JSON)

=back

=head2 USAGE

    cd examples
    perl storage_formats_demo.pl

After running, examine the contents of:

    storage/desk1/  - SQLite + Database backends
    storage/desk2/  - All file backends
    storage/desk3/  - SQLite sessions + YAML users
    storage/desk4/  - File sessions + Database users

=head1 SEE ALSO

L<Concierge>
L<Concierge::Auth>
L<Concierge::Sessions>
L<Concierge::Users>

=cut
