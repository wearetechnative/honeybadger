# Change: Fix Tarball Ownership Shows Root

## Why
Currently, when running `sudo ./RUNME.sh audit`, the generated tarball and output directory are owned by root instead of the actual user who invoked sudo. This causes:
- **Permission issues**: User cannot easily access or modify their own audit results
- **Cleanup problems**: User needs sudo to delete tarball and output directory
- **Inconsistent ownership**: Files inside output directory may have mixed ownership
- **Poor user experience**: Users expect their files to be owned by them, not root

Example of current behavior:
```bash
$ sudo ./RUNME.sh audit
$ ls -l
-rw-r--r-- root root honeybadger-hostname-user-17-03-2026.tar.gz
drwxr-xr-x root root output-hostname-user-17-03-2026/
```

Users then need:
```bash
$ sudo chown -R user:user honeybadger-*.tar.gz output-*/
```

## What Changes
- Change ownership of tarball to actual user (not root) after creation
- Change ownership of output directory to actual user (not root)
- Use `chown` with SUDO_USER to fix ownership after audit completes
- Ensure all generated files are accessible by the user who ran the audit

## Impact
- Affected specs: `audit-output` (new spec for output file ownership)
- Affected code:
  - `RUNME.sh`: Add chown commands after tar creation (line ~418-419)
- User experience: Tarball and output directory owned by actual user
- Backward compatibility: Non-breaking change (fixes ownership issue)
- Permissions: Users can now access and delete their audit results without sudo
- Version: Patch release 0.4.1 (bug fix)
