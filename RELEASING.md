# Release policy

This repository is the private GitLab mirror used by `dostup/gui_client`.

## Branches

- `master` — integration branch pinned by the client submodule;
- `agp9-builtin-kotlin` — upstream PR #897;
- `feat/*` — feature/platform work, merged into `master` before release.

## Tags

Fork releases use a vendor suffix on the upstream package version:

```text
v3.1.6-dostup.1
```

Tag rules:

1. Package version stays in `pubspec.yaml`.
2. Create an annotated tag on `master`.
3. Push the tag to `origin` (GitLab mirror) and optionally `upstream` (GitHub fork).
4. Update the `gui_client` submodule pin to the tagged commit.
5. Record package version + tag in the client release notes.

## Host contract

The client installs `CallkitNotificationDelegate` via
`FlutterCallkitIncoming.setNotificationDelegate(...)`. The fork owns call state
and events; the host owns notification presentation.
