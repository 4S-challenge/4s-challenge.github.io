"""스토어 스크린샷 꾸미기: 실제 앱 화면(store_screenshots/out) 위에 홍보 문구를 얹는다.
실행: python3 tools/make_store_screenshots.py   (Pillow, Noto Sans CJK 글꼴 필요)
결과: store/screenshots/<기기>/NN-이름.png (문구 있음), store/screenshots/<기기>/raw/ (화면만)"""
import shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'store_screenshots' / 'out'
DST = ROOT / 'store' / 'screenshots'
FONTS = Path('/usr/share/fonts/opentype/noto')

# 스토어에 올릴 순서, 원본 파일, 두 줄 문구 (둘째 줄은 강조색)
SHOTS = [
    ('01-home', '1-home', '숨겨진 네 자리 숫자,', '몇 번 만에 맞힐까?'),
    ('02-solo', '2-solo', 'S·B·OUT 힌트로', '추리하는 숫자야구'),
    ('03-versus', '3-versus', '친구와 번갈아 던지는', '1:1 실시간 대결'),
    ('04-result', '4-result', '정답을 맞히면', '이니셜로 랭킹 등록'),
    ('05-ranking', '5-ranking', '적은 시도, 빠른 시간으로', '랭킹 1위에 도전'),
    ('06-invite', '6-invite', '방 코드 하나로', '친구를 바로 초대'),
]


def font(name, size):
    for idx in range(8):
        try:
            f = ImageFont.truetype(str(FONTS / name), size, index=idx)
        except OSError:
            break
        if 'KR' in ' '.join(f.getname()):
            return f
    return ImageFont.truetype(str(FONTS / name), size)


def compose(src: Path, line1: str, line2: str) -> Image.Image:
    shot = Image.open(src).convert('RGB')
    W, H = shot.size
    canvas = Image.new('RGB', (W, H), '#0E2A22')
    d = ImageDraw.Draw(canvas)

    # 위쪽 문구
    top = round(H * 0.045)
    size1 = round(W * 0.062)
    size2 = round(W * 0.078)
    f1 = font('NotoSansCJK-Bold.ttc', size1)
    f2 = font('NotoSansCJK-Black.ttc', size2)
    d.text((W / 2, top), line1, font=f1, fill='#F4F1E8', anchor='ma')
    d.text((W / 2, top + size1 * 1.45), line2, font=f2, fill='#F5B83D', anchor='ma')
    caption_bottom = top + size1 * 1.45 + size2 * 1.35

    # 아래쪽: 실제 화면을 줄여서 둥근 모서리 + 테두리로 얹는다. 아래로는 살짝 잘려도 된다.
    margin_top = round(caption_bottom + H * 0.03)
    scale = 0.84
    sw, sh = round(W * scale), round(H * scale)
    small = shot.resize((sw, sh), Image.LANCZOS)
    x = (W - sw) // 2
    radius = round(W * 0.06)
    mask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], radius=radius, fill=255)
    border = round(W * 0.012)
    d.rounded_rectangle([x - border, margin_top - border, x + sw + border, margin_top + sh + border],
                        radius=radius + border, fill='#2C5A4B')
    canvas.paste(small, (x, margin_top), mask)
    return canvas


for device_dir in sorted(p for p in SRC.iterdir() if p.is_dir()):
    out = DST / device_dir.name
    raw = out / 'raw'
    raw.mkdir(parents=True, exist_ok=True)
    for name, src_name, line1, line2 in SHOTS:
        src = device_dir / f'{src_name}.png'
        compose(src, line1, line2).save(out / f'{name}.png', optimize=True)
        shutil.copyfile(src, raw / f'{name}.png')
    print(out.relative_to(ROOT), Image.open(out / f'{SHOTS[0][0]}.png').size)
