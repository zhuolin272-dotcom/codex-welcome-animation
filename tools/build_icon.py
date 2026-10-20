"""Rasterize the repository's OpenAI vector into transparent Windows icons."""
from pathlib import Path
from xml.etree import ElementTree as ET
import shutil
from fontTools.pens.basePen import BasePen
from fontTools.svgLib.path import parse_path
from PIL import Image, ImageChops, ImageDraw

root = Path(__file__).resolve().parents[1]
assets = root / 'assets'
source = ET.parse(assets / 'openai.svg').getroot()
path = source.find('{http://www.w3.org/2000/svg}path').attrib['d']
svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-3 -3 30 30" width="512" height="512"><title>OpenAI</title><path fill="#ffffff" fill-rule="evenodd" d="{path}"/></svg>\n'
(assets / 'openai-transparent.svg').write_text(svg, encoding='utf8')

class Contours(BasePen):
    def __init__(self):
        super().__init__(None)
        self.contours = []
        self.current = []

    def _moveTo(self, point):
        self.current = [point]

    def _lineTo(self, point):
        self.current.append(point)

    def _curveToOne(self, p1, p2, p3):
        p0 = self._getCurrentPoint()
        for i in range(1, 49):
            t = i / 48
            u = 1 - t
            self.current.append(tuple(u**3*p0[j] + 3*u*u*t*p1[j] + 3*u*t*t*p2[j] + t**3*p3[j] for j in (0, 1)))

    def _qCurveToOne(self, p1, p2):
        p0 = self._getCurrentPoint()
        for i in range(1, 49):
            t = i / 48
            self.current.append(tuple((1-t)**2*p0[j] + 2*(1-t)*t*p1[j] + t*t*p2[j] for j in (0, 1)))

    def _closePath(self):
        self.contours.append(self.current)
        self.current = []

    def _endPath(self):
        self._closePath()

pen = Contours()
parse_path(path, pen)
size = 2048
mask = Image.new('1', (size, size))
for contour in pen.contours:
    layer = Image.new('1', (size, size))
    ImageDraw.Draw(layer).polygon([((x+3)*size/30, (y+3)*size/30) for x, y in contour], fill=1)
    mask = ImageChops.logical_xor(mask, layer)
alpha = mask.convert('L').resize((512, 512), Image.Resampling.LANCZOS)
icon = Image.new('RGBA', (512, 512), (255, 255, 255, 0))
icon.putalpha(alpha)
icon.save(assets / 'openai-transparent.png')
sizes = [(n, n) for n in (16, 20, 24, 32, 40, 48, 64, 96, 128, 256)]
icon.save(assets / 'openai-transparent.ico', sizes=sizes)
# Preserve the existing favicon resource name for earlier animation URLs.
shutil.copyfile(assets / 'openai-transparent.ico', assets / 'app.ico')
print('Built transparent white OpenAI SVG, PNG and 10-size Windows ICO.')
