# Capability: audit-output

Generated audit artifacts (tarballs, output directories) must be owned by the actual user who invoked the audit, not root.

## ADDED Requirements

### Requirement: Output Files MUST Be Owned By Actual User

When running audit with sudo, all generated files SHALL be owned by the actual user, not root.

#### Scenario: Tarball owned by actual user after audit

**Given** a user runs `sudo ./RUNME.sh audit`
**When** the audit completes and creates a tarball
**Then** the tarball file must be owned by the actual user (from SUDO_USER), not root
**And** the user can read, modify, and delete the tarball without sudo

#### Scenario: Output directory owned by actual user after audit

**Given** a user runs `sudo ./RUNME.sh audit`
**When** the audit completes and creates an output directory
**Then** the output directory must be owned by the actual user (from SUDO_USER), not root
**And** all files within the output directory should be accessible by the user
**And** the user can delete the output directory without sudo

#### Scenario: Files created by user without sudo remain user-owned

**Given** a user runs `./RUNME.sh audit` without sudo (if permitted)
**When** the audit completes
**Then** all generated files are already owned by the user
**And** no ownership changes are necessary
