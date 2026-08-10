# Maintainers guide

This page collects maintainer-only release and repository maintenance notes.

## New release checklist

1. Review the entries under `## [Unreleased]` in `CHANGELOG.md`.

2. Move the release notes into a new version section:

   ```markdown
   ## [Unreleased]

   ## [x.y.z] - YYYY-MM-DD
   ```

3. Add a `Migration guide` subsection if users need to update code, input files, settings, output-processing scripts, or workflows.

4. Update the comparison links at the bottom of `CHANGELOG.md`.

5. Update the version in `Project.toml`.

6. Open and merge the release PR before creating the release tag or registering the new version.

7. Optional: run the changelog generator locally to include generated README and documentation updates in the release PR:

   ```bash
   julia --project=. docs/scripts/update_changelog.jl
   ```

   This step is optional because GitHub Actions runs the generator automatically. The documentation workflow also runs it before deploying docs.
