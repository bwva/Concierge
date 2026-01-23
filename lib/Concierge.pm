package Concierge v0.2.0;
use v5.36;

our $VERSION = 'v0.2.0';

# ABSTRACT: Service layer orchestrator for authentication, sessions, and user data

use Carp qw<carp croak>;
use JSON::PP qw< encode_json decode_json >;
use YAML;

# === COMPONENT MODULES ===
use Concierge::Auth;
use Concierge::Sessions;
use Concierge::Users;

sub new_concierge {
    my ($class) = @_;
	bless {}, $class;
}

sub build_desk ($storage_dir, $auth_file, $app_fields=[], $user_session_fields=[]) {
	my $self = Concierge->new_concierge(); 					# minimal object

	$self->{sessions}	= Concierge::Sessions->new(
		storage_dir 	=> $storage_dir,					# required
	);
	my $session_result	= $self->{sessions}->new_session(
		user_id         => '__concierge__',
		session_timeout => 'indefinite',
		admin_session   => 1,
	);
	unless ($session_result->{success}) {
		warn "build_desk: Failed to create concierge session: " . $session_result->{message};
		return;
	}
	my $session			= $session_result->{session};
	$self->{concierge_session} 		= $session;
	$self->{user_session_fields}	= $user_session_fields;	# optional, specified by app

	$self->{auth} 		=	Concierge::Auth->new ({
		file => $auth_file		 							# required
	});
	my $users_setup		= Concierge::Users->setup( {
		storage_dir 		=> $storage_dir,				# required
		backend 			=> 'database',					# use default ('database')
		include_standard_fields => 'all', 					# use standard
		field_overrides 	=> [],							# use standard
		app_fields 			=> $app_fields,					# optional, specified by app
	});
	unless ($users_setup->{success}) {
		warn "build_desk: Failed to setup Users: " . $users_setup->{message};
		return;
	}

	my $full_config	= { 
		users_config_file	=> $users_setup->{config_file},
		storage_dir 		=> $storage_dir,
		auth_file			=> $auth_file,
		user_session_fields	=> $user_session_fields,
	};
	
	my $concierge_session_data	= {
		concierge_config	=> $full_config,
		user_keys			=> {},
	};
	$session->set_data($concierge_session_data);
	my $save_result = $session->save();
	unless ($save_result->{success}) {
		warn "build_desk: Failed to save concierge session: " . $save_result->{message};
		return;
	}

	return { success => 1, message => "Ready!", desk => $storage_dir };
}

sub open_desk ($class, $desk_location) {
	croak unless -d $desk_location;
	my $instantiated_concierge	= Concierge->new_concierge(); 	# minimal object
	# Instantiate the concierge from config stored in Concierge's session data
	$instantiated_concierge->{sessions}	= Concierge::Sessions->new(
		storage_dir => $desk_location
	);

	my $concierge_session_result	= $instantiated_concierge->{sessions}->get_session('__admin_session__');
	croak "Failed to retrieve concierge session" unless $concierge_session_result->{success};
	my $concierge_session	= $concierge_session_result->{session};
	my $concierge_config	= $concierge_session->get_data()->{value}{concierge_config};
	# Instantiate users and auth from $concierge_config
	$instantiated_concierge->{concierge_session}	= $concierge_session;
	$instantiated_concierge->{users}	= Concierge::Users->new( $concierge_config->{users_config_file} );
	$instantiated_concierge->{auth}		= Concierge::Auth->new( { file => $concierge_config->{auth_file} } );

	return { success => 1, message => 'Welcome!', concierge => $instantiated_concierge };
}

# Application-specific session data access methods
# These methods work with user_session_fields declared during build_desk()

sub get_app_data {
    my ($self, $session_id, @field_names) = @_;

    # Get the session
    my $session_result = $self->{sessions}->get_session($session_id);
    return { success => 0, message => 'Session not found' } unless $session_result->{success};
    my $session = $session_result->{session};

    # Get user_session_fields from concierge session
    state $declared_fields ||= do {
		my $concierge_data = $self->{concierge_session}->get_data()->{value};
		$concierge_data->{concierge_config}{user_session_fields} // [];
    };

    # Get all session data
    my $all_data = $session->get_data()->{value};

    # If specific fields requested, return just those
    if (@field_names) {
        my %selection;
        @selection{@field_names} = @{$all_data}{@field_names};
        return \%selection;
    }

    # Otherwise return all declared fields, ensuring they exist (even if undef)
    my %app_data;
    foreach my $field ($declared_fields->@*) {
        $app_data{$field} = $all_data->{$field} // undef;
    }

    return \%app_data;
}

