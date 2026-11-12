# movim website

The site is built from `site/index.html`, its assets, and **every** Markdown file in `docs/`. Update the documentation alongside each feature; site builds automatically include new chapters and rebuild the search index. Run `npm ci && npm test && npm run build` in this folder. `dist/` is generated and is not committed.

`.github/workflows/pages.yml` deploys the built site on pushes to `main` when the repository's Pages source is set to GitHub Actions. The site works below a project subpath.

Downloads and the update checker use the latest stable GitHub Release. Create a release with a semantic version tag such as `v1.0.1`, keep the app version aligned with that release, and attach `movim-Setup.exe`, `movim-macOS.zip`, and `movim-linux.tar.gz` after verifying each package. The website intentionally links to the releases page until the corresponding asset is actually present.
