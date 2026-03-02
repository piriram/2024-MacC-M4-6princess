import XCTest

final class SmokeLaunchUITests: XCTestCase {
    func testLaunchesApp() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testCameraLayoutParity_PreSnapKitRefactor() throws {
        let app = XCUIApplication()

        // 테스트 안정성 확보: 시뮬레이터에서는 샘플 카메라를 강제 사용
        // - 디바이스 카메라 권한 의존성/렌즈 선택 이슈를 줄임
        app.launchArguments += ["-debug.camera.source", "sample"]
        app.launchArguments += ["-openFirstTime", "true"]
        app.launch()

        let preview = app.otherElements["camera.preview"]
        let top = app.otherElements["camera.top"]
        let bottom = app.otherElements["camera.bottom"]
        let zoom = app.otherElements["camera.zoom"]

        XCTAssertTrue(preview.waitForExistence(timeout: 8), "카메라 미리보기 컨테이너 접근성 식별자(camera.preview)를 찾지 못했습니다.")

        // 앱이 카메라 뷰를 실제로 렌더링할 때까지 약간 더 대기
        Thread.sleep(forTimeInterval: 0.3)

        let window = app.windows.element(boundBy: 0).frame
        let p = preview.frame
        let t = top.frame
        let b = bottom.frame
        let z = zoom.frame

        let isTallScreen = (window.height / max(window.width, 1)) > 2.0

        // 1) 레이어 시작점 정렬
        XCTAssertLessThanOrEqual(abs(p.minY - t.maxY), 2.0, "preview top should align with top container bottom")
        XCTAssertGreaterThanOrEqual(p.minY, t.minY - 2.0)

        // 2) preview width: 화면 전체 폭 기준
        XCTAssertLessThanOrEqual(abs(p.width - window.width), 2.0, "preview width should match window width")

        // 3) bottom height/tall-screen 분기(시뮬레이터/상태바 이슈 반영)
        let expectedBottomRange: ClosedRange<CGFloat> = isTallScreen ? (45.0...130.0) : (45.0...80.0)
        XCTAssertTrue(expectedBottomRange.contains(b.height), "bottom height(\(b.height)) should be within expected range")

        // 4) zoom bar 위치
        XCTAssertLessThanOrEqual(abs(z.maxY - (b.minY - 20.0)), 2.0, "zoom should sit 20pt above bottom container")

        // 5) 프리뷰 비율은 카메라 정책(1:1, 3:4, 9:16) 중 하나여야 함
        let ratio = p.height / max(p.width, 1)
        let expectedRatios: [CGFloat] = [1.0, 4.0 / 3.0, 16.0 / 9.0]
        let matched = expectedRatios.contains { abs(ratio - $0) < 0.02 }
        XCTAssertTrue(matched, "Unexpected camera preview ratio: \(ratio)")

        // 6) 수집 로그(디버깅/리포팅용)
        let shortLog = "[CameraLayoutTest] isTall=\(isTallScreen) window=(\(window.width),\(window.height)) preview=(\(p.minX),\(p.minY),\(p.width),\(p.height)) ratio=\(String(format: "%.4f", ratio)) top=(\(t.minX),\(t.minY),\(t.width),\(t.height)) bottom=(\(b.minX),\(b.minY),\(b.width),\(b.height)) zoom=(\(z.minX),\(z.minY),\(z.width),\(z.height))"
        print(shortLog)

        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        // P0 회귀 기준: preview는 전체 뷰 계층 안에서 유의미한 위치여야 함
        XCTAssertGreaterThan(p.maxY, t.minY, "preview should have positive height")

        if isPad {
            // iPad는 iPhone과 다른 오버레이/바 높이 규칙이 적용될 수 있어 완화 검사
            XCTAssertLessThanOrEqual(p.maxY, window.height + 10.0, "preview bottom should stay within device bounds")
            XCTAssertLessThanOrEqual(abs(z.maxY - (b.minY - 20.0)), 40.0, "zoom should be around 20pt above bottom container")
            XCTAssertGreaterThan(z.minY, p.minY, "zoom should be below preview")
        } else {
            XCTAssertLessThanOrEqual(p.maxY, b.minY + 2.0, "preview bottom should be above or near bottom container top")
            XCTAssertLessThanOrEqual(abs(z.maxY - (b.minY - 20.0)), 2.0, "zoom should sit 20pt above bottom container")
        }
    }
}
