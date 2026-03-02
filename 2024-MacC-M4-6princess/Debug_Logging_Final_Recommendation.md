# Debug Logging Final Recommendation (개정)

작성일: 2026-03-03

## 목적
네가 원하는 로그 운영은 **"카메라만"이 아니라 앱 전체로 확장 가능한 구조**이다.
- 큰 영역(area) 분리: `camera`, `ui`, `network`, `storage`, `capture`
- 그 안의 세부 태그(tag) 분리: `layout`, `preview`, `api`, `cache` 등
- 코드 삭제 없이 제어: 설정 토글/필터로 로그의 CRUD(가치가 없는 로그 비활성화 포함)

---

## 결론
현재 니즈 기준으로 가장 적합한 기본안은 다음이다.

**`Apple OSLog/Logger`를 기본 채널로 사용하고, 그 위에 `AppLogger` 같은 공통 래퍼를 얇게 둔다.**

---

## 비교: 실무 관점 객관 요약

> 아래의 퍼센티지는 공개 통계가 아닌, 여러 iOS 팀/프로젝트 운영 패턴을 종합한 **실무 추정치(참고값)**이다.

### 1) Apple OSLog/Logger
- **채택 추정치:** 약 **75~90%**
- **장점**
  - 운영 체계와 완전 통합 (iOS 기본 로깅 파이프라인)
  - 별도 라이브러리 의존성 없이 바로 도입 가능
  - category/subsystem로 영역 분리(카메라/UI/네트워크 등) 쉬움
  - 콘솔/로그 조회 도구에서 안정적으로 필터링
  - 성능 부담이 낮고 배포 안정성 높음
- **단점**
  - 구조화 태그/메타데이터 활용은 라이브러리 대비 제한적
  - 로그 보관 정책/파일 로테이션은 별도 구현이 필요
  - 원격 집계/검색 플랫폼 연동은 추가 계층 필요

### 2) Swift Log (`apple/swift-log`) + 백엔드
- **채택 추정치:** 약 **10~25%**
- **장점**
  - API 표준화가 잘 되어 있어 모듈별 교체가 쉬움
  - 백엔드 변경이 쉬워 파일/원격 수집 확장성이 좋음
  - 메타데이터로 context(tag-like) 정보를 풍부하게 붙이기 유리
- **단점**
  - 초기 설정/부트스트랩 코드가 필요
  - 앱에서 추가 의존성 관리가 생김
  - 팀 전체 합의 없으면 도입 후 규칙이 흩어지기 쉬움

### 3) CocoaLumberjack
- **채택 추정치:** 약 **3~10%**
- **장점**
  - 파일 로테이션/보관 정책이 강함
  - 대량 로그 유지가 필요한 앱에서 사용성이 높음
  - 여러 출력 대상 동시 설정 가능
- **단점**
  - 라이브러리 의존성, 초기 셋업/운영 비용 큼
  - OSLog 중심 워크플로 대비 설정 복잡도 높음
  - 현재 iOS 네이티브 진단 체계와의 일관성 유지 비용 존재

### 4) 커스텀 로거(사내 구현)
- **채택 추정치:** 약 **2~8%**
- **장점**
  - 규격/포맷/저장방식/UI가 자유로움
  - 특정 상품 규칙(비즈니스 규칙) 반영이 가장 빠름
- **단점**
  - 스레드 안전성, 성능, 로그 누락 방지 등을 직접 구현해야 함
  - 운영 도구 연계가 약해 유지보수 비용 상승
  - 장기적으로 버그/회귀 리스크가 가장 큼

---

## 너의 니즈 기준 추천 점수(10점 만점, 정성)

### 핵심 니즈
- 영역 분리 + 태그 분리
- 설정 기반 CRUD(비활성화/활성화/필터)
- 다도메인 확장 용이
- 문서/운영 일관성

| 방식 | 영역/태그 표현력 | 설정 제어용이성 | 확장성 | 운영 안정성 | 학습/도입 비용 | 총평 |
|---|---:|---:|---:|---:|---:|---|
| OSLog + 공통 래퍼 | 9/10 | 8/10 | 8/10 | 9/10 | 7/10 | **최고 균형** |
| SwiftLog + 백엔드 | 9/10 | 8/10 | 10/10 | 8/10 | 5/10 | 확장형 2순위 |
| CocoaLumberjack | 8/10 | 7/10 | 9/10 | 7/10 | 4/10 | 보관 우선 프로젝트 3순위 |
| 커스텀 로거 | 10/10 | 10/10 | 9/10 | 4/10 | 2/10 | 특수요건만 4순위 |

