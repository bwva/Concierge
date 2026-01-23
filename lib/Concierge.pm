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

1;
