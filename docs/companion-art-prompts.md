# Companion 스프라이트 생성 프롬프트 키트

> ⚠️ **대체됨(2026-06-23).** 아트 방향이 **소프트 벡터 코드 드로잉**(Pusheen 계열)으로 확정되어,
> 이 픽셀아트 + sprite-gen 파이프라인은 더 이상 채택 경로가 아니다. 확정 결정은
> [companion-character-design.md §15.4](companion-character-design.md)를 따른다.
> 이 문서는 픽셀아트로 회귀할 경우의 참고용으로만 보존한다.

작성일: 2026-06-23
대상: Mochi(기본 고양이) 스프라이트를 100% 생성(gen)으로 제작
연관: [companion-character-design.md](companion-character-design.md) §15(에셋), §16(프롬프트)

## 0. 전제 (손제작 0, 전량 gen)

- 손튜닝 불가 → **메뉴바 18px 세트도 별도 프롬프트로 생성**한다. 디테일한 32px를 18px로 줄이지 않는다(줄이면 식별 불가).
- 색 고정 · 다운스케일 · atlas 조립은 **스크립트 후처리**로 처리(손 아트 아님, §4).
- 모델: **픽셀아트 네이티브 모델 권장** (Retro Diffusion / PixelLab / SD pixel-art LoRA). 범용 모델(DALL·E/Midjourney)은 안티에일리어싱이 섞여 양자화 후처리 부담이 커진다.
- sprite-gen은 "base 1장 + 액션 리스트"로 행을 생성하므로, §1 base를 먼저 만들고 §3 액션 리스트를 먹인다.

## 1. 공용 블록 (모든 프롬프트에 append)

### 1.1 STYLE (스타일·팔레트 고정)

```text
STYLE: true pixel art, low resolution, 1:1 pixels, hard edges, flat shading,
no anti-aliasing, no blur, no gradient, no dithering noise, clean single-pixel dark outline,
limited palette of EXACTLY 8 colors, use ONLY these hex:
outline #2F2F35, cream fur #F2E7D5, fur shadow #CDBFA8, fur highlight #FFF7EA,
ear-inner pink #E9A8A1, eyes/nose #24242A, blue cursor charm #7DB7FF, accent amber #F59E0B.
CHARACTER: a small cream kitten named Mochi — round head, two small triangle ears,
two tiny dot eyes, 1px nose, no mouth, short tail, a tiny blue cursor charm.
Calm, cute, developer-tool aesthetic, not childish.
BACKGROUND: fully transparent (or solid magenta #FF00FF if alpha is unsupported, for chroma key).
```

### 1.2 NEGATIVE (전 프롬프트 공통)

```text
NEGATIVE: anti-aliasing, blur, soft edges, gradient shading, glow bloom, drop shadow,
3d render, realistic, photo, big anime eyes, open mouth, text, letters, watermark, signature,
extra limbs, inconsistent character between frames, more than 8 colors, background scenery, ground shadow.
```

## 2. Base 이미지 (정체성 앵커)

### 2.1 팝오버용 base (96~128px 표시, 32px 그리드)

```text
A single front-facing idle sprite of Mochi the cream kitten, sitting upright, centered,
drawn on a 32x32 pixel grid shown large. Crisp readable silhouette.
[STYLE]  [NEGATIVE]
```

### 2.2 메뉴바용 base (18px 식별성 — 별도 생성)

```text
A single front-facing sprite of Mochi reduced to its BOLDEST silhouette for an 18x18
macOS menu bar icon: only two triangle ears, one round bright face, two dot eyes,
and a thick dark outline. Maximum contrast so it reads on BOTH light and dark menu bars.
NO whiskers, NO tail detail, NO charm detail, NO inner shading. 16x16 pixel grid shown large.
[STYLE]  [NEGATIVE]
```

## 3. 상태별 애니메이션 스트립

각 상태를 **가로 스프라이트 스트립**(프레임 좌→우, 등간격, 캐릭터 동일, 지정 부위만 변화)으로 생성한다.
**팝오버 스트립**(디테일)과 **메뉴바 스트립**(미니멀·모션 ≤1px)을 각각 만든다 — 메뉴바 스트립은 §2.2 base 기준.

### 3.1 egg (Lv.0)

```text
A horizontal sprite strip of 2 evenly-spaced frames of a "Token Egg":
a cream egg with a small blue token dot. Frame1 dot dim; Frame2 dot bright glint + faint hairline crack.
Egg position identical across frames.
[STYLE]  [NEGATIVE]
```

### 3.2 idle

```text
A horizontal sprite strip of 2 frames, Mochi sitting. Frame1 eyes open; Frame2 eyes closed (blink).
Nothing else moves.
[STYLE]  [NEGATIVE]
```

### 3.3 working

```text
A horizontal sprite strip of 4 frames, Mochi sitting, both front paws tapping as if typing:
Frame1 paws up, Frame2 left paw down, Frame3 paws up, Frame4 right paw down. Head and body steady.
[STYLE]  [NEGATIVE]
```

### 3.4 focus

