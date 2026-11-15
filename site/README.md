# movim website

The default homepage and complete handbook are Persian (RTL). English is an explicit, persistent language choice. Home documentation and installation links follow that choice, and the English guide links back to the full Persian index. Keep both languages aligned.

The terminal-inspired homepage includes accessible editor/terminal/diff tabs. Documentation is generated from **every** Markdown file in `docs/`, with the index first, followed by numbered chapters and practical references. It includes stable heading anchors, a table of contents, previous/next navigation, copyable code blocks, scrollable tables, mobile navigation and a full-text search dialog (`Ctrl+K`, `Cmd+K` or `/`). `search.js` normalizes Persian/Arabic letter variants. Webfonts and their OFL licenses live in `fonts/`; no external font service is required.

Run `npm ci && npm test` here. Tests rebuild `dist/` and validate all documentation, local links and anchors, shared versions, Persian content, full-text search and language-sensitive navigation. `dist/` is generated and ignored. Serve that directory over HTTP for browser review; all paths support GitHub Pages project subdirectories.

`.github/workflows/release.yml` builds and checks the site on each push to `main` and deploys it only after publishing matching platform installers. Every page carries the version and source commit from `lua/config/version.lua` and `installer/manifest.cjs`. The former standalone Pages workflow is manual-only.

Downloads retain direct latest-release links when the GitHub API is unavailable. When the lookup succeeds, links are matched to `movim-Setup.exe`, `movim-macOS.zip` and `movim-linux.tar.gz`; missing assets lead to the release page. Do not publish an archive until its contents have been verified.
