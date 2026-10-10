# Yards to Kilometers

A World of Warcraft Classic Era addon that best-effort converts detectable yard
measurements in UI text to meters or kilometers.

## Install

Download the installable ZIP from
[GitHub Releases](https://github.com/jlblancolb/yards-to-km/releases) and extract
its `YardsToKm` folder into your Classic Era `Interface/AddOns` directory.
Use the attached addon ZIP, not GitHub's automatically generated source ZIP.

Copy the `YardsToKm` project folder into
`World of Warcraft/_classic_era_/Interface/AddOns/`. The installed files should
be at `AddOns/YardsToKm/YardsToKm.toc`, `AddOns/YardsToKm/YardsToKm.lua`, and
`AddOns/YardsToKm/Icon.tga`; the folder and `.toc` filenames match.
Enable **Yards to Kilometers** from the AddOns list.

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

Run the mocked Lua regression checks from the project directory:

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

## License

MIT; see [LICENSE](LICENSE).
