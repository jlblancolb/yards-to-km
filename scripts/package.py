"""Build a reproducible, installable addon ZIP from an explicit file list."""

import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parent.parent
FILES = ("YardsToKm.toc", "YardsToKm.lua", "Icon.tga", "README.md", "LICENSE")


def package():
    toc = (ROOT / "YardsToKm.toc").read_text()
    match = re.search(r"^## Version: ([0-9A-Za-z.-]+)$", toc, re.MULTILINE)
    if not match:
        raise ValueError("Missing or invalid version in YardsToKm.toc")

    destination = ROOT / "dist" / f"YardsToKm-{match[1]}-classic.zip"
    destination.parent.mkdir(exist_ok=True)
    with ZipFile(destination, "w", compression=ZIP_DEFLATED) as archive:
        for name in FILES:
            entry = ZipInfo(f"YardsToKm/{name}", date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = ZIP_DEFLATED
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, (ROOT / name).read_bytes())

    with ZipFile(destination) as archive:
        assert archive.testzip() is None, "ZIP integrity check failed"
        assert archive.namelist() == [f"YardsToKm/{name}" for name in FILES]
    print(destination)


if __name__ == "__main__":
    package()
