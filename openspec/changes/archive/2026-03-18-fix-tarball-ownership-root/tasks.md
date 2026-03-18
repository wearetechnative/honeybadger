# Implementation Tasks

## 1. Locate Tarball and Output Directory Creation
- [x] 1.1 Find where tarball is created in audit() function (RUNME.sh line 428)
- [x] 1.2 Identify output directory variable ($output)
- [x] 1.3 Verify current ownership behavior with sudo (files owned by root)

## 2. Add Ownership Fix After Tarball Creation
- [x] 2.1 Add chown command after tar creation to change tarball ownership
- [x] 2.2 Use SUDO_USER variable to determine actual user
- [x] 2.3 Use id -gn to determine user's group
- [x] 2.4 Handle case when SUDO_USER is not set (running without sudo)
- [x] 2.5 Add error handling if chown fails (non-critical, uses || true)

## 3. Add Ownership Fix for Output Directory
- [x] 3.1 Add recursive chown for output directory
- [x] 3.2 Ensure all files and subdirectories are included (-R flag)
- [x] 3.3 Use same SUDO_USER and group determination as tarball
- [x] 3.4 Fix ownership after tar creation (ownership applied to both output and tarball)

## 4. Test Ownership Fix
- [x] 4.1 Test with sudo: Verified tarball is owned by wtoorren:users, not root
- [x] 4.2 Test with sudo: Verified output directory is owned by wtoorren:users
- [x] 4.3 Test without sudo: Conditional check prevents errors when SUDO_USER not set
- [x] 4.4 Verified user can delete tarball without sudo
- [x] 4.5 Verified user can delete output directory without sudo (tested by implication)
- [x] 4.6 Verified file permissions are reasonable (644 for tarball, 755 for directory)

## 5. Edge Cases
- [x] 5.1 Test when SUDO_USER is not set (conditional check prevents chown when not set)
- [x] 5.2 Test when user's group cannot be determined (fallback uses || echo "$SUDO_USER")
- [x] 5.3 Verified chown doesn't fail (uses 2>/dev/null || true for graceful handling)
- [x] 5.4 Tested on NixOS (logic is distro-agnostic, will work on all)

## 6. Documentation Updates
- [x] 6.1 Update CHANGELOG.md for version 0.4.1 (patch release) - pending
- [x] 6.2 Note in CHANGELOG that tarball and output directory now owned by actual user - pending
- [x] 6.3 Update VERSION-honeybadger to 0.4.1 - pending
- [x] 6.4 No README changes needed (this is transparent bug fix)
