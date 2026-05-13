# CLAUDE.md — IberisRaidAuction

> Claude Code가 이 디렉토리에서 시작할 때 자동으로 읽는 컨텍스트 파일.

## 프로젝트 개요

`IberisRaidAuction` (slash: `/ira`) — WoW 공격대 GDKP 골드 분배 장부 애드온. 단일 창 + 인라인 편집 + 자동 전리품 캡처 + 거래 자동 등록 + 정산 보고서.

- 작성자: Iberis (GitHub: Iberis6501)
- 라이선스: **Apache 2.0** (원본과 동일)
- 대상 클라이언트: Anniversary (1.15.x) / TBC / Wrath / Mists / Mainline

## 기반 / Attribution (필수 유지)

이 애드온은 **[RaidLedger](https://github.com/tg123/RaidLedger) by tg123** (Apache 2.0) 의 fork. 한국 변형 **RaidLedgerBR** UX 패턴 일부 차용. **카운트다운/테스트모드 패턴은 RaidBook 차용** (Apache 2.0).

- `LICENSE` (Apache 2.0) 그대로 유지
- `NOTICE` 의 attribution 항목은 **삭제/수정 금지** — 원작자 명시는 라이선스 의무
- 새 의존성/패턴 차용 시 `NOTICE` 에 항목 추가

## 디렉토리 구조

```
IberisRaidAuction/
├── IberisRaidAuction.toc        단일 TOC, 5종 Interface 동시 지정
├── IRACmd.lua                   슬래시 명령 (/ira) + LDB launcher
├── IRACountdown.lua             자동/▶/● 카운트다운 버튼 (좌하단)
├── IRAData.lua                  GetItemInfo 캐시 + 데이터 처리
├── IRAEvent.lua                 이벤트 라우팅 (regevent 함수 노출)
├── IRAGui.lua                   메인 프레임 / 위젯 / 인라인 편집
├── IRALocale.lua                L 테이블 (현재 fallback 패스스루)
├── IRAOptions.lua               Blizzard Settings 패널 + 미니맵 옵션
├── IRATest.lua                  테스트모드 + 카라잔 TBC 25 가상 데이터
├── IRATheme.lua                 LSM 기반 ElvUI 풍 테마 (옵션)
├── IRAUtil.lua                  Print, GetMoneyStringL 등 유틸
├── lib/                         vendored libs (LibStub, CB-1.0, LDB-1.1, LDBIcon-1.0, LDeformat-3.0, LSM-3.0, lib-st)
├── LICENSE / NOTICE / README.md
└── .pkgmeta                     packager 설정 (manual-changelog: CHANGELOG.md)
```

## 네임스페이스 / 모듈 등록 패턴

원본 RaidLedger 패턴 유지: 두 번째 가변인자(`...`)를 `ADDONSELF`로 받아 모듈 트리에 등록.

```lua
local _, ADDONSELF = ...
ADDONSELF.gui = {}            -- 모듈 부착
local L = ADDONSELF.L         -- 다른 모듈 참조
```

**현재 등록된 키** (의존 그래프 파악용):
- 코어: `L`, `print`, `deformat`, `regevent`, `db`
- 데이터: `calcavg`, `genexport`, `genreport`
- UI: `gui`, `st` (lib-st 핸들), `theme`, `countdown`, `options`, `test`

신규 모듈 추가 시 `IRA<이름>.lua` 명명 + TOC 끝에 추가 + `ADDONSELF.<key>` 등록.

## 의존성 정책

- **`RequiredDeps` 없음** — standalone 애드온. ElvUI 미설치 환경에서도 동작해야 함.
- 외부 통합은 **옵셔널**: `IRATheme.lua`가 LSM 통해 ElvUI 미디어 fetch 시도, 실패 시 클린 fallback.
- 라이브러리는 전부 `lib/` 에 vendored. 외부 lib repo 의존 금지 (단일 클론으로 동작).

## SavedVariables (이름 변경 금지)

- `IberisRaidAuctionGlobalConfig` — account-wide 설정
- `IberisRaidAuctionDatabase` — per-character 장부 데이터

이름 변경 시 기존 사용자 데이터 손실. **불가피하면 마이그레이션 코드 동봉.**

## 파일 명명 / prefix

- 모든 lua 파일: `IRA<역할>.lua` (RaidBook 패턴 차용)
- 전역 함수/프레임 노출 시: `IberisRaidAuction*` 또는 `IRA*` prefix

## 멀티 클라이언트

- 단일 TOC `IberisRaidAuction.toc` 에 `## Interface: 11508, 20505, 30404, 50502, 110200` 한 줄로 5종 동시 지원.
- 클라별 TOC 분리 안 함 (vs `ElvUI_IberisUI`는 5개 별도 TOC).
- 클라이언트별 분기는 런타임 체크 (`WOW_PROJECT_ID`, `WOW_PROJECT_MAINLINE` 등). 예: `addonProfiles/InvenRaidFrames3.lua` 패턴 참고는 `ElvUI_IberisUI` 쪽.

## 커밋 / 릴리스 규칙

- 커밋 메시지: 한글. type: 한글제목 형식 또는 마일스톤 라벨 (`v0.3: ...`).
- 코드 변경과 버전 bump는 **별도 커밋** (ElvUI_IberisUI 컨벤션 동일).
- TOC `## Version` 단일 줄만 갱신.
- `CHANGELOG.md` 는 `.gitignore` + `.pkgmeta` manual-changelog 대상 — packager가 zip에 포함. 로컬에는 생성/수정 가능, repo commit X.

## 릴리스 인프라 (TODO)

- **`.github/workflows/` 미설정** — GH Actions 자동 배포 없음. ElvUI_IberisUI와 달리 태그 푸시만으론 CF/GitHub Releases 안 올라감.
- 배포 자동화 필요 시: `BigWigsMods/packager` Actions 추가 + `CF_API_KEY` / `GITHUB_TOKEN` 시크릿 설정.

## 개발 환경 (이 PC / 집 PC 공통)

- repo clone 위치: `C:\Program Files (x86)\World of Warcraft\IberisRaidAuction\`
- 4개 클라이언트 `_<client>_\Interface\AddOns\IberisRaidAuction` 는 위 클론으로 **mklink /J 정션** 연결.
  - `_anniversary_`, `_classic_`, `_classic_era_`, `_retail_`
- 코드 수정 즉시 `/reload` 로 반영.
- 인증: `gh auth login` (HTTPS + GCM). Iberis6501 계정.

## 관련 프로젝트

- [`ElvUI_IberisUI`](../ElvUI_IberisUI/CLAUDE.md) — 같은 사용자/PC, 같은 배포 인프라. 다만 **별개 애드온/repo**, 의존 관계 없음.
