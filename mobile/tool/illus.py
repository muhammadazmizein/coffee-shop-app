"""Pustaka kecil pembuat ilustrasi SVG (gaya flat dengan gradien lembut).
Dipakai oleh gen_illustrations.py. Semua fungsi mengembalikan potongan <g> dengan id unik (prefix)
supaya beberapa elemen bisa digabung dalam satu SVG tanpa bentrok."""
import math
import re

ESPRESSO = '#3B2416'
CREAM = '#FBF5EC'


def lin(id, stops, x1=0, y1=0, x2=0, y2=1):
    s = ''.join(f'<stop offset="{o}" stop-color="{c}"' + (f' stop-opacity="{a}"' if a is not None else '') + '/>' for o, c, a in
                [(st + (None,))[:3] if len(st) == 2 else st for st in stops])
    return f'<linearGradient id="{id}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>'


def rad(id, stops, cx=.5, cy=.5, r=.5):
    s = ''.join(f'<stop offset="{o}" stop-color="{c}"' + (f' stop-opacity="{a}"' if a is not None else '') + '/>' for o, c, a in
                [(st + (None,))[:3] if len(st) == 2 else st for st in stops])
    return f'<radialGradient id="{id}" cx="{cx}" cy="{cy}" r="{r}">{s}</radialGradient>'


def wave(y, x0=90, x1=310, amp=5, period=70, phase=0.0):
    pts = []
    x = x0
    while x <= x1:
        pts.append(f'{x:.1f},{y + amp * math.sin((x - x0) / period * 2 * math.pi + phase):.1f}')
        x += 6
    return 'M' + ' L'.join(pts)


def bean(cx, cy, s=1.0, rot=0, fill=ESPRESSO, line=CREAM, op=1.0):
    return (f'<g transform="translate({cx} {cy}) rotate({rot}) scale({s})" opacity="{op}">'
            f'<ellipse rx="11" ry="16" fill="{fill}"/>'
            f'<path d="M-1,-15 C8,-6 -8,6 1,15" stroke="{line}" stroke-width="2.6" fill="none" stroke-linecap="round"/></g>')


def sparkle(cx, cy, s=1.0, fill='#FFFFFF', op=0.9):
    return (f'<path transform="translate({cx} {cy}) scale({s})" opacity="{op}" fill="{fill}" '
            f'd="M0,-12 C1.5,-4 4,-1.5 12,0 C4,1.5 1.5,4 0,12 C-1.5,4 -4,1.5 -12,0 C-4,-1.5 -1.5,-4 0,-12 Z"/>')


def backdrop(p, c1, c2, r=172, cx=200, cy=200):
    return (f'<defs>{rad(p + "bd", [(0, c1), (1, c2)], .4, .35, .75)}</defs>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#{p}bd)"/>')


def shadow(cx, cy, rx, ry=12, op=0.22):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#3B2416" opacity="{op}"/>'


def logo_badge(cx, cy, r=21):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#FFFFFF" opacity="0.92"/>' + bean(cx, cy, r / 24, 28))


