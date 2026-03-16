# Change: Move Shell Scripts to lib/ Folder

## Why
Currently, the project has multiple `.sh` scripts and the `_library` file scattered in the root directory:
- `check-os-status.sh` (36K)
- `check-os-updates.sh` (17K)
- `fetch-os-releases.sh` (3.0K)
- `lynis-report-parser.sh` (4.6K)
- `_library` (functions library)

This creates several issues:
1. **Cluttered root directory**: Makes it harder to find the main entry point (RUNME.sh)
2. **Poor organization**: No clear separation between main scripts and helper scripts
3. **Unclear hierarchy**: Users may not understand which scripts are meant to be called directly
4. **Maintenance difficulty**: Harder to manage and update related scripts
5. **Discoverability**: New contributors struggle to understand project structure

Moving scripts to a dedicated `lib/` folder provides:
- Clear separation of concerns (main entry point vs library code)
- Professional project structure (common in Unix/Linux tools)
- Easier maintenance and navigation
- Better alignment with the existing `_library` concept

## What Changes
- Create new `lib/` directory in project root
- Move all `.sh` scripts (except RUNME.sh) to `lib/`
- Move `_library` file to `lib/`
- Update all references to moved scripts:
  - RUNME.sh sourcing of `_library` → `lib/_library`
  - Any cross-script references in moved scripts
  - CACHE-INTEGRATION.md documentation
- Update documentation to reflect new structure:
  - README.md (if scripts are mentioned)
  - openspec/project.md
  - Any other docs referencing script locations
- Maintain executable permissions on moved scripts
- Keep RUNME.sh in root (main entry point stays accessible)

## Impact
- Affected specs: `project-structure` capability (new spec)
- Affected code:
  - RUNME.sh (line ~10-15): Update `source ./_library` to `source ./lib/_library`
  - check-os-status.sh: Update any references to fetch-os-releases.sh
  - CACHE-INTEGRATION.md: Update all script path references
  - openspec/project.md: Update file structure documentation
- **BREAKING**: Users who call individual scripts directly (e.g., `./check-os-status.sh`) will need to update paths to `./lib/check-os-status.sh`
- **NON-BREAKING**: Main user workflow via `./RUNME.sh` remains unchanged
- Scripts can still be called directly from root with: `./lib/scriptname.sh`

## Migration Notes
For users with existing scripts/automation:
- Replace `./check-os-status.sh` → `./lib/check-os-status.sh`
- Replace `./fetch-os-releases.sh` → `./lib/fetch-os-releases.sh`
- Replace `./check-os-updates.sh` → `./lib/check-os-updates.sh`
- Replace `./lynis-report-parser.sh` → `./lib/lynis-report-parser.sh`
- Main entry point `./RUNME.sh` unchanged
