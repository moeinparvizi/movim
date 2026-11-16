# Synchronized releases

The in-app updater consumes the existing movim-macOS.zip or movim-AI-macOS.zip as a platform-neutral configuration payload on all platforms, plus SHA256SUMS. Keep those names, manifests and complete AI/base version agreement. Native executables and launchers remain installer-managed. Run `node tests/updates.cjs` on every supported OS: it checks staged installs, edit protection, checksums, rollback, process interruption, AI runtime preparation and installer preservation. User-owned user.lua and .movim-update/ must never be added to a release manifest.

Work in the Git repository containing this file (the outer workspace can be a separate repository).

Every push to main runs .github/workflows/release.yml. The workflow updates the shared patch version and commits it with the Actions token, which does not recursively trigger another release. It builds Windows/macOS packages from one checkout, Linux from the same source commit, validates package hashes and clean Windows startup, tests the bundled fallback on native Unix runners, then publishes all three assets and deploys the matching documentation website.

Workspace recovery tests run across fresh Neovim processes on Windows, Linux and macOS. Windows additionally exercises the real Telescope, Neo-tree and terminal UI with the prepared plugin runtime. The native macOS check uses `macos-15-intel` because the arm64 pool could not acquire a runner for the previous release; this does not claim interactive installation or Apple Silicon validation.

The documentation guard requires changes in docs/*.md and site/docs-en/README.md for changes to configuration or installer behavior. It cannot verify the prose semantically; review the instructions against actual behavior.

Windows runtime tools are seeded from the immutable v1.0.0 Windows installer. The seed configuration is discarded; the current checkout supplies all configuration and docs. Plugin revisions differing from the seed are downloaded from the current lazy-lock.json. Language-tool upgrades require updating the seed preparation step deliberately. Windows-only native plugin builds may also need a new build step after a lockfile change. A failed check blocks publication.

For a local build, run from the outer workspace:

    powershell -NoProfile -ExecutionPolicy Bypass -File neovim/installer/build-installers.ps1

This builds movim-Setup.exe and movim-macOS.zip and generates neovim/release.json. Build Linux with bash neovim/installer/build-linux.sh after putting Node on PATH. The Windows builder uses workspace-local Inno Setup, Neovim, Node, language tools and plugin data. CI prepares these with prepare-windows.ps1.

Do not publish obsolete Nemovim/WebNeovim packages as current assets. Current asset names are movim-Setup.exe, movim-macOS.zip and movim-linux.tar.gz. Publish checksums with them. Do not claim complete macOS/Linux installer or interactive UI validation from a fallback-theme unit test.
