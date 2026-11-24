# Project maintenance

Keep the Persian documentation in `docs/` aligned with every feature and behavior change. Add new documentation pages to the index; the site build automatically includes every Markdown file in that directory. Keep platform download and installation instructions accurate and do not claim untested platform support.

When preparing a release, update `lua/config/version.lua` and the Windows installer version together, then rebuild and validate all affected installers. Publish release assets with the names expected by `site/site.js` only after validating them. Preserve existing user data and unrelated changes.

Keep the English guide in `site/docs-en/README.md` and the English and Persian website copy aligned with feature and behavior changes.

## Standing update request

When the user says "update" or "آپدیت کن", treat it as a complete release request: include the authorized project changes, update the shared application and package versions, validate and rebuild Windows, macOS and Linux packages, commit and push, publish all release assets, and deploy the matching website. Update the changelog and Persian/English documentation wherever behavior changes require it. Verify the release and website deployment before reporting completion; report any failed build or untested platform. This request authorizes the associated commits, pushes and publication without another confirmation.

The release workflow stamps the next shared version automatically after a push to `main`. Do not also increment it manually for the same release. Fetch the workflow's version commit before the final local installer rebuild so local packages match the published version.
