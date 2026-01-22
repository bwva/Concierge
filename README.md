# Concierge

Service layer orchestrator for authentication, session management, and user data operations.

## VERSION

Version 0.1.0 (Under Active Development)

## STATUS

**This is a complete rewrite in progress.** No backward compatibility with previous Local::App::Concierge versions.

## DESCRIPTION

Concierge provides a unified API integrating three component modules:

- **Concierge::Auth** - Authentication with Argon2 password hashing
- **Concierge::Sessions** - Session management (SQLite, PostgreSQL, Text backends)
- **Concierge::Users** - User data operations (Database, CSV/TSV, YAML backends)

Concierge coordinates the setup and configuration of these components, then provides a single interface for all operations. Applications using Concierge need only interact with its API - no direct contact with component modules required.

## INSTALLATION

Currently in development. Installation instructions will be added when the module is ready for CPAN.

## PROJECT STRUCTURE

```
Concierge/
├── lib/
│   └── Concierge.pm          # Main orchestration module
├── t/                        # Integration test suite
├── examples/                 # Usage examples
└── README.md                # This file
```

## DEVELOPMENT NOTES

### Current Phase

Starting fresh with minimal implementation. Initial focus is on:

1. Documentation and evolving TODO list
2. Component setup coordination methods
3. Integration testing for component combinations

### Component Configuration

Each component has its own setup requirements that Concierge coordinates:

- **Auth**: Password file path
- **Sessions**: Storage directory, backend type, timeout settings
- **Users**: Storage directory, backend type, field definitions

Concierge will eventually provide a unified configuration interface that allows components to self-disclose their requirements and options.

### Testing Strategy

Since all three components have their own comprehensive test suites, Concierge tests focus on:

- Setup coordination (configuring components correctly)
- Cross-component workflows (e.g., authenticate → create session → fetch user data)
- Error handling across components
- Component combinations (apps may use any 1, 2, or all 3 components)

## RELATED MODULES

- Concierge::Auth
- Concierge::Sessions
- Concierge::Users

## AUTHOR AND LICENSE

Copyright and license information to be added.

## CONTRIBUTING

This is currently in early development. Contribution guidelines will be added when the module stabilizes.