# ---------- gelas es ----------
def iced_cup(p, layers, straw='#6E8B5E', topping=None, x=0, y=0, s=1.0, ice=True, pearls=False, drizzle='#5A3322', garnish=None, garnish_color='#F8DE6A'):
    """layers: [(warna_atas, warna_bawah, fraksi)] dari bawah ke atas. topping: None|'cream'|'foam'."""
    outer = 'M118,122 L282,122 L262,320 Q260,334 246,334 L154,334 Q140,334 138,320 Z'
    inner = 'M124,128 L276,128 L257,318 Q255,328 244,328 L156,328 Q145,328 143,318 Z'
    top, bottom = 160, 330
    defs = [f'<clipPath id="{p}c"><path d="{inner}"/></clipPath>',
            lin(p + 'gl', [(0, '#FFFFFF', .55), (1, '#FFFFFF', .12)], 0, 0, 1, 0),
            lin(p + 'str', [(0, straw), (1, straw)])]
    body = []
    acc = bottom
    total = bottom - top
    for i, (ct, cb, fr) in enumerate(layers):
        h = total * fr
        yt = acc - h
        gid = f'{p}l{i}'
        defs.append(lin(gid, [(0, ct), (1, cb)]))
        wv = wave(yt, amp=4.5 if i < len(layers) - 1 else 3, phase=i * 1.3)
        body.append(f'<path d="{wv} L310,{bottom + 10} L90,{bottom + 10} Z" fill="url(#{gid})"/>')
        acc = yt
    extras = []
    if pearls:
        for k, (px, py) in enumerate([(160, 312), (182, 316), (204, 312), (226, 316), (246, 311), (172, 298), (214, 298), (194, 306)]):
            extras.append(f'<circle cx="{px}" cy="{py}" r="8" fill="#2A1710"/><circle cx="{px - 2.5}" cy="{py - 2.5}" r="2.2" fill="#fff" opacity=".35"/>')
    if ice:
        for (ix, iy, ir) in [(168, 186, -14), (228, 176, 11), (196, 218, 26), (240, 232, -8)]:
            extras.append(f'<g transform="translate({ix} {iy}) rotate({ir})"><rect x="-19" y="-19" width="38" height="38" rx="9" fill="#FFFFFF" opacity=".30"/>'
                          f'<rect x="-19" y="-19" width="38" height="38" rx="9" fill="none" stroke="#FFFFFF" stroke-width="2" opacity=".65"/>'
                          f'<path d="M-12,-10 L-4,-12" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity=".7"/></g>')
    inside = f'<g clip-path="url(#{p}c)">{"".join(reversed(body))}{"".join(extras)}</g>'
    straw_g = (f'<g transform="rotate(9 232 130)"><rect x="224" y="46" width="14" height="230" rx="7" fill="url(#{p}str)"/>'
               f'<rect x="228" y="52" width="3" height="214" rx="1.5" fill="#fff" opacity=".35"/></g>')
    top_g = ''
    if topping == 'cream':
        top_g = (f'<g><circle cx="165" cy="112" r="34" fill="#FFFFFF"/><circle cx="205" cy="98" r="38" fill="#FFFFFF"/><circle cx="242" cy="112" r="32" fill="#FFFFFF"/>'
                 f'<circle cx="205" cy="84" r="24" fill="#FFF8EE"/><path d="M168,104 C190,92 214,116 238,98" stroke="{drizzle}" stroke-width="6" stroke-linecap="round" fill="none"/>'
                 f'<path d="M150,124 L250,124" stroke="#EADFCF" stroke-width="10" stroke-linecap="round"/></g>')
    garnish_g = ''
    if garnish == 'lemon':
        cuts = ''.join(f'<path d="M282,128 L{282 + 21 * math.cos(math.radians(a)):.1f},{128 + 21 * math.sin(math.radians(a)):.1f}" stroke="#fff" stroke-width="2.5" opacity=".8"/>' for a in range(0, 360, 45))
        garnish_g = f'<g><circle cx="282" cy="128" r="28" fill="{garnish_color}"/><circle cx="282" cy="128" r="23" fill="{garnish_color}" stroke="#fff" stroke-width="3" opacity=".95"/>{cuts}</g>'
    rim = f'<rect x="112" y="114" width="176" height="12" rx="6" fill="#FFFFFF" opacity=".75"/>'
    glass = (f'<path d="{outer}" fill="#FFFFFF" fill-opacity=".14" stroke="#FFFFFF" stroke-opacity=".8" stroke-width="3"/>'
             f'<path d="M130,138 L143,138 L158,318 L148,318 Z" fill="url(#{p}gl)"/>'
             f'<path d="M262,140 L268,140 L254,312 L249,312 Z" fill="#fff" opacity=".18"/>')
    g = (f'<defs>{"".join(defs)}</defs>{shadow(200, 340, 96)}{inside}'
         f'{straw_g if topping != "cream" else ""}{glass}{rim}{logo_badge(200, 262)}{top_g}{garnish_g}')
    return f'<g transform="translate({x} {y}) scale({s})">{g}</g>'


