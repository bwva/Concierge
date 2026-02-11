# Concierge Architecture Notes

## Password Reset Architecture (Revised 2026-01-28)

### Key Principle: Application Controls Policy, Concierge Provides Operations

The `reset_password()` methods were revised to correctly separate concerns:

**Concierge's Responsibility:**
- Provide the operation: Set a new password for a user
- Validate basic inputs (user_id exists, password not empty)
- Pass through Auth component error messages

**Application's Responsibility:**
- Verify user identity (via session/user_key, email token, admin privileges, etc.)
- Decide whether to verify old password (web form) or not (email reset, admin action)
- Call Concierge's `reset_password()` only after policy checks pass

### API Signatures

```perl
# Core method - accepts user_id
$concierge->reset_password($user_id, $new_password)

# Wrapper method - accepts user_key (for logged-in users)
$concierge->reset_password_for_key($user_key, $new_password)
```

### Application Workflow Examples

**1. Web Form with Old Password Verification**
```perl
# User submits old_password + new_password via web form
# Application decides: verify old password before reset

my ($old_pwd_ok, $msg) = $concierge->{auth}->checkPwd($user_id, $old_password);
if (!$old_pwd_ok) {
    return { error => "Incorrect current password" };
}

# Old password verified, now reset
my $result = $concierge->reset_password_for_key($user_key, $new_password);
```

**2. Email-Based Password Reset**
```perl
# User clicks "Forgot Password"
# Application emails reset link with token
# User clicks link and enters new_password only
# Application decides: no old password needed (token verifies identity)

my $user_id = verify_reset_token($token);  # App's token verification
if (!$user_id) {
    return { error => "Invalid or expired reset link" };
}

# Token verified, reset password directly
my $result = $concierge->reset_password($user_id, $new_password);
```

**3. Admin Password Reset**
```perl
# Admin selects user and enters new_password
# Application decides: admin authority sufficient, no old password needed

if (!is_admin($current_user)) {
    return { error => "Unauthorized" };
}

# Admin verified, reset password directly
my $result = $concierge->reset_password($target_user_id, $new_password);
```

### Benefits of This Architecture

1. **Flexibility**: Applications can implement any password reset policy without Concierge changes
2. **Separation of Concerns**: Concierge handles data operations, application handles policy
3. **Simpler API**: Fewer parameters, clearer purpose
4. **No Assumptions**: Concierge doesn't assume how applications verify user identity
5. **Multiple Workflows**: Same API supports web forms, email resets, admin actions, etc.

### Why Not Include Old Password Verification?

Originally, `reset_password()` accepted and verified the old password. This was incorrect because:

1. **Users don't call Concierge directly** - The application sits between user and Concierge
2. **Different workflows need different verification** - Web forms verify old password, email resets don't
3. **Application controls authentication flow** - The app decides when/how to verify identity
4. **Concierge can't know policy** - Whether to require old password is application policy

The application is already responsible for verifying user identity (they have a valid session). 
Whether to also verify the old password is just another policy decision the application makes.

