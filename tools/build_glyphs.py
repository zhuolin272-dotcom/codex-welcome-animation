"""Precompute reusable Sacramento strokes; end users need no Python runtime."""
import json, unicodedata
from build import (root, fp, font, glyphs, cmap, upm, SVGPathPen, TransformPen,
                   Image, ImageDraw, ImageFont, np, distance_transform_edt, chains, smooth)

size=300
scale=size/upm
library={}
for cp in sorted(cmap):
    if not 32<=cp<=591 or unicodedata.category(chr(cp)).startswith('C'): continue
    char=chr(cp); name=cmap[cp]; advance=font['hmtx'][name][0]*scale
    pen=SVGPathPen(glyphs)
    glyphs[name].draw(TransformPen(pen,(scale,0,0,-scale,0,0)))
    canvas=Image.new('L',(int(advance+size*1.2),int(size*1.8)))
    origin=(size*.6,size*1.2)
    ImageDraw.Draw(canvas).text(origin,char,font=ImageFont.truetype(str(fp),size),fill=255,anchor='ls')
    pixels=np.array(canvas)>80
    strokes=[smooth([(float(x)-origin[0],float(y)-origin[1]) for y,x in line])
             for line in chains(pixels) if len(line)>=3]
    library[char]={'advance':round(advance,4),'outline':pen.getCommands(),
                   'width':round(float(distance_transform_edt(pixels).max())*2+7,1),'strokes':strokes}
output=root/'docs/glyphs.js'
output.write_text('/* Sacramento glyph outlines and ink paths; see assets/fonts/OFL.txt. */\nwindow.CWGlyphs='+json.dumps(library,ensure_ascii=True,separators=(',',':'))+';\n',encoding='utf8')
print(f'Built {len(library)} reusable glyphs: {output.stat().st_size} bytes')