```text
A horizontal sprite strip of 4 frames, Mochi sitting, eyes slightly narrowed,
the small blue cursor charm pulsing: Frame1 charm dim → Frame4 charm brightest. Tail near-still.
[STYLE]  [NEGATIVE]
```

### 3.5 tired

```text
A horizontal sprite strip of 2 frames, Mochi with ears drooped and body lowered, breathing slowly:
Frame1 slightly up, Frame2 slightly down. Optional tiny amber sweat dot.
[STYLE]  [NEGATIVE]
```

### 3.6 sleep

```text
A horizontal sprite strip of 2 frames, Mochi curled up asleep, tail wrapped around the body,
closed eyes, gentle breathing: Frame1 up, Frame2 down.
[STYLE]  [NEGATIVE]
```

### 3.7 levelUp (one-shot, 비루프)

```text
A horizontal sprite strip of 6 frames, Mochi celebrating a level up:
egg-shard sparkles and tiny star-dust burst around it, ears up, a quick tail wag, eyes briefly wide.
A short start → peak → settle sequence (not looping).
[STYLE]  [NEGATIVE]
```

### 3.8 메뉴바 스트립 추가 지시 (위 7종에 공통 append)

```text
MENUBAR VARIANT: redraw the SAME motion for an 18x18 menu bar icon using the bold silhouette
of §2.2 — ears + round face + thick outline only, motion delta ≤1px, no fine detail.
Generate as its own strip (do NOT downscale the detailed strip).
```

## 4. sprite-gen 액션 리스트 (개념)

base를 먹이고 아래 액션 리스트로 행을 생성한다.

```json
{
  "base": "mochi_base.png",
  "fps": 6,
  "actions": [
    {"name": "egg",     "frames": 2, "loop": true,  "desc": "token egg, blue dot pulse + hairline crack"},
    {"name": "idle",    "frames": 2, "loop": true,  "desc": "sitting, eye blink"},
    {"name": "working", "frames": 4, "loop": true,  "desc": "front paws typing"},
    {"name": "focus",   "frames": 4, "loop": true,  "desc": "eyes narrowed, cursor charm pulse"},
    {"name": "tired",   "frames": 2, "loop": true,  "desc": "ears drooped, body low, slow breath"},
    {"name": "sleep",   "frames": 2, "loop": true,  "desc": "curled, breathing"},
    {"name": "levelUp", "frames": 6, "loop": false, "desc": "sparkle burst, tail wag, ears up"}
  ]
}
```

## 5. 자동 후처리 (스크립트, 손작업 아님)

생성 직후 아래를 스크립트로 강제한다 — gen 결과의 팔레트·선명도 편차를 손이 아니라 코드로 잡는다.

1. **알파**: sprite-gen 크로마키(magenta → alpha), 또는 배경 투명 직출.
2. **팔레트 양자화**: 8색 팔레트 PNG로 remap (ImageMagick `-dither None -remap palette.png`, 또는 PIL `quantize(palette=...)`). 9색 이상이면 가장 가까운 8색으로 강제.
3. **다운스케일**: nearest-neighbor만. 팝오버 96/128px, 메뉴바 18px. **메뉴바는 §2.2/§3.8 미니멀 결과에서** 생성(디테일판 축소 금지).
4. **atlas + manifest 조립**: 상태별 프레임을 가로 행으로 합쳐 `popover-atlas.png` / `menubar-atlas.png` + `*-manifest.json`(프레임 사각형·loop·fps). 런타임은 manifest 사각형으로 슬라이스.

## 6. 진화 단계 / 시즌 캐릭터로 확장

- 진화 단계(Desk Kitten Lv5, Cursor Cat Lv15 …)는 §2.1 base 프롬프트에 단계 특징 1줄만 추가해 새 base를 만들고 §3 액션을 다시 돌린다. (예: Lv15 → "with a small blue cursor charm on the collar, the charm blinks in focus state")
- 시즌 캐릭터(Rudolph/Snow Cat 등)는 STYLE의 CHARACTER 줄에 시즌 액세서리+팔레트만 교체. 실루엣(귀+둥근 얼굴)은 유지(메뉴바 식별성). 상세 로스터는 companion-character-design.md §17.

## 7. 한국어 base 미러 (참고)

```text
macOS 메뉴바 앱용 작은 픽셀아트 고양이 Mochi. 정면, 앉은 자세, 32x32 그리드를 크게 표시.
진짜 픽셀아트: 1:1 픽셀, 하드 엣지, 안티에일리어싱·블러·그라데이션 없음, 1px 어두운 외곽선, 정확히 8색 팔레트.
색: 외곽선 #2F2F35, 크림털 #F2E7D5, 그림자 #CDBFA8, 하이라이트 #FFF7EA, 귀안쪽 #E9A8A1,
눈/코 #24242A, 파란 cursor charm #7DB7FF, 앰버 #F59E0B.
둥근 머리, 작은 삼각 귀 2개, 점 눈 2개, 1px 코, 입 없음, 짧은 꼬리, 작은 파란 charm.
배경 완전 투명. 큰 애니풍 눈·열린 입·텍스트·워터마크 금지.
```
