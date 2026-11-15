# Changelog

## 1.1

- Correct the documented session, window movement, alternate-file and bookmark shortcuts to match the configuration.

- Resolve configuration paths containing spaces and isolate the Windows application name from inherited environment settings.

- Add a readable built-in startup palette on every platform. Restore a saved theme immediately and fall back safely when it is missing, without erasing the preference.
- Use English for dashboard text, status labels and command descriptions; retain optional Persian keyboard input and display tools.
- Ship the same configuration, colors, fonts and documentation in Windows, macOS and Linux packages, with a version and SHA-256 manifest.
- Build, test and publish all download assets together on each main update. Deploy the matching website after package checks pass.
- Require English and Persian documentation updates alongside configuration and installer behavior changes.

Patch releases are stamped automatically by the release workflow. Each package includes release.json with its exact source commit and file hashes.
