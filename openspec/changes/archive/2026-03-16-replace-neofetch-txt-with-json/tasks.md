# Implementation Tasks

## 1. Update neofetch.json Generation
- [x] 1.1 Update RUNME.sh:120 to generate neofetch.json using enhanced command with user/hostname extraction
- [x] 1.2 Verify the JSON structure matches the example and includes user/hostname fields
- [x] 1.3 Remove the old neofetch.txt generation line

## 2. Update OS Info Extraction (lib/_library)
- [x] 2.1 Update extract_os_info() function to read from neofetch.json using jq
- [x] 2.2 Extract OS_FULLNAME from JSON field "os" using jq
- [x] 2.3 Update OS name parsing to work with JSON data
- [x] 2.4 Keep backward compatibility with neofetch.txt for old audits

## 3. Update Hardware Info Extraction (lib/_library)
- [x] 3.1 Update generate_asset_inventory() function to use neofetch.json
- [x] 3.2 Extract owner from JSON "user" field using jq
- [x] 3.3 Extract model from JSON field "host" using jq
- [x] 3.4 Extract kernel from JSON field "kernel" using jq
- [x] 3.5 Extract hostname from JSON "hostname" field using jq
- [x] 3.6 Keep backward compatibility with neofetch.txt for old audits

## 4. Update Nix Installation Detection (lib/_library)
- [x] 4.1 Check neofetch.json for "nix-" in packages field using jq
- [x] 4.2 Keep backward compatibility with neofetch.txt for old audits

## 5. Update Fetch File Selection (lib/check-os-status.sh)
- [x] 5.1 Update to check for neofetch.json first, then neofetch.txt
- [x] 5.2 Update parsing code to use jq for JSON extraction with format detection
- [x] 5.3 Maintain fastfetch.txt fallback support (separate format)

## 6. Backward Compatibility for check-output
- [x] 6.1 Keep fallback support to read old neofetch.txt files from existing audit archives
- [x] 6.2 Ensure check-output tries neofetch.json first, then falls back to neofetch.txt
- [x] 6.3 Add logic to detect which format is available and use appropriate parsing

## 7. Documentation Updates
- [x] 7.1 Update openspec/project.md to reference neofetch.json instead of neofetch.txt
- [x] 7.2 Update CHANGELOG.md with this change
- [x] 7.3 README.md does not mention output file formats (no change needed)

## 8. Testing and Validation
- [x] 8.1 Tested neofetch JSON generation command - works correctly with user/hostname fields
- [x] 8.2 Verified jq field extraction works for user, hostname, host, kernel, packages
- [x] 8.3 Generated neofetch.json in test output directory - verified structure
- [x] 8.4 Test check-output with new neofetch.json output - all data extracted correctly
- [x] 8.5 Test check-output with old neofetch.txt archive - backward compatibility confirmed
- [x] 8.6 Verified JSON takes priority over TXT when both exist (kernel version test)
