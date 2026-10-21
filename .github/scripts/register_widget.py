#!/usr/bin/env python3
"""Merge the home-screen widget <receiver> block into the app's AndroidManifest.xml.

Usage: register_widget.py <AndroidManifest.xml> <AndroidManifest_widget_entry.xml>
Idempotent: does nothing if the provider is already registered.
"""
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: register_widget.py <manifest> <entry-block>")
        return 2
    man, entry = sys.argv[1], sys.argv[2]
    with open(man, "r", encoding="utf-8") as fh:
        manifest = fh.read()
    if "ShelfWidgetProvider" in manifest:
        print("already registered — nothing to do")
        return 0
    with open(entry, "r", encoding="utf-8") as fh:
        block = fh.read().strip()
    if "</application>" not in manifest:
        print("no </application> in the manifest — cannot insert")
        return 1
    manifest = manifest.replace("</application>", block + "\n</application>", 1)
    with open(man, "w", encoding="utf-8") as fh:
        fh.write(manifest)
    print("widget receiver registered")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
