# 기여하기

HanjaKey에 관심 가져 주셔서 고마워요. 버그 제보·기능 제안·PR 모두 환영합니다.
(English contributors: the commands below are language-agnostic; feel free to open issues/PRs in English.)

## 개발 환경

- **macOS 14+**, **Xcode 툴체인** (빌드·테스트의 XCTest용)
- 순수 SwiftPM 프로젝트입니다 (`.xcodeproj` 없음)

## 빌드 & 실행

```sh
swift test            # 유닛 테스트 (HanjaKitCore 엔진)
scripts/bundle.sh     # .build/HanjaKey.app 생성 → open 으로 실행
```

첫 실행 때 **접근성 권한**을 켜 줘야 커서 자리 치환이 동작합니다
(시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용).

## 구조

- `Sources/HanjaKitCore` — 순수 변환 엔진(한자·특수문자·단어 테이블, 어절 세그멘터). **유닛 테스트 대상.**
- `Sources/HanjaKey` — 메뉴바 앱(단축키, 팝업 UI, 접근성 기반 캡처·치환).
- `Sources/HanjaKitCore/Resources/data` — 번들 데이터(출처별 라이선스 유지).

## 컨벤션

- 코드·주석·커밋 메시지는 **영어**, [Conventional Commits](https://www.conventionalcommits.org)
  (`feat:`, `fix:`, `docs:`, `refactor:`, …).
- 엔진 로직을 바꾸면 가능하면 `HanjaKitCore`에 **유닛 테스트를 함께** 올려 주세요.
- 포매팅·네이밍은 **기존 코드 스타일**을 따라 주세요(4칸 들여쓰기).

## 데이터 기여

번들 데이터를 추가할 땐 **출처별 라이선스를 그대로 유지**하세요(프로젝트 MIT로 재라이선스 금지). 각
소스는 자체 디렉터리 + 라이선스 표기 + [`THIRD_PARTY_DATA.md`](THIRD_PARTY_DATA.md) 항목으로 관리하며,
CC BY-SA·KOGL 같은 copyleft/출처표시 데이터는 특히 그 조건을 지켜 주세요.

## PR

- 작은 단위로, **무엇을·왜** 바꿨는지 설명을 붙여 주세요.
- 올리기 전에 `swift test`가 통과하는지 확인해 주세요.
