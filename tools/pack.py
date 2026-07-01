#!/usr/bin/env python
"""
pack.py - build the Roku channel package (global-pulse-roku.zip).

Zips the channel payload with forward-slash entry names and `manifest` at the
zip root (Compress-Archive writes backslashes, which Roku rejects). Excludes
dev-only source frames; includes the globe video + hold stills.

Run:  python tools/pack.py
Out:  ../global-pulse-roku.zip  (next to the repo folder)
"""
import os, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROKU = os.path.normpath(os.path.join(HERE, "..", "roku"))
OUT  = os.path.normpath(os.path.join(HERE, "..", "..", "global-pulse-roku.zip"))

# images to ship (icons + splash + marker dot); globe_still/ handled separately
KEEP_IMAGES = {
    "dot.png",
    "icon_focus_hd.png", "icon_focus_fhd.png", "icon_side_hd.png",
    "splash_hd.jpg", "splash_fhd.jpg",
}

def main():
    if os.path.exists(OUT):
        os.remove(OUT)
    n = 0
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(os.path.join(ROKU, "manifest"), "manifest"); n += 1
        z.write(os.path.join(ROKU, "events_sample.json"), "events_sample.json"); n += 1
        for sub in ("source", "components", "video"):
            for root, _, files in os.walk(os.path.join(ROKU, sub)):
                for f in files:
                    full = os.path.join(root, f)
                    z.write(full, os.path.relpath(full, ROKU).replace("\\", "/")); n += 1
        for f in os.listdir(os.path.join(ROKU, "images")):
            if f in KEEP_IMAGES:
                z.write(os.path.join(ROKU, "images", f), "images/" + f); n += 1
        gs = os.path.join(ROKU, "images", "globe_still")
        for f in sorted(os.listdir(gs)):
            z.write(os.path.join(gs, f), "images/globe_still/" + f); n += 1

    size = os.path.getsize(OUT) / 1024 / 1024
    with zipfile.ZipFile(OUT) as z:
        names = z.namelist()
        assert "manifest" in names, "manifest must be at zip root"
        assert not any("\\" in x for x in names), "entries must use forward slashes"
    print(f"built {OUT}")
    print(f"  {n} entries, {size:.1f} MB")

if __name__ == "__main__":
    main()
