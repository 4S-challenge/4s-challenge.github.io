// 앱 아이콘 SVG 만들기: dart run tool/make_icon.dart
//
// 야구장 전광판처럼 LED 도트로 "4S"를 쓰고, 아래에 B·S·O 표시등을 둔다.
// 만든 SVG는 PNG로 바꿔 assets/icon/에 두고 flutter_launcher_icons로 각 플랫폼에 적용한다 (README 참고).
import 'dart:io';

const ground = '#0E2A22';
const board = '#08201A';
const line = '#2C5A4B';
const unlit = '#173A30';
const strike = '#F5B83D';
const ball = '#8FD3F4';
const out = '#E8836B';

// 5x7 도트 글꼴
const glyphs = {
  '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
};

/// [cx], [cy]를 가운데로 하는 도트 "4S"와 표시등. [pitch]는 도트 간격.
/// [mono]면 켜진 도트와 표시등만 한 색으로 그린다 (Android 테마 아이콘).
String scoreboard(double cx, double cy, double pitch, {bool mono = false}) {
  final b = StringBuffer();
  const cols = 11; // 5 + 사이 1칸 + 5
  const rows = 7;
  final lampGap = pitch * 1.5;
  final lampR = pitch * 0.55;
  final height = rows * pitch + lampGap + lampR * 2;
  final left = cx - (cols - 1) * pitch / 2;
  final top = cy - height / 2 + pitch / 2;
  final r = pitch * 0.38;

  b.writeln('<g>');
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      if (col == 5) continue;
      final glyph = glyphs[col < 5 ? '4' : 'S']!;
      final on = glyph[row][col < 5 ? col : col - 6] == '1';
      final x = left + col * pitch;
      final y = top + row * pitch;
      if (on) {
        if (!mono) {
          b.writeln('<circle cx="${x.toStringAsFixed(1)}" cy="${y.toStringAsFixed(1)}" r="${(r * 1.45).toStringAsFixed(1)}" fill="$strike" opacity="0.18"/>');
        }
        b.writeln('<circle cx="${x.toStringAsFixed(1)}" cy="${y.toStringAsFixed(1)}" r="${r.toStringAsFixed(1)}" fill="${mono ? '#FFFFFF' : strike}"/>');
      } else if (!mono) {
        b.writeln('<circle cx="${x.toStringAsFixed(1)}" cy="${y.toStringAsFixed(1)}" r="${(r * 0.8).toStringAsFixed(1)}" fill="$unlit"/>');
      }
    }
  }
  // B · S · O 표시등
  final lampY = top + (rows - 1) * pitch + lampGap + lampR;
  final lampStep = pitch * 2.2;
  final colors = [ball, strike, out];
  for (var i = 0; i < 3; i++) {
    final x = cx + (i - 1) * lampStep;
    if (!mono) {
      b.writeln('<circle cx="${x.toStringAsFixed(1)}" cy="${lampY.toStringAsFixed(1)}" r="${(lampR * 1.5).toStringAsFixed(1)}" fill="${colors[i]}" opacity="0.18"/>');
    }
    b.writeln('<circle cx="${x.toStringAsFixed(1)}" cy="${lampY.toStringAsFixed(1)}" r="${lampR.toStringAsFixed(1)}" fill="${mono ? '#FFFFFF' : colors[i]}"/>');
  }
  b.writeln('</g>');
  return b.toString();
}

String svg(String body, {int size = 1024}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $size $size" width="$size" height="$size">\n$body</svg>\n';

void main() {
  final out = Directory('assets/icon')..createSync(recursive: true);

  // iOS·웹·기본 아이콘: 꽉 찬 배경 + 전광판 판
  final full = StringBuffer()
    ..writeln('<rect width="1024" height="1024" fill="$ground"/>')
    ..writeln('<rect x="96" y="96" width="832" height="832" rx="120" fill="$board" stroke="$line" stroke-width="16"/>')
    ..write(scoreboard(512, 512, 62));
  File('${out.path}/icon.svg').writeAsStringSync(svg(full.toString()));

  // Android 적응형 아이콘 앞면: 투명 배경, 가운데 안전 영역(지름 66%) 안에만 그림
  File('${out.path}/icon_foreground.svg').writeAsStringSync(svg(scoreboard(512, 512, 40)));

  // Android 13+ 테마 아이콘: 모양(알파)만 쓰므로 켜진 도트와 표시등만
  File('${out.path}/icon_monochrome.svg').writeAsStringSync(svg(scoreboard(512, 512, 40, mono: true)));

  // 웹 파비콘
  File('web/favicon.svg').writeAsStringSync(svg(full.toString()));
}
