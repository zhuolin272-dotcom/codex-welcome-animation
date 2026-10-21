"""Deterministic original particle flight, sampled from our existing OpenAI asset.

96 frames at 60 fps, 640x400. Shared by WPF and Core Animation so startup
never waits for a browser shader or a live particle simulation.
"""
from pathlib import Path
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[1]
W, H, FRAMES = 640, 400, 96
rng = np.random.default_rng(37)
mask = np.asarray(Image.open(ROOT/'assets/openai-transparent-1024.png').getchannel('A').resize((256,256)))
ys,xs = np.where(mask > 170)
idx = rng.integers(0,len(xs),2900)
# Extruded knot ribbons give the passage an identifiable OpenAI silhouette.
x = (xs[idx]/255-.5)*2
y = (ys[idx]/255-.5)*2
z = rng.uniform(1.5,8.0,len(idx))
z[:1950] = rng.uniform(4.3,4.5,1950)
bright = rng.uniform(.25,1,len(idx))
bright[:1950] = rng.uniform(.7,1,1950)
size = rng.uniform(.15,.65,len(idx))
ambient = np.column_stack((rng.uniform(-4,4,260),rng.uniform(-2.8,2.8,260),rng.uniform(1.5,9,260)))
def smooth(p):
    p=max(0,min(1,p));return p*p*(3-2*p)
def render(frame,dark):
    t=frame/60;p=t/1.6
    camera=.15+9.8*(.1*p+.9*p*p)
    background=(5,6,9) if dark else (247,246,242)
    image=Image.new('RGB',(W*2,H*2),background)
    dust=Image.new('RGB',image.size);draw=ImageDraw.Draw(dust)
    fade=1-smooth((p-.82)/.18)
    # Depth sorting gives small distant dust and broad, softly glowing near stars.
    for i in np.argsort(z)[::-1]:
        depth=z[i]-camera
        if depth<.18:continue
        scale=H*1.04/depth
        angle=.065*t+.025*z[i]
        xx=(x[i]*math.cos(angle)-y[i]*math.sin(angle))*scale+W/2
        yy=(x[i]*math.sin(angle)+y[i]*math.cos(angle))*scale+H/2
        if not (-20<xx<W+20 and -20<yy<H+20):continue
        radius=min(4.8,max(.22,size[i]*1.7/depth))
        a=bright[i]*fade*(.72+.28*math.sin(i*1.8+t*3))
        c=(int(170*a),int(193*a),int(246*a)) if dark else (int(107*a),int(116*a),int(127*a))
        # Radial motion trails become visible only while accelerating through.
        trail=min(.045,p*p*.04)/depth
        end=(xx+(xx-W/2)*trail,yy+(yy-H/2)*trail)
        draw.line((xx*2,yy*2,end[0]*2,end[1]*2),fill=c,width=max(1,int(radius)))
        draw.ellipse(((xx-radius)*2,(yy-radius)*2,(xx+radius)*2,(yy+radius)*2),fill=c)
    for i,(ax,ay,az) in enumerate(ambient):
        depth=az-camera
        if depth<.25:continue
        xx=W/2+ax*H/depth;yy=H/2+ay*H/depth
        if 0<xx<W and 0<yy<H:
            r=max(.2,.65/depth);v=int(135*fade)
            draw.ellipse(((xx-r)*2,(yy-r)*2,(xx+r)*2,(yy+r)*2),fill=(v,v,v))
    glow=dust.filter(ImageFilter.GaussianBlur(2.7))
    dust=ImageChops.add(dust,glow,scale=1)
    image=ImageChops.add(image,dust) if dark else ImageChops.subtract(image,dust)
    return image.resize((W,H),Image.Resampling.LANCZOS)
if __name__=='__main__':
    for dark in [True,False]:
        atlas=Image.new('RGB',(W*8,H*12))
        for frame in range(FRAMES):atlas.paste(render(frame,dark),((frame%8)*W,(frame//8)*H))
        path=ROOT/'docs'/('tunnel-dark.png' if dark else 'tunnel-light.png')
        atlas.save(path,optimize=True)
        print(path.name,path.stat().st_size)
