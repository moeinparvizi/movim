# Changelog

## 2.0.0

- Start the 2.x release series for Windows, macOS and Linux. This version carries forward the editor and updater from 1.1.30 without changing user configuration.

## 1.1.30

- Skip identical files during installation and rollback, including native parsers locked by a running Windows editor.

## 1.1.29

- Install verified editor updates directly from :MovimUpdate, including on read-only projects and when GitHub rate-limits release metadata requests.
- Manage project services and database connections from the editor, with persistent connection settings and custom database clients.

## 1.1.28

- Show the active search folders above Find Files and Grep, with an overflow count and access to the complete list through Ctrl+D.
- Click search preview text to edit the actual file at the clicked line, save with Ctrl+S and return to the search with Ctrl+E.
- Validate preview editing through real keyboard and mouse input for both search modes, including saving changes to disk.

## 1.1.27

- Search multiple folders in Find Files and Grep, keep each project's scope, and edit the actual file directly from the preview.
- Add searchable project clipboard history with multiline previews and paste at the original cursor.
- Add language-aware live templates with Tab expansion, editable fields and selection surrounds; save custom templates in `.movim/live-templates.json`.
- Restore Structure loading with a compatible Aerial version and Tree-sitter-first outlines. Make file, line and selection formatting available before an LSP attaches.
- Preserve the editing cursor during mouse scrolling and improve project, Git and task selection popups.
- Cover project recovery, search previews, clipboard actions, templates, formatting and outline loading with editor integration tests.

## Project-local workspace recovery

- Store editor checkpoints in each project's `.movim/settings.json`, using relative internal paths. Migrate central checkpoints without deleting recovery copies; restore only the launch folder automatically.
- Keep safe mouse-driven file closing inside the editor and return the last file to the dashboard. Reuse terminal display numbers after closing sessions.
- Restore Explorer width after asynchronous rendering and retain expanded folders. Avoid stale dashboard cache callbacks during project switches.
- Add default report/font exclusions and Visual-mode current-file, file-name and project-text search shortcuts.
- Collapse type inlay hints to clickable labels, preserving full server-provided types and parameter-name hints.
- Test recovery across fresh processes and rendered mouse clicks, including Explorer size after restart.

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
