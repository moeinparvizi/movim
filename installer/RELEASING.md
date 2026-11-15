# Synchronized releases

Work in the Git repository containing this file (the outer workspace can be a separate repository).

Every push to main runs .github/workflows/release.yml. The workflow updates the shared patch version and commits it with the Actions token, which does not recursively trigger another release. It builds Windows/macOS packages from one checkout, Linux from the same source commit, validates package hashes and clean Windows startup, tests the bundled fallback on native Unix runners, then publishes all three assets and deploys the matching documentation website.

The documentation guard requires changes in docs/*.md and site/docs-en/README.md for changes to configuration or installer behavior. It cannot verify the prose semantically; review the instructions against actual behavior.

Windows runtime tools are seeded from the immutable v1.0.0 Windows installer. The seed configuration is discarded; the current checkout supplies all configuration and docs. Plugin revisions differing from the seed are downloaded from the current lazy-lock.json. Language-tool upgrades require updating the seed preparation step deliberately. Windows-only native plugin builds may also need a new build step after a lockfile change. A failed check blocks publication.

For a local build, run from the outer workspace:

    powershell -NoProfile -ExecutionPolicy Bypass -File neovim/installer/build-installers.ps1

This builds movim-Setup.exe and movim-macOS.zip and generates neovim/release.json. Build Linux with bash neovim/installer/build-linux.sh after putting Node on PATH. The Windows builder uses workspace-local Inno Setup, Neovim, Node, language tools and plugin data. CI prepares these with prepare-windows.ps1.

Do not publish obsolete Nemovim/WebNeovim packages as current assets. Current asset names are movim-Setup.exe, movim-macOS.zip and movim-linux.tar.gz. Publish checksums with them. Do not claim complete macOS/Linux installer or interactive UI validation from a fallback-theme unit test.
