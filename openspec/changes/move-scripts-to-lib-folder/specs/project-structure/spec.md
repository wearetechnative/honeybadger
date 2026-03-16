# project-structure Capability

## ADDED Requirements

### Requirement: Library Directory Organization
The project SHALL organize helper scripts and library files in a dedicated `lib/` directory separate from the main entry point.

#### Scenario: Helper scripts in lib directory
- **WHEN** project contains helper scripts (check-os-status.sh, fetch-os-releases.sh, etc.)
- **THEN** these scripts SHALL be located in `lib/` directory
- **AND** main entry point (RUNME.sh) SHALL remain in project root

#### Scenario: Library file organization
- **WHEN** project uses a library file (_library)
- **THEN** library file SHALL be located in `lib/` directory
- **AND** main script SHALL source from `lib/_library`

#### Scenario: Scripts maintain functionality after move
- **WHEN** scripts are moved to lib/ directory
- **THEN** all script functionality SHALL remain unchanged
- **AND** executable permissions SHALL be maintained
- **AND** scripts SHALL be callable as `./lib/scriptname.sh`

#### Scenario: Cross-script references updated
- **WHEN** one script references another script
- **THEN** references SHALL use correct relative paths
- **AND** scripts SHALL successfully find and execute dependencies

### Requirement: Main Entry Point Accessibility
The main user-facing entry point SHALL remain easily accessible in the project root.

#### Scenario: RUNME.sh stays in root
- **WHEN** user clones repository
- **THEN** RUNME.sh SHALL be visible in root directory
- **AND** user can execute `./RUNME.sh` without navigating to subdirectories

#### Scenario: Main workflow unchanged
- **WHEN** user runs `./RUNME.sh audit` or `./RUNME.sh check-output`
- **THEN** commands SHALL work identically to before lib/ reorganization
- **AND** no user-visible behavior changes occur

### Requirement: Documentation Accuracy
Project documentation SHALL accurately reflect the new directory structure.

#### Scenario: Documentation updated for lib directory
- **WHEN** documentation references script paths
- **THEN** paths SHALL point to lib/ directory for helper scripts
- **AND** examples SHALL show correct usage (e.g., `./lib/check-os-status.sh`)

#### Scenario: Migration guidance provided
- **WHEN** users have existing automation calling scripts directly
- **THEN** documentation SHALL provide clear migration path
- **AND** breaking changes SHALL be clearly documented

### Requirement: Git History Preservation
The reorganization SHALL preserve git history for moved files.

#### Scenario: File history maintained
- **WHEN** files are moved to lib/ directory
- **THEN** git history SHALL be preserved using `git mv`
- **AND** `git log --follow lib/filename` SHALL show complete history
