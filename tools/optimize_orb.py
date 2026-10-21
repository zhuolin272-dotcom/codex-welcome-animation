"""Compact the generated cloud loop using a shared 256-color palette.

Frame dimensions and timing remain 512x512 / 120 fps. A single shared palette
prevents per-frame palette changes. The shader source remains in the template.
"""
from pathlib import Path
from PIL import Image

path=Path(__file__).resolve().parents[1]/'assets/orb-motion.png'
image=Image.open(path)
if image.mode!='P':
    image=image.convert('RGB')
    sample=image.resize((1024,2048),Image.Resampling.NEAREST)
    palette=sample.quantize(colors=256,method=Image.Quantize.MEDIANCUT,kmeans=2)
    image.quantize(palette=palette,dither=Image.Dither.FLOYDSTEINBERG).save(path,optimize=True)
print(path.name,path.stat().st_size)
