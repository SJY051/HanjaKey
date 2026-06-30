<p align="center">
  <img src="docs/images/hanjakey-hero.png" width="720" alt="HanjaKey — 가벼운 macOS용 한글 → 한자·특수문자 변환기">
</p>

# HanjaKey

윈도우의 **한자 키**를 macOS에서도 쓰고 싶어 만든 메뉴바 앱입니다. 입력기를 따로 바꾸지 않아도,
전역 단축키 하나로 커서 앞의 한글을 그 자리에서 한자·특수문자로 바꿔 줍니다.

> English: [README.en.md](README.en.md)

<p align="center">
  <img src="docs/images/hanjakey-word.gif" width="480" alt="한자를 漢字로 변환하는 데모"><br>
  <sub>단어 인식 · 한자 → 漢字 (뜻과 빈도순으로)</sub>
</p>

<table align="center">
  <tr>
    <td align="center"><img src="docs/images/hanjakey-single.gif" width="300" alt="단일 한자 변환"><br><sub>단일 한자 · 가 → 歌</sub></td>
    <td align="center"><img src="docs/images/hanjakey-symbol.gif" width="300" alt="특수문자 변환"><br><sub>특수문자 · ㅁ → ♥</sub></td>
  </tr>
</table>

## 개요

macOS 한글 입력기에도 한자 변환(`Option+Return`)은 있지만, **자모로 특수문자를 넣는 길이 없고** 한글을
입력하는 중일 때만 동작합니다. HanjaKey는 입력 소스와 상관없이 어디서든 단축키로 불러서, 한자와
KS X 1001 특수문자를 한 창에서 고르고 그대로 끼워 넣습니다.

## 기능

- **음절 → 한자** : 한 → 韓 · 漢 · 寒 …
- **자모 → 특수문자** : ㅁ → ※ ◎ □ …, ㄷ → ± × ÷ …
- **단어 → 한자어** : 대한민국 → 大韓民國, 한자 → 漢字

한자와 한자어에는 각각 훈독 및 의미가 간략히 표기되어 있습니다.
특수문자는 Windows IME에서 사용하는 같은 KS X 1001의 특수문자 배열을 그대로 가져오며, 한자와 한자어는 자주 사용되는 문자들부터 빈도수에 따라 정렬됩니다.

## 작동 범위

- **사용 가능** : 네이티브 앱(TextEdit 등), Electron 앱(Claude·Discord 등), 브라우저 등 **대부분의 macOS 앱**
- **사용 불가능** : 터미널. 편집 가능한 접근성(AX) 텍스트를 내주지 않습니다.

## 사용법

1. 한글을 치고 커서를 바로 뒤에 둔 채 `⌥ + ⌘ + H`
   - 단어는 커서 앞 어절을 알아서 잡습니다. 직접 드래그해 둔 텍스트가 있으면 그걸 쓰고요.
2. 뜬 후보에서 고르기
   - `1–9` 선택 · `↑↓` `←→` 이동·페이지 · `Tab` 전체 펼치기 · `↵` 입력 · `esc` 취소
3. 사전에 없는 단어는 **‘음절별로 만들기’** 로 한 글자씩 골라 맞춥니다

설정은 메뉴바 **字** 아이콘이나 팝업의 **⋯ → 설정**에서 확장 보기(와이드·컴팩트 그리드), 특수문자
전각·반각, 사용자 정의 세트, 메뉴바 아이콘 표시를 바꿀 수 있습니다.

## 설치

**Homebrew (권장)** — 자체 tap으로 설치·업데이트가 가장 간단합니다:

```sh
brew install --cask SJY051/tap/hanjakey
```

이후 업데이트는 `brew upgrade --cask hanjakey`. (`HOMEBREW_REQUIRE_TAP_TRUST`를 켜둔 환경이라면 먼저 `brew trust SJY051/tap`을 실행하세요.)

**직접 다운로드** — [Releases](https://github.com/SJY051/HanjaKey/releases/latest)에서
`HanjaKey-vx.y.z.dmg`를 받아 열고, **HanjaKey를 응용 프로그램 폴더로 드래그**하세요. (실행: macOS 14 이상)

**처음 열 때** — 이 빌드는 **Apple 공증을 받았습니다** — Gatekeeper 경고 없이 바로 실행됩니다.

처음 실행 시 **접근성 권한**만 켜 주세요(시스템 설정 → 개인정보 보호 및 보안 → "손쉬운 사용"). 앱의 실제 기능에 필요하며, 한 번만 허용하면 됩니다.

> ℹ️ v0.1.2·v0.1.3(self-signed)에서 업데이트하는 경우, 서명 신원이 바뀌어 접근성 권한을 한 번 다시 허용해야 할 수 있어요.

**소스에서 빌드** — `scripts/bundle.sh` → `.build/HanjaKey.app`. 개발 환경·구조는
[CONTRIBUTING.md](CONTRIBUTING.md), 단축키는 [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)를 참고하세요.

## 데이터 / 출처

본 레포지토리의 소스는 MIT 라이선스이지만 **번들 데이터는 각 출처의 라이선스를 그대로 따릅니다**(MIT로 재라이선스하지 않습니다).
전체 목록과 전문은 [`THIRD_PARTY_DATA.md`](THIRD_PARTY_DATA.md)에 있습니다.

- **한자·한자어 표제어** — [libhangul](https://github.com/libhangul/libhangul) `hanja.txt` · BSD 3-Clause · ⓒ 2005,2006 Choe Hwanjin
- **특수문자** — KS X 1001 자모별 배열 (자체 작성)
- **한자어 빈도(동음어 정렬)** — 국립국어원 「현대 국어 사용 빈도 조사」(2002) · KOGL 제1유형(출처표시)
- **한자어 뜻풀이** — 국립국어원 표준국어대사전 · **CC BY-SA 2.0 KR**
- **단일 한자 훈음(보완)** — 한국어 위키낱말사전 · **CC BY-SA** / NeoMindStd [HanjaDB](https://github.com/NeoMindStd/HanjaDB) · MIT
- **단일 한자 정렬·훈음(생성)** — LLM으로 생성한 HanjaKey 자체 데이터 · MIT

> 표준국어대사전·위키낱말사전 데이터는 **CC BY-SA(동일조건변경허락)**, 국립국어원 빈도조사는
> **KOGL 제1유형(출처표시)** 조건으로 배포됩니다. 재배포할 때 위 출처 표시와 동일 라이선스 조건을 지켜 주세요.

## 기여

버그 제보와 PR 모두 환영합니다. 개발 환경·구조·컨벤션은 [CONTRIBUTING.md](CONTRIBUTING.md)에 정리해 뒀습니다.

## 라이선스

- 코드: [MIT](LICENSE)
- 번들 데이터: 출처별 라이선스 유지 : 자세한 내용은 [`THIRD_PARTY_DATA.md`](THIRD_PARTY_DATA.md).
  CC BY-SA·KOGL 데이터는 MIT 라이선스가 아닌 각자의 라이선스로 배포되며, 원 저작권·출처 고지를 데이터 파일에
  유지합니다.
