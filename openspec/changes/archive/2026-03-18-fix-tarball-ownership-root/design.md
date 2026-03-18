# Design: Fix Tarball Ownership Shows Root

## Problem

When users run `sudo ./RUNME.sh audit`, the generated tarball and output directory are owned by root because the script runs with root privileges. This creates a poor user experience:

1. Users cannot access their own audit results without sudo
2. Users cannot delete the tarball or output directory without sudo
3. Inconsistent with user expectations (they initiated the audit, they should own the results)

## Current Behavior

```bash
$ sudo ./RUNME.sh audit
# ... audit runs ...

$ ls -l
-rw-r--r-- root root honeybadger-hostname-user-17-03-2026.tar.gz
drwxr-xr-x root root output-hostname-user-17-03-2026/

$ rm honeybadger-*.tar.gz
rm: cannot remove 'honeybadger-hostname-user-17-03-2026.tar.gz': Permission denied
```

## Proposed Solution

After creating the tarball and before exiting the audit() function, change ownership of both the tarball and output directory to the actual user who invoked sudo.

### Implementation Approach

1. **Use SUDO_USER environment variable** to identify the actual user
   - SUDO_USER is automatically set by sudo to the name of the user who invoked it
   - Fallback to current user if SUDO_USER not set (when running without sudo)

2. **Determine user's primary group**
   - Use `id -gn "$SUDO_USER"` to get the group name
   - Fallback to using username as group (user:user) if group lookup fails

3. **Apply chown after file creation**
   - Fix output directory ownership first (recursive)
   - Then create tarball (which will inherit root ownership)
   - Fix tarball ownership last

### Code Location

In `RUNME.sh`, around line 418-419 after tarball creation:

```bash
# Current code:
tar -czf "$tarball" -C "$(dirname "$output")" "$(basename "$output")"
echo "Report saved to: $tarball"

# Add after:
if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
  user_group=$(id -gn "$SUDO_USER" 2>/dev/null || echo "$SUDO_USER")
  chown -R "$SUDO_USER:$user_group" "$output" 2>/dev/null || true
  chown "$SUDO_USER:$user_group" "$tarball" 2>/dev/null || true
fi
```

### Error Handling

- Use `|| true` to prevent script failure if chown fails
- chown failure is non-critical (audit succeeded, just ownership issue)
- Redirect stderr to /dev/null to avoid confusing error messages
- Only apply chown when SUDO_USER is set and not "root"

### Why This Works

1. **SUDO_USER is reliable**: Set by sudo itself, not user-modifiable
2. **Minimal code change**: Only 4 lines added at the end of audit()
3. **Safe**: Uses || true to prevent script failure
4. **Backwards compatible**: No effect when running without sudo
5. **No security risk**: Only changes ownership, not permissions

## Alternative Approaches Considered

### Alternative 1: Run entire audit as actual user
**Rejected**: Lynis and other tools require root privileges to perform comprehensive system audits.

### Alternative 2: Use sudo -u for file creation commands
**Rejected**: Would require wrapping many commands throughout the script; complex and error-prone.

### Alternative 3: Create files in user's home directory
**Rejected**: Current working directory is the expected location; changing this would be a breaking change.

### Alternative 4: Use ACLs (setfacl)
**Rejected**: Not all filesystems support ACLs; chown is more universally available.

## Testing Strategy

1. **Test with sudo**: Most common use case
   - Run `sudo ./RUNME.sh audit`
   - Verify tarball owned by actual user
   - Verify output directory owned by actual user
   - Verify user can delete files without sudo

2. **Test without sudo**: Should still work
   - Run `./RUNME.sh audit` (if not blocked by root check)
   - Verify no errors from chown commands
   - Files already owned by user anyway

3. **Test edge cases**:
   - SUDO_USER not set: chown should be skipped
   - User's group cannot be determined: fallback to user:user
   - Different filesystems (ext4, btrfs, NFS)

## Impact Assessment

- **User experience**: Significantly improved (no sudo needed for file cleanup)
- **Breaking changes**: None
- **Performance**: Negligible (two chown commands at end of audit)
- **Security**: No impact (only changes ownership, not permissions)
- **Compatibility**: Works on all Linux distributions
- **Version**: Patch release 0.4.1 (bug fix, no breaking changes)
