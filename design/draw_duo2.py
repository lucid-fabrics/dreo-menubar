"""Tower fan + circulator, with real form shading, rim light and a ground plane."""
from PIL import Image, ImageDraw, ImageFilter
import numpy as np, math
from iconkit import (SS, linear_gradient, radial_light, squircle_mask, drop_shadow,
                     cylinder_shade, apply_shade, rim_light, ground_reflection)

ART, S = 824*SS, 1024
WHITE, SHADE = np.array([255,255,255]), np.array([196,214,233])
DARK_T, DARK_B = np.array([11,40,84]), np.array([30,102,148])
FLOOR = ART*0.845

def blank(): return Image.new('RGBA',(ART,ART),(0,0,0,0))
def L(im): return ImageDraw.Draw(im)

# ---------------------------------------------------------------- backdrop
bg = linear_gradient(ART, (14,38,112), (22,182,180), angle=0.72)
bg.alpha_composite(radial_light(ART, ART*0.26, ART*0.14, ART*0.92, (150,235,255), 0.38))
# light pool on the floor so the objects have somewhere to stand
pool = blank()
L(pool).ellipse([ART*0.06, FLOOR-ART*0.075, ART*0.94, FLOOR+ART*0.085], fill=(180,245,255,44))
bg.alpha_composite(pool.filter(ImageFilter.GaussianBlur(ART*0.045)))
yy, xx = np.mgrid[0:ART,0:ART]
d = np.sqrt((xx-ART/2)**2+(yy-ART/2)**2)/(ART*0.72)
v = np.zeros((ART,ART,4), np.float32); v[...,3] = np.clip(d-0.52,0,1)*135
bg.alpha_composite(Image.fromarray(v.astype(np.uint8),'RGBA'))

objects = blank()          # everything solid, so it can cast one reflection

# ------------------------------------------------------------- TOWER
TW, TH = ART*0.168, ART*0.545
TCX = ART*0.308
t_bot = FLOOR - ART*0.026
t_top = t_bot - TH
def tower_body(dr): dr.rounded_rectangle([TCX-TW/2,t_top,TCX+TW/2,t_bot], radius=TW/2, fill=255)

tmask = Image.new('L',(ART,ART),0); tower_body(L(tmask))
tower = blank(); L(tower).rounded_rectangle([TCX-TW/2,t_top,TCX+TW/2,t_bot], radius=TW/2,
                                            fill=(246,251,255,255))
# cylindrical form: highlight left-of-centre, shadow on both edges
tower = apply_shade(tower, cylinder_shade(ART, TCX-TW/2, TCX+TW/2, light=0.33),
                    tmask, cool=(122,152,190), amount=1.0)
objects.alpha_composite(tower)

grille = blank(); gd = L(grille)
g_top, g_bot = t_top+TH*0.250, t_bot-TH*0.070
for i in range(5):
    sx = TCX-TW*0.285 + i*(TW*0.57/4)
    gd.rounded_rectangle([sx-TW*0.028,g_top,sx+TW*0.028,g_bot], radius=TW*0.028,
                         fill=tuple(int(x) for x in DARK_T)+(230,))
grille = apply_shade(grille, cylinder_shade(ART, TCX-TW/2, TCX+TW/2, light=0.33),
                     Image.fromarray((np.asarray(grille)[...,3]).astype(np.uint8),'L'),
                     warm=(120,175,225), cool=(6,22,52), amount=0.9)
objects.alpha_composite(grille)

dial = blank(); dd = L(dial)
dr_, dcy = TW*0.29, t_top+TH*0.128
dd.ellipse([TCX-dr_,dcy-dr_,TCX+dr_,dcy+dr_], fill=tuple(int(x) for x in DARK_T)+(255,))
dd.ellipse([TCX-dr_*0.62,dcy-dr_*0.62,TCX+dr_*0.62,dcy+dr_*0.62], fill=(24,86,132,255))
dd.ellipse([TCX-dr_*0.30,dcy-dr_*0.44,TCX+dr_*0.02,dcy-dr_*0.12], fill=(255,255,255,150))
objects.alpha_composite(dial)
objects.alpha_composite(rim_light(tmask, dx=-int(SS*3.2), dy=0, blur=SS*1.6, opacity=150))

# ------------------------------------------------------------- CIRCULATOR
CCX, CR = ART*0.648, ART*0.213
CCY = FLOOR - ART*0.128 - CR
def ring(dr): dr.ellipse([CCX-CR,CCY-CR,CCX+CR,CCY+CR], fill=255)
rmask = Image.new('L',(ART,ART),0); ring(L(rmask))

neck = blank(); nd = L(neck); nw = CR*0.165
nd.rounded_rectangle([CCX-nw,CCY+CR*0.72,CCX+nw,FLOOR-ART*0.020], radius=nw*0.6, fill=(242,248,253,255))
nmask = Image.fromarray((np.asarray(neck)[...,3]).astype(np.uint8),'L')
neck = apply_shade(neck, cylinder_shade(ART, CCX-nw, CCX+nw, light=0.34), nmask,
                   cool=(122,152,190), amount=1.0)
objects.alpha_composite(neck)

housing = blank(); ring(L(housing))
hg = np.zeros((ART,ART,3), np.float32)
t = np.clip((np.mgrid[0:ART,0:ART][0]-(CCY-CR))/(2*CR),0,1)
for i in range(3): hg[...,i] = WHITE[i] + (SHADE[i]-WHITE[i])*t
hgi = Image.fromarray(hg.astype(np.uint8),'RGB').convert('RGBA')
hlayer = blank(); hlayer.paste(hgi,(0,0),rmask)
hlayer = apply_shade(hlayer, cylinder_shade(ART, CCX-CR, CCX+CR, light=0.32), rmask,
                     cool=(126,156,194), amount=0.85)
