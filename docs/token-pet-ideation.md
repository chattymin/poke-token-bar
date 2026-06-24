# TokenMac 성장형 캐릭터 아이데이션

작성일: 2026-06-23
대상: TokenMac의 다음 제품 방향
상태: 아이데이션 / 제품 컨셉 초안

## 1. 한 줄 컨셉

AI 코딩 토큰 사용량이 2D 도트 캐릭터의 경험치가 되고, 사용자가 코딩할수록 캐릭터가 레벨업하고 새로운 캐릭터를 해금하는 macOS 메뉴바 앱.

현재 TokenMac은 "오늘 AI 코딩 토큰을 얼마나 썼는지 보여주는 유틸리티"다. 여기에 성장형 캐릭터를 얹으면 "AI 코딩을 많이 한 날의 흔적이 쌓이는 작은 동료"가 된다. 숫자를 확인하는 앱에서 매일 열어보고 싶은 앱으로 바뀌는 것이 핵심이다.

## 2. 왜 이 방향이 좋은가

### 2.1 기능보다 감정이 붙는다

토큰 사용량, 비용, 한도, burn rate는 유용하지만 그 자체로는 도구적이다. 사용자는 필요할 때만 앱을 본다. 반면 캐릭터 성장은 같은 데이터를 감정적인 피드백으로 바꾼다.

- 오늘 토큰을 많이 썼다 → 캐릭터가 성장했다
- 이번 주 작업량이 많았다 → 새 스킨이나 캐릭터가 열렸다
- 한도에 가까워졌다 → 캐릭터가 지친 표정을 짓거나 쉬는 모드로 들어간다
- 며칠간 꾸준히 썼다 → streak 보상이나 작은 장식이 생긴다

이 변화는 앱의 사용 빈도를 올리고, 스크린샷 공유 가능성을 만든다.

### 2.2 오픈소스 확산 포인트가 생긴다

현재의 차별점은 "Claude Code / Codex 토큰과 공식 한도를 메뉴바에서 본다"다. 충분히 유용하지만 설명형 가치에 가깝다. 성장형 캐릭터를 넣으면 설명이 짧아진다.

> AI 코딩 토큰을 먹고 자라는 메뉴바 펫

이 문장은 README, GitHub social preview, Hacker News, X, Reddit에서 바로 이해된다. 오픈소스가 퍼지려면 "쓸모"와 함께 "한 번 보여주고 싶은 장면"이 있어야 한다. 도트 캐릭터는 그 장면을 만든다.

### 2.3 기존 기능과 충돌하지 않는다

캐릭터는 기존 토큰/한도 기능을 대체하지 않는다. 오히려 기존 데이터를 더 자주 보게 만드는 입구가 된다.

- 메뉴바: 캐릭터 + 오늘 토큰 요약
- 팝오버 상단: 캐릭터 상태, 레벨, XP
- 팝오버 하단: 기존 토큰/비용/한도 상세
- 설정: 캐릭터 표시 끄기, 기존 코인 모드 유지

즉, 실용 앱의 신뢰성은 유지하면서 첫인상만 더 강하게 만들 수 있다.

## 3. 제품 이름 방향

`TokenMac`은 현재 기능에는 잘 맞지만, 캐릭터 성장 컨셉까지 담기에는 건조하다. 이름 변경은 기능 구현보다 먼저 확정할 필요는 없지만, README와 브랜딩을 바꿀 때를 대비해 후보를 정리한다.

### 3.1 이름 후보

| 이름 | 느낌 | 장점 | 단점 |
|---|---|---|---|
| TokenCat | AI 토큰 + 고양이 | 무엇인지 즉시 이해되고 캐릭터 중심 포지셔닝이 강함 | 장난감 앱처럼 보일 수 있음 |
| PromptCat | 프롬프트 + 고양이 | 캐릭터와 AI 맥락이 같이 드러남 | 단어 조합이 약간 직설적 |
| TokenMochi | 기본 캐릭터 중심 | 고유하고 부드러운 인상 | 토큰 추적 앱임이 덜 명확함 |
| CodeKitty | 개발자용 고양이 | 기억하기 쉽고 귀여움 | 유치하게 느껴질 수 있음 |
| PromptPal | AI 코딩 동료 | 고양이 외 companion 확장 가능 | 고양이 캐릭터성이 이름에 드러나지 않음 |

