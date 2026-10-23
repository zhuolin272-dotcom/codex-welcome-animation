"""Encode our existing frames into bounded, hardware-decodable Mac movies.

Developer-only: requires ffmpeg (or --ffmpeg). End users need no encoder.
No user recordings, screenshots or reference video are used.
"""
from pathlib import Path
import argparse
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'macos' / 'Resources'


def encode(executable, name, size, frames):
    width, height = size
    command = [executable, '-hide_banner', '-loglevel', 'error', '-y',
               '-f', 'rawvideo', '-pixel_format', 'rgb24', '-video_size', f'{width}x{height}',
               '-framerate', '120', '-i', 'pipe:0', '-an', '-c:v', 'libx264',
               '-preset', 'slow', '-crf', '15', '-pix_fmt', 'yuv420p',
               '-profile:v', 'high', '-g', '120', '-bf', '2',
               '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709',
               '-movflags', '+faststart', str(OUT / name)]
    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    try:
        for frame in frames:
            process.stdin.write(frame.convert('RGB').tobytes())
    finally:
        process.stdin.close()
    if process.wait() != 0:
        raise RuntimeError(f'Encoding failed: {name}')
    print(name, (OUT / name).stat().st_size, flush=True)


def tunnel(theme):
    for chunk in range(6):
        with Image.open(ROOT / 'docs' / f'tunnel-{theme}-{chunk:02}.png') as atlas:
            atlas.load()
            for frame in range(32):
                x, y = frame % 4 * 1280, frame // 4 * 800
                yield atlas.crop((x, y, x + 1280, y + 800))


def orb():
    with Image.open(ROOT / 'assets' / 'orb-motion.png') as atlas:
        atlas.load()
        for frame in range(128):
            x, y = frame % 8 * 512, frame // 8 * 512
            yield atlas.crop((x, y, x + 512, y + 512))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ffmpeg', default='ffmpeg')
    args = parser.parse_args()
    OUT.mkdir(exist_ok=True)
    for theme in ('dark', 'light'):
        encode(args.ffmpeg, f'tunnel-{theme}.mp4', (1280, 800), tunnel(theme))
        with Image.open(ROOT / 'docs' / f'tunnel-{theme}-00.png') as atlas:
            atlas.crop((0, 0, 1280, 800)).save(OUT / f'tunnel-{theme}-poster.png', optimize=True)
    encode(args.ffmpeg, 'orb-loop.mp4', (512, 512), orb())
    with Image.open(ROOT / 'assets' / 'orb-motion.png') as atlas:
        atlas.crop((0, 0, 512, 512)).save(OUT / 'orb-poster.png', optimize=True)
