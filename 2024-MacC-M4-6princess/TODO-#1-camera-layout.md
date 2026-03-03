# TODO: 카메라 레이아웃 Tall 기준 통일 (#1)

## 목표
- 아이폰/아이패드에서 카메라 Top/Bottom 분기 처리를 `height/width` Tall 기준 한 가닥으로 통일
- iPad에서 화면 짤림 이슈 재현/해결

## 작업 내용
- [x] `CameraTopView` 분기 제거 및 Tall 기반 공통 레이아웃 적용
- [x] `CameraBottomView` 분기 제거 및 Tall 기반 공통 레이아웃 적용
- [ ] `CameraView` 미리보기 크기 계산이 iPad/짧은 화면에서 안정적인지 추가 확인
- [ ] 실기기(iPad)에서 실제 오버랩/잘림 체크 및 필요 시 미세값 조정
- [ ] 빌드 및 스냅샷으로 동작 검증

## 비고
- `piriram/2024-MacC-M4-6princess`는 이슈 기능이 비활성화되어 있어 개인 브랜치 기준으로 작업 이력만 관리함