# ---------- cangkir panas ----------
def hot_cup(p, coffee=('#A9744A', '#7A4B2A'), art='heart', x=0, y=0, s=1.0):
    defs = (lin(p + 'cup', [(0, '#FFFFFF'), (1, '#E9DECE')], 0, 0, 1, 1) + lin(p + 'sau', [(0, '#FFFFFF'), (1, '#E2D5C2')], 0, 0, 0, 1)
            + lin(p + 'cof', [(0, coffee[0]), (1, coffee[1])], 0, 0, 1, 1))
    heart = ('<path d="M200,203 C168,184 182,168 200,180 C218,168 232,184 200,203 Z" fill="#FFF3E1" opacity=".95"/>'
             '<path d="M200,198 C184,186 190,178 200,185 C210,178 216,186 200,198 Z" fill="#C79A6C" opacity=".55"/>') if art == 'heart' else ''
    steam = ''.join(f'<path d="M{sx},150 C{sx - 16},128 {sx + 16},112 {sx},88 C{sx - 12},70 {sx + 10},62 {sx + 2},46" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round" fill="none" opacity="{o}"/>'
                    for sx, o in ((168, .55), (202, .75), (236, .5)))
    g = (f'<defs>{defs}</defs>{shadow(200, 338, 128, 14)}'
         f'<ellipse cx="200" cy="322" rx="132" ry="28" fill="url(#{p}sau)"/><ellipse cx="200" cy="318" rx="86" ry="15" fill="#D9CBB7" opacity=".6"/>'
         f'<path d="M286,228 C344,214 346,296 282,290" stroke="#F3EADB" stroke-width="15" fill="none" stroke-linecap="round"/>'
         f'<path d="M286,228 C344,214 346,296 282,290" stroke="#fff" stroke-width="4" fill="none" stroke-linecap="round" opacity=".6"/>'
         f'<path d="M108,190 Q108,318 200,320 Q292,318 292,190 Z" fill="url(#{p}cup)"/>'
         f'<path d="M120,210 Q122,296 176,310" stroke="#fff" stroke-width="9" stroke-linecap="round" fill="none" opacity=".6"/>'
         f'<ellipse cx="200" cy="190" rx="92" ry="23" fill="#FFFFFF"/><ellipse cx="200" cy="192" rx="80" ry="17" fill="url(#{p}cof)"/>'
         f'<ellipse cx="200" cy="192" rx="80" ry="17" fill="none" stroke="#F1E3CF" stroke-width="3" opacity=".7"/>{heart}'
         f'{logo_badge(200, 262, 22)}{steam}')
    return f'<g transform="translate({x} {y}) scale({s})">{g}</g>'


