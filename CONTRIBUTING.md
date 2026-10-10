# Contributing

Bug reports, compatibility improvements, documentation, and pull requests are
welcome. Discuss large behavior changes in an issue before implementing them.

## Local setup

1. Fork the repository on GitHub.
2. Clone your fork with `git clone https://github.com/<your-user>/yards-to-km.git YardsToKm`.
3. Create a branch for your change.
4. Install Lua 5.1 for syntax checks and tests; Python 3 is needed for packaging.

Copy the addon files into a folder named `YardsToKm` in Classic Era's
`Interface/AddOns` directory. Do not rename the manifest or install a nested
`YardsToKm/YardsToKm` folder. Run `/reload` after changing Lua files.

## Implementation guidelines

- Keep the addon compatible with Classic Era and Lua 5.1.
- Change presentation only; do not modify range checks or game mechanics.
- Preserve original text so settings changes and disabling conversion work.
- Keep unsupported text intact, including hyperlinks and texture markup.
- Avoid modifying protected UI in unsafe ways. Do not assume a secure hook
  makes subsequent writes safe.
- Keep changes focused and avoid additional runtime dependencies unless needed.
- Never commit account data, SavedVariables, credentials, or private logs.

## Checks

Run these commands from the repository directory:

```sh
luac5.1 -p YardsToKm.lua
lua5.1 tests/tooltip.lua
python3 scripts/package.py
git diff --check
```

If Lua is unavailable, the existing test can also run with:

```sh
npm exec --yes --package=fengari-node-cli -- fengari tests/tooltip.lua
```

Mocked tests do not prove behavior in WoW. For display changes, also check:

- Spell tooltips, formatted text, and text overwritten by another addon.
- Conversion on/off, both unit modes, and both precision settings.
- Fresh install, `/reload`, and persisted settings.
- Out-of-combat and in-combat behavior, including Lua errors or blocked actions.

Do not risk a Hardcore character to test combat: use a safe non-Hardcore
Classic Era character when possible. Enable Lua error reporting with
`/console scriptErrors 1` and disable it afterwards with `/console scriptErrors 0`.
Record what was actually tested and what remains unverified.

## Pull requests

Explain the problem, the change, and how it was tested. Add regression coverage
for fixes where feasible, and update related documentation. GitHub Actions
checks Lua syntax, tooltip behavior, and packaging.

Maintainers manage release versions and tags; do not bump the manifest version
in an unrelated contribution. Releases must keep the installable folder named
`YardsToKm` and exclude tests and development tooling.

## License

By submitting a contribution, you agree that it is distributed under the
project's [MIT license](LICENSE). Submit only material you have the right to share.
