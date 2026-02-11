package Concierge::Setup v0.4.0;
use v5.36;

our $VERSION = 'v0.4.0';

# ABSTRACT: Setup and configuration for Concierge desk initialization

use Carp qw<carp croak>;
use File::Spec;
use File::Path qw/make_path/;
use JSON::PP;
use Concierge;

# === COMPONENT MODULES ===
use Concierge::Auth;
use Concierge::Sessions;
use Concierge::Users;

# =============================================================================
# SIMPLE SETUP - Opinionated defaults for quick start
# =============================================================================

sub build_desk ($storage_dir, $app_fields=[]) {
    # Simple, opinionated setup with reasonable defaults:
    # - Database sessions backend (SQLite via Concierge::Sessions)
    # - Database users backend (SQLite via Concierge::Users)
    # - All standard user fields included
    # - All storage co-located in $storage_dir

    return { success => 0, message => 'desk_location is required' }
        unless defined $storage_dir;

    # Safety: Convert '.' or empty string to './desk' to avoid cluttering app root
    if (!$storage_dir || $storage_dir eq '.' || $storage_dir eq './') {
        $storage_dir = './desk';
        carp "Storage directory set to './desk' (convention: avoid cluttering application root)";
    }

    # Ensure storage directory exists
    unless (-d $storage_dir) {
        eval { make_path($storage_dir) };
        croak "Cannot create storage directory '$storage_dir': $@" if $@;
    }

    # Create minimal Concierge object for internal operations
    my $concierge = bless {}, 'Concierge';

    # Initialize Sessions component
    $concierge->{sessions} = Concierge::Sessions->new(
        storage_dir => $storage_dir,  # Uses database backend (SQLite) by default
    );

    # Initialize Auth component
    my $auth_file	= File::Spec->catfile($storage_dir, 'auth.pwd');
    $concierge->{auth} = Concierge::Auth->new({
        file => $auth_file
    });

    # Setup Users component
    my $users_setup = Concierge::Users->setup({
        storage_dir             => $storage_dir,
        backend                 => 'database',  # Database backend (SQLite)
        include_standard_fields => 'all',       # All standard fields
        field_overrides         => [],          # No overrides
        app_fields              => $app_fields,
    });
    unless ($users_setup->{success}) {
        return {
            success => 0,
            message => "Failed to setup Users: " . $users_setup->{message}
        };
    }

    # Build configuration to store in concierge session
    my $full_config = {
        users_config_file   => $users_setup->{config_file},
        storage_dir         => $storage_dir,
        sessions_dir        => $storage_dir,
        users_dir           => $storage_dir,
        auth_file           => $auth_file,
        sessions_backend    => 'database',
        users_backend       => 'database',
    };
    # Encode to JSON with pretty formatting and write with trailing newline
    my $json = JSON->new->utf8->pretty->encode($full_config) . "\n";
   
    my $concierge_conf_file	= File::Spec->catfile($storage_dir, 'concierge.conf');
    
    my $fh;
    open $fh, ">", $concierge_conf_file
    	and
    print $fh $json
    	and
    close $fh
    	or return { success => 0, message => "Cannot write to concierge config file: $!" };

    return {
        success => 1,
        message => "Concierge desk built successfully",
        desk    => $storage_dir,
    };
}

# =============================================================================
# ADVANCED SETUP - Full control with custom configuration
# =============================================================================

sub build_custom_desk ($config) {
    # Advanced setup with full configuration options:
    # - Separate storage directories per component
    # - Full Users.pm field configuration (include_standard_fields, field_overrides, etc.)
    # - Custom backend selection for Sessions and Users
    # - No assumptions or defaults

    # Validate required top-level config
    return { success => 0, message => 'Configuration must be a hash reference' }
        unless ref $config eq 'HASH';

    return { success => 0, message => 'Missing storage.base_dir' }
        unless $config->{storage} && $config->{storage}{base_dir};

    # Safety: Convert '.' or empty string to './desk' to avoid cluttering app root
    my $base_dir = $config->{storage}{base_dir};
    if (!$base_dir || $base_dir eq '.' || $base_dir eq './') {
        $base_dir = './desk';
        $config->{storage}{base_dir} = $base_dir;
        carp "Storage directory set to './desk' (convention: avoid cluttering application root)";
    }

    # Determine storage locations (support separate dirs or single base_dir)
    my $sessions_dir	= $config->{storage}{sessions_dir} || $base_dir;
    my $users_dir		= $config->{storage}{users_dir} || $base_dir;
    my $auth_file		= $config->{auth}{file} || File::Spec->catfile($base_dir, 'auth.pwd');

    # Create directories if needed
    for my $dir ($base_dir, $sessions_dir, $users_dir) {
        next if -d $dir;
        eval { make_path($dir) };
        return {
            success => 0,
            message => "Failed to create directory '$dir': $@"
        } if $@;
    }

    # Create minimal Concierge object for internal operations
    my $concierge = bless {}, 'Concierge';

    # Initialize Sessions component with specified backend
    my $sessions_backend = $config->{sessions}{backend} || 'database'; 
    $concierge->{sessions} = Concierge::Sessions->new(
        backend     => $sessions_backend,
        storage_dir => $sessions_dir,
    );

    # Initialize Auth component
    $concierge->{auth} = Concierge::Auth->new({
        file => $auth_file
    });

    # Build Users setup configuration
    my $users_config = {
        storage_dir => $users_dir,
        backend     => $config->{users}{backend} || 'database',
    };

    # Add Users-specific configuration options
    $users_config->{include_standard_fields} = $config->{users}{include_standard_fields}
        if exists $config->{users}{include_standard_fields};

    $users_config->{app_fields} = $config->{users}{app_fields}
        if exists $config->{users}{app_fields};

    $users_config->{field_overrides} = $config->{users}{field_overrides}
        if exists $config->{users}{field_overrides};

    # Setup Users component
    my $users_setup = Concierge::Users->setup($users_config);
    unless ($users_setup->{success}) {
        return {
            success => 0,
            message => "Failed to setup Users: " . $users_setup->{message}
        };
    }

    # Build configuration to store in concierge session
    my $full_config = {
        users_config_file   => $users_setup->{config_file},
        storage_dir         => $base_dir,
        sessions_dir        => $sessions_dir,
        users_dir           => $users_dir,
        auth_file           => $auth_file,
        sessions_backend    => $sessions_backend,
        users_backend       => $users_config->{backend},
    };
    my $json = JSON->new->utf8->pretty->encode($full_config) . "\n";

	my $config_location	= $full_config->{storage_dir};
    my $concierge_conf_file	= File::Spec->catfile($config_location, 'concierge.conf');
    my $fh;
    open $fh, ">", $concierge_conf_file
    	and
    print $fh $json
    	and
    close $fh
    	or return { success => 0, message => "Cannot write to concierge config file: $!" };

    return {
        success => 1,
        message => "Custom Concierge desk built successfully",
        desk    => $base_dir,
        config  => $full_config,
    };
}


