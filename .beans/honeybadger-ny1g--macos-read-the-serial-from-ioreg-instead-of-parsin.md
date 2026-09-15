---
# honeybadger-ny1g
title: 'macOS: read the serial from ioreg instead of parsing a human report'
status: completed
type: task
priority: high
tags:
    - honeybadger
created_at: 2026-09-15T21:16:29Z
updated_at: 2026-09-15T21:29:48Z
parent: honeybadger-ck4l
---

The current macOS path writes `Mac OS X<TAB>` - a fragment of unrelated output,
almost certainly from matching the wrong line of `system_profiler`. That output
is a formatted human report, its labels change between releases, and "Serial
Number" appears in more than one section.

Read the value as a property:

    ioreg -d2 -c IOPlatformExpertDevice \
      | awk -F'"' '/IOPlatformSerialNumber/{print $(NF-1)}'

Fall back to `system_profiler SPHardwareDataType`, parsed on the `Serial Number`
label.

Verify against what About This Mac reports.

Tasks 2.1 to 2.3 in the OpenSpec change.

## Summary of Changes

`hb_collect_serial_macos()` reads `IOPlatformSerialNumber` from
`ioreg -d2 -c IOPlatformExpertDevice`, falling back to
`system_profiler SPHardwareDataType` parsed on the `Serial Number` label. The
parsers are separate stdin functions so they can be fed captured output.

The path that produced `Mac OS X<TAB>` is gone: there is no `system_profiler`
line-matching left outside the labelled parser, and the validation gate rejects
the value regardless of where it came from.

Both tools are captured before being parsed rather than piped into the parser,
so a tool that fails outright is not counted as having answered - without that,
the outcome depended on whether `pipefail` happened to be set.

Verification against About This Mac on real hardware is honeybadger-1lo9: no Mac
was reachable from the machine this was implemented on.
