from pathlib import Path
import argparse, json, re, math, html
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from skimage.measure import approximate_polygon
from skimage.morphology import skeletonize
from scipy.ndimage import distance_transform_edt
root=Path(__file__).resolve().parents[1]
fp=root/'assets/fonts/Sacramento-Regular.ttf'
font=TTFont(fp);glyphs=font.getGlyphSet();cmap=font.getBestCmap();upm=font['head'].unitsPerEm
defs=[];shapes=[];letters=[]

def chains(binary):
    sk=skeletonize(binary)
    pts=set(zip(*np.where(sk)))
    adj={p:[] for p in pts}
    for y,x in pts:
        for dy,dx in ((-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)):
            q=(y+dy,x+dx)
            if q not in pts: continue
            if dx and dy and ((y,x+dx) in pts or (y+dy,x) in pts): continue
            adj[(y,x)].append(q)
    used=set(); lines=[]
    nodes=sorted(pts,key=lambda p:(len(adj[p])==2,p[1],-p[0]))
    for p in nodes:
        for q in adj[p]:
            edge=frozenset((p,q))
            if edge in used: continue
            line=[p,q];used.add(edge);prev=p;cur=q
            while len(adj[cur])==2:
                nxt=next((n for n in adj[cur] if n!=prev),None)
                if nxt is None or frozenset((cur,nxt)) in used:break
                used.add(frozenset((cur,nxt)));line.append(nxt);prev,cur=cur,nxt
            if len(line)>2:lines.append(line)
    # Traverse the pen graph from the leftmost entry, choosing nearby continuations.
    ordered=[]; cursor=min(pts,key=lambda p:(p[1],-p[0])) if pts else (0,0)
    while lines:
        best=min(range(len(lines)),key=lambda i:min(math.dist(cursor,lines[i][0]),math.dist(cursor,lines[i][-1])))
        line=lines.pop(best)
        if math.dist(cursor,line[-1])<math.dist(cursor,line[0]):line.reverse()
        ordered.append(line);cursor=line[-1]
    return ordered

def smooth(points):
    a=np.array(points,dtype=float)
    a=approximate_polygon(a,.8)
    if len(a)<2:return ''
    d=f'M {a[0,0]:.2f},{a[0,1]:.2f}'
    for i in range(len(a)-1):
        p0=a[max(0,i-1)];p1=a[i];p2=a[i+1];p3=a[min(len(a)-1,i+2)]
        c1=p1+(p2-p0)/6;c2=p2-(p3-p1)/6
        d+=f' C {c1[0]:.2f},{c1[1]:.2f} {c2[0]:.2f},{c2[1]:.2f} {p2[0]:.2f},{p2[1]:.2f}'
    return d

def flowing_word(text,size,baseline,phase):
    scale=size/upm
    width=sum(font['hmtx'][cmap[ord(c)]][0]*scale for c in text)
    x=(1920-width)/2
    for ci,c in enumerate(text):
        name=cmap[ord(c)];advance=font['hmtx'][name][0]*scale
        pen=SVGPathPen(glyphs);glyphs[name].draw(TransformPen(pen,(scale,0,0,-scale,x,baseline)))
        canvas=Image.new('L',(int(advance+size*1.2),int(size*1.8)))
        origin=(size*.6,size*1.2)
        ImageDraw.Draw(canvas).text(origin,c,font=ImageFont.truetype(str(fp),size),fill=255,anchor='ls')
        a=np.array(canvas)>80;sw=float(distance_transform_edt(a).max())*2+7
        paths=[]
        # Only actual ink chains consume writing time. Empty travel between
        # branches previously made the lettering seem to stop unexpectedly.
        for j,line in enumerate(chains(a)):
            if len(line)<3:continue
            pts=[(float(px)+x-origin[0],float(py)+baseline-origin[1]) for py,px in line]
            rid=f'ink-{phase}-{ci}-{j}'
            paths.append(f'<path id="{rid}" d="{smooth(pts)}"/>')
            letters.append(dict(id=rid))
        mid=f'glyph-{phase}-{ci}'
        defs.append(f'<mask id="{mid}" maskUnits="userSpaceOnUse" x="0" y="0" width="1920" height="1080"><g fill="none" stroke="white" stroke-width="{sw:.1f}" stroke-linecap="round" stroke-linejoin="round">{"".join(paths)}</g></mask>')
        shapes.append(f'<path d="{pen.getCommands()}" mask="url(#{mid})"/>')
        x+=advance

def main():
    parser=argparse.ArgumentParser(description="Build the offline welcome animation")
    parser.add_argument('--name',default='JimmSun');parser.add_argument('--greeting',default='welcome')
    args=parser.parse_args()
    if not 1<=len(args.name)<=20 or not 1<=len(args.greeting)<=20:parser.error('Use 1-20 supported Latin characters per line.')
    if any(ord(c) not in cmap for c in args.name+args.greeting):parser.error('This font does not support one of the supplied characters.')
    flowing_word(args.greeting,216,510,2);flowing_word(args.name,300,760,4)
    logo=(root/'assets/openai.svg').read_text(encoding='utf8')
    logo=re.search(r'<path d="([^"]+)"',logo).group(1)
    content=(root/'source/animation.template.html').read_text(encoding='utf8')
    for key,value in {'__MASKS__':''.join(defs),'__LETTERS__':json.dumps(letters),'__GLYPHS__':''.join(shapes),'__LOGO__':logo,'__GREETING_LABEL__':html.escape(args.greeting+' '+args.name,quote=True)}.items():content=content.replace(key,value)
    (root/'docs/animation.html').write_text(content,encoding='utf8')
    print('Built docs/animation.html; full 8.1s / fast 5.0625s; ink chains:',len(letters))

if __name__=='__main__': main()
