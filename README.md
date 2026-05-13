# IberisRaidAuction

WoW 공격대 GDKP 골드 분배 장부 애드온. 직관적 단일 창 + 인라인 편집 + 자동 전리품 캡처 + 거래 자동 등록 + 정산 보고서.

대상 클라이언트: Anniversary (1.15.x) / TBC / Wrath / Mists / Mainline.

## 기반 / 라이센스

이 애드온은 **[RaidLedger](https://github.com/tg123/RaidLedger) by tg123** (Apache License 2.0) 의 fork 입니다. 한국 커뮤니티 변형 **RaidLedgerBR** 의 UX 패턴 일부를 차용했습니다.

라이센스 조항은 [`LICENSE`](LICENSE) (Apache 2.0) 그대로 유지되며, 본 fork 의 변경 사항은 [`NOTICE`](NOTICE) 에 명시되어 있습니다.

## 사용법

```
/ira          장부 창 열기/닫기
/ira new      새 장부 시작
/ira help     전체 명령 목록
```

상세 명령은 인게임 `/ira help` 또는 옵션 패널 참고.

## 작업 내역 / Changelog

### v0.2 (2026-05-13)
- RaidLedger 기반 fork 로 재구성
- namespace / 슬래시 (/ira) / SavedVariables (IberisRaidAuctionGlobalConfig, IberisRaidAuctionDatabase) rebrand
- 파일 prefix `IRA*` 적용 (RaidBook 패턴)
- LICENSE Apache 2.0 + NOTICE 추가

### v0.1 (이전)
- 자체 골격 (단일 위젯/탭 분리 장부) — v0.2 에서 폐기
