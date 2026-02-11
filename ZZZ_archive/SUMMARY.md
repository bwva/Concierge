# Concierge Storage Formats Demo - Summary

## What Was Accomplished

Created comprehensive example scripts demonstrating all file and configuration formats used by Concierge and its component modules (Auth, Sessions, Users).

## Fixes Applied

### 1. Concierge Session Timeout (lib/Concierge.pm)
- **Fixed**: Changed `timeout => 'indefinite'` to `session_timeout => 'indefinite'` (line 275)
- **Result**: Concierge internal session now correctly stores 'indefinite' for session_timeout and expires_at

### 2. Session ID Extraction (lib/Concierge.pm)
- **Fixed**: Changed `session_id => $result->{session_id}` to `session_id => $result->{session}{session_id}` (line 284)
- **Result**: Concierge session_id is now properly extracted and stored in config

### 3. Users Config File Parameter (lib/Concierge.pm)
- **Fixed**: Added check for `users_config_file` parameter in setup() method (lines 104-106)
- **Fixed**: Updated load() to check for both `users_config_file` and `config_file` (lines 197-199)
- **Result**: Users component configuration is now properly saved and loaded

### 4. Sessions Backend Parameter (lib/Concierge.pm)
- **Fixed**: Changed load() to check for `backend` instead of `sessions_backend` (line 183)
- **Result**: Sessions component now uses correct backend (SQLite or File) when loading from config

## Demo Scripts Created

### storage_formats_demo.pl
Creates 4 separate Concierge instances with different backend configurations:
- **desk1**: SQLite sessions + Database users (default)
- **desk2**: File sessions + File users (all file storage)
- **desk3**: SQLite sessions + YAML users (mixed)
- **desk4**: File sessions + Database users (hybrid)

Each instance creates:
- 4 auth entries (alice, bob, carol, dave) with Argon2id encrypted passwords
- 4 user records in Users component
- 4 user sessions (one per user, with alice's being replaced when she logs in from mobile)
- 1 Concierge internal session with 'indefinite' timeout

### show_file_contents.pl
Displays the actual contents of generated files:
- Concierge config files (JSON and YAML)
- Auth password file (tab-separated format)
- Users config files (JSON and YAML)
- SQLite database contents (concierge and user sessions)
- File-based session files (JSON format)
- TSV user files

## Session Records Displayed

### SQLite Backend (desk1, desk3, desk4)
**Concierge Internal Session:**
- user_id: `__concierge_id__`
- session_timeout: `indefinite` ✓
- expires_at: `indefinite` ✓

**App User Sessions:** (4 sessions)
- alice, bob, carol, dave
- session_timeout: `3600` (1 hour)
- Individual session IDs and timestamps

### File Backend (desk2)
**Session Files:** (4 JSON files)
- One per session (UUID filename)
- Contains: session_id, user_id, created_at, expires_at, session_timeout, data, status
- Example:
  ```json
  {
    "session_id": "299662f6-1b82-4811-8c5c-96b1829fef76",
    "user_id": "bob",
    "session_timeout": "3600",
    "created_at": 1769062145,
    "expires_at": 1769065745,
    "data": {
      "username": "bob",
      "login_time": 1769062145,
      "preferences": {"lang": "en", "theme": "light"}
    }
  }
  ```

## File Formats Documented

### Concierge Config
- `concierge.json` - Machine-readable (JSON)
- `concierge.yaml` - Human-readable (YAML)

### Auth Component
- `auth.pwd` - Tab-separated: `user_id<TAB>encrypted_password<TAB>|`
  - Argon2id encryption with Bcrypt fallback

### Sessions Component
- **SQLite backend**: `sessions.db` (SQLite database)
  - Tables: session_id, user_id, created_at, expires_at, session_timeout, status, data
- **File backend**: `{uuid}` files (JSON)
  - One file per session with complete session data

### Users Component
- `users-config.json` - Machine-readable configuration
- `users-config.yaml` - Human-readable configuration
- **Database backend**: `users.db` (SQLite)
- **File backend**: `users.tsv` (Tab-separated values)
- **YAML backend**: `users.yaml` (YAML format)

## Usage

```bash
cd examples

# Generate all storage examples
perl storage_formats_demo.pl

# View file contents
perl show_file_contents.pl

# Clean up and start fresh
rm -rf storage/
perl storage_formats_demo.pl
```

## Storage Structure

```
examples/storage/
├── desk1/  (SQLite + Database)
│   ├── concierge.json/yaml
│   ├── auth.pwd
│   ├── concierge-internal/sessions.db
│   ├── sessions/sessions.db
│   └── users/users.db + users-config.json/yaml
├── desk2/  (File + File)
│   ├── concierge.json/yaml
│   ├── auth.pwd
│   ├── concierge-internal/{uuid}.json
│   ├── sessions/{uuid}.json (4 files)
│   └── users/users.tsv + users-config.json/yaml
├── desk3/  (SQLite + YAML)
│   └── ... (SQLite sessions, YAML users)
└── desk4/  (File + Database)
    └── ... (File sessions, Database users)
```

All storage is persistent and located in the `examples/storage/` directory as requested.
