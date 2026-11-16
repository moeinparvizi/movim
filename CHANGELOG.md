# Changelog

## In-app updates

- Add dashboard Update movim, Space u U and :MovimUpdate. Download stable releases in the background and apply verified files on the next interactive launch.
- Preserve user.lua, workspaces, drafts, project files, preferences and AI credentials; stop on edited distribution files or conflicting personal files.
- Back up replaced files, roll back write failures and recover process interruption. Stage changed AI runtimes before applying them; synchronize plugins to the release lockfile.
- Preserve existing Unix configuration on installer upgrades and check/back up existing Windows distribution files before overwriting them. Native runtimes still require an in-place installer upgrade.

## 1.1

- Persist per-project workspaces, unsaved named and unnamed drafts, split layouts, cursors, search scopes/exclusions and panel sizes. Add a project chooser, automatic startup recovery, atomic debounced checkpoints, legacy-session import and external-change recovery.
- Search Visual selections with Space f g and stop terminal panels from leaving extra unnamed editor buffers.
- Redesign the website around a terminal workspace, with responsive editor previews and self-hosted Persian and code fonts.
- Fingerprint website scripts, styles and search data to prevent a cached English-only route from overriding new Persian pages.
- Restore direct access to all twenty Persian chapters and five practical references, translate the remaining references, and add keyboard-driven full-text search, heading navigation and code copying. Persian is the homepage default; English remains an explicit choice.

- Correct the documented session, window movement, alternate-file and bookmark shortcuts to match the configuration.

- Resolve configuration paths containing spaces and isolate the Windows application name from inherited environment settings.

- Add a readable built-in startup palette on every platform. Restore a saved theme immediately and fall back safely when it is missing, without erasing the preference.
- Use English for dashboard text, status labels and command descriptions; retain optional Persian keyboard input and display tools.
- Ship the same configuration, colors, fonts and documentation in Windows, macOS and Linux packages, with a version and SHA-256 manifest.
- Build, test and publish all download assets together on each main update. Deploy the matching website after package checks pass.
- Require English and Persian documentation updates alongside configuration and installer behavior changes.

Patch releases are stamped automatically by the release workflow. Each package includes release.json with its exact source commit and file hashes.
