"""Play 스토어 그래픽: 대표 이미지(1024x500)와 앱 아이콘(512x512).
실행: python3 tools/make_store_graphics.py   (Pillow, Noto Sans CJK 글꼴 필요)
앱 아이콘(web/favicon.svg)의 전광판 점을 그대로 옮겨 그린다."""
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'store'
OUT.mkdir(exist_ok=True)
FONTS = Path('/usr/share/fonts/opentype/noto')


def font(name, size):
    for idx in range(8):
        try:
            f = ImageFont.truetype(str(FONTS / name), size, index=idx)
        except OSError:
            break
        if 'KR' in ' '.join(f.getname()):
            return f
    return ImageFont.truetype(str(FONTS / name), size)


def blend(hex_color, alpha, bg=(0x08, 0x20, 0x1A)):
    h = hex_color.lstrip('#')
    c = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    return tuple(round(c[i] * alpha + bg[i] * (1 - alpha)) for i in range(3))


def draw_board(d, x, y, size, s):
    """아이콘 전광판을 (x, y)에 size 크기로 그린다. s는 확대 배율."""
    d.rounded_rectangle([x * s, y * s, (x + size) * s, (y + size) * s],
                        radius=size * 0.144 * s, fill='#08201A', outline='#2C5A4B',
                        width=max(2, round(size * 0.018)) * s)
    scale = size / 832.0
    svg = (ROOT / 'web' / 'favicon.svg').read_text()
    for cx, cy, r, fill, op in re.findall(
            r'<circle cx="([\d.]+)" cy="([\d.]+)" r="([\d.]+)" fill="(#\w+)"(?: opacity="([\d.]+)")?', svg):
        px = x + (float(cx) - 96) * scale
        py = y + (float(cy) - 96) * scale
        rr = float(r) * scale
        d.ellipse([(px - rr) * s, (py - rr) * s, (px + rr) * s, (py + rr) * s],
                  fill=blend(fill, float(op) if op else 1.0))


def feature_graphic():
    W, H, S = 1024, 500, 3
    img = Image.new('RGB', (W * S, H * S), '#0E2A22')
    d = ImageDraw.Draw(img)
    draw_board(d, 72, 70, 360, S)

    tx = 480
    d.text((tx * S, 92 * S), '4S 챌린지', font=font('NotoSansCJK-Black.ttc', 84 * S), fill='#F4F1E8')
    d.text((tx * S + 4 * S, 205 * S), '숫자야구', font=font('NotoSansCJK-Medium.ttc', 34 * S), fill='#A9BDB4')

    chip_font = font('NotoSansCJK-Bold.ttc', 28 * S)
    y = 290
    for label, bg, fg in [('혼자 랭킹 도전', '#F5B83D', '#1A1405'), ('친구와 1:1 대결', '#8FD3F4', '#0A2633')]:
        w = d.textlength(label, font=chip_font) / S + 44
        d.rounded_rectangle([tx * S, y * S, (tx + w) * S, (y + 56) * S], radius=14 * S, fill=bg)
        d.text(((tx + 22) * S, (y + 7) * S), label, font=chip_font, fill=fg)
        tx += w + 14
    d.text((480 * S, 375 * S), '숨겨진 네 자리 숫자, 몇 번 만에 4S?',
           font=font('NotoSansCJK-Bold.ttc', 28 * S), fill='#F4F1E8')

    img = img.resize((W, H), Image.LANCZOS)
    img.save(OUT / 'feature-graphic-1024x500.png', optimize=True)


def icon_512():
    src = Image.open(ROOT / 'assets' / 'icon' / 'icon.png').convert('RGBA')
    src.resize((512, 512), Image.LANCZOS).save(OUT / 'icon-512.png', optimize=True)


feature_graphic()
icon_512()
for p in sorted(OUT.glob('*.png')):
    im = Image.open(p)
    print(p.relative_to(ROOT), im.size, im.mode, f'{p.stat().st_size // 1024}KB')