# ---------- croissant ----------
def croissant(p, x=0, y=0, s=1.0, plate=True, extra=None):
    """Siluet bulan sabit (busur luar - busur dalam) + garis lapisan menyilang badan."""
    cx, cy = 200, 296
    oa, ob = 134, 128   # elips luar
    ia, ib = 86, 58     # elips dalam
    def O(t): return cx + oa * math.sin(t), cy - ob * math.cos(t)
    def I(t): return cx + ia * math.sin(t), cy - ib * math.cos(t)
    defs = lin(p + 'cr', [(0, '#F8CC72'), (.45, '#E39B3B'), (1, '#B8691F')], 0, 0, 0, 1)
    body = (f'<path d="M{cx - oa},{cy} A{oa},{ob} 0 0 1 {cx + oa},{cy} L{cx + ia},{cy} A{ia},{ib} 0 0 0 {cx - ia},{cy} Z" fill="url(#{p}cr)"/>'
            f'<circle cx="{cx - (oa + ia) / 2}" cy="{cy}" r="{(oa - ia) / 2}" fill="#C9792A"/><circle cx="{cx + (oa + ia) / 2}" cy="{cy}" r="{(oa - ia) / 2}" fill="#C9792A"/>')
    bands = []
    for deg in (-74, -50, -25, 0, 25, 50, 74):
        t = math.radians(deg)
        (ox, oy), (ix, iy) = O(t), I(t)
        mx, my = (ox + ix) / 2, (oy + iy) / 2
        tx, ty = math.cos(t), math.sin(t) * 0.45  # arah singgung kasar
        bulge = 9
        bands.append(f'<path d="M{ox:.1f},{oy:.1f} Q{mx + tx * bulge:.1f},{my + ty * bulge:.1f} {ix:.1f},{iy:.1f}" stroke="#8F4A12" stroke-width="3.4" fill="none" stroke-linecap="round" opacity=".5"/>')
        bands.append(f'<path d="M{ox - tx * 5:.1f},{oy - ty * 5:.1f} Q{mx + tx * (bulge - 4):.1f},{my + ty * (bulge - 4):.1f} {ix - tx * 5:.1f},{iy - ty * 5:.1f}" stroke="#FFE7B0" stroke-width="3" fill="none" stroke-linecap="round" opacity=".75"/>')
    gloss = f'<path d="M{cx - oa + 16},{cy - 24} A{oa - 14},{ob - 12} 0 0 1 {cx + oa - 16},{cy - 24}" stroke="#FFF1CF" stroke-width="6" fill="none" stroke-linecap="round" opacity=".5"/>'
    crumbs = ''.join(f'<circle cx="{a}" cy="{b}" r="{r}" fill="#D58A35"/>' for a, b, r in ((84, 330, 4), (318, 326, 3.5), (126, 344, 3), (278, 346, 4)))
    plate_g = (f'<ellipse cx="200" cy="334" rx="150" ry="26" fill="#FFFFFF"/><ellipse cx="200" cy="332" rx="120" ry="17" fill="#EFE3D2"/>' if plate else '')
    deco = ''
    if extra == 'choco':
        deco = '<path d="M96,230 L128,196 L150,226 L176,184 L204,224 L232,184 L256,226 L280,196 L306,232" stroke="#4A2A18" stroke-width="7" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
    elif extra == 'almond':
        deco = ''.join(f'<ellipse cx="{ax}" cy="{ay}" rx="11" ry="6" transform="rotate({r} {ax} {ay})" fill="#F7E7C4" stroke="#C9A25B" stroke-width="1.5"/>' for ax, ay, r in ((130, 214, -30), (160, 190, 10), (196, 178, -8), (232, 190, 18), (266, 214, 30), (180, 214, 22), (222, 214, -20), (146, 238, -50), (254, 238, 50))) + '<g fill="#fff" opacity=".85">' + ''.join(f'<circle cx="{a}" cy="{b}" r="2.2"/>' for a, b in ((112, 250), (150, 206), (210, 196), (250, 204), (292, 250), (190, 232))) + '</g>'
    g = f'<defs>{defs}</defs>{shadow(200, 360, 142, 11)}{plate_g}{body}{"".join(bands)}{gloss}{deco}{crumbs}'
    return f'<g transform="translate({x} {y}) scale({s})">{g}</g>'


# ---------- donat ----------
def donut(p, glaze='#F7B7C7', sprinkles=True, chocolate=False, x=0, y=0, s=1.0):
    cx, cy = 200, 240
    defs = lin(p + 'dg', [(0, '#EDB467'), (1, '#C47F33')], 0, 0, 0, 1)
    drips = ''.join(f'<circle cx="{cx + 100 * math.cos(math.radians(a)):.1f}" cy="{cy - 2 + 70 * math.sin(math.radians(a)):.1f}" r="{13 + (a // 30) % 3 * 2}" fill="{glaze}"/>' for a in range(0, 360, 30))
    colors = ['#FFFFFF', '#6FB5E8', '#FFD25E', '#7DC47A', '#EF6A6A']
    spr = ''
    if sprinkles:
        for k in range(26):
            ang = math.radians(k * 14.5 + (k % 3) * 9)
            rr = 0.52 + (k * 37 % 40) / 100
            px, py = cx + 86 * rr * math.cos(ang), cy - 2 + 56 * rr * math.sin(ang)
            spr += f'<rect x="{px - 6:.1f}" y="{py - 2:.1f}" width="12" height="4.2" rx="2.1" transform="rotate({(k * 53) % 180} {px:.1f} {py:.1f})" fill="{colors[k % 5]}"/>'
    elif chocolate:
        for k in range(30):
            ang = math.radians(k * 12 + (k % 4) * 7)
            rr = 0.5 + (k * 29 % 45) / 100
            px, py = cx + 86 * rr * math.cos(ang), cy - 2 + 56 * rr * math.sin(ang)
            spr += f'<rect x="{px - 5:.1f}" y="{py - 1.6:.1f}" width="10" height="3.2" rx="1.6" transform="rotate({(k * 61) % 180} {px:.1f} {py:.1f})" fill="#2A170C"/>'
    g = (f'<defs>{defs}</defs>{shadow(200, 360, 136, 11)}<ellipse cx="200" cy="334" rx="150" ry="26" fill="#FFFFFF"/><ellipse cx="200" cy="332" rx="120" ry="17" fill="#EFE3D2"/>'
         f'<ellipse cx="{cx}" cy="{cy + 16}" rx="120" ry="84" fill="#A8662A"/><ellipse cx="{cx}" cy="{cy}" rx="120" ry="84" fill="url(#{p}dg)"/>'
         f'<ellipse cx="{cx}" cy="{cy - 2}" rx="104" ry="71" fill="{glaze}"/>{drips}'
         f'<ellipse cx="{cx - 40}" cy="{cy - 38}" rx="46" ry="9" transform="rotate(-12 {cx - 40} {cy - 38})" fill="#fff" opacity=".35"/>{spr}'
         f'<ellipse cx="{cx}" cy="{cy}" rx="38" ry="26" fill="#A8662A"/><ellipse cx="{cx}" cy="{cy + 3}" rx="33" ry="21" fill="#EFE3D2"/>')
    return f'<g transform="translate({x} {y}) scale({s})">{g}</g>'


