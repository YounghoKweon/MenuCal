<img width="268" height="536" alt="image" src="https://github.com/user-attachments/assets/f267c5b0-2025-4ea6-91b5-7c1164332736" />

# MenuCal

macOS 26이 메뉴막대 기본 시계의 커스텀 날짜 형식(`DateFormat`)을 무시하게 되면서 직접 만든 **메뉴막대 시계 / 달력 / 세계시계 앱**.

```
7/5(일)      ← 두 줄 모드 (한 줄 모드: 7/5(일) 14:23:45)
14:23:45
```

## 기능

- **커스텀 형식 시계** — Unicode 날짜 형식으로 자유롭게 (`M/d(E) HH:mm:ss` 등), 한 줄/두 줄 모드, 설정에서 실시간 미리보기, 매초 갱신 (초 경계 정렬, monospaced digit으로 폭 흔들림 없음)
- **월 달력** — 지난달/다음달 이동, 오늘 하이라이트, 일요일 빨강/토요일 파랑, 날짜 클릭 시 상세(공휴일 이름 + 일정)
- **한국 공휴일** — 하드코딩 없이 계산: 양력 고정일 + 한국 음력(`Calendar(.dangi)`, macOS 26+ API)으로 설날·부처님오신날·추석 산출 + 대체공휴일 규칙 적용. 2026·2027년 관보 목록과 대조 검증됨. (선거일·임시공휴일은 계산 불가라 미포함)
- **캘린더 이벤트(EventKit)** — 다가오는 이벤트 목록, 달력에 캘린더 색상 점, 이벤트 있으면 메뉴바 🔔 넛지(팝오버 열면 해제, 자정에 리셋). macOS에 연동된 Google 캘린더도 함께 표시
- **세계시계** — 한국어 주요 도시 프리셋 + 전체 tz database 검색, 날짜가 다르면 어제/내일 배지
- **로그인 시 자동 실행**(SMAppService), 독 아이콘 없는 액세서리 앱

## 요구사항

- macOS 26+ (`Calendar(.dangi)` API 의존)
- Xcode (Swift 6)

## 설치

```bash
./build.sh
```

release 빌드 → `.app` 번들 조립 → ad-hoc 코드사인 → `/Applications` 설치 → 실행까지 한 번에.

> ad-hoc 서명이라 재빌드하면 캘린더 권한을 다시 물어볼 수 있습니다.

## 디버그 CLI

```bash
swift build
.build/debug/MenuCal --print-holidays 2026   # 해당 연도 공휴일 계산 결과
.build/debug/MenuCal --print-title           # 현재 메뉴바 타이틀 문자열
```

## 팁: 기본 시계 최소화

macOS 26은 기본 시계 숨김을 OS 차원에서 막아둡니다(`NSStatusItem VisibleCC Clock` 키를 0으로 써도 ControlCenter가 시작 시 강제 복원). 대신 아날로그 스타일로 최소화할 수 있어요:

```bash
defaults write com.apple.menuextra.clock IsAnalog -bool true && killall ControlCenter
```

---

🤖 Built with [Claude Code](https://claude.com/claude-code)
