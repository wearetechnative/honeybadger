---
# honeybadger-ww2f
title: 'Windows: write hardware-serial.txt through the shared usability rule'
status: completed
type: task
priority: high
created_at: 2026-09-18T08:40:27Z
updated_at: 2026-09-18T09:01:00Z
parent: honeybadger-k80g
---

AUDIT.ps1 reads Win32_BIOS.SerialNumber correctly but keeps it in a variable; it reaches the operator only inside the compliance markdown. The report-submission spec requires the archive to carry hardware-serial.txt, because that file is what lets the collection server attribute a submission to an asset in the ISO register.

Write hardware-serial.txt and hardware-serial-source.txt, and decide usability with the same rule lib/_library applies: one token, no whitespace, no placeholder, not all zeroes, and could-not-read distinguished from none-present. AUDIT.ps1 currently writes the literal "Not available (VM or unknown hardware)" into the value, which is a placeholder the shared rule rejects.

Note: whether the measured serial matches the ISO register is honeybadger-wbq4, not this task.


## Summary of Changes

AUDIT.ps1 writes hardware-serial.txt and hardware-serial-source.txt, and
decides usability with Test-HbUsableSerial rather than the regex that used to
sit beside the WMI query. A placeholder becomes none-present and a failed query
becomes could-not-read, and the run reports which applies at the end where the
operator is looking.

The literal "Not available (VM or unknown hardware)" is in the shared
placeholder list, so the value this client used to record as a measurement is
now correctly reported as no serial. The compliance report shows the same
determination as the file.
