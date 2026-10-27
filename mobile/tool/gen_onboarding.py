"""Ilustrasi onboarding + logo -> assets/illustrations/. Jalankan: python3 tool/gen_onboarding.py"""
import os
from illus import *

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'illustrations')
W, H = 400, 440


def blob(p, c1, c2):
    return (f'<defs>{rad(p + "bl", [(0, c1), (1, c2)], .35, .3, .85)}</defs>'
            f'<path d="M200,26 C300,22 380,92 378,196 C376,300 330,390 214,408 C110,424 30,350 24,236 C18,120 96,30 200,26 Z" fill="url(#{p}bl)"/>')


def stars(*pts):
    return ''.join(sparkle(x, y, s) for x, y, s in pts)


# 1) semua favorit dalam satu aplikasi
o1 = (blob('o1', '#F2FFFC', '#B9EBE3')
      + iced_cup('m', [('#F6EEDB', '#EBDDBE', .28), ('#A9C77F', '#6C9743', .56), ('#E3F0CB', '#C5DDA0', .16)], straw='#F2D9B8', x=148, y=84, s=.62)
      + iced_cup('l', [('#3B2416', '#2A170C', .42), ('#C47A32', '#9A5A22', .26), ('#F7EAD4', '#EAD2AE', .32)], straw='#6E8B5E', x=22, y=40, s=.86)
      + croissant('k', x=134, y=206, s=.62)
      + bean(64, 360, 1.0, -30, op=.8) + bean(346, 340, .9, 40, op=.8) + bean(330, 76, .8, 15, op=.6) + bean(70, 92, .7, -20, op=.6)
      + stars((48, 170, 1.0), (352, 190, .8), (300, 60, .6), (110, 400, .7)))

# 2) pesan -> diantar kurir
sky = ''.join(f'<rect x="{x}" y="{360 - h}" width="{w}" height="{h}" rx="6" fill="#A9D8D1" opacity=".55"/>' for x, w, h in
              ((34, 44, 120), (84, 38, 84), (128, 50, 146), (292, 44, 104), (338, 40, 150)))
wheel = lambda cx: (f'<circle cx="{cx}" cy="338" r="36" fill="#2B1710"/><circle cx="{cx}" cy="338" r="20" fill="#EADFCF"/>'
                    f'<circle cx="{cx}" cy="338" r="7" fill="#3B2416"/>')
o2 = (blob('o2', '#F0FBFF', '#BFE6F0') + sky
      + '<path d="M18,372 L382,372" stroke="#8FC4BC" stroke-width="5" stroke-linecap="round"/>'
      + '<path d="M60,392 L100,392 M130,392 L170,392 M200,392 L240,392 M270,392 L310,392" stroke="#C4E4DF" stroke-width="5" stroke-linecap="round"/>'
      + '<path d="M60,238 L110,238 M42,262 L96,262 M70,286 L112,286" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round" opacity=".85"/>'
      + shadow(206, 376, 120, 9, .2)
      # kotak pengiriman
      + '<rect x="108" y="150" width="104" height="92" rx="14" fill="#FFF7EA" stroke="#E2CBA8" stroke-width="3"/><rect x="108" y="150" width="104" height="22" rx="11" fill="#0F766E"/>'
      + logo_badge(160, 208, 22)
      # badan skuter
      + wheel(124) + wheel(300)
      + '<path d="M104,300 C102,262 128,246 164,246 L236,246 C244,246 250,250 252,258 L256,296 L190,300 Z" fill="#14A398"/>'
      + '<rect x="132" y="228" width="104" height="22" rx="11" fill="#3B2416"/>'
      + '<path d="M250,300 L268,206 C270,194 284,192 290,202 L310,300 Z" fill="#2DBDB0"/>'
      + '<path d="M278,200 L300,166" stroke="#3B2416" stroke-width="9" stroke-linecap="round"/><circle cx="302" cy="162" r="7" fill="#3B2416"/>'
      + '<circle cx="312" cy="214" r="11" fill="#FFE9A8"/><circle cx="312" cy="214" r="5" fill="#FFFFFF"/>'
      + '<path d="M278,308 C288,288 326,288 334,306" stroke="#0B5F58" stroke-width="12" fill="none" stroke-linecap="round"/>'
      # pengendara
      + '<path d="M196,226 C190,190 214,168 244,176 C262,182 268,206 262,224 Z" fill="#6E8B5E"/>'
      + '<path d="M250,190 L284,176" stroke="#6E8B5E" stroke-width="14" stroke-linecap="round"/>'
      + '<path d="M214,236 C226,258 246,270 252,296" stroke="#3B2416" stroke-width="15" fill="none" stroke-linecap="round"/>'
      + '<circle cx="246" cy="152" r="21" fill="#F0C9A4"/><path d="M224,150 C222,126 266,118 270,150 L224,154 Z" fill="#C47A32"/><rect x="250" y="146" width="22" height="10" rx="5" fill="#3B2416" opacity=".75"/>'
      # pin lokasi + rute putus-putus
      + '<path d="M270,126 C300,96 318,100 330,86" stroke="#C47A32" stroke-width="4" stroke-dasharray="2 10" stroke-linecap="round" fill="none"/>'
      + '<path d="M336,36 C310,36 296,56 304,78 C308,90 326,106 336,122 C346,106 364,90 368,78 C376,56 362,36 336,36 Z" fill="#E0573A"/><circle cx="336" cy="68" r="12" fill="#FFFFFF"/>'
      + stars((40, 90, .9), (360, 250, .7), (190, 70, .6)))