### 3.2 추천

기본 캐릭터를 고양이로 정한다면 초기 오픈소스 포지셔닝은 `TokenCat`이 가장 설명력이 높다. `PromptPal`은 장기적으로 여러 companion을 확장할 때 좋지만, 첫인상에서 고양이 캐릭터를 밀기에는 힘이 약하다.

추천 순서:

1. `TokenCat`: 고양이 캐릭터 중심의 MVP를 가장 짧게 설명한다.
2. `PromptCat`: AI 코딩 맥락과 고양이를 같이 드러낸다.
3. `PromptPal`: 고양이 외 캐릭터까지 확장할 때 안정적이다.

실행안: 당장은 저장소명과 앱명을 유지하고, 문서/README에서는 "TokenMac is evolving into a token-powered coding cat companion"처럼 소개한다. 캐릭터 기능 반응이 좋으면 v2에서 `TokenCat` 계열로 이름 변경을 결정한다.

## 4. 핵심 경험

### 4.1 메뉴바

메뉴바는 앱의 첫인상이다. 현재 코인 아이콘은 토큰/비용에는 맞지만 캐릭터 성장과는 거리가 있다. 다음 방향은 2가지 모드를 제공하는 것이다.

- Companion mode: 도트 캐릭터가 메뉴바에 표시된다.
- Classic mode: 기존 코인 아이콘과 토큰 텍스트를 유지한다.

Companion mode에서는 캐릭터가 상태에 따라 움직인다.

| 상태 | 조건 | 표현 |
|---|---|---|
| Idle | 최근 사용량 낮음 | 서 있거나 눈 깜빡임 |
| Working | burn rate 보통 | 타이핑/걷기 애니메이션 |
| Focus | burn rate 높음 | 빠른 작업 애니메이션 |
| Tired | 한도 임박 | 땀, 느린 움직임, 빨간 포인트 |
| Sleep | 장시간 사용 없음 | 잠자는 프레임 |

메뉴바 텍스트는 설정으로 선택한다.

- 캐릭터만
- 캐릭터 + 오늘 토큰
- 캐릭터 + 레벨
- 캐릭터 + 한도 %

### 4.2 팝오버

팝오버는 탭 구조로 나눈다. 현재 키우는 캐릭터만 보여주면 캐릭터를 max까지 키운 뒤 새 알을 받을 때 이전 성과를 잃는 느낌이 생긴다. 따라서 팝오버는 현재 성장과 수집 기록을 함께 보여줘야 한다.

권장 탭:

| 탭 | 역할 |
|---|---|
| Home | 현재 키우는 캐릭터 상태창, XP, 오늘 획득량, 다음 성장 목표 |
| Collection | 지금까지 키운 캐릭터 도감, max 달성 기록, 부화 날짜, 누적 XP |
| Playground | 보유 캐릭터들이 자유롭게 돌아다니는 작은 2D 공간 |
| Usage | 기존 토큰/비용/한도 상세 |

첫 MVP에서는 `Home`과 `Usage`만 있어도 되지만, 성장 완료 후 새 알을 주는 구조를 넣는 순간 `Collection`은 필수다. `Playground`는 v0.4 이후 시각적 확산 포인트로 둔다.

Home 탭 필수 요소:

- 큰 도트 캐릭터
- 이름
- 레벨
- XP 바
- 오늘 획득 XP
- 다음 레벨까지 남은 토큰
- 오늘 상태 문구

예시:

```text
Mochi Lv. 12
[████████░░] 82%
오늘 +148 XP
다음 진화까지 2.4M tokens
```

상태 문구는 짧고 과하지 않게 유지한다.

- "오늘 꽤 많이 성장했어요."
- "현재 속도면 곧 한도에 가까워져요."
- "오늘은 아직 조용한 편이에요."
- "이번 주 누적 사용량이 높아요."

기존 토큰/비용/한도 상세는 하단에 유지한다. 이 앱의 신뢰성은 정확한 숫자에서 나오므로 캐릭터가 정보를 가리면 안 된다.

