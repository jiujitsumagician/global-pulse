#!/usr/bin/env python
"""
render_globe_video.py - render a SEAMLESS globe-spin H.264 loop for the Roku
Video node (smooth hardware-decoded rotation). Frames 0..N-1 cover exactly
360 deg, so frame N == frame 0 -> the loop is seamless. Same orthographic
projection as render_globe.py so the marker math still lines up.

Output (to a scratch dir, not the channel until chosen):
  <out>/frames/f_#####.jpg ... and <out>/globe_spin.mp4
"""
import os, math, sys, subprocess, numpy as np
from PIL import Image
import imageio_ffmpeg

N      = int(os.environ.get("GP_N", "360"))     # distinct frames over 360 deg
FPS    = int(os.environ.get("GP_FPS", "24"))    # -> 360/24 = 15s per revolution
W, H   = 1280, 720
CX, CY = 640, 326
R      = 332
LAT0   = 16.0

HERE   = os.path.dirname(os.path.abspath(__file__))
SRCMAP = os.path.normpath(os.path.join(HERE, "..", "roku", "images", "world.jpg"))
OUT    = os.environ.get("GP_OUT", os.path.normpath(os.path.join(HERE, "..", ".tmp_video")))
FDIR   = os.path.join(OUT, "frames")
os.makedirs(FDIR, exist_ok=True)

src = np.asarray(Image.open(SRCMAP).convert("RGB"), dtype=np.float32)
MH, MW, _ = src.shape

ys, xs = np.mgrid[0:H, 0:W]
nx = (xs - CX) / R
ny = (CY - ys) / R
rho2 = nx*nx + ny*ny
disc = rho2 <= 1.0
nz = np.sqrt(np.clip(1.0 - rho2, 0.0, 1.0))

light = np.array([-0.35, 0.45, 0.82]); light /= np.linalg.norm(light)
shade = np.clip(nx*light[0] + ny*light[1] + nz*light[2], 0.0, 1.0)
shade = 0.35 + 0.65*shade
shade = shade * (0.55 + 0.45*nz)

lat0 = math.radians(LAT0); s0, c0 = math.sin(lat0), math.cos(lat0)

rng = np.random.default_rng(7)
space = np.zeros((H, W, 3), dtype=np.float32); space[:] = (4, 6, 12)
sx = rng.integers(0, W, 1100); sy = rng.integers(0, H, 1100)
sb = rng.uniform(0.25, 1.0, 1100)[:, None]; tint = rng.uniform(0.85, 1.0, (1100, 3))
space[sy, sx] = np.clip(space[sy, sx] + 235*sb*tint, 0, 255)

rho = np.sqrt(rho2)
atmo = np.exp(-np.clip(rho - 1.0, 0, 5)*7.0); atmo[disc] = 0.0
atmo = atmo[..., None]*np.array([70, 150, 255], dtype=np.float32)

rho_ = rho.copy()
c = np.arcsin(np.clip(rho_, -1, 1)); cosc = np.cos(c); sinc = np.sin(c)
sinc_safe = np.where(rho_ < 1e-9, 1e-9, rho_)

def frame(i):
    lon0 = math.radians(-i*(360.0/N))
    lat = np.arcsin(np.clip(cosc*s0 + (ny*sinc*c0)/sinc_safe, -1, 1))
    lon = lon0 + np.arctan2(nx*sinc, rho_*c0*cosc - ny*s0*sinc)
    u = (np.degrees(lon) + 180.0) % 360.0 / 360.0*(MW-1)
    v = (90.0 - np.degrees(lat)) / 180.0*(MH-1)
    earth = src[np.clip(v,0,MH-1).astype(np.int32), np.clip(u,0,MW-1).astype(np.int32)]*shade[...,None]
    f = space.copy() + atmo
    f[disc] = earth[disc]
    return np.clip(f, 0, 255).astype(np.uint8)

print(f"render {N} frames -> {FDIR}")
for i in range(N):
    Image.fromarray(frame(i), "RGB").save(os.path.join(FDIR, f"f_{i:05d}.jpg"), quality=85)
    if i % 60 == 0: print(f"  {i}/{N}")

mp4 = os.path.join(OUT, "globe_spin.mp4")
exe = imageio_ffmpeg.get_ffmpeg_exe()
cmd = [exe, "-y", "-framerate", str(FPS), "-i", os.path.join(FDIR, "f_%05d.jpg"),
       "-c:v", "libx264", "-pix_fmt", "yuv420p", "-profile:v", "high", "-level", "4.0",
       "-crf", "20", "-preset", "slow", "-movflags", "+faststart",
       "-vf", "format=yuv420p", mp4]
print("encoding:", " ".join(cmd[:3]), "...")
r = subprocess.run(cmd, capture_output=True, text=True)
print("ffmpeg rc:", r.returncode)
if r.returncode != 0: print(r.stderr[-1500:])
if os.path.exists(mp4):
    print(f"MP4: {mp4}  {os.path.getsize(mp4)/1024/1024:.2f} MB  ({N} frames @ {FPS}fps = {N/FPS:.1f}s/rev)")
