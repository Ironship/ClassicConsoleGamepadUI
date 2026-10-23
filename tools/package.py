"""Build the standalone Forever addon with only its runtime files and documentation."""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = "ClassicConsoleGamepadUI"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT.parent / f"{NAME}-releases")
    args = parser.parse_args()
    toc = (ROOT / f"{NAME}.toc").read_text(encoding="utf-8")
    version = re.search(r"^## Version: (.+)$", toc, re.M).group(1)
    core = (ROOT / "Core.lua").read_text(encoding="utf-8")
    code_version = re.search(r'^Addon\.version = "([^"]+)"$', core, re.M).group(1)
    if code_version != version:
        raise SystemExit(f"Core.lua version must match {NAME}.toc before packaging")
    runtime = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    files = [f"{NAME}.toc", *runtime, "README.md", "CHANGELOG.md", "LICENSE"]
    payload = {name: (ROOT / name).read_bytes() for name in files}
    # Forever loads the _Camelot TOC; the plain TOC keeps other loaders working.
    payload[f"{NAME}_Camelot.toc"] = payload[f"{NAME}.toc"]
    args.output.mkdir(parents=True, exist_ok=True)
    # CurseForge expects one top-level folder named after the TOC.
    destination = args.output / f"{NAME}-{version}.zip"
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(payload.items()):
            info = zipfile.ZipInfo(f"{NAME}/{name}", date_time=(2026, 10, 22, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, data)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    destination.with_suffix(".zip.sha256").write_text(f"{digest}  {destination.name}\n", encoding="ascii")
    print(json.dumps({"path": str(destination), "sha256": digest, "files": len(payload)}, indent=2))


if __name__ == "__main__":
    main()
