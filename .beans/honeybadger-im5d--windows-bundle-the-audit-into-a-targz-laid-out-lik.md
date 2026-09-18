---
# honeybadger-im5d
title: 'Windows: bundle the audit into a tar.gz laid out like the Linux one'
status: completed
type: task
priority: high
created_at: 2026-09-18T08:40:28Z
updated_at: 2026-09-18T09:01:00Z
parent: honeybadger-k80g
---

AUDIT.ps1 writes loose files into report-<yyyyMMdd>/ and zips it. The collection server takes tar archives, and check-output and every other consumer expect output-<host>-<user>-<dd-MM-yyyy>/ inside.

Rename the output directory to the shared convention and produce honeybadger-<host>-<user>-<dd-MM-yyyy>.tar.gz with tar.exe, which Windows 10 1803 and later ship as bsdtar. The zip is replaced rather than kept beside it: two bundles of the same audit is two things to submit and two to keep in step.


## Summary of Changes

The output directory is output-<host>-<user>-<dd-MM-yyyy>, which the shared
output-name parser reads; it was report-<yyyyMMdd>, which it does not. The
archive is honeybadger-<host>-<user>-<dd-MM-yyyy>.tar.gz, built with tar.exe -
bsdtar, shipped with Windows since build 17063, so nothing is installed.

Compress-Archive is gone rather than kept beside it: the zip is the bundle the
archive endpoint cannot attribute, and shipping both means an operator can
submit the one that does not work. When tar is missing the audit says so and
leaves the output directory in place with the command to archive it by hand.
