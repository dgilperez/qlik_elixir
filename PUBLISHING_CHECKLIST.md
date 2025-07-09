# Publishing Checklist for qlik_elixir

Before publishing to Hex.pm, ensure you've completed these steps:

## Pre-publish Tasks

- [ ] Update `@github_url` in `mix.exs` with your actual GitHub repository URL
- [ ] Update `maintainers` in `mix.exs` with your name
- [ ] Update copyright holder in `LICENSE` file
- [ ] Review and update `README.md` if needed
- [ ] Ensure all tests pass: `mix test`
- [ ] Check code formatting: `mix format`
- [ ] Run Credo for code quality: `mix credo --strict`
- [ ] Generate docs locally to verify: `mix docs`
- [ ] Update `CHANGELOG.md` with the correct release date
- [ ] Commit all changes and push to GitHub
- [ ] Create a git tag for the release: `git tag -a v0.1.0 -m "Release v0.1.0"`

## Publishing Steps

1. **Dry run to check everything:**
   ```bash
   mix hex.publish --dry-run
   ```

2. **Build the package:**
   ```bash
   mix hex.build
   ```

3. **Publish to Hex.pm:**
   ```bash
   mix hex.publish
   ```

4. **Push git tag:**
   ```bash
   git push origin v0.1.0
   ```

## Post-publish Tasks

- [ ] Verify package on https://hex.pm/packages/qlik_elixir
- [ ] Create a GitHub release with the same version tag
- [ ] Test installation in a new project
- [ ] Update any internal projects to use the Hex version

## Future Releases

1. Update version in `mix.exs`
2. Update `CHANGELOG.md` with new changes
3. Follow the same publishing steps
4. Consider semantic versioning:
   - Patch version (0.1.x) for bug fixes
   - Minor version (0.x.0) for new features
   - Major version (x.0.0) for breaking changes