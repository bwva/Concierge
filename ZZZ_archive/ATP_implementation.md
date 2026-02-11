# AT Protocol Implementation for Concierge

## Overview

This document explores integrating AT Protocol (Authenticated Transfer Protocol) as an optional identity provider for applications using Concierge, while maintaining backward compatibility with traditional authentication.

## What is AT Protocol?

The AT Protocol is a decentralized protocol developed by Bluesky for social networking and data management. Key features relevant to identity management:

1. **Personal Data Repositories (PDRs)** - Each user controls their own data repository
2. **DIDs (Decentralized Identifiers)** - Portable identity users own (did:plc or did:web)
3. **Lexicons** - Strongly-typed schemas for data records
4. **Data portability** - Users can migrate their data between providers
5. **OAuth 2.0** - Modern authentication with DPoP (Demonstrating Proof-of-Possession)

## How AT Protocol Serves Applications

**Three architectural components**:

1. **Identity/Authentication** - Users sign in with their AT Protocol DID (like `alice.bsky.social` or `did:plc:xyz`)
   - App initiates OAuth flow, user authorizes at their PDS
   - App receives access tokens (15 min lifetime) + refresh tokens (2 year lifecycle)
   - Replaces username/password in app database

2. **Data Storage** - User data lives in their Personal Data Repository, not app database
   - App reads/writes records to their PDR using their access token
   - Data is schema-validated using Lexicons (strongly-typed)
   - Users can migrate their data between providers

3. **Session Management** - DPoP tokens with cryptographic keypairs
   - Each session has unique keypair
   - Auto-refreshing credentials
   - Users can revoke app access from their PDS settings

## Comparison: Concierge vs AT Protocol

| Component | Concierge (current) | AT Protocol Approach |
|-----------|---------------------|----------------------|
| **User Identity** | Internal user records | DID (portable identity) |
| **Authentication** | Gatekeeper system | OAuth to user's PDS |
| **User Data** | App database | User's PDR (they own it) |
| **Sessions** | user_key tokens | DPoP access/refresh tokens |
| **Data Control** | App hosts & controls | User controls, can migrate |

**Key question**: Does the app need to **own** the user data, or could users **own** their data?

## Integration Patterns

### Pattern 1: AT Protocol as Identity Provider Only (RECOMMENDED)
- Users sign in with Bluesky/AT Protocol DID
- App still stores application data in its database
- Session management: Convert AT Protocol access token → app's user_key
- **Benefit**: Users don't need another password
- **Concierge role**: Same as now, but authentication delegates to PDS

### Pattern 2: Hybrid Storage
- User identity via AT Protocol DIDs
- Critical app data in their PDR (user owns it)
- Operational data in app database (queries, caching)
- **Benefit**: User data portability
- **Concierge role**: Manages AT Protocol sessions + app's operational data

### Pattern 3: Full AT Protocol
- Everything stored in user PDRs with custom Lexicons
- App is stateless service that reads/writes to their PDR
- **Benefit**: Pure decentralization
- **Challenge**: Query performance, aggregation across users
- **Concierge role**: Might be replaced entirely by AT Protocol session management

## Perl Implementation Status

### Available CPAN Modules

**At.pm** - Core AT Protocol implementation
- OAuth support: ✅ **Implemented and recommended**
- Methods: `oauth_start()`, `oauth_callback()`, session resumption
- Supports DPoP (Demonstrating Proof-of-Possession)
- Modern Perl class system
- GitHub: https://github.com/sanko/At.pm
- Note: Legacy password auth still available but deprecated

**Bluesky** (v0.20) - Higher-level Bluesky client
- Built on AT Protocol
- MetaCPAN: https://metacpan.org/dist/Bluesky

**App::bsky** - Command-line client
- Example implementation showing session handling
- MetaCPAN: https://metacpan.org/dist/App-bsky

**Status**: At.pm has OAuth implemented as of 2024-2025. OAuth is noted as "not currently recommended for headless clients (CLI tools, bots)" but should work fine for web applications.

## Sample Implementation: Pattern 1

### Module: Concierge::Auth::ATProtocol

