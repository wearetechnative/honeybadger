## 1. Collection

- [ ] 1.1 `lib/check-os-status.sh`: remove the `neofetch.json`, `neofetch.txt`
      and `fastfetch.txt` branches from the format selection
- [ ] 1.2 Missing `fastfetch.json` exits with an error naming the file and the
      command that produces it
- [ ] 1.3 Remove the legacy note emitted when live kernel data is unavailable
      because of an old format

## 2. Verify

- [ ] 2.1 `check-output` on a current output directory is unchanged
- [ ] 2.2 `check-output` on a directory containing only `neofetch.json` fails
      with the new error