# =============================================================================
# HELPER METHODS
# =============================================================================

# Validate setup configuration before executing
sub validate_setup_config ($config) {
    my @errors;

    # Check required fields
    push @errors, "Missing storage.base_dir"
        unless $config->{storage} && $config->{storage}{base_dir};

    push @errors, "Missing auth.file"
        unless $config->{auth} && $config->{auth}{file};

    push @errors, "Missing sessions.backend"
        unless $config->{sessions} && $config->{sessions}{backend};

    push @errors, "Missing users.backend"
        unless $config->{users} && $config->{users}{backend};

    # Validate backend values
    if ($config->{sessions}{backend}) {
        my $backend = lc $config->{sessions}{backend};
        push @errors, "Invalid sessions.backend: must be 'database' or 'file'"
            unless $backend =~ /^(database|file)$/;
    }

    if ($config->{users}{backend}) {
        my $backend = lc $config->{users}{backend};
        push @errors, "Invalid users.backend: must be 'database', 'yaml', or 'file'"
            unless $backend =~ /^(database|yaml|file)$/;
    }

    return {
        success => @errors ? 0 : 1,
        (@errors ? (errors => \@errors) : ()),
    };
}

1;

__END__

=head1 NAME

Concierge::Setup - One-time desk creation and configuration for Concierge

=head1 VERSION

v0.4.0

=head1 SYNOPSIS

    use Concierge::Setup;

    # Simple setup -- database backends, all standard user fields
    my $result = Concierge::Setup::build_desk(
        './desk',
        ['role', 'theme'],       # application-specific user fields
    );

    # Advanced setup -- full control over backends and field configuration
    my $result = Concierge::Setup::build_custom_desk({
        storage => {
            base_dir     => './desk',
            sessions_dir => './desk/sessions',
            users_dir    => './desk/users',
        },
        auth => {
            file => './desk/auth.pwd',
        },
        sessions => {
            backend => 'database',  # or 'file'
        },
        users => {
            backend    => 'database',  # 'database', 'yaml', or 'file'
            app_fields => ['membership_tier', 'department'],
        },
    });

=head1 DESCRIPTION

Concierge::Setup provides methods for one-time initialization of a
Concierge desk -- the storage directory containing configuration and data
files for all three component modules (Auth, Sessions, Users).

Setup is separate from runtime operations. Use this module once to create
a desk, then use L<Concierge/open_desk> at runtime.

=head2 The ./desk Convention

If C<$storage_dir> is C<'.'>, C<'./'>, or an empty string, it is
automatically converted to C<'./desk'> to avoid cluttering the
application root directory.

=head1 METHODS

=head2 build_desk

    my $result = Concierge::Setup::build_desk(
        $storage_dir,
        \@app_fields,
    );

Creates a desk with opinionated defaults: SQLite backends for both
Sessions and Users, all standard user fields included, all storage
co-located in C<$storage_dir>. The password file (C<auth.pwd>) is
created automatically inside C<$storage_dir>.

B<Parameters:>

=over 4

=item C<$storage_dir> (required) -- directory for all data files; created if it does not exist

=item C<\@app_fields> -- additional user data fields beyond the standard set

=back

Returns C<< { success => 1, desk => $desk_location } >> on success,
or C<< { success => 0, message => '...' } >> on failure.

=head2 build_custom_desk

    my $result = Concierge::Setup::build_custom_desk(\%config);

Creates a desk with full control over backend selection, storage
layout, and field configuration. See the SYNOPSIS for the configuration
structure.

Returns C<< { success => 1, desk => $desk_location, config => \%config } >>
on success.

=head2 validate_setup_config

    my $result = Concierge::Setup::validate_setup_config(\%config);

Validates a configuration hashref without creating anything. Returns
C<< { success => 1 } >> or C<< { success => 0, errors => [...] } >>.

=head1 SEE ALSO

L<Concierge> -- runtime operations after desk is built

=head1 AUTHOR

Bruce Van Allen <bva@cruzio.com>

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the terms of the Artistic License 2.0.

=cut
