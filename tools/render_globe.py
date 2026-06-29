#!/usr/bin/env python
"""
render_globe.py - Pre-render an orthographic 3D globe spin for the Roku channel.

Roku has no WebGL, so the "3D globe" on Roku is a pre-rendered frame sequence:
the real blue-marble equirectangular map reprojected onto a sphere (orthographic),
one frame per longitude step, composited over a starfield with an atmosphere glow.

The Roku scene (ScreensaverScene.brs) flips through these frames to rotate the
globe and "fly to" an event by spinning to the frame whose centre longitude
matches the event, then projects live markers with the SAME orthographic math.

Output:
  roku/images/globe/frame_000.jpg .. frame_(N-1).jpg   full 1280x720 frames
  prints GLOBE CONSTANTS that must be kept in sync with ScreensaverScene.brs

Run:  python tools/render_globe.py
"""
import os, math, numpy as np
from PIL import Image

# ---- output geometry (must match ScreensaverScene.brs constants) -----------
W, H   = 1280, 720          # Roku HD design surface
CX, CY = 640, 326           # globe centre on screen (slightly high; card sits low)
R      = 332                # globe radius in px
LAT0   = 16.0               # camera tilt: look slightly down on N hemisphere
N      = 72                 # frames for a full 360 deg spin (5 deg/frame)
# Frame i is centred on longitude LON0(i) = -i * (360/N).  Marker projection in
# BrightScript uses the identical formula so dots land on the right pixels.

HERE   = os.path.dirname(os.path.abspath(__file__))
ROKU   = os.path.normpath(os.path.join(HERE, "..", "roku"))
SRCMAP = os.path.join(ROKU, "images", "world.jpg")
OUTDIR = os.path.join(ROKU, "images", "globe")
os.makedirs(OUTDIR, exist_ok=True)

# ---- load equirectangular earth -------------------------------------------
src = np.asarray(Image.open(SRCMAP).convert("RGB"), dtype=np.float32)
MH, MW, _ = src.shape

# ---- precompute the disc: for each screen pixel inside the globe, the 3D
#      camera-space unit vector (sphere point facing camera) ----------------
ys, xs = np.mgrid[0:H, 0:W]
nx = (xs - CX) / R
ny = (CY - ys) / R          # screen y is down; flip so +y is up
rho2 = nx * nx + ny * ny
disc = rho2 <= 1.0          # inside the globe silhouette
nz = np.sqrt(np.clip(1.0 - rho2, 0.0, 1.0))   # toward camera

# limb darkening + simple directional shading for sphere realism
light = np.array([-0.35, 0.45, 0.82])          # sun from upper-left-front
light /= np.linalg.norm(light)
shade = np.clip(nx * light[0] + ny * light[1] + nz * light[2], 0.0, 1.0)
shade = 0.35 + 0.65 * shade                    # ambient floor so night side isn't black
limb  = 0.55 + 0.45 * nz                        # darken toward the edge
shade = shade * limb

lat0 = math.radians(LAT0)
sin_lat0, cos_lat0 = math.sin(lat0), math.cos(lat0)

# ---- static starfield (same for every frame = stable space background) -----
rng = np.random.default_rng(7)
space = np.zeros((H, W, 3), dtype=np.float32)
space[:] = (4, 6, 12)                            # deep space navy
nstars = 1100
sx = rng.integers(0, W, nstars); sy = rng.integers(0, H, nstars)
sb = rng.uniform(0.25, 1.0, nstars)[:, None]
tint = rng.uniform(0.85, 1.0, (nstars, 3))
space[sy, sx] = np.clip(space[sy, sx] + 235 * sb * tint, 0, 255)
# a few brighter stars
for _ in range(70):
    bx, by = rng.integers(2, W - 2), rng.integers(2, H - 2)
    space[by, bx] = (255, 255, 255)
    space[by, bx-1] = space[by, bx+1] = space[by-1, bx] = space[by+1, bx] = (150,170,200)

# ---- atmosphere glow ring just outside the silhouette ----------------------
rho = np.sqrt(rho2)
atmo = np.exp(-np.clip(rho - 1.0, 0, 5) * 7.0)   # falls off outside the disc
atmo[disc] = 0.0
atmo = atmo[..., None] * np.array([70, 150, 255], dtype=np.float32)  # blue rim

def reproject_correct(lon0_deg):
    """Snyder inverse orthographic projection (the textbook formula)."""
    lon0 = math.radians(lon0_deg)
    rho_ = np.sqrt(rho2)
    c = np.arcsin(np.clip(rho_, -1, 1))          # since R-normalised, rho = sin(c)
    cosc = np.cos(c); sinc = np.sin(c)
    sinc_safe = np.where(rho_ < 1e-9, 1e-9, rho_)
    lat = np.arcsin(np.clip(cosc * sin_lat0 + (ny * sinc * cos_lat0) / sinc_safe, -1, 1))
    lon = lon0 + np.arctan2(nx * sinc,
                            rho_ * cos_lat0 * cosc - ny * sin_lat0 * sinc)
    return lat, lon

print(f"Rendering {N} frames {W}x{H}  globe R={R} centre=({CX},{CY}) tilt={LAT0}")
for i in range(N):
    lon0_deg = -i * (360.0 / N)
    lat, lon = reproject_correct(lon0_deg)
    # map lat/lon -> equirectangular pixel
    u = (np.degrees(lon) + 180.0) % 360.0 / 360.0 * (MW - 1)
    v = (90.0 - np.degrees(lat)) / 180.0 * (MH - 1)
    ui = np.clip(u, 0, MW - 1).astype(np.int32)
    vi = np.clip(v, 0, MH - 1).astype(np.int32)
    earth = src[vi, ui] * shade[..., None]

    frame = space.copy()
    frame += atmo                                 # glow rim
    frame[disc] = earth[disc]
    out = np.clip(frame, 0, 255).astype(np.uint8)
    Image.fromarray(out, "RGB").save(os.path.join(OUTDIR, f"frame_{i:03d}.jpg"),
                                     quality=82, optimize=True)
    if i % 12 == 0:
        print(f"  frame {i:3d}  lon0={lon0_deg:7.1f}")

print("\nGLOBE CONSTANTS (sync with ScreensaverScene.brs):")
print(f"  m.gW={W} : m.gH={H}")
print(f"  m.gCX={CX} : m.gCY={CY} : m.gR={R}")
print(f"  m.gLat0={LAT0} : m.gN={N}")
print("  frame i centre longitude = -i * (360/N)")
print(f"\nWrote {N} frames to {OUTDIR}")
