"""Ikon aplikasi (PNG 1024) dari logo -> assets/icon/. Butuh Chrome untuk merender SVG.
Jalankan: python3 tool/gen_icon.py   lalu: dart run flutter_launcher_icons"""
import os, subprocess, tempfile
from illus import *

ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT = os.path.join(ROOT, 'assets', 'icon')
os.makedirs(OUT, exist_ok=True)

grad = '<defs>' + lin('g', [(0, '#14B8A6'), (1, '#0B5F58')], 0, 0, 1, 1) + '</defs>'
# ikon penuh (tanpa sudut membulat; OS yang memotong), dipakai iOS dan Android lawas
full = svg(200, 200, grad + '<rect width="200" height="200" fill="url(#g)"/>' + bean(100, 100, 3.6, 28, fill='#F4FAF9', line='#0B5F58') + sparkle(150, 52, 1.2, '#CCFBF1', .95))
# latar adaptif Android: gradien polos; latar depan: biji kopi di zona aman (±62% tengah)
back = svg(200, 200, grad + '<rect width="200" height="200" fill="url(#g)"/>')
fore = svg(200, 200, bean(100, 100, 2.9, 28, fill='#F4FAF9', line='#0B5F58') + sparkle(138, 64, 1.0, '#CCFBF1', .95))

def render(name, content, transparent):
    with tempfile.TemporaryDirectory() as d:
        svgp = os.path.join(d, name + '.svg'); open(svgp, 'w').write(content)
        html = os.path.join(d, 'p.html')
        open(html, 'w').write(f'<body style="margin:0;background:transparent"><img src="file://{svgp}" width="1024" height="1024" style="display:block"></body>')
        args = ['google-chrome', '--headless=new', '--no-sandbox', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
                '--window-size=1024,1024', f'--screenshot={os.path.join(OUT, name + ".png")}', f'file://{html}']
        if transparent: args.insert(1, '--default-background-color=00000000')
        subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

render('icon', full, False)
render('icon_bg', back, False)
render('icon_fg', fore, True)
print('ok', os.listdir(OUT))
