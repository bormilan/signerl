# Historical task: return_signed_message

**Status: Completed; superseded signing flow.** Reconciled on 17 October 2026.

The public signing API returns signed XML and verify/3 consumes it. The original whole-message cryptographic operation was superseded by canonicalized SignedInfo plus reference digests; do not implement the historical flow again.

Current ownership/history: [PR #24](https://github.com/bormilan/signerl/pull/24), [#34](https://github.com/bormilan/signerl/issues/34), [#59](https://github.com/bormilan/signerl/issues/59).

The original plan is preserved in Git history. This file is an archival summary,
not an active checklist. See the [implementation record](../implementations/return_signed_message.md),
[current profile](../signing_profile.md) and [task index](README.md).
Follow [AGENTS.md](../../AGENTS.md) for current quality gates.