```perl
package Concierge::Auth::ATProtocol;
use v5.36;
use At;
use Params::Filter qw(filter);

# Configuration
my $CLIENT_ID = 'https://yourapp.example.com/client-metadata.json';
my $REDIRECT_URI = 'https://yourapp.example.com/auth/atproto/callback';

sub new ($class, %args) {
    my $params = filter(
        \%args,
        required => [qw(concierge_db)],
        optional => [qw(client_id redirect_uri)],
    );

    return bless {
        db => $params->{concierge_db},
        client_id => $params->{client_id} // $CLIENT_ID,
        redirect_uri => $params->{redirect_uri} // $REDIRECT_URI,
    }, $class;
}

# Step 1: Initiate OAuth flow
sub initiate_login ($self, $user_handle) {
    # user_handle is like 'alice.bsky.social' or 'did:plc:xyz123'

    my $at = At->new();

    # Start OAuth authorization
    my $auth_url = $at->oauth_start(
        client_id => $self->{client_id},
        redirect_uri => $self->{redirect_uri},
        scope => 'atproto',  # Basic identity scope
        handle => $user_handle,
    );

    # Store the AT session temporarily (for callback verification)
    my $state = $at->oauth_state();  # CSRF protection token
    $self->_store_pending_auth($state, $at);

    return {
        auth_url => $auth_url,
        state => $state,
    };
}

# Step 2: Handle OAuth callback
sub handle_callback ($self, $code, $state) {
    # Retrieve the pending AT session
    my $at = $self->_retrieve_pending_auth($state)
        or die "Invalid or expired state token";

    # Complete the OAuth flow
    my $session = $at->oauth_callback(
        code => $code,
        state => $state,
    );

    # Extract user identity
    my $did = $session->did();  # e.g., 'did:plc:abc123xyz'
    my $handle = $session->handle();  # e.g., 'alice.bsky.social'

    # Get or create Concierge user record
    my $user = $self->_get_or_create_user(
        did => $did,
        handle => $handle,
        at_session => $session,
    );

    # Generate Concierge user_key for this session
    my $user_key = $self->_generate_user_key($user->{user_id});

    # Store session mapping
    $self->_store_session(
        user_key => $user_key,
        user_id => $user->{user_id},
        did => $did,
        at_refresh_token => $session->refresh_token(),  # For future re-auth
    );

    return {
        user_key => $user_key,
        user_id => $user->{user_id},
        did => $did,
        handle => $handle,
    };
}

# Step 3: Verify user_key and optional AT token refresh
sub verify_session ($self, $user_key) {
    my $session = $self->_get_session($user_key)
        or return undef;

    # Standard Concierge session verification
    if ($self->_is_session_valid($session)) {
        return {
            user_id => $session->{user_id},
            did => $session->{did},
            handle => $session->{handle},
        };
    }

    # If AT Protocol user, optionally refresh their AT token
    if ($session->{did} && $session->{at_refresh_token}) {
        return $self->_refresh_at_session($session);
    }

    return undef;
}

# Helper: Get or create user in Concierge DB
sub _get_or_create_user ($self, %args) {
    my $params = filter(
        \%args,
        required => [qw(did handle)],
        optional => [qw(at_session)],
    );

    # Check if DID already exists
    my $user = $self->{db}->get_user_by_did($params->{did});

    if ($user) {
        # Update handle if changed
        $self->{db}->update_user(
            user_id => $user->{user_id},
            handle => $params->{handle},
        );
        return $user;
    }

    # Create new user record
    return $self->{db}->create_user(
        auth_type => 'atprotocol',
        did => $params->{did},
        handle => $params->{handle},
        created_at => time(),
    );
}

# Helper: Generate Concierge user_key (existing method)
sub _generate_user_key ($self, $user_id) {
    # Existing user_key generation logic
    # e.g., HMAC-SHA256 of user_id + timestamp + secret
    use Digest::SHA qw(hmac_sha256_hex);
    my $timestamp = time();
    my $secret = $self->{db}->get_secret();

    return hmac_sha256_hex("$user_id:$timestamp", $secret);
}

# Helper: Store session (existing method, extended)
sub _store_session ($self, %args) {
    my $params = filter(
        \%args,
        required => [qw(user_key user_id)],
        optional => [qw(did at_refresh_token)],
    );

    $self->{db}->store_session(
        user_key => $params->{user_key},
        user_id => $params->{user_id},
        did => $params->{did},
        at_refresh_token => $params->{at_refresh_token},
        expires_at => time() + 86400,  # 24 hours
    );
}

# Helper: Temporarily store pending auth (in-memory or Redis)
sub _store_pending_auth ($self, $state, $at_session) {
    # Store for ~10 minutes (OAuth callback window)
    # Could use Cache::FastMmap, Redis, or database
    $self->{db}->store_temp(
        key => "atproto_auth:$state",
        value => $at_session,
        ttl => 600,
    );
}

sub _retrieve_pending_auth ($self, $state) {
    return $self->{db}->get_temp("atproto_auth:$state");
}

1;
```

