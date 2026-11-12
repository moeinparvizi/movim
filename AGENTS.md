# Project maintenance

Keep the Persian documentation in `docs/` aligned with every feature and behavior change. Add new documentation pages to the index; the site build automatically includes every Markdown file in that directory. Keep platform download and installation instructions accurate and do not claim untested platform support.

When preparing a release, update `lua/config/version.lua` and the Windows installer version together, then rebuild and validate all affected installers. Publish release assets with the names expected by `site/site.js` only after validating them. Preserve existing user data and unrelated changes.
