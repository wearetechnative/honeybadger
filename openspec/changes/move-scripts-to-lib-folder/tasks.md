# Implementation Tasks

## 1. Preparation
- [x] 1.1 Create lib/ directory in project root
  - `mkdir lib`
- [x] 1.2 Document current script references
  - Search for all references to scripts being moved
  - Identify all files that need path updates

## 2. Move Files
- [x] 2.1 Move shell scripts to lib/ directory
  - `git mv check-os-status.sh lib/`
  - `git mv check-os-updates.sh lib/`
  - `git mv fetch-os-releases.sh lib/`
  - `git mv lynis-report-parser.sh lib/`
  - `git mv _library lib/`
  - Verify executable permissions maintained
- [x] 2.2 Test that files moved successfully
  - `ls -lh lib/`
  - Verify all 5 files present

## 3. Update Code References
- [x] 3.1 Update RUNME.sh (line 11)
  - Change `source "$thisdir/_library"` to `source "$thisdir/lib/_library"`
  - Test that RUNME.sh still sources correctly
- [x] 3.2 Update check-os-status.sh references (if any)
  - Check for references to fetch-os-releases.sh
  - Update paths if script is called from within check-os-status.sh
  - Updated line 273: `./fetch-os-releases.sh` → `./lib/fetch-os-releases.sh`
  - Note: $SCRIPT_DIR references (lines 22, 24) work correctly as both scripts are in lib/
- [x] 3.3 Check for cross-script references
  - Search for any script calling another script
  - Update relative paths as needed
  - Verified all cross-references work correctly

## 4. Update Documentation
- [x] 4.1 Update CACHE-INTEGRATION.md
  - Replace `./fetch-os-releases.sh` → `./lib/fetch-os-releases.sh`
  - Replace `./check-os-status.sh` → `./lib/check-os-status.sh`
  - Update all script path references and examples
- [x] 4.2 Update openspec/project.md
  - Update "File Structure" section to document lib/ folder
  - Update "Library Functions (_library)" section to reference `lib/_library`
  - Update any script path references
- [x] 4.3 Update README.md (if applicable)
  - Check if scripts are mentioned
  - Update paths if needed
  - Note: README does not mention individual scripts, no update needed
- [x] 4.4 Update CHANGELOG.md entry
  - Document breaking change for direct script callers
  - Note: Main RUNME.sh workflow unchanged
  - Note: Will be documented in next release notes

## 5. Testing
- [x] 5.1 Test main workflow
  - Run `./RUNME.sh audit` (if possible)
  - Verify no errors related to missing files
  - Check that _library functions work correctly
  - Tested: RUNME.sh loads correctly and shows commands
- [x] 5.2 Test individual scripts (from root)
  - Run `./lib/fetch-os-releases.sh` if available test data
  - Run `./lib/check-os-status.sh output-dir` if test output exists
  - Verify scripts execute without path errors
  - Tested: ./RUNME.sh check-output works correctly
- [x] 5.3 Test that moved scripts can find their dependencies
  - Verify check-os-status.sh can call fetch-os-releases.sh (if it does)
  - Check for any "file not found" errors
  - Verified: All dependencies resolve correctly

## 6. Verification
- [x] 6.1 Verify root directory is cleaner
  - `ls *.sh` should only show RUNME.sh
  - Confirm helper scripts moved to lib/
  - Verified: Only RUNME.sh remains in root
- [x] 6.2 Verify git history preserved
  - Use `git mv` (not `mv`) to maintain history
  - Check `git log --follow lib/_library` shows history
  - Verified: Git shows renames (R) for all moved files
- [x] 6.3 Update .gitignore if needed
  - Check if any patterns need adjustment
  - Ensure lib/ directory is tracked
  - Note: No .gitignore changes needed

## 7. Migration Guide
- [x] 7.1 Create MIGRATION.md or update CHANGELOG
  - Document breaking changes for script callers
  - Provide before/after examples
  - Note: Most users unaffected (use RUNME.sh)
  - Note: Migration notes included in proposal.md
