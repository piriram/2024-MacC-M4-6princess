# Debug Logging Strategy Guide / 디버그 로깅 전략 가이드 (2026-03-02)

작성자: 이리

## 1. 목적
- 카메라뷰 문제 해결을 위해 만든 로그가 아니라, **앱 전체 공통 로깅 구조**로 정착시키기.
- `영역(area)` + `태그(tag)` 기반으로 로그를 분리해 **원하는 부분만 쉽게 찾고 제어**할 수 있게 한다.
- 로그 CRUD(추가/조회/수정/비활성화)를 코드 삭제가 아닌 설정/포맷 정책으로 운영한다.

## 2. 당신의 니즈 정리(최우선)
1. **대규모 영역 분리**
   - 영역 단위로 큰 카테고리를 나눈다.
   - 예: `camera`, `ui`, `network`, `storage`, `capture`
2. **영역 내 태그 분리**
   - 같은 영역 안에서도 세부 목적별 태그로 분리한다.
   - 예: `camera.layout`, `camera.preview`, `ui.state`, `network.api`
3. **로그 CRUD의 편의성**
   - 로그는 원하면 **켜고/끄고/필터링**해서 운영.
   - 코드가 남아 있어도 키 설정 변경만으로 제어 가능하도록 설계.
4. **문서 기반 운영 일관성**
   - 절대 경로·설정 키·적용 예시를 문서로 고정해 다음 작업자가 재현 가능하게 한다.

> 주의: TestFlight에서 디버그 확인이 목적이 아니라, **로그 구조 설계** 자체(영역/태그/CRUD)가 우선인 니즈다.

## 3. 적용 원칙 (iOS 실무 기준)
1. OSLog/Logger를 기본으로 사용
- OSLog subsystem/category를 앱 식별자와 도메인으로 매핑
- 예: `com.2024-MacC-M4-6princess`(subsystem), `camera`/`ui`/`network`(category)

2. 공통 로거 래퍼 도입
- `AppDebugLogger`(새 파일)에서 공통 인터페이스 제공
- 호출부는 `AppLogger.log(area:tags:level:message:)`로 통일

3. 런타임 토글
- 하드코딩이 아닌 설정/런치 arg/환경변수로 제어
- 릴리즈/개발 플래그를 쉽게 분기

4. 민감정보 제외
- 좌표/장치 식별자/개인정보는 로그에서 직접 노출하지 않음
- 필요 시 마스킹 규칙을 함께 적용

## 4. 제안 키 설계 (런타임)
- `debug.log.enabled` (Bool)
- `debug.log.areas` (String/Set): 예) `camera,ui,network,capture`
- `debug.log.tags` (String/Set): 예) `layout,preview,zoom,capture,frame`
- `debug.log.level` (String): `debug|info|warning|error`
- `cameraLogProfile` (String): `none|layoutOnly|full|previewOnly`

## 5. 영역/태그 운영 예시
### 5.1 영역(area)
- `camera`, `ui`, `network`, `storage`, `capture`

### 5.2 태그(tag)
- `camera`: `layout`, `preview`, `zoom`, `frame`, `permission`
- `ui`: `state`, `routing`, `gesture`
- `network`: `api`, `retry`, `cache`

### 5.3 로그 호출 형태 예시
```swift
AppLogger.log(area: .camera, tags: [.layout, .preview], level: .debug, message: "preview 계산 완료")
AppLogger.log(area: .ui, tags: [.routing], level: .info, message: "이동 완료")
```

## 6. CRUD 운영 가이드
- **Create**: 새 로그 호출 추가
- **Read**: `log show`에서 `subsystem/category`와 메시지의 tag 값으로 조회
- **Update**: `debug.log.areas`, `debug.log.tags`, `debug.log.level` 변경으로 동작 조절
- **Delete**: 호출을 즉시 삭제하지 말고, area/tag 비활성화로 숨김 처리

## 7. 기존 코드 마이그레이션 가이드
1) `CameraLayoutDebugLog` → `AppLogger.camera(layout:preview:)` 형태로 치환
2) `updateLayoutForCurrentBounds()` 내 레이아웃 로그: area=`camera`, tags=`layout`
3) `updatePreviewContent()` 내 프리뷰 로그: area=`camera`, tags=`preview`
4) 향후 프레임/오버레이/캡처 로그는 태그 분해 후 동일 패턴 적용

## 8. 다음 단계
- `Source/Utils/AppDebugLogger.swift` 신규 파일 추가
- `CameraView.swift` 로그 포인트 표준화 교체
- 런타임 토글 키 래핑/설정 화면 반영
- 문서-코드 동기화

## 9. 절대 경로 참조
- 문서: `/Users/piri/shared/active/2024-MacC-M4-6princess/2024-MacC-M4-6princess/Debug_Logging_Strategy_Guide.md`
- 문서(한글명): `/Users/piri/shared/active/2024-MacC-M4-6princess/2024-MacC-M4-6princess/디버그_로깅_전략_가이드.md`
- 코드(카메라 시작점): `/Users/piri/shared/active/2024-MacC-M4-6princess/2024-MacC-M4-6princess/Source/View/Camera/CameraView.swift`
