---
# honeybadger-epzu
title: Deploy the client configuration through a NixOS module
status: scrapped
type: task
priority: normal
tags:
    - honeybadger
    - config
created_at: 2026-09-16T06:27:27Z
updated_at: 2026-09-16T06:32:39Z
parent: honeybadger-6dkw
---

**Scrapped: the premise was wrong.**

`.honeybadger.conf` being local and hand-placed is the design, not a gap. The
user holds their own token, issued by the badgersbay administrator, and the
allowlist lives in `badgersbay-tokens.age`. Deploying the file centrally would
work against that boundary, and the audited machines are personal laptops
rather than servers under configuration management.

---

Nothing manages the client configuration. Searching
`technative-awsaccounts-workloads` for `honeybadger.conf`, `SERVER_URL` and
`SERVER_TOKEN` returns nothing: the server side is deployed through the
elastinix module with agenix secrets, the client side is placed by hand on each
machine.

The consequence is that the bearer token granting write access to the
compliance evidence store lives in an unmanaged file on eleven laptops, with no
record of which token is on which machine and no way to rotate one without
visiting each.

Scope:

1. A module option in elastinix that writes `.honeybadger.conf`, following the
   pattern `service-badgersbay.nix` already uses: structure in the module,
   values through agenix.
2. The token as an agenix secret, so it is encrypted at rest and rotating it is
   a commit rather than a tour of the fleet.
3. A decision on scope: the audited machines are personal laptops, not servers
   under NixOS management. This may only be feasible for the NixOS ones, which
   would leave macOS and Windows hand-placed. Say so plainly rather than
   pretending the problem is solved.

Touches elastinix; that side needs its own issue in that repository once the
shape is agreed.