# 3) kumpulkan poin
coin = lambda p, cx, cy, r, rot=0: (
    f'<defs>{rad(p + "g", [(0, "#FFE9A0"), (1, "#E3A92E")], .35, .3, .9)}</defs>'
    f'<g transform="translate({cx} {cy}) rotate({rot})"><circle r="{r}" fill="url(#{p}g)"/><circle r="{r * .78}" fill="none" stroke="#B87A12" stroke-width="{r * .05}" opacity=".6"/>'
    f'<path transform="scale({r / 40})" d="M0,-24 L7,-8 L25,-6 L11,6 L15,24 L0,14 L-15,24 L-11,6 L-25,-6 L-7,-8 Z" fill="#FFF6D6" stroke="#C98A1B" stroke-width="2.5" stroke-linejoin="round"/></g>')
o3 = (blob('o3', '#F4FFFD', '#B5E9E0')
      + coin('c1', 118, 262, 52, -14) + coin('c2', 168, 290, 60, 8) + coin('c3', 150, 196, 76, 0)
      + iced_cup('q', [('#5E3322', '#3B1D12', .62), ('#8A5238', '#6A3A27', .38)], straw='#E9B7A0', topping='cream', ice=False, x=170, y=100, s=.74)
      + '<circle cx="86" cy="130" r="9" fill="#E0573A"/><circle cx="340" cy="96" r="7" fill="#6E8B5E"/><circle cx="356" cy="300" r="8" fill="#C47A32"/><circle cx="60" cy="330" r="6" fill="#6E8B5E"/>'
      + '<path d="M300,60 l8,18 l18,3 l-14,12 l4,18 l-16,-9 l-16,9 l4,-18 l-14,-12 l18,-3 z" fill="#FFD36A" transform="scale(.7) translate(130 20)"/>'
      + stars((52, 214, 1.0), (350, 220, .8), (110, 78, .7), (250, 52, .6)))

tumbler = (backdrop('mh', '#E8FCF9', '#A5E4DA') + sparkle(86, 110, .9) + sparkle(318, 140, .6) + shadow(200, 352, 92)
           + '<defs>' + lin('tg', [(0, '#1CC4B2'), (1, '#0B5F58')], 0, 0, 1, 0) + '</defs>'
           + '<rect x="232" y="46" width="14" height="86" rx="7" fill="#F2D9B8" transform="rotate(8 239 90)"/>'
           + '<path d="M138,138 L262,138 L248,336 Q246,350 232,350 L168,350 Q154,350 152,336 Z" fill="url(#tg)"/>'
           + '<path d="M150,150 L164,150 L174,338 L162,338 Z" fill="#fff" opacity=".28"/>'
           + '<rect x="124" y="112" width="152" height="30" rx="15" fill="#0B2E2B"/><rect x="136" y="104" width="128" height="14" rx="7" fill="#12403C"/>'
           + '<path d="M146,214 L254,214 L252,262 L148,262 Z" fill="#F4FAF9"/>' + logo_badge(200, 238, 20).replace('#FFFFFF', '#E3F7F4')
           + '<ellipse cx="200" cy="350" rx="48" ry="6" fill="#063B38" opacity=".35"/>')

logo = ('<defs>' + lin('lg', [(0, '#14B8A6'), (1, '#0B5F58')], 0, 0, 1, 1) + '</defs>'
        '<rect x="0" y="0" width="200" height="200" rx="52" fill="url(#lg)"/>' + bean(100, 100, 3.6, 28, fill='#F4FAF9', line='#0B5F58') + sparkle(150, 52, 1.2, '#CCFBF1', .95))

for name, inner, w, h in (('onboarding_1', o1, W, H), ('onboarding_2', o2, W, H), ('onboarding_3', o3, W, H)):
    open(os.path.join(OUT, name + '.svg'), 'w').write(svg(w, h, inner))
open(os.path.join(OUT, 'logo.svg'), 'w').write(svg(200, 200, logo))
open(os.path.join(OUT, 'merch.svg'), 'w').write(svg(400, 400, tumbler))
open(os.path.join(OUT, 'bean.svg'), 'w').write(svg(40, 40, bean(20, 20, 1.0, 28, fill='#7FDCCF', line='#063B38')))
print('ok')
