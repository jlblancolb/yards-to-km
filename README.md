# Yards to Kilometers

[![Test and package addon](https://github.com/jlblancolb/yards-to-km/actions/workflows/package.yml/badge.svg)](https://github.com/jlblancolb/yards-to-km/actions/workflows/package.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A World of Warcraft Classic Era addon that best-effort converts detectable yard
measurements in UI text to meters or kilometers.

**Classic Era 1.15.9, including Hardcore. Currently in beta.**

## Features

- Converts English yard labels in accessible UI text and spell tooltips.
- Uses meters for short distances and kilometers for long distances automatically.
- Offers kilometers-only mode and compact or precise formatting.
- Converts both ends of ranges: `8-35 yd range` becomes `7 m - 32 m range`
  in the default compact mode.
- Saves settings account-wide and refreshes converted text when settings change.
- Changes displayed text only, never spell ranges or game mechanics.

## Install

Download the installable ZIP from
[GitHub Releases](https://github.com/jlblancolb/yards-to-km/releases) and extract
its `YardsToKm` folder into your Classic Era `Interface/AddOns` directory.
Use the attached addon ZIP, not GitHub's automatically generated source ZIP.

The installed folder should look like:

```text
World of Warcraft/_classic_era_/Interface/AddOns/YardsToKm/
    YardsToKm.toc
    YardsToKm.lua
    Icon.tga
    README.md
    LICENSE
```

Keep the folder named `YardsToKm` so it matches `YardsToKm.toc`. Restart WoW
after the first installation and enable **Yards to Kilometers** in the AddOns
list. For Lua-only updates to an existing installation, overwrite the files
and run `/reload`.

## Use

Conversion is enabled by default and applies to detectable numeric values
followed by `yard`, `yards`, `yd`, or `yds`. Open **Options → AddOns → Yards to
Kilometers** to configure:

- **Conversion:** enable or disable display conversion.
- **Units:** automatically use meters/kilometers, or always use kilometers.
- **Precision:** compact (whole meters / thousandths of a kilometer) or precise
  (tenths of a meter / ten-thousandths of a kilometer).

Automatic units are the default: distances below 1,000 meters are shown in
meters and longer distances in kilometers. Ranges such as `10-20 yards` are
converted at both ends and show a unit for each endpoint. `/ytk on`, `/ytk off`,
and `/ytk scan` are also available in chat. Settings are saved account-wide.

| Command | Purpose |
| --- | --- |
| `/ytk on` | Enable conversion |
| `/ytk off` | Disable conversion and restore tracked original text |
| `/ytk scan` | Scan for additional UI text regions |

## Coverage

The addon hooks accessible UI text regions and periodically rescans for newly
created ones, so visible spell tooltips or range labels that expose yard values
may be converted automatically, including text set through formatted font
string calls. Visible tooltip text is also checked every 0.1 seconds to catch
native spell-range updates and later changes made by other addons.
This changes only displayed text: spell range checks and the
game's underlying yard-based APIs remain unchanged. Other game and addon UI
text may not be accessible, and hyperlink or texture markup is left unchanged.
Review converted displays for layout changes, especially in protected UI.

## Beta compatibility

The first beta targets Classic Era 1.15.9 (including Hardcore).
Spell tooltip conversion has been confirmed in-game by the initial tester.
Compatibility with all other addons and protected UI during combat is not yet
verified. This is best-effort display conversion, not a change to game mechanics.
English yard unit names are currently supported.

## Development

Fork the repository and clone your fork into a folder named `YardsToKm`.
See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, testing, and pull-request
guidelines. The runtime has no external addon dependencies.

With Lua 5.1 installed, run from the project directory:

```sh
luac5.1 -p YardsToKm.lua
lua5.1 tests/tooltip.lua
```

Alternatively, run the mocked regression checks with Node.js/npm:

```sh
npm exec --yes --package=fengari-node-cli -- fengari tests/tooltip.lua
```

## Packaging and releases

Run `python3 scripts/package.py` to generate `dist/YardsToKm-<version>-classic.zip`.
The ZIP contains a single `YardsToKm/` folder with only the addon files,
README, and license; Git metadata, tests, and tooling are excluded.

GitHub Actions checks Lua 5.1 syntax, runs the tooltip regression tests, and
builds a downloadable ZIP artifact on pushes, pull requests, and manual runs.
To publish a new version:

1. Update `## Version` in `YardsToKm.toc`, commit, and push.
2. Create a GitHub release tagged `v<version>` at that commit; mark betas as
   pre-releases.
3. The workflow verifies that the tag matches the manifest and attaches the
   installable ZIP. Upload that ZIP to CurseForge with the matching game version.

Do not replace an existing release's ZIP with different code; publish a new
version instead. CurseForge uploads remain manual for now.

## Support and contributions

[Report a bug or suggest a feature](https://github.com/jlblancolb/yards-to-km/issues/new/choose).
For display issues, include the exact unconverted text, client/addon versions,
UI language, and other addons affecting the tooltip. Remove personal details
from screenshots and error logs before sharing them.

Contributions are welcome through pull requests; please read
[CONTRIBUTING.md](CONTRIBUTING.md) first.

## License

MIT; see [LICENSE](LICENSE).