Collection 탭은 도감이자 성과 보관함이다. max까지 키운 캐릭터는 사라지지 않고 여기에 남는다. 사용자는 언제든 이전 캐릭터를 다시 볼 수 있고, 대표 캐릭터로 지정할 수도 있다.

Playground 탭은 [git-goods/gitanimals](https://github.com/git-goods/gitanimals)의 farm mode에서 받은 좋은 인상을 로컬 앱 안으로 가져오는 영역이다. 보유 캐릭터들이 작은 책상/터미널 배경에서 걷고, 자고, 가끔 서로 마주 보는 정도면 충분하다. 여기서는 정밀한 게임보다 "내가 키운 애들이 여기 있다"는 감정이 중요하다.

## 5. 성장 시스템

### 5.1 토큰을 XP로 바꾸는 원칙

토큰 수는 사용량에 따라 매우 크게 튄다. 단순히 `1,000 tokens = 1 XP`처럼 선형으로 계산하면 대량 사용자가 너무 빨리 모든 것을 해금한다. 반대로 너무 빡빡하면 성장감이 없다.

권장 원칙:

- 오늘 사용량은 즉시 성장감에 반영한다.
- 누적 사용량은 장기 레벨에 반영한다.
- 레벨이 올라갈수록 필요 XP는 증가한다.
- 하루 폭주 사용량은 보상하되 전체 밸런스를 깨지 않게 한다.

초기 공식 후보:

```text
dailyXP = floor(sqrt(todayTokens / 1_000) * 4)
bonusXP = streakBonus + limitAwarenessBonus
totalXP += dailyXP + bonusXP
```

예시:

| 오늘 토큰 | dailyXP 대략 |
|---:|---:|
| 100K | 40 |
| 1M | 126 |
| 10M | 400 |
| 100M | 1264 |

이 방식은 많이 쓰면 확실히 성장하지만, 10배 많이 쓴다고 10배 성장하지는 않는다.

### 5.2 첫 설치와 기존 사용량 소급 성장

앱을 처음 설치했는데 이미 로컬 `ccusage` 기록에 많은 사용량이 있는 경우, 캐릭터는 알에서 시작하되 기존 사용량을 읽고 즉시 성장한다.

권장 흐름:

1. 첫 실행 시 `Token Egg` 표시
2. 기존 Claude Code / Codex 누적 토큰 스캔
3. "기존 작업 흔적 384.2M tokens를 발견했어요." 문구 표시
4. 알이 깨지고 `Mochi` 부화
5. 기존 누적 토큰에 해당하는 XP를 소급 지급
6. 최종적으로 현재 누적 사용량에 맞는 레벨과 진화형 표시

정책:

- 첫 시각 경험은 항상 알이다.
- 최종 상태는 기존 누적 사용량을 반영한다.
- 소급 지급 후 `claimedTokenTotal`을 현재 누적 토큰으로 저장한다.
- 이후부터는 누적 토큰 증가분만 XP로 지급한다.

이 방식은 알에서 태어나는 감정적 순간을 유지하면서도, 이미 많이 쓴 사용자의 기록을 무시하지 않는다.

### 5.3 레벨 곡선

초기에는 단순한 누적 XP 테이블이 좋다.

| 구간 | 목적 | 필요 XP |
|---|---|---:|
| Lv. 1-5 | 첫날 성장 체감 | 낮음 |
| Lv. 6-15 | 일주일 사용 보상 | 보통 |
| Lv. 16-30 | 습관 형성 | 높음 |
| Lv. 31-50 | 장기 사용 | 높음 |
| Lv. 51+ | 수집/명예 | 완만한 반복 |

MVP에서는 50레벨까지만 설계하고, 50 이후는 `prestige`나 시즌으로 넘긴다.

### 5.4 진화와 해금

처음부터 많은 캐릭터가 필요하지 않다. 1~2세트만 있어도 된다. 중요한 것은 "앞으로 더 열릴 것 같다"는 느낌이다.

MVP 캐릭터 세트:

1. Mochi 계열
   - Lv.0 Token Egg
   - Lv.1 Hatchling Mochi
   - Lv.5 Desk Kitten
   - Lv.15 Cursor Cat
   - Lv.30 Terminal Cat
   - Lv.50 Orbit Cat

2. Byte 계열
   - Lv.1 Gray Kitten
   - Lv.15 Prompt Cat
   - Lv.30 Terminal Cat
   - Lv.50 Orbit Cat

해금 방식:

- Token Egg는 처음부터 제공하고, 첫 XP 지급 시 기본 고양이 `Mochi`가 부화
- Lv.20 또는 누적 50M tokens 달성 시 두 번째 고양이 세트 해금
- 누적 100M tokens 달성 시 색상 스킨 해금
- 7일 streak 달성 시 작은 액세서리 해금
- 한도 임박 알림을 받고 쉬었다가 복귀하면 "rested" 배지 해금

### 5.5 Max 성장과 새 알 루프

캐릭터가 max level에 도달하면 해당 캐릭터는 사라지지 않는다. 대신 `Collection`에 보존되고, 사용자는 새 `Token Egg`를 받는다. 새 알에서는 아직 키워보지 않은 다른 캐릭터가 랜덤으로 부화한다.

루프:

1. 현재 캐릭터가 max level 달성
2. `Maxed` 배지와 완료 연출 표시
3. 캐릭터를 `Collection`에 보존
4. 새 `Token Egg` 지급
5. 다음 XP부터 새 알 부화/성장 시작
6. 기존 max 캐릭터는 Collection/Playground에서 계속 볼 수 있음

랜덤 알 정책:

- 알 추첨은 **수집 단계와 수집 후 단계**로 나눈다(상세 5.6).
  - 수집 단계(미보유 기본 캐릭터 있음): 미보유 캐릭터 중에서만 등급 가중으로 부화. 중복 없음 → 기존 보장 유지.
  - 수집 후 단계(모든 기본 보유): 풀 가중 추첨, 중복은 `알 조각(shard)`으로 환산.
- 등급(rarity)과 확률은 5.6에서 정의한다. `common`, `rare`, `event` 3단어는 **등급(normal/rare/unique/legendary)** 과 **풀(standard/seasonal)** 두 축으로 분리한다. `event`는 등급이 아니라 seasonal 풀이다.
- 시즌 한정 알은 5.7에서 정의한다. 풀이 다를 뿐 등급 축은 동일하게 적용된다.
- 같은 캐릭터가 중복으로 나오는 구조는 수집 단계에서는 피한다. 수집 후에만 중복을 `알 조각`으로 바꿔 보상감을 유지한다.

### 5.6 등급(rarity)과 확률

토큰을 많이 쓰면 알을 더 자주 받지만, **어떤 알이 나오는지는 등급 가중치로 조절**한다. 흔한 캐릭터는 빨리, 어려운 캐릭터는 늦게 나오게 만든다.

등급 사다리(순서 있는 enum, 위로 확장 여지):

| 등급 | 역할 | 기본 가중치(예시) |
|---|---|---:|
| normal | 기본 고양이(Mochi, Byte) | 60 |
| rare | 색 variant, 차분한 대안 | 28 |
| unique | 강한 개성 액세서리/실루엣 | 10 |
| legendary | 장기 사용 보상 | 2 |
| (mythic) | 추후 확장 자리 | — |

가중치는 코드 상수가 아니라 **테이블 1개**로 둔다. 위에 `mythic`을 추가해도 스키마 변경이 없도록 등급은 순서 있는 enum으로만 비교한다("더 높은 등급이 나올 수 있다"는 요구를 마이그레이션 없이 흡수).

"어려운 알은 늦게"를 두 방향으로 보장한다.

- **anti-frontload 게이트**: 높은 등급은 일정 조건 전에는 후보에서 제외한다. 예: `unique`는 알 4개째부터, `legendary`는 알 8개째 또는 누적 500M tokens 이후.
- **pity(천장/바닥)**: rare+ 가 5연속 안 나오면 바닥 가중치를 올리고, legendary는 30 알 천장에서 확정한다. 후반 운빨로 영영 못 받는 상황을 막아 성장감을 지킨다(5.1 밸런스 원칙과 동일선).

수집 후 단계에서 이미 보유한 캐릭터가 뽑히면 `알 조각`으로 환산한다. `알 조각`은 이미 캐릭터 모티프(방석/level up 연출)로 존재하므로 새 화폐를 만들지 않고 재사용한다.

### 5.7 시즌 한정 알 (seasonal pool)

특정 시기에만 활성화되는 별도 풀이다. 12월 루돌프, 눈사람처럼 계절감 있는 캐릭터를 그 시기에만 부화시킨다.

원칙:

- **고양이 정체성 유지(§13 연장).** "눈사람"이 아니라 "눈사람 모자/머플러를 두른 고양이(Snow Cat)", "루돌프"는 "뿔+빨간 코 고양이(Rudolph Cat)"처럼 액세서리+팔레트로 시즌을 표현한다. 메뉴바 18px 식별성을 위해 귀/얼굴 실루엣은 유지한다.
- **알은 토큰으로 살 수 없다(risk 10.1 방어).** 알은 진화/streak/누적 마일스톤으로만 지급된다. 시즌 윈도 중에 받는 첫 알 지급 1회를 시즌 알로 확정한다. 즉 기준은 "토큰을 얼마나 태웠나"가 아니라 "그 시기에 앱을 켜 두었나(presence)"다.
- **매년 재등장(annual recurrence).** 시즌 캐릭터는 매년 같은 시기에 다시 받을 수 있다. 한 해를 놓쳐도 영구 상실이 아니다. 비수익 1인 OSS의 가치와 과소비 경계(risk 10.1)에 맞춰 FOMO 압박을 최소화한다.
- 시즌 캐릭터도 5.6의 등급 축을 그대로 쓴다(보통 rare~unique, 일부 시즌 정점은 legendary).

시즌 후보(로컬 시스템 날짜 기준, 상세 로스터는 companion-character-design.md):

| 시즌 | 윈도(로컬) | 캐릭터 후보 |
|---|---|---|
| 겨울 홀리데이 | 12/1–12/31 | Rudolph Cat, Snow Cat |
| 새해 | 1/1–1/15 | Fortune Cat |
| 봄 | 3/20–4/30 | Sakura Cat |
| 여름 | 7/1–8/20 | Beach Cat |
| 가을/할로윈 | 10/1–10/31 | Pumpkin Cat |

윈도 판정은 로컬 시스템 날짜를 쓴다(1인 로컬 단일 기기 전제와 일치). 윈도 밖에서는 해당 풀이 비활성이라 시즌 알이 지급되지 않는다.

완료 문구 후보:

- "Mochi가 max level에 도달했어요."
- "Mochi는 Collection에서 계속 만날 수 있어요."
- "새 Token Egg가 도착했어요."

이 루프는 [git-goods/gitanimals](https://github.com/git-goods/gitanimals)의 "활동으로 펫을 얻고 성장시키며, 여러 펫을 farm처럼 보여주는" 재미를 TokenMac의 로컬 메뉴바 앱에 맞게 줄인 버전이다. 거래/길드 같은 외부 시스템은 넣지 않고, 개인의 누적 작업 기록과 수집 경험에 집중한다.

## 6. 도트 캐릭터 아트 방향

처음부터 고품질 아트 파이프라인을 만들 필요는 없다. 대신 작은 해상도와 제한된 프레임으로 일관성을 만든다.

캐릭터 상세 설계는 [Companion 캐릭터 상세 설계](companion-character-design.md)에 둔다. 기본 캐릭터는 알에서 깨어나는 크림색 도트 고양이 `Mochi`를 우선 후보로 한다. 새싹/코어 같은 추상형보다 고양이가 첫인상에서 사람을 끌어들이는 힘이 강하고, sleep/focus/working/tired 상태 표현도 자연스럽다.

권장 스펙:

- 원본 크기: 32x32 또는 48x48
- 메뉴바 표시: 18x18 전후
- 팝오버 표시: 96x96 또는 128x128로 nearest-neighbor 확대
- 프레임: idle 2장, working 4장, tired 2장, sleep 2장
- 팔레트: 캐릭터별 6~10색 이내

파일 구조 예시:

```text
assets/companions/
  mochi/
    metadata.json
    lv0_egg_0.png
    lv0_egg_1.png
    lv1_idle_0.png
    ...
  byte/
    metadata.json
    ...
```

MVP에서는 PNG sprite를 번들에 포함한다. 추후 커뮤니티 기여를 받으려면 `metadata.json` 스키마와 preview script를 제공한다.

## 7. 오픈소스 참여 포인트

성장형 캐릭터는 기여 포인트를 자연스럽게 만든다.

### 7.1 캐릭터 팩

가장 기여하기 쉬운 영역은 코드가 아니라 캐릭터 팩이다.

- 새 캐릭터 세트
- 색상 변형
- 액세서리
- 레벨별 진화형
- 계절 이벤트 스킨

이를 위해 `CONTRIBUTING.md`에 캐릭터 팩 규격을 명확히 적는다. 아트 기여는 코드 기여보다 진입장벽이 낮고, 프로젝트에 커뮤니티 감각을 만든다.

### 7.2 공유 카드

공유 카드는 확산을 위한 핵심 기능이다.

이미지에 포함할 정보:

- 캐릭터
- 앱 이름
- 레벨
- 오늘 토큰
- 주간 토큰
- 현재 streak
- "Powered by local ccusage data" 같은 짧은 신뢰 문구

사용자는 이 이미지를 GitHub README, X, Slack, Discord에 올릴 수 있다. 오픈소스 프로젝트 입장에서는 가장 직접적인 홍보 루프다.

### 7.3 README 첫 화면

README의 첫 문장은 숫자보다 캐릭터여야 한다.

현재:

> 오늘 사용한 AI 코딩 토큰량을 macOS 상태바에 표시하는 메뉴바 앱.

변경 후보:

> AI 코딩 토큰을 먹고 자라는 macOS 메뉴바 캐릭터.

그 아래에 정확한 토큰/한도 추적 기능을 설명한다.

## 8. MVP 범위

### v0.2: Companion MVP

목표: 캐릭터 성장 컨셉이 실제 앱에서 느껴지게 만든다.

필수:

- 캐릭터 1세트
- 레벨 / XP 계산
- UserDefaults 또는 Application Support JSON에 성장 상태 저장
- 팝오버 상단 캐릭터 상태창
- 메뉴바 Companion mode
- 기존 Classic mode 유지
- XP 계산 단위 테스트

제외:

- 캐릭터 팩 외부 로딩
- 공유 카드
- 시즌/랭킹
- 복잡한 퀘스트
- 많은 캐릭터

### v0.3: Unlocks

목표: 계속 쓰면 열리는 보상을 만든다.

필수:

- 캐릭터 2세트
- 레벨별 진화형
- max level 달성 처리
- 새 Token Egg 지급
- 해금 목록 UI
- 캐릭터 선택 UI
- Collection 탭
- unlock 조건 테스트

### v0.4: Share Card

목표: 사용자가 스크린샷을 공유하고 싶게 만든다.

필수:

- 공유 이미지 생성
- "Copy Image" 또는 "Save Image"
- GitHub README용 badge/card 옵션
- 개인정보 노출 방지 옵션: 비용 숨기기, 한도 숨기기, provider 숨기기
- Playground 탭의 자유롭게 뛰노는 캐릭터 화면

### v0.5: Community Packs

목표: 오픈소스 기여 루프를 만든다.

필수:

- 캐릭터 팩 규격 문서
- 샘플 pack
- pack validation script
- `CONTRIBUTING.md`
- README에 "Add your companion" 섹션

## 9. 구현 메모

### 9.1 데이터 모델

새 모델 후보:

```swift
struct CompanionState: Codable {
    var activeCompanionInstanceID: String
    var totalXP: Int
    var claimedTokenTotal: Int
    var didApplyInitialBackfill: Bool
    var ownedCompanions: [CompanionInstance]
    var eggInventory: [CompanionEgg]
    var unlockedCompanionIDs: Set<String>
    var unlockedCosmeticIDs: Set<String>
    var lastUpdatedDate: String
    var streakDays: Int
    var pityCounter: Int            // rare+ 미출현 누적 (5.6 pity)
    var legendaryPity: Int          // legendary 천장 카운터
    var eggsOpenedTotal: Int        // anti-frontload 게이트 판정용
    var shardBalance: Int           // 수집 후 중복 환산 (알 조각)
    var seenSeasons: Set<String>    // "winter_2026" 등, 시즌당 1회 지급 판정
}

struct CompanionInstance: Codable, Identifiable {
    var id: String
    var companionID: String
    var displayName: String
    var level: Int
    var totalXP: Int
    var isMaxed: Bool
    var hatchedAt: Date
    var maxedAt: Date?
    var selectedSkinID: String?
}

struct CompanionEgg: Codable, Identifiable {
    var id: String
    var poolID: String
    var grantedAt: Date
    var source: String
}
```

핵심은 이미 반영된 토큰량을 중복 XP로 지급하지 않는 것이다. `claimedTokenTotal` 또는 provider별 claimed daily key를 저장해 중복 지급을 막는다. 또 현재 키우는 캐릭터와 지금까지 키운 캐릭터 목록을 분리해야 한다. maxed 캐릭터를 active 슬롯에서 빼더라도 `ownedCompanions`에는 계속 남아야 한다.

### 9.2 기존 구조와의 연결

현재 `UsageStore`가 오늘/주간/월간 토큰과 provider snapshot을 가지고 있다. Companion 기능은 이 값을 읽어 별도 상태를 갱신하면 된다.

추가 후보:

- `CompanionStore`
- `CompanionModel`
- `CompanionXP`
- `CompanionCatalog`
- `CompanionSpriteView`

`UsageStore`에 모든 로직을 넣기보다, 성장/해금 로직은 `CompanionStore`로 분리하는 편이 낫다. `UsageStore`는 사용량의 출처이고, `CompanionStore`는 게임 상태의 출처가 된다.

### 9.3 저장 위치

1인 로컬 앱 기준으로는 Application Support JSON이면 충분하다.

```text
~/Library/Application Support/TokenMac/companion-state.json
```

UserDefaults도 가능하지만, 해금 목록과 상태가 늘어나면 JSON이 디버깅하기 쉽다.

### 9.4 밸런스 조정

XP 공식은 코드 상수로 박기보다 작은 테이블로 분리한다.

```swift
enum CompanionBalance {
    static let tokenXPDivisor = 1_000.0
    static let xpMultiplier = 4.0
    static let levelThresholds = [...]
}
```

나중에 README나 설정에서 "XP formula"를 설명하기 쉬워진다.

## 10. 리스크

### 10.1 과소비를 장려하는 느낌

"토큰을 많이 쓸수록 성장"은 재미있지만, 과소비를 장려하는 인상을 줄 수 있다. 해결책은 많이 쓰는 것만 보상하지 않고 꾸준함과 휴식도 보상하는 것이다.

- streak 보상
- 한도 임박 시 쉬었다가 복귀하면 보상
- "healthy pace" 상태
- 비용/한도 경고는 기존처럼 명확히 표시

메시지는 "많이 써라"가 아니라 "오늘의 작업 흔적이 쌓인다"에 가깝게 유지한다.

### 10.2 유틸리티 신뢰도 저하

너무 귀여운 UI가 토큰 추적 신뢰도를 낮출 수 있다. 그래서 Classic mode를 유지하고, 팝오버 하단의 숫자 정보는 지금처럼 정밀하게 둔다.

### 10.3 아트 품질

도트 캐릭터는 품질 편차가 눈에 잘 띈다. 처음에는 캐릭터 수보다 일관된 팔레트와 애니메이션 품질이 중요하다. 1세트만 잘 만들어도 충분하다.

## 11. 우선순위 결론

가장 먼저 할 일은 이름 변경이 아니라 Companion MVP다.

권장 순서:

1. `CompanionStore`와 XP/level 계산 추가
2. 캐릭터 1세트 sprite 추가
3. 팝오버 상단에 캐릭터 상태창 추가
4. 메뉴바 Companion mode 추가
5. README 첫 문장과 스크린샷 교체
6. 반응을 보고 앱 이름 변경 결정

이 방향의 핵심 가설은 단순하다.

> 토큰 사용량은 숫자로 보면 비용이지만, 캐릭터 성장으로 보면 기록이 된다.

이 가설이 맞으면 TokenMac은 "AI 코딩 사용량 표시 앱"에서 "AI 코딩을 함께 자라는 작은 동료"로 포지셔닝이 바뀐다. 오픈소스에서 유명해질 가능성은 후자가 더 크다.
