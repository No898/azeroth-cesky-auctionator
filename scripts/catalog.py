"""Build the Czech addon and detect upstream changes without executing upstream Lua."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = "AAzerothAuctionator"
SOURCE = "Auctionator/Locales/enUS.lua"
# Direct UI strings, never passed to string.format. "% of" otherwise looks
# like the valid Lua format "% o". The search sentinel keeps its delimiters.
LITERAL_PERCENT_KEYS = {
    "EXTENDED_SEARCH_ACTIVE_TEXT", "STARTING_PRICE_PERCENTAGE_SUFFIX", "PERCENTAGE_SUFFIX"
}
ASSIGNMENT = re.compile(r'^\s*L\["([A-Z0-9_]+)"\]\s*=\s*("(?:[^"\\]|\\.)*")\s*$')
FORMAT = re.compile(r"%%|%[-+ #0]*\d*(?:\.\d+)?[cdiouxXeEfgGqs]")
MARKUP = re.compile(r"\|c[0-9a-fA-F]{8}|\|r|\|[HTht]|\|[14]")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_object)


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def parse_source(source):
    """The pinned source uses double-quoted literals compatible with JSON escapes.

    Duplicate Lua assignments intentionally use the last value, as Lua does.
    Fail closed on a new source syntax instead of silently dropping entries.
    """
    result = {}
    for number, line in enumerate(source.splitlines(), 1):
        match = ASSIGNMENT.fullmatch(line)
        if match:
            result[match[1]] = json.loads(match[2])
        elif line.strip() and line.strip() not in {
            "AUCTIONATOR_LOCALES.enUS = function()", "local L = {}", "return L", "end"
        } and not line.lstrip().startswith("--"):
            raise ValueError(f"Unsupported upstream Lua syntax at line {number}")
    if not result:
        raise ValueError("Empty upstream catalogue")
    return result


def signature(key, value):
    return {
        "sha256": digest(value.encode("utf-8")),
        "format": [] if key in LITERAL_PERCENT_KEYS else FORMAT.findall(value),
        "markup": MARKUP.findall(value),
        "newlines": value.replace("\\n", "\n").count("\n"),
        "percents": value.count("%"),
    }


def source_from_zip(path):
    with zipfile.ZipFile(path) as archive:
        return parse_source(archive.read(SOURCE).decode("utf-8-sig"))


def metadata():
    return read_json(ROOT / "locales/upstream.json")


def translations():
    return read_json(ROOT / "locales/csCZ.json")


def validate(catalogue, upstream):
    issues = []
    expected = upstream["strings"]
    for key in sorted(expected.keys() - catalogue.keys()):
        issues.append(f"Missing translation: {key}")
    for key in sorted(catalogue.keys() - expected.keys()):
        issues.append(f"Unknown translation: {key}")
    for key in sorted(expected.keys() & catalogue.keys()):
        value = catalogue[key]
        if not isinstance(value, str) or not value or (not value.strip() and key != "NUMBER_SEPARATOR"):
            issues.append(f"Empty/non-string translation: {key}")
            continue
        actual = signature(key, value)
        for field in ("format", "markup", "newlines", "percents"):
            if actual[field] != expected[key][field]:
                issues.append(f"Changed {field}: {key}")
        if any(ord(character) < 32 and character not in "\n\t" for character in value):
            issues.append(f"Unsupported control character: {key}")
        if key == "EXTENDED_SEARCH_ACTIVE_TEXT" and not (value.startswith("%") and value.endswith("%")):
            issues.append(f"Missing sentinel delimiters: {key}")
    return issues


def render(catalogue, version):
    lines = [
        "-- Generated from locales/csCZ.json; edit the catalogue, not this file.",
        f"-- Czech translation maintained by Azeroth česky. Auctionator {version}.",
        "-- Must load before Auctionator; no Dependencies/OptionalDeps: Auctionator.",
        "AUCTIONATOR_LOCALES_OVERRIDE = function()", "  local L = {}", "",
    ]
    for key, value in sorted(catalogue.items()):
        lines.append(f"  L[{json.dumps(key)}] = {json.dumps(value, ensure_ascii=False)}")
    return "\n".join(lines + ["", "  return L", "end", ""])


def check():
    upstream, catalogue = metadata(), translations()
    problems = validate(catalogue, upstream)
    target = ROOT / "addon" / ADDON / "Translations.lua"
    if not target.exists() or target.read_text(encoding="utf-8") != render(catalogue, upstream["version"]):
        problems.append("Generated Lua is stale; run python3 scripts/catalog.py build")
    toc = (target.parent / f"{ADDON}.toc").read_text(encoding="utf-8")
    if re.search(r"^##\s*(?:Dependencies|RequiredDeps|OptionalDeps|LoadOnDemand):", toc, re.M):
        problems.append("Translation must load eagerly, before Auctionator, without TOC dependencies")
    if not ADDON.casefold() < "Auctionator".casefold():
        problems.append("Addon name must sort before Auctionator")
    version = (ROOT / "VERSION").read_text().strip()
    if f"## Version: {version}\n" not in toc:
        problems.append("TOC and VERSION disagree")
    if problems:
        raise ValueError("\n".join(problems))
    print(f"OK: {len(catalogue)}/{len(upstream['strings'])} translations, format, markup, TOC and generated Lua")


def package():
    check()
    version = (ROOT / "VERSION").read_text().strip()
    target = ROOT / "dist" / f"{ADDON}-{version}.zip"
    target.parent.mkdir(exist_ok=True)
    files = {
        f"{ADDON}/{ADDON}.toc": ROOT / "addon" / ADDON / f"{ADDON}.toc",
        f"{ADDON}/Translations.lua": ROOT / "addon" / ADDON / "Translations.lua",
        f"{ADDON}/README.md": ROOT / "README.md",
        f"{ADDON}/CHANGELOG.md": ROOT / "CHANGELOG.md",
    }
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, path in sorted(files.items()):
            info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes())
    checksum = digest(target.read_bytes())
    target.with_suffix(".zip.sha256").write_text(f"{checksum}  {target.name}\n")
    print(f"Packaged {target.name}: {checksum}")


def fetch():
    upstream = metadata()
    target = ROOT / ".cache" / f"Auctionator-{upstream['version']}.zip"
    target.parent.mkdir(exist_ok=True)
    if not target.exists():
        with urllib.request.urlopen(upstream["download_url"], timeout=60) as response:
            data = response.read()
        if digest(data) != upstream["archive_sha256"]:
            raise ValueError("Upstream download checksum mismatch")
        target.write_bytes(data)
    if digest(target.read_bytes()) != upstream["archive_sha256"]:
        raise ValueError("Cached upstream checksum mismatch")
    print(target)


def compare(path):
    upstream = metadata()
    current = source_from_zip(path)
    before = upstream["strings"]
    added = sorted(current.keys() - before.keys())
    removed = sorted(before.keys() - current.keys())
    changed = sorted(k for k in current.keys() & before.keys()
                     if signature(k, current[k])["sha256"] != before[k]["sha256"])
    report = {"added": added, "changed": changed, "removed": removed,
              "source_texts_to_review": {k: current[k] for k in added + changed}}
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return bool(added or changed or removed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["fetch", "build", "check", "package", "compare", "snapshot"])
    parser.add_argument("--zip", type=Path, help="Official Auctionator release archive")
    args = parser.parse_args()
    if args.command in {"compare", "snapshot"} and not args.zip:
        parser.error("--zip is required")
    if args.command == "fetch":
        fetch()
    elif args.command == "snapshot":
        upstream = metadata()
        if digest(args.zip.read_bytes()) != upstream["archive_sha256"]:
            raise ValueError("Archive does not match configured upstream checksum")
        upstream["strings"] = {k: signature(k, v) for k, v in sorted(source_from_zip(args.zip).items())}
        write_json(ROOT / "locales/upstream.json", upstream)
        print(f"Recorded {len(upstream['strings'])} source fingerprints")
    elif args.command == "compare":
        raise SystemExit(1 if compare(args.zip) else 0)
    elif args.command == "build":
        upstream, catalogue = metadata(), translations()
        problems = validate(catalogue, upstream)
        if problems:
            raise ValueError("\n".join(problems))
        (ROOT / "addon" / ADDON / "Translations.lua").write_text(render(catalogue, upstream["version"]), encoding="utf-8")
        check()
    elif args.command == "check":
        check()
    else:
        package()


if __name__ == "__main__":
    main()