# ---------- kue kering ----------
def cookie(p, x=0, y=0, s=1.0):
    defs = rad(p + 'ck', [(0, '#EDC47E'), (1, '#CF9444')], .4, .35, .8)
    chips = ((150, 216, -20), (214, 196, 15), (252, 240, 40), (178, 262, -35), (122, 258, 10), (226, 276, -10), (286, 206, 25), (196, 232, 30))
    ch = ''.join(f'<g transform="translate({a} {b}) rotate({r})"><path d="M-12,-7 L10,-9 L13,6 L-8,10 Z" fill="#4A2A18"/><path d="M-8,-5 L6,-6" stroke="#7A4B2A" stroke-width="2" opacity=".7"/></g>' for a, b, r in chips)
    g = (f'<defs>{defs}</defs>{shadow(200, 360, 136, 11)}<ellipse cx="200" cy="334" rx="150" ry="26" fill="#FFFFFF"/><ellipse cx="200" cy="332" rx="120" ry="17" fill="#EFE3D2"/>'
         f'<ellipse cx="200" cy="262" rx="116" ry="82" fill="#A56A28"/><ellipse cx="200" cy="246" rx="116" ry="82" fill="url(#{p}ck)"/>'
         f'<ellipse cx="200" cy="246" rx="116" ry="82" fill="none" stroke="#B7792F" stroke-width="5" opacity=".6"/>{ch}'
         '<path d="M130,200 Q170,182 214,184" stroke="#FFF1D2" stroke-width="5" fill="none" stroke-linecap="round" opacity=".55"/>'
         '<circle cx="262" cy="278" r="3" fill="#B7792F"/><circle cx="148" cy="290" r="3" fill="#B7792F"/><circle cx="238" cy="214" r="2.5" fill="#B7792F"/>')
    return f'<g transform="translate({x} {y}) scale({s})">{g}</g>'


