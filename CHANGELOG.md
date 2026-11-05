# Changelog

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
