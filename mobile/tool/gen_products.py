"""Menghasilkan ilustrasi produk -> assets/illustrations/product_*.svg. Jalankan: python3 tool/gen_products.py"""
import os
from illus import *

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'illustrations')

PRODUCTS = {
    # kopi susu gula aren: espresso di bawah, karamel tengah, susu di atas
    'latte': (('#F6E7CF', '#EAD2AE'), lambda: iced_cup('a', [('#3B2416', '#2A170C', .42), ('#C47A32', '#9A5A22', .26), ('#F7EAD4', '#EAD2AE', .32)], straw='#6E8B5E'),
              '#FBE9CF', '#EBC99C'),
    'americano': (None, lambda: iced_cup('b', [('#4A2A18', '#24120A', 1.0)], straw='#C47A32'), '#EFE1D0', '#DCC4A6'),
    'cappuccino': (None, lambda: hot_cup('c'), '#F7E6D2', '#E6C9A8'),
    'matcha': (None, lambda: iced_cup('d', [('#F7EFDC', '#EBDDBE', .28), ('#A9C77F', '#6C9743', .56), ('#E3F0CB', '#C5DDA0', .16)], straw='#F2D9B8'),
               '#E8F0D8', '#C9DDAE'),
    'chocolate': (None, lambda: iced_cup('e', [('#5E3322', '#3B1D12', .62), ('#8A5238', '#6A3A27', .38)], straw='#E9B7A0', topping='cream', ice=False),
                  '#F3DDD2', '#E2B9A6'),
    'boba': (None, lambda: iced_cup('f', [('#B98B5E', '#8E6038', .5), ('#F2E2C6', '#E2C99F', .5)], straw='#3B2416', pearls=True),
             '#F5E6D3', '#E5C7A0'),
    'croissant': (None, lambda: croissant('g'), '#FBEBC6', '#F0CF8E'),
}

LATTE = [('#3B2416', '#2A170C', .40), ('#C47A32', '#9A5A22', .26), ('#F7EAD4', '#EAD2AE', .34)]
PRODUCTS.update({
    'mocha': (None, lambda: iced_cup('h', [('#5E3322', '#3B1D12', .34), ('#7A4B2A', '#5B3418', .30), ('#F3E3CB', '#E5CDA8', .36)], straw='#E9B7A0', topping='cream', drizzle='#4A2A18', ice=False), '#EEDCCB', '#DDBA9C'),
    'caramel': (None, lambda: iced_cup('i', [('#3B2416', '#2A170C', .36), ('#D58A35', '#B66A1A', .28), ('#F7EAD4', '#EAD2AE', .36)], straw='#6E8B5E', topping='cream', drizzle='#C47A32'), '#F8E6CA', '#EDC48A'),
    'taro': (None, lambda: iced_cup('j', [('#8E6BB3', '#6F4C97', .46), ('#C9B2E4', '#B596D6', .30), ('#E6D8F4', '#D2BDEA', .24)], straw='#F2D9B8'), '#EFE6F7', '#D3BFE9'),
    'redvelvet': (None, lambda: iced_cup('k', [('#C2334A', '#8E1F33', .5), ('#F4CFCB', '#E8AEAB', .5)], straw='#F2D9B8'), '#F9DEE1', '#EDB4BD'),
    'thaitea': (None, lambda: iced_cup('n', [('#E8801F', '#B85A10', .62), ('#F8DDB0', '#EBC384', .38)], straw='#3B2416'), '#FBE4C4', '#F1C088'),
    'cookiescream': (None, lambda: iced_cup('o', [('#2E2220', '#1A1210', .40), ('#F4EDE4', '#E6DACA', .60)], straw='#C47A32', topping='cream', drizzle='#2E2220', ice=False), '#F0E7DD', '#DACCBC'),
    'strawberry': (None, lambda: iced_cup('r', [('#F06A8A', '#C93C63', .5), ('#F8CBD6', '#EFA9BB', .5)], straw='#F8DE9A'), '#FDE4EA', '#F4BCCB'),
    'lemontea': (None, lambda: iced_cup('t', [('#F7C85A', '#E49A1E', 1.0)], straw='#6E8B5E', garnish='lemon'), '#FBF1CC', '#F2DB8E'),
    'lychee': (None, lambda: iced_cup('u', [('#F9C4B4', '#EE9C8A', 1.0)], straw='#6E8B5E', garnish='lemon', garnish_color='#F6A7A0'), '#FCE6DE', '#F3C2B3'),
    'hotlatte': (None, lambda: hot_cup('v', coffee=('#C79A6C', '#9A6B42')), '#F6E5D1', '#E5C6A3'),
    'espresso': (None, lambda: hot_cup('w', coffee=('#4A2A18', '#2A170C'), art='none', x=22, y=30, s=.88), '#EADBC9', '#D3B896'),
    'hottea': (None, lambda: hot_cup('y', coffee=('#E5A33A', '#C27A1B'), art='none'), '#FBEBCB', '#F0CF8B'),
    'donut': (None, lambda: donut('z1'), '#FCE7EC', '#F4BFCE'),
    'donutchoco': (None, lambda: donut('z2', glaze='#5A3322', sprinkles=False, chocolate=True), '#EEDDD0', '#D9B79C'),
    'cookie': (None, lambda: cookie('z3'), '#F8E8CF', '#EBC88F'),
    'sandwich': (None, lambda: sandwich('z4'), '#F5EBD2', '#E8D29A'),
    'bread': (None, lambda: bread('z5'), '#FBF0C8', '#F0D88C'),
    'chococroissant': (None, lambda: croissant('z6', extra='choco'), '#F3E3D1', '#E2BE97'),
    'almondcroissant': (None, lambda: croissant('z7', extra='almond'), '#FBEBC6', '#F0CF8E'),
})

for name, (_, make, c1, c2) in PRODUCTS.items():
    inner = backdrop(name[:6], c1, c2) + sparkle(78, 96, .8) + sparkle(330, 120, .55) + bean(70, 300, .8, -25, op=.55) + bean(338, 292, .7, 30, op=.55) + make()
    open(os.path.join(OUT, f'product_{name}.svg'), 'w').write(svg(400, 400, inner))
print('ok', len(PRODUCTS))