### Usage in Web Application

```perl
# In your web app controller

use Concierge::Auth::ATProtocol;

my $at_auth = Concierge::Auth::ATProtocol->new(
    concierge_db => $concierge->db,
    client_id => 'https://myapp.com/client-metadata.json',
    redirect_uri => 'https://myapp.com/auth/callback',
);

# Login page offers two options:
# 1. Traditional username/password
# 2. "Sign in with Bluesky" button

# When user clicks "Sign in with Bluesky"
post '/auth/atproto/start' => sub {
    my $handle = param('handle');  # User enters their handle

    my $result = $at_auth->initiate_login($handle);

    # Redirect user to Bluesky authorization page
    redirect $result->{auth_url};
};

# OAuth callback endpoint
get '/auth/atproto/callback' => sub {
    my $code = param('code');
    my $state = param('state');

    my $result = $at_auth->handle_callback($code, $state);

    # Set user_key cookie (same as traditional auth)
    cookie user_key => $result->{user_key}, {
        expires => '+1d',
        http_only => 1,
        secure => 1,
    };

    # Redirect to app
    redirect '/dashboard';
};

# Session verification works the same for both auth methods
before sub {
    my $user_key = cookie('user_key');
    my $session = $at_auth->verify_session($user_key);

    unless ($session) {
        redirect '/login';
    }

    var user_id => $session->{user_id};
    var did => $session->{did};  # Only present for AT Protocol users
};
```

## Database Schema Extension

Add to existing Concierge user table:

```sql
ALTER TABLE users ADD COLUMN auth_type VARCHAR(20) DEFAULT 'traditional';
ALTER TABLE users ADD COLUMN did VARCHAR(255) UNIQUE;
ALTER TABLE users ADD COLUMN handle VARCHAR(255);

ALTER TABLE sessions ADD COLUMN at_refresh_token TEXT;

CREATE INDEX idx_users_did ON users(did);
```

## Client Metadata File

Host a JSON file at your `client_id` URL (e.g., `https://yourapp.com/client-metadata.json`):

```json
{
  "client_id": "https://yourapp.com/client-metadata.json",
  "client_name": "Your App Name",
  "client_uri": "https://yourapp.com",
  "redirect_uris": [
    "https://yourapp.com/auth/atproto/callback"
  ],
  "scope": "atproto",
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "none",
  "application_type": "web",
  "dpop_bound_access_tokens": true
}
```

## Key Benefits of Pattern 1 Approach

1. **Optional** - Traditional auth still works
2. **Transparent** - user_key system unchanged for apps
3. **Portable identity** - Users bring their AT Protocol DID
4. **No password storage** - For AT Protocol users
5. **Fallback ready** - If At.pm OAuth isn't stable, easy to disable
6. **Backward compatible** - Existing Concierge users unaffected

## Implementation Steps

1. Install At.pm: `cpan At` or `cpanm At`
2. Test OAuth flow in development environment
3. Create and host client metadata JSON file
4. Extend database schema with DID fields
5. Implement Concierge::Auth::ATProtocol module
6. Add "Sign in with Bluesky" UI option to login page
7. Monitor At.pm updates for OAuth stability
8. Test with real Bluesky accounts
9. Document setup for app developers using Concierge

## Technical Considerations

### Session Lifetime
- AT Protocol access tokens: 15 minutes
- AT Protocol refresh tokens: 2 years
- Concierge user_key: Configurable (suggest 24 hours)
- Strategy: Use Concierge session as primary, refresh AT token only when needed for PDS access

### Token Storage
- Store AT refresh tokens securely (encrypted at rest)
- Never store access tokens (request fresh via refresh token)
- Clean up expired sessions regularly

### Error Handling
- AT Protocol PDS unavailable during login
- OAuth callback timeout or failure
- Token refresh failures
- Handle migration (user changes handle)
- DID resolution failures

### Security
- Validate OAuth state parameter (CSRF protection)
- Verify DPoP tokens properly
- Secure storage of client secrets (if confidential client)
- Rate limit OAuth attempts
- Monitor for suspicious authorization patterns

## OAuth Technical Details

### Authentication Flow

