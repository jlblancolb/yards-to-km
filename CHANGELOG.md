# Changelog

## 1.1.1 (2026-11-06)

- Fixed empty **Display** and **Decimal separator** buttons (and a Lua error
  when opening settings) for players upgrading from 1.0: defaults for new
  options are now applied after saved variables load.
- The **Convert visible yard measurements** checkbox is visible again.
- README explains why only English clients are converted.

## 1.1.0 (2026-11-05)

- New **Display** option: show yards and metric together, such as `30 yd (27 m)`.
- New **Decimal separator** option: decimal comma (`0,5 km`) for players who use it.
- Ranges written with "to", such as `8 to 35 yards`, are now converted.
- Settings panel buttons are aligned in one column; new `/ytk replace`,
  `/ytk both`, `/ytk point` and `/ytk comma` shortcuts.
- CI uses Node.js 24 releases of its GitHub Actions.

## 1.0.0 (2026-11-05)

First stable release.

- Supports WoW Forever (interface 16001) alongside Classic Era 1.15.9 in a single package.
- On Forever, spell tooltips are hooked through tooltip data callbacks, and
  secret text values and forbidden frames are skipped safely.
- `/ytk` now shows the current settings; new `/ytk auto`, `/ytk km`,
  `/ytk compact` and `/ytk precise` shortcuts.
- Skips text with no digits or yard units before running conversion patterns.
- Release ZIPs are now named `YardsToKm-<version>.zip`.

## 0.1.0-beta.2 (2026-10-10)

- Fixed settings button labels going stale after changing options.

## 0.1.0-beta.1 (2026-10-10)

- First Classic Era beta: converts yard measurements in UI text and spell
  tooltips to meters or kilometers, with unit and precision settings.
