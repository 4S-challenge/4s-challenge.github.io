"""공유 미리보기 이미지(1200x630). 앱 아이콘(favicon.svg)의 전광판 점을 그대로 옮겨 그린다."""
# 실행: python3 tools/make_og_image.py web/favicon.svg web/og-image.png  (Pillow, Noto Sans CJK 글꼴 필요)
import re, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

svg_path, out_path = sys.argv[1], sys.argv[2]
W, H = 1200, 630
S = 2  # 2배로 그린 뒤 줄여서 가장자리를 부드럽게
img = Image.new('RGB', (W * S, H * S), '#0E2A22')
d = ImageDraw.Draw(img)

def hexrgb(h, a=1.0, bg=(0x08, 0x20, 0x1A)):
    h = h.lstrip('#'); c = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    return tuple(round(c[i] * a + bg[i] * (1 - a)) for i in range(3))

# 왼쪽: 아이콘 전광판
bx, by, bs = 70, 75, 480  # 화면 좌표(1x)
d.rounded_rectangle([bx * S, by * S, (bx + bs) * S, (by + bs) * S], radius=60 * S,
                    fill='#08201A', outline='#2C5A4B', width=8 * S)
scale = bs / 832.0  # svg 안쪽 판 크기 832
svg = open(svg_path).read()
for cx, cy, r, fill, op in re.findall(
        r'<circle cx="([\d.]+)" cy="([\d.]+)" r="([\d.]+)" fill="(#\w+)"(?: opacity="([\d.]+)")?', svg):
    x = bx + (float(cx) - 96) * scale; y = by + (float(cy) - 96) * scale; rr = float(r) * scale
    col = hexrgb(fill, float(op) if op else 1.0)
    d.ellipse([(x - rr) * S, (y - rr) * S, (x + rr) * S, (y + rr) * S], fill=col)

# 오른쪽: 글자
black = '/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc'
bold = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
medium = '/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc'
KR = 1  # ttc 안의 KR 글꼴 번호
def font(path, size):
    for idx in (1, 0, 2, 3, 4):
        f = ImageFont.truetype(path, size * S, index=idx)
        if 'KR' in ' '.join(f.getname()):
            return f
    return ImageFont.truetype(path, size * S)

tx = 610
d.text((tx * S, 120 * S), '4S 챌린지', font=font(black, 92), fill='#F4F1E8')
d.text((tx * S + 6 * S, 245 * S), '숫자야구', font=font(medium, 40), fill='#A9BDB4')
# 강조 띠
d.rounded_rectangle([tx * S, 345 * S, (tx + 500) * S, 425 * S], radius=18 * S, fill='#F5B83D')
d.text(((tx + 28) * S, 357 * S), '친구와 대결해요!', font=font(black, 42), fill='#1A1405')
d.text((tx * S, 460 * S), '숨겨진 네 자리 숫자,', font=font(bold, 34), fill='#F4F1E8')
d.text((tx * S, 510 * S), '누가 먼저 4S를 맞힐까?', font=font(bold, 34), fill='#F4F1E8')

img = img.resize((W, H), Image.LANCZOS)
img.save(out_path, optimize=True)
print(out_path, img.size)