1. User enters their handle (e.g., `alice.bsky.social`)
2. App resolves handle to DID and PDS location
3. App initiates OAuth authorization with user's PDS
4. User approves at their PDS
5. PDS redirects back with authorization code
6. App exchanges code for access token + refresh token
7. App verifies DPoP binding
8. App creates Concierge session

### DPoP (Demonstrating Proof-of-Possession)

- Each OAuth session generates unique cryptographic keypair
- Access tokens bound to specific keypair
- Prevents token theft and replay attacks
- At.pm handles DPoP automatically

### Token Refresh

```perl
sub _refresh_at_session ($self, $session) {
    my $at = At->new();

    # Load session with refresh token
    $at->resume_session(
        refresh_token => $session->{at_refresh_token},
    );

    # Get new access token
    my $new_session = $at->refresh();

    # Update stored session
    $self->{db}->update_session(
        user_key => $session->{user_key},
        at_refresh_token => $new_session->refresh_token(),
    );

    return {
        user_id => $session->{user_id},
        did => $new_session->did(),
        handle => $new_session->handle(),
    };
}
```

## Testing Strategy

### Unit Tests
- OAuth flow initiation
- Callback handling with valid/invalid codes
- Session creation and verification
- Token refresh logic
- Error conditions

### Integration Tests
- Full OAuth flow with test PDS
- Session persistence across requests
- Concurrent login attempts
- Token expiration and refresh
- Fallback to traditional auth

### Manual Testing
- Real Bluesky account login
- Handle changes and migration
- Multiple devices/sessions
- Revocation from PDS settings
- Network failures during OAuth

## Future Enhancements

### Phase 2: Hybrid Storage
- Store user preferences in their PDR
- Define custom Lexicons for app data
- Sync between app database and PDR
- Allow users to export their data

### Phase 3: Federation
- Discover other users via AT Protocol
- Cross-app data sharing (with permission)
- Integration with Bluesky social graph
- Custom feeds and notifications

## Resources

### AT Protocol Documentation
- Official site: https://atproto.com/
- Quick start guide: https://atproto.com/guides/applications
- OAuth spec: https://atproto.com/specs/oauth
- OAuth guide: https://atproto.com/guides/oauth

### Bluesky Documentation
- OAuth for AT Protocol: https://docs.bsky.app/blog/oauth-atproto
- OAuth improvements: https://docs.bsky.app/blog/oauth-improvements
- OAuth client implementation: https://docs.bsky.app/docs/advanced-guides/oauth-client
- 2025 protocol roadmap: https://docs.bsky.app/blog/2025-protocol-roadmap-spring
- Protocol check-in (Fall 2025): https://docs.bsky.app/blog/protocol-checkin-fall-2025

### Perl Resources
- At.pm GitHub: https://github.com/sanko/At.pm
- Bluesky on CPAN: https://metacpan.org/dist/Bluesky
- App::bsky on CPAN: https://metacpan.org/dist/App-bsky

### Other Implementations
- AT Protocol discussions: https://github.com/bluesky-social/atproto/discussions
- OAuth roadmap: https://github.com/bluesky-social/atproto/discussions/2656
- Auth scopes progress: https://github.com/bluesky-social/atproto/discussions/4118

## Notes

- OAuth implementation in At.pm appears to be relatively new (2024-2025 timeframe)
- AT Protocol OAuth is in developer preview but being actively deployed
- Not recommended for headless clients (CLI tools, bots) but suitable for web apps
- Granular permissions (auth scopes) rolled out August 2025, may not be in At.pm yet
- Monitor At.pm repository for updates and stability improvements

## Decision Points

Before implementing, decide:

1. **Scope**: Identity only (Pattern 1) or data storage (Pattern 2/3)?
2. **Requirement**: Optional feature or mandatory migration path?
3. **Fallback**: How to handle At.pm instability or AT Protocol outages?
4. **Migration**: How to handle existing users who want to link AT identity?
5. **Data ownership**: What data lives in app DB vs user PDRs?
6. **Testing**: Resources available for thorough OAuth testing?

## Recommendation

Start with **Pattern 1** (identity provider only) as:
- Lowest risk (traditional auth remains)
- Clear user benefit (no new password)
- Limited code changes to Concierge
- Easy to extend to Patterns 2/3 later
- Provides experience with AT Protocol before deeper integration

---

*Document created: 2026-01-28*
*Context: Exploration of AT Protocol integration for Concierge user authentication*