# ---------- sandwich ----------
def sandwich(p, x=0, y=0, s=1.0):
    defs = lin(p + 'br', [(0, '#F1CD86'), (1, '#D9A24E')], 0, 0, 0, 1)
    lettuce = 'M70,250 ' + ''.join(f'Q{80 + i * 20},{238 + (8 if i % 2 else -2)} {90 + i * 20},250 ' for i in range(0, 13)) + 'L330,266 L70,266 Z'
    g = (f'<defs>{defs}</defs>{shadow(200, 362, 150, 12)}<ellipse cx="200" cy="338" rx="156" ry="26" fill="#FFFFFF"/><ellipse cx="200" cy="336" rx="126" ry="17" fill="#EFE3D2"/>'
         '<rect x="72" y="288" width="256" height="40" rx="16" fill="#C98A3B"/><rect x="78" y="290" width="244" height="30" rx="12" fill="url(#' + p + 'br)"/>'
         f'<path d="{lettuce}" fill="#7DB35A"/><path d="{lettuce}" fill="#9CCB74" opacity=".5" transform="translate(0 -5)"/>'
         '<rect x="76" y="238" width="248" height="30" rx="14" fill="#F4E2BE"/><rect x="92" y="244" width="216" height="8" rx="4" fill="#fff" opacity=".6"/>'
         '<circle cx="132" cy="262" r="15" fill="#E5533D"/><circle cx="200" cy="264" r="15" fill="#E5533D"/><circle cx="268" cy="262" r="15" fill="#E5533D"/>'
         '<circle cx="132" cy="262" r="9" fill="#F28B78" opacity=".6"/><circle cx="200" cy="264" r="9" fill="#F28B78" opacity=".6"/><circle cx="268" cy="262" r="9" fill="#F28B78" opacity=".6"/>'
         '<path d="M70,238 L330,238 L318,258 L82,258 Z" fill="#F6C945" opacity=".95"/>'
         '<path d="M64,238 C60,176 120,156 200,156 C280,156 340,176 336,238 Z" fill="#C98A3B"/>'
         f'<path d="M72,238 C70,184 126,166 200,166 C274,166 330,184 328,238 Z" fill="url(#{p}br)"/>'
         '<path d="M104,196 Q150,176 214,176" stroke="#FFF0CC" stroke-width="6" fill="none" stroke-linecap="round" opacity=".6"/>'
         + ''.join(f'<ellipse cx="{a}" cy="{b}" rx="6" ry="3" fill="#FFF6DD" transform="rotate({r} {a} {b})"/>' for a, b, r in ((150, 200, -20), (200, 190, 5), (250, 200, 25), (176, 214, 15), (232, 216, -10))))
    return f'<g transform="translate({x} {y}) scale({s})">{g}</g>'


# ---------- roti pisang ----------
def bread(p, x=0, y=0, s=1.0):
    defs = lin(p + 'cr', [(0, '#E7B56A'), (1, '#B97431')], 0, 0, 0, 1)
    def slice_(cx, cy, rot):
        return (f'<g transform="translate({cx} {cy}) rotate({rot})"><path d="M-70,60 L-70,-4 C-96,-12 -92,-70 -50,-72 C-30,-86 30,-86 50,-72 C92,-70 96,-12 70,-4 L70,60 Q70,70 60,70 L-60,70 Q-70,70 -70,60 Z" fill="url(#{p}cr)"/>'
                f'<path d="M-58,56 L-58,-8 C-80,-14 -78,-60 -46,-62 C-28,-74 28,-74 46,-62 C78,-60 80,-14 58,-8 L58,56 Z" fill="#F6DFA6"/>'
                + ''.join(f'<circle cx="{a}" cy="{b}" r="2.6" fill="#B7843C" opacity=".7"/>' for a, b in ((-30, -30), (10, -40), (36, -10), (-10, 4), (-36, 24), (22, 30), (0, 46))) + '</g>')
    banana = lambda bx, by: (f'<g transform="translate({bx} {by})"><circle r="19" fill="#F8E28A" stroke="#E2BC4A" stroke-width="3"/><circle r="7" fill="#EBC85F"/>'
                             '<circle cx="-4" cy="-4" r="2" fill="#fff" opacity=".6"/></g>')
    g = (f'<defs>{defs}</defs>{shadow(200, 362, 150, 12)}<ellipse cx="200" cy="338" rx="156" ry="26" fill="#FFFFFF"/><ellipse cx="200" cy="336" rx="126" ry="17" fill="#EFE3D2"/>'
         + slice_(158, 252, -8) + slice_(238, 244, 9) + banana(238, 238) + banana(268, 262))
    return f'<g transform="translate({x} {y}) scale({s})">{g}</g>'


def svg(w, h, inner):
    # Angkat semua <defs> ke akar: lebih aman untuk renderer SVG yang tidak mendukung defs bersarang.
    defs = ''.join(re.findall(r'<defs>(.*?)</defs>', inner, flags=re.S))
    inner = re.sub(r'<defs>.*?</defs>', '', inner, flags=re.S)
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}"><defs>{defs}</defs>{inner}</svg>\n'
