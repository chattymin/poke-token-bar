# Companion 디자인 시스템 (재사용 가이드)

작성일: 2026-06-23
대상: 모든 companion 캐릭터(현재/미래)가 공유하는 단일 디자인 시스템
연관: [companion-character-design.md](companion-character-design.md), [token-pet-ideation.md](token-pet-ideation.md)
레퍼런스 구현: `patrick-html/2026-06-23-mochi-state-preview.html` (작동하는 JS 엔진 — Swift 포팅 기준)

## 1. 원칙: 하나의 큐트 엔진 + 트레이트 오버라이드

새 캐릭터를 새로 그리지 않는다. **공통 엔진**(둥근 만두 베이스 + 베이비 스키마 표정 + 상태 모션)에 **트레이트만 바꿔** 종·품종을 만든다. 고양이/강아지/품종이 모두 같은 귀여움 규칙과 모션을 공유한다.

근거(폭넓은 레퍼런스 조사):

- **베이비 스키마**(Lorenz, Kindchenschema): 큰 머리·둥근 몸 + 크고 낮고 멀리 떨어진 반짝 눈 + 작은 코·입 + 둥근 볼이 귀여움 트리거. ([PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC3260535/), [의인화 비율 연구](https://www.sciencedirect.com/science/article/pii/S1875952123000411))
- **Pusheen·Hello Kitty 교훈**: 화려함보다 단순·둥글기·공감이 사랑받는다. ([CuteStudies](https://www.cutestudies.com/compendium/pusheen))
- **귀 규칙**: 귀를 따로 붙이지 않고 머리+귀+몸을 하나의 실루엣으로(앞면이 윤곽을 파고듦). ([easydrawingguides](https://easydrawingguides.com/how-to-draw-a-chibi-cat/), [MediBang](https://medibangpaint.com/en/use/2023/05/cute-animal-ears/))

## 2. 공통 엔진 (모든 캐릭터 고정)

이 부분은 캐릭터마다 바뀌지 않는다.

- **체형**: 둥근 가로 loaf(만두). 큰 머리가 몸과 하나로 합쳐진 단일 실루엣. 팔다리 없음.
- **눈**: 크게 + 얼굴 아래쪽 + 서로 멀리 + 반짝 2개. 부드러운 색(순검정 아님)으로 부담 줄임.
- **코·입**: 작게. 볼은 옅은 블러시.
- **외곽선**: 부드러운 웜그레이, 얇게. 파스텔.
- **통합 실루엣 렌더**: 어두운 윤곽(귀+몸 부풀려)을 뒤에 깔고 본체 색을 위에 얹어 통합 외곽선을 만든다(`drawBody`).
- **모션**(팔 없이 귀·꼬리·몸통·표정으로만): `breathe`(숨), `bounce`(점프), `earUp`/`droop`(귀), `tw`(귀 움찔), `sway`(꼬리), `eye`(blink/narrow/half/wide/closed), `loaf`(납작), `charm`(가슴 점 맥박), `sweat`/`z`/`sparkle`.
- **상태**: egg / idle / working / focus / tired / sleep / levelUp. (companion-character-design.md §7과 동일)

## 3. 트레이트 스키마 (캐릭터별 오버라이드)

캐릭터 = 아래 트레이트의 집합. 새 품종은 이 표만 채우면 된다.

| 트레이트 | 값 | 설명 |
|---|---|---|
| `pal` | 팔레트 객체 | `{o,C,S,H,ear,blush,E,B,Bd,A,stripe,(point),(saddle)}` |
| `rx`,`ry` | 숫자 | loaf 비율. `rx>ry`=가로 만두. 닥스훈트는 `rx`↑`ry`↓(길고 낮음) |
| `ears.type` | `pointy`/`floppy`/`fluffy` | 뾰족(고양이) / 처진(리트리버·닥스훈트) / 복슬(푸들) |
| `ears.size` | 숫자 | 귀 길이/크기 배수 |
| `snout` | 0/1 | 강아지 주둥이(코+Y입). 0이면 고양이(납작 얼굴+수염) |
| `tail` | `curl`/`wag`/`plume` | 말림(고양이) / 흔들(강아지) / 술 달린(리트리버·푸들) |
| `mark` | `tabby`/`points`/`saddle`/`curlyfluff`/`none` | 태비 줄무늬 / 샴 포인트 / 안장 패치 / 푸들 곱슬 / 없음 |
| `eye` | 색(선택) | 눈 색 override(예: 샴 블루 `#6f9fd8`) |
| `body` | `loaf`/`mounty`/`drop`/… | 몸 도형. loaf=둥근 만두(기본), mounty=둥근 삼각, drop=물방울. **비동물은 여기로 확장** |
| `kind` | `cat`/`dog`/`object` | object면 귀·꼬리·주둥이·수염·charm 없이 **도형 + 미니멀 얼굴**만 |

확장 여지: `markings`는 배열로 합성 가능(줄무늬+양말 등), `accessory`(시즌 모자 등), `texture`(복슬/매끈)를 같은 방식으로 추가한다.

## 4. 현재 로스터 (예시 6종)

| 캐릭터 | 종·품종 | ears | snout | tail | mark | 팔레트 |
|---|---|---|---|---|---|---|
| Mochi | 고양이 · 크림 태비 | pointy | – | curl | tabby | 크림 |
| Smoke | 고양이 · 그레이(Pusheen) | pointy | – | curl | tabby | 그레이 |
| Coco | 고양이 · 샴 | pointy | – | curl | points | 크림+브라운 포인트, 블루 눈 |
| Toast | 강아지 · 골든 리트리버 | floppy | ✓ | plume | none | 골드 |
| Cloud | 강아지 · 푸들 | fluffy | ✓ | plume | curlyfluff | 애프리콧 |
| Dash | 강아지 · 닥스훈트 | floppy(김) | ✓ | wag | saddle | 탄+다크 새들, 긴 loaf |

## 5. 새 품종 추가 절차

1. 팔레트 정의(8~10색, 파스텔, 부드러운 외곽선).
2. 트레이트 표(§3) 한 줄 작성 — 기존 ear/tail/mark 타입 재사용.
3. 필요한 새 타입이 있으면 엔진에 렌더러 1개만 추가(예: 새 `ears.type='bat'`). 나머지는 그대로.
4. 레퍼런스 JS(`drawCompanion`)에 추가해 7상태 시각 확인 후 확정.

핵심: **공통 엔진은 건드리지 않고 트레이트만 추가** → 모든 캐릭터가 같은 귀여움·모션 일관성을 유지한다.

## 6. 게임 시스템과의 연결

종·품종 확장은 알/컬렉션/등급 시스템(companion-character-design.md §11·§17·§18)의 수집 다양성을 크게 늘린다.

- 알 풀을 **종(고양이/강아지/…) → 품종**으로 조직. 등급(normal/rare/unique/legendary)은 품종 희소도에 매핑(흔한 태비=normal, 샴/푸들=rare, 특수 품종=unique+).
- 시즌 한정도 같은 트레이트 위에 시즌 액세서리/팔레트만 얹어 만든다(별도 에셋 생성 없음).
- 컬렉션 도감은 종별 탭으로 자연 확장.

## 7. 렌더링/구현 메모

- **코드 드로잉**(Core Graphics / SwiftUI Path). PNG 스프라이트·sprite-gen 불필요(companion-character-design.md §15.4).
- 트레이트 = Swift `struct CompanionTraits`(팔레트/ear enum/tail enum/mark enum/proportions). `drawCompanion(ctx, traits, state, t)` 1개 함수가 모든 캐릭터를 그린다.
- 메뉴바/팝오버/컬렉션/Playground 모두 같은 함수 호출, 크기만 다름.
- 레퍼런스 JS의 함수 대응: `drawBody`(통합 실루엣), `earShape`(ear 디스패치), `drawTailFor`, `drawFace`, `drawStripes`, `drawCompanion`(엔진).

## 8. 캐릭터 제작 프로세스 (품질 플레이북) — 새 캐릭터 요청 시 자동 적용

새 캐릭터(예: "코알라 만들어줘")를 받으면 추측으로 한 번에 그리지 말고, 아래 루프를 **알아서** 돈다. 이 프로세스가 Mochi/강아지 품질을 만든 실제 과정이다.

### 8.1 단계

1. **레퍼런스 먼저 (추측 금지).** 그 동물의 *정체성 특징*이 유명/귀여운 만화에서 어떻게 그려지는지 웹에서 10개+ 조사한다. 베이비 스키마/Pusheen 원칙도 재확인. 예: 코알라 → 큰 둥근 복슬 귀(머리 폭만큼) + 크고 검은 코 + 목 없는 둥근 몸 + 회색.
2. **트레이트 매핑.** 정체성 특징을 엔진 트레이트(§3)로 변환. 기존 ear/tail/mark 타입으로 되면 재사용, 안 되면 *새 렌더러 1개만* 추가(공통 엔진은 안 건드림).
3. **코드 구현.** `drawCompanion` + 트레이트로 그린다.
4. **렌더 → 스크린샷 → 자가검토 루프 (핵심).** 헤드리스 Chrome으로 크게 렌더해 PNG로 뽑고, **내가 직접 이미지를 본다.** 어색하면 수치 고치고 반복 — 자연스러워질 때까지. *눈으로 확인하지 않고 끝내지 않는다.*
5. **헤드리스 기하·경계 검증.** node로 2D 컨텍스트 stub 해 전 상태×프레임 no-throw + 경계(0..SZ) + 모션(프레임 distinct) 확인.
6. **사용자 확인.** 보고 판단 받기.

### 8.2 렌더+스크린샷 하네스 (그대로 재사용)

```bash
# 1) 함수 정의부만 떼어 큰 캔버스로 렌더하는 임시 html 생성 (python)
#    - main html 의 <script> 에서 '// ===== 페이지 =====' 앞까지가 함수 정의부
#    - canvas 240px, ctx.setTransform(3.75,...) 로 64좌표를 확대 렌더, drawCompanion(ctx,C,state,1200)
# 2) 헤드리스 Chrome 스크린샷
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
  --window-size=900,720 --screenshot=_eartest.png "file://$PWD/_eartest.html"
# 3) Read 도구로 _eartest.png 를 열어 직접 본다 → 수정 → 반복. 끝나면 _eartest.* 삭제.
```

### 8.3 자주 틀린 것 (이미 겪은 실패 → 규칙)

| 실패 증상 | 원인 | 해결 |
|---|---|---|
| 큰 눈·진한 볼이 "부담" | baby schema 과적용 + 강한 대비 | 눈은 키우되 부드러운 색·깔끔하게, 볼 옅게 |
| 도트가 각지고 별로 | 저해상도 픽셀 | 소프트 벡터 코드 드로잉(안티에일리어싱) |
| 귀가 "공/덩어리" | 작은 귀+둥근 머리 | 귀를 실루엣 특징으로 키움 |
| 귀가 "팔/주걱" | 귀가 수평으로 짧게 뻗음 | 거의 수직으로 길게, 또는 머리 바깥 초승달 |
| 귀가 "스티커처럼 떠 있음" | 얼굴 위에 외곽선째 얹음 | 머리 바깥에 걸치고 밑동은 머리에 연결 |
| 처진 귀가 안 보임 | 몸과 같은 색 + 머리 안에 묻힘 | 몸보다 **진한 톤**(Pochacco/Snoopy) + 머리 *밖*으로 |
| 귀가 얼굴/눈 침범 | 귀를 얼굴 옆(머리 안)에 둠 | 머리 *중심 극좌표*로 머리 외곽 테두리에 그림 |
| 너무 복잡/거품 | 디테일 과다 | Pusheen 원칙: 단순·둥글기가 이김 |
| 계속 어긋남 | 안 보고 추측 | **매번 스크린샷으로 직접 보고** 고침 |

### 8.4 강아지 귀 최종 해법 (기록)

레퍼런스(Pochacco·Pluto·Snoopy·Goofy·Lady 등 10+) 결론:

- **머리 중심 극좌표의 초승달 플랩.** `Pt(a,r)=[cx+side*r*rx*sin(a), cy-r*ry*cos(a)]` (a=머리 위에서 각도, r=반경 배수). 안쪽 `ri≈0.90`(머리 테두리 hug) ~ 바깥 `ro≈1.15+`(머리 밖으로 부풂)의 초승달.
- **머리 꼭대기 모서리에 부착, 바깥으로 늘어짐** → 얼굴 안 침범.
- **몸보다 진한 톤(`dear`)** + 자기 외곽선 + 안쪽 평행선(Snoopy) → "귀"로 읽힘.
- **각도 시프트 `s` 하나로 모션**: 처짐(s+0.30, Pluto) / 들림(s−0.55, Pochacco) / 움찔(tw).
- 복슬(푸들)은 머리 외곽에 큰 둥근 puff 1개 + 작은 정수리 뭉치.

## 9. 워크드 예시: 코알라 (요청 시 이렇게)

1. **레퍼런스 조사**: 코알라 정체성 = 머리 폭만 한 *큰 둥근 복슬 귀 2개*(머리 위-옆), *크고 검은 둥근 코*(주둥이 대신 큰 코), 목 없는 둥근 회색 몸, 작은 눈.
2. **트레이트**: `pal`=회색(`C:#B9BEC6` 류)+귀 진한 회색 `dear`; `ears.type:'fluffy'` 큰 size; `snout`은 코알라식 큰 코로 변형(주둥이 대신 코 ellipse 확대 — `drawFace` 에 `bigNose` 분기 1개 추가); `tail:none`(코알라 꼬리 안 보임 → tail 생략 트레이트 추가); `mark:none`. 귀 안쪽 핑크/흰 복슬.
3. **구현 → 스크린샷 루프**로 귀 크기/코 비율 맞춤(코알라는 귀가 매우 크고 복슬). 4. 기하 검증. 5. 사용자 확인.

원칙: 새 동물의 *상징적 특징 1~2개*(코알라=큰 귀+큰 코)를 트레이트로 정확히 잡고, 나머지는 공통 만두 엔진을 그대로 쓴다.

## 10. 비동물 캐릭터 (오브젝트·음식·식물·블롭)

동물뿐 아니라 사물도 만든다. 레퍼런스: [JeyRam "Mounty"](https://www.jeyram.org/cute-character) — 둥근 삼각/물방울/찌그러진 블롭 등 **어떤 단순한 둥근 도형이든 점 눈 2개 + 작은 미소를 얹으면 귀여워진다**(플랫 + 손그림 외곽선 + muted 팔레트). 이미지 4장 직접 분석.

핵심: 이 원리가 우리 엔진과 동일하다 — 베이비 스키마 얼굴은 그대로 두고 **몸 도형만 바꾼다**.

- `kind:'object'` → 귀·꼬리·주둥이·수염·charm 끔. 얼굴 = 큰 반짝 눈 + 작은 미소 + 옅은 볼(코 없음).
- `body` 트레이트로 도형 선택: `mounty`(둥근 삼각/onigiri), `drop`(물방울), `loaf`(원형), 필요하면 새 도형 path 1개만 `bodyPath`에 추가.
- 모션은 동물과 동일(몸 숨/바운스/squash + 눈 깜빡). 귀/꼬리가 없어도 살아 있음.
- 구현 검증됨: `Mounty`(둥근 삼각, 탄색), `Dewy`(물방울, 하늘색), `Vesu`(화산, `body:'volcano'`+`feature:'volcano'`). 레퍼런스 JS `bodyPath`/`drawVolcanoTop` 참조.
- **도형이 뾰족할 필요 없음**: 화산은 평평한 분화구 윗면(둥근 사다리꼴). 각 사물의 실제 실루엣을 따른다.
- **feature → 상태 매핑 패턴**: 사물 고유 요소를 상태에 연결하면 생동감이 커진다. 예: 화산 분출(용암 밝기·연기 크기)을 working/focus=강, sleep=약으로. 새 사물도 이런 고유 feature를 상태에 묶을 수 있으면 묶는다.

새 사물 요청(예: "별/구름/커피컵/새싹") 시: §8 프로세스 그대로 — 레퍼런스 조사 → `bodyPath`에 도형 1개 추가 + 팔레트 + `kind:'object'` → 렌더·스크린샷 자가검토 → 확인. 사물의 *상징 실루엣 1개*만 정확히 잡으면 나머지는 공통 얼굴·모션 재사용.