---

## 결론(객관적)
- **지금 바로 도입**: OSLog/Logger + area/tag 래퍼가 가장 실무 안정성이 높고, 네 목표(영역/태그 + CRUD)에 가장 잘 맞는다.
- **나중 확장**: 로그를 원격 분석/집계로 뽑아야 할 때 `AppLogger` 내부에서 SwiftLog 백엔드로 확장.

---

## 실행 시 핵심(코드 예시 제외)
- 공통 로거 래퍼(한 곳)만 정의
- 모든 로그 호출을 `area + tag` 표준 형식으로 통일
- Runtime 설정으로 전역 ON/OFF, area 허용 목록, tag 허용 목록, 최소 level 제어
- 문서와 실제 호출 지점 동기화

## 문서/대상 경로
- 최종 제안 문서: `/Users/piri/shared/active/2024-MacC-M4-6princess/2024-MacC-M4-6princess/Debug_Logging_Final_Recommendation.md`
- 전략 가이드: `/Users/piri/shared/active/2024-MacC-M4-6princess/2024-MacC-M4-6princess/Debug_Logging_Strategy_Guide.md`
- 시작 코드: `/Users/piri/shared/active/2024-MacC-M4-6princess/2024-MacC-M4-6princess/Source/View/Camera/CameraView.swift`

## OSLog로 카메라 가로 미달 원인 추적(실무 체크리스트)

`OSLog/Logger`로 `camera/layout` 로그를 남길 때, **카메라가 가로를 꽉 채우지 않는 원인**을 좁히는 가장 빠른 방법.

### 1단계: 계산값 자체가 잘못되었는지 확인
`updateLayoutForCurrentBounds`에서 아래 값들을 찍어서 비교한다.
- `bounds.width` vs `previewContainerView.frame.size.width`
- `top/bottom` 실제 높이
- `previewTopOffset` (`overlapTopBar` 토글 여부)
- `requiredHeight = previewHeight + bottomHeight + (allowTopOverlap ? 0 : topHeight)`

이 값들로 판단:
- `preview.width != bounds.width`면 **constraint 적용 타이밍/호출 누락**이 의심됨.
- `requiredHeight > bounds.height`이면 상하 간섭(오버랩/투명 처리)이 실제 레이아웃 압축을 유발.

### 2단계: 제약 조건 확인
- `previewContainerView`가 `centerX` + `width` 제약만으로 넓이를 가짐.
- `width`는 `previewWidthConstraint`로 갱신됨.
- 갱신 직후 `layoutIfNeeded()`와 `previewContainerView.bounds` 기록이 함께 있어야 함.
- `preview` 레이어 자체는 `previewContainerView.bounds`를 그대로 받아야 하므로,
  `viewModel.preview?.frame` 값이 `previewContainerView.frame`과 다르면 레이어 적용 위치/크기 문제.

### 3단계: 화면 특성 관련 오탐지 구간 분리
- iPhone/짧은 화면/작은 폰에서 높이 계산이 압축을 일으키는지,
- iPad 분할/멀티태스크에서 `bounds.width` 자체가 기기 전체가 아닌 컨테이너 폭인지.
- 회전 전환 직후(특히 `viewDidLayoutSubviews`)에 로그 순서를 남겨서,
  회전 이벤트 이전/이후 프레임 값이 튀는지 확인.

### 4단계: 결론 도출
- `bounds.width`는 정상인데 실제 미표시인 경우 → 뷰 자체 배치(부모 컨테이너 safe-area/transform)가 의심.
- `bounds.width`가 줄어든 경우 → 현재 화면 컨텍스트(분할 화면, 모달/네비게이션 래핑) 영향이 큼.
- 로그에서 원인군이 명확하지 않으면 `camera/preview` 로그에 `device/userInterfaceIdiom + boundsHeight/width + isTall`를 추가해 원인 구분을 강화한다.

### 로그로 빠르게 묶어보는 의도
- 로그는 코드 변경 없이도 조건 판단이 가능해야 하므로, 위 4단계 값만 보고도
  "제약 실패인지(가로값 부족) / 오버랩 정책인지(높이 부족)/부모 컨텍스트 문제인지"를 구분 가능하다.
