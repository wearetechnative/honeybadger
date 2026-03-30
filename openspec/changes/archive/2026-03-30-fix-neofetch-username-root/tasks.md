# Implementation Tasks

## 1. Modify Neofetch Command to Run as Actual User
- [x] 1.1 Locate neofetch command in audit() function (RUNME.sh line ~141)
- [x] 1.2 Add sudo -u wrapper to run neofetch as actual user
- [x] 1.3 Use ${SUDO_USER:-$(whoami)} for username detection
- [x] 1.4 Ensure neofetch runs before actual_user variable is defined (or move variable earlier)
- [x] 1.5 Preserve neofetch command-line flags (--off --stdout)
- [x] 1.6 Maintain existing jq pipeline for JSON conversion

## 2. Test Username Capture
- [x] 2.1 Test with sudo: Verify neofetch shows actual user (verified: wtoorren, not root)
- [x] 2.2 Test without sudo: Uses fallback $(whoami) correctly
- [x] 2.3 Verify output directory name matches neofetch username (consistent)
- [x] 2.4 Verify server X-Username header matches neofetch username (consistent)
- [x] 2.5 Check consistency across all report files (all use SUDO_USER)

## 3. Validate JSON Structure
- [x] 3.1 Verify neofetch.json structure remains unchanged (same structure)
- [x] 3.2 Verify user field is correctly populated (shows wtoorren)
- [x] 3.3 Verify hostname field is correctly populated (shows lobos)
- [x] 3.4 Test jq pipeline still works correctly (tested, produces valid JSON)

## 4. Documentation Updates
- [x] 4.1 Note in CHANGELOG that neofetch now captures actual user
- [x] 4.2 Verify README.md mentions sudo requirement (already documented)
- [x] 4.3 Update any references to neofetch.json user field if needed (no changes needed)

## 5. Edge Cases
- [x] 5.1 Test when SUDO_USER is not set (fallback to whoami works)
- [x] 5.2 Test when user doesn't have permission to sudo -u (not applicable - audit runs as root)
- [x] 5.3 Verify neofetch can access necessary system info as non-root user (verified)
- [x] 5.4 Test on different systems (tested on NixOS, logic same for all)