objects.alpha_composite(hlayer)

IR = CR*0.800
imask = Image.new('L',(ART,ART),0); L(imask).ellipse([CCX-IR,CCY-IR,CCX+IR,CCY+IR], fill=255)
rg = np.zeros((ART,ART,3), np.float32)
t2 = np.clip((np.mgrid[0:ART,0:ART][0]-(CCY-IR))/(2*IR),0,1)
for i in range(3): rg[...,i] = DARK_T[i] + (DARK_B[i]-DARK_T[i])*t2
rl = blank(); rl.paste(Image.fromarray(rg.astype(np.uint8),'RGB').convert('RGBA'),(0,0),imask)
objects.alpha_composite(rl)

# ambient occlusion hugging the inside of the bezel
ao = blank()
L(ao).ellipse([CCX-IR,CCY-IR,CCX+IR,CCY+IR], fill=(0,8,26,205))
L(ao).ellipse([CCX-IR*0.86,CCY-IR*0.86,CCX+IR*0.86,CCY+IR*0.86], fill=(0,0,0,0))
ao = ao.filter(ImageFilter.GaussianBlur(ART*0.014))
ao.putalpha(Image.composite(ao.split()[3], Image.new('L',(ART,ART),0), imask))
objects.alpha_composite(ao)

blades = blank(); bd = L(blades); hub = CR*0.150; tip = IR*0.905
for k in range(5):
    a0 = math.radians(k*72-90); pts=[]
    for s_ in np.linspace(0,1,46):
        a = a0+s_*math.radians(60); r = hub+(tip-hub)*(s_**0.55)
        pts.append((CCX+r*math.cos(a), CCY+r*math.sin(a)))
    for s_ in np.linspace(0,1,14):
        a = a0+math.radians(60)-s_*math.radians(26)
        pts.append((CCX+tip*math.cos(a), CCY+tip*math.sin(a)))
    for s_ in np.linspace(1,0,46):
        a = a0+s_*math.radians(34); r = hub+(tip*0.99-hub)*(s_**1.25)
        pts.append((CCX+r*math.cos(a), CCY+r*math.sin(a)))
    bd.polygon(pts, fill=(243,250,255,255))
blades = blades.filter(ImageFilter.GaussianBlur(SS*0.55))
bmask = Image.fromarray((np.asarray(blades)[...,3]).astype(np.uint8),'L')
blades = apply_shade(blades, cylinder_shade(ART, CCX-IR, CCX+IR, light=0.30), bmask,
                     cool=(140,168,205), amount=0.75)
objects.alpha_composite(drop_shadow(blades, blur=ART*0.009, offset=(int(ART*0.004),int(ART*0.006)), opacity=125))
objects.alpha_composite(blades)

hb = blank(); hd = L(hb)
hd.ellipse([CCX-hub,CCY-hub,CCX+hub,CCY+hub], fill=(252,254,255,255))
hd.ellipse([CCX-hub*0.72,CCY-hub*0.76,CCX-hub*0.06,CCY-hub*0.10], fill=(255,255,255,255))
objects.alpha_composite(hb)
objects.alpha_composite(rim_light(rmask, dx=-int(SS*3.2), dy=-int(SS*1.2), blur=SS*1.6, opacity=160))

# specular sweep across the bezel
sp = blank()
L(sp).ellipse([CCX-CR*1.02,CCY-CR*1.48,CCX+CR*0.22,CCY-CR*0.06], fill=(255,255,255,62))
sp = sp.filter(ImageFilter.GaussianBlur(ART*0.020))
sp.putalpha(Image.composite(sp.split()[3], Image.new('L',(ART,ART),0), rmask))
objects.alpha_composite(sp)

# ------------------------------------------------------------- feet + ground
feet = blank(); fd = L(feet)
fd.ellipse([TCX-TW*0.82,FLOOR-ART*0.040,TCX+TW*0.82,FLOOR+ART*0.010], fill=(240,247,253,255))
fd.ellipse([CCX-CR*0.60,FLOOR-ART*0.038,CCX+CR*0.60,FLOOR+ART*0.012], fill=(242,249,254,255))
objects.alpha_composite(feet)

bg.alpha_composite(ground_reflection(objects, FLOOR+ART*0.006, ART*0.30, fade=0.26, blur=SS*3))
for lay, bl, off, op in ((objects, ART*0.030, (int(ART*0.008), int(ART*0.016)), 150),):
    bg.alpha_composite(drop_shadow(lay, blur=bl, offset=off, opacity=op))
# tight contact shadows where each object meets the floor
cs = blank(); cd = L(cs)
cd.ellipse([TCX-TW*0.72,FLOOR-ART*0.012,TCX+TW*0.72,FLOOR+ART*0.016], fill=(0,16,48,150))
cd.ellipse([CCX-CR*0.55,FLOOR-ART*0.010,CCX+CR*0.55,FLOOR+ART*0.016], fill=(0,16,48,150))
bg.alpha_composite(cs.filter(ImageFilter.GaussianBlur(ART*0.011)))
bg.alpha_composite(objects)

bg.putalpha(squircle_mask(ART))
art = bg.resize((824,824), Image.LANCZOS)
c = Image.new('RGBA',(S,S),(0,0,0,0)); c.paste(art,((S-824)//2,)*2, art)
c.save('duo3_master.png'); print('duo3_master.png')
