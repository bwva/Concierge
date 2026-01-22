# Concierge Examples

This directory contains example scripts demonstrating the Concierge service layer and its component modules.

## Current Examples

### storage_formats_demo.pl

Demonstrates the file and configuration formats used by Concierge and its component modules (Auth, Sessions, Users) with various backend configurations.

**What it does:**
- Creates 4 separate Concierge instances in `storage/desk1/` through `storage/desk4/`
- Each instance uses different backend combinations (SQLite, Database, File, YAML)
- Performs basic operations (create users, create sessions)
- Lists all generated files with sizes

**Backend configurations demonstrated:**
- **desk1**: SQLite + Database backends (default)
- **desk2**: File-based backends (all file storage)
- **desk3**: SQLite sessions + YAML users (mixed)
- **desk4**: File sessions + Database users (hybrid)

**Usage:**
```bash
cd examples
perl storage_formats_demo.pl
```

**Output:**
Creates persistent storage in `./storage/` directory with the following structure:
```
storage/
├── desk1/
│   ├── concierge.json          # Machine-readable config
│   ├── concierge.yaml          # Human-readable config
│   ├── auth.pwd                # Password file (tab-separated)
│   ├── concierge-internal/     # Concierge's internal session
│   │   └── sessions.db         # SQLite database
│   └── users/
│       ├── users-config.json   # Users component config
│       ├── users-config.yaml   # Human-readable config
│       └── users.db            # User data (SQLite)
├── desk2/
│   ├── concierge.json
│   ├── concierge.yaml
│   ├── auth.pwd
│   ├── concierge-internal/
│   │   └── {uuid}.json         # Session files (JSON)
│   └── users/
│       ├── users-config.json
│       ├── users-config.yaml
│       └── users.tsv           # User data (tab-separated)
├── desk3/
│   └── ... (SQLite sessions + YAML users)
└── desk4/
    └── ... (File sessions + Database users)
```

### show_file_contents.pl

Displays the actual contents of key files created by `storage_formats_demo.pl` to show the formats used by Concierge and its components.

**What it does:**
- Shows parsed and formatted content of config files
- Displays password file format
- Shows TSV file format
- Displays JSON and YAML structures

**Usage:**
```bash
cd examples
perl show_file_contents.pl
```

## File Format Reference

### Concierge Configuration Files

**concierge.json** - Machine-readable configuration:
```json
{
   "version": "v0.1.0",
   "generated": 1769059504,
   "components_configured": ["auth", "sessions", "users"],
   "concierge": {
      "backend": "SQLite",
      "storage_dir": "./storage/desk1/concierge-internal"
   },
   "auth": {
      "auth_file": "./storage/desk1/auth.pwd"
   },
   "sessions": {
      "backend": "SQLite",
      "storage_dir": "./storage/desk1/sessions",
      "session_timeout": 7200
   },
   "users": {
      "users_backend": "database",
      "users_storage_dir": "./storage/desk1/users",
      "users_config_file": "./storage/desk1/users/users-config.json"
   }
}
```

**concierge.yaml** - Human-readable configuration (same structure in YAML format)

### Auth Component

**auth.pwd** - Password file:
- Format: Tab-separated values
- Fields: `user_id<TAB>encrypted_password<TAB>|`
- Encryption: Argon2id (with Bcrypt validation support)
- Permissions: 0600 (owner read/write only)
- Example:
  ```
  alice	$argon2id$v=19$m=262144,t=3,p=1$...	|
  bob	$argon2id$v=19$m=262144,t=3,p=1$...	|
  ```

### Sessions Component

**SQLite backend** (`sessions.db`):
- Binary SQLite database
- Contains session records in structured tables
- Supports indexes and efficient queries
- View with: `sqlite3 sessions.db`

**File backend** (`.json` files):
- JSON files, one per session
- Filename: `{session_uuid}.json`
- Format:
  ```json
  {
     "session_id": "uuid-string",
     "user_id": "alice",
     "created": 1769059504,
     "expires": 1769066704,
     "data": {
        "username": "alice",
        "preferences": { "theme": "dark" }
     }
  }
  ```

### Users Component

**users-config.json** - Machine-readable configuration:
```json
{
   "version": "v0.7.0",
   "generated": "2026-01-22 05:25:04",
   "backend_module": "Concierge::Users::Database",
   "backend_config": {
      "db_file": "users.db",
      "storage_dir": "./storage/desk1/users"
   },
   "fields": ["user_id", "moniker", "email", ...],
   "field_definitions": { ... }
}
```

**users-config.yaml** - Human-readable configuration (custom YAML format)

**Database backend** (`users.db`):
- SQLite database with user records
- Table name: `users`
- Supports SQL queries and indexes

**File backend** (`users.tsv`):
- Tab-separated values file
- First line: Field names (headers)
- Subsequent lines: User records
- Example:
  ```
  user_id	moniker	user_status	email	created_date
  alice	alice_w	Eligible	alice@example.com	2026-01-22 05:25:04
  bob	bobby	OK	bob@example.com	2026-01-22 05:25:05
  ```

**YAML backend** (`users_YYYYMMDD_HHMMSS/users.yaml`):
- YAML format user records
- Timestamped directory for versioning
- Human-readable and editable

## Component Integration

Concierge provides a unified service layer that integrates:

1. **Concierge::Auth** - Authentication and password management
   - Argon2id password encryption
   - User ID and password validation
   - Password file management

2. **Concierge::Sessions** - Session management
   - SQLite backend for high-performance applications
   - File backend for simple file-based storage
   - User sessions with expiration and data storage

3. **Concierge::Users** - User data management
   - Database backend (SQLite) - structured queries
   - File backend (TSV) - simple tab-separated format
   - YAML backend - human-readable format
   - Field validation and type checking

## Running the Examples

1. **Generate example storage:**
   ```bash
   cd /Volumes/Main/Development/Repositories/Concierge/examples
   perl storage_formats_demo.pl
   ```

2. **View file contents:**
   ```bash
   perl show_file_contents.pl
   ```

3. **Examine generated files:**
   ```bash
   ls -R storage/
   cat storage/desk1/concierge.yaml
   cat storage/desk1/auth.pwd
   ```

4. **Clean up and start fresh:**
   ```bash
   rm -rf storage/
   perl storage_formats_demo.pl
   ```

## Notes

- All storage is persistent in the `./storage/` directory
- Each "desk" is independent and can be used separately
- The scripts demonstrate working Concierge instances, not just empty files
- Config files are saved in both JSON (machine-readable) and YAML (human-readable) formats
- Concierge maintains its own internal session separate from application user sessions

## See Also

- L<Concierge> - Main service layer module
- L<Concierge::Auth> - Authentication component
- L<Concierge::Sessions> - Session management component
- L<Concierge::Users> - User data management component