sub set_app_data {
    my ($self, $session_id, $new_data) = @_;

    # Get the session
    my $session_result = $self->{sessions}->get_session($session_id);
    return { success => 0, message => 'Session not found' } unless $session_result->{success};

    my $session = $session_result->{session};

    # Merge new data with existing data
    my $all_data = $session->get_data()->{value};
    $all_data = { %$all_data, %$new_data };

    # Save the updated data
    $session->set_data($all_data);
    my $save_result = $session->save();
    return { success => 0, message => 'Save failed' } unless $save_result->{success};

    # Get user_session_fields from concierge session
    state $declared_fields ||= do {
		my $concierge_data = $self->{concierge_session}->get_data()->{value};
		$concierge_data->{concierge_config}{user_session_fields} // [];
    };

	# Return the updated app data for convenience
    my %app_data;
    foreach my $field ($declared_fields->@*) {
        $app_data{$field} = $all_data->{$field} // undef;
    }

    return { success => 1, value => \%app_data };
}

# =============================================================================
# CONCIERGE STATE MANAGEMENT
# =============================================================================

# Safely update concierge session state (preserves all other data)
sub set_concierge_state ($self, $new_data) {
    my $concierge_data = $self->{concierge_session}->get_data()->{value};
    my $updated_data = { %$concierge_data, %$new_data };

    $self->{concierge_session}->set_data($updated_data);
    my $save_result = $self->{concierge_session}->save();
    return { success => 0, message => 'Failed to save concierge state' }
        unless $save_result->{success};

    return { success => 1, value => $updated_data };
}

# =============================================================================
# LOGIN AND USER_KEY SUPPORT
# =============================================================================

# Login user: authenticate, create session, store external_key mapping
sub login_user ($self, $user_id, $password, $session_opts={}) {
    # Step 1: Get user from database
    my $user_result = $self->{users}->get_user($user_id);
    return { success => 0, message => 'User not found' }
        unless $user_result->{success};

    # Step 2: Verify password
    my $auth_result = $self->{auth}->checkPwd($user_id, $password);
    return { success => 0, message => 'Authentication failed' }
        unless $auth_result;

    # Step 3: Create session with external_key (generated by Session backend)
    # Note: If user already has a session, backend will delete it (one-session-per-user)
    my $create_result = $self->{sessions}->new_session(
        user_id         => $user_id,
        session_timeout => $session_opts->{timeout} || 3600,  # default 1 hour
        %{ $session_opts->{extra} || {} },
    );
    return { success => 0, message => 'Failed to create session' }
        unless $create_result->{success};

    my $session = $create_result->{session};
    my $session_id = $session->session_id();
    my $external_key = $session->external_key();

    # Step 5: Update concierge session with external_key mapping
    my $concierge_data = $self->{concierge_session}->get_data()->{value};
    $concierge_data->{user_keys}{$external_key} = {
        user_id    => $user_id,
        session_id => $session_id,
    };
    $self->{concierge_session}->set_data($concierge_data);
    $self->{concierge_session}->save();

    # Step 6: Add user database info to session if requested
    if ($session_opts->{include_user_data}) {
        $self->user_data_to_session($user_id, $session_id);
    }

    return {
        success   => 1,
        message   => 'Login successful',
        external_key => $external_key,
        user_id   => $user_id,
        session_id => $session_id,
    };
}

# Helper: Get user_id from external_key
sub get_user_for_key ($self, $external_key) {
    my $concierge_data = $self->{concierge_session}->get_data()->{value};
    my $mapping = $concierge_data->{user_keys}{$external_key};

    return { success => 0, message => 'Invalid external_key' } unless $mapping;

    return {
        success => 1,
        user_id => $mapping->{user_id},
    };
}

# Helper: Get session_id from external_key
sub get_session_for_key ($self, $external_key) {
    my $concierge_data = $self->{concierge_session}->get_data()->{value};
    my $mapping = $concierge_data->{user_keys}{$external_key};

    return { success => 0, message => 'Invalid external_key' } unless $mapping;

    return {
        success    => 1,
        session_id => $mapping->{session_id},
    };
}

# Convenience: Add user's database record to their session data
sub user_data_to_session ($self, $user_id, $session_id) {
    # Get user from database
    my $user_result = $self->{users}->get_user($user_id);
    return { success => 0, message => 'User not found' }
        unless $user_result->{success};

    # Get session
    my $session_result = $self->{sessions}->get_session($session_id);
    return { success => 0, message => 'Session not found' }
        unless $session_result->{success};

    my $session = $session_result->{session};

    # Merge user data into session (preserving existing data)
    my $session_data = $session->get_data()->{value};
    my $updated_data = { %$session_data, %{ $user_result->{user} } };

    $session->set_data($updated_data);
    my $save_result = $session->save();

    return { success => 0, message => 'Failed to update session' }
        unless $save_result->{success};

    return { success => 1, message => 'User data added to session' };
}

1;
