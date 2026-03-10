//
//  CameraView.swift
//  2024-MacC-M4-6princess
//
//  Created by 김이예은 on 9/30/24.
//

import SwiftUI
import AVFoundation
import CoreData
import FirebaseAnalytics
import UIKit
import Combine
import os
import SnapKit

struct CameraView: View {
    @Environment(\.managedObjectContext) var viewContext
    @EnvironmentObject var naviManager: NavigationManager
    @EnvironmentObject var frameManager: FrameManager
    @EnvironmentObject var imageModel: ImageListModel
    @StateObject var viewModel = CameraViewModel()
    @StateObject var motionManager = MotionManager()

    private var resultNavigationBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.captureState == .readyToNavigate &&
                viewModel.routeToResult
            },
            set: { isPresented in
                if !isPresented {
                    print("[CameraNavigation] destination dismissed")
                    viewModel.finishResultNavigation()
                }
            }
        )
    }

    var body: some View {
        CameraUIKitContainerView(
            viewModel: viewModel,
            motionManager: motionManager,
            naviManager: naviManager,
            frameManager: frameManager,
            imageModel: imageModel,
            viewContext: viewContext
        )
        .overlay {
            if viewModel.delayTime != 0 && viewModel.isTakePic {
                CameraTimerSecondsView(viewModel: viewModel)
                    .ignoresSafeArea(.all, edges: .all)
            }
        }
        .onChange(of: frameManager.isFrameLoading) { _, newValue in
            if newValue {
                frameManager.isFrameLoading = false
            }
        }
        .alert("세로 고정 권장", isPresented: $viewModel.showOrientationAlert) {
            Button("확인") { }
        } message: {
            Text("이 앱은 세로 화면에서 더 좋은 경험을 제공합니다.\n세로 화면 고정을 활성화해주세요.")
        }
        .persistentSystemOverlays(.hidden)
        .statusBar(hidden: true)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: resultNavigationBinding) {
            if let takenImg = viewModel.takenImg,
               let frameImg = viewModel.capturedFrameImage ?? frameManager.resultImage {
                IOView(bg: takenImg, idol: frameImg, motionManager: motionManager)
                    .onAppear {
                        print("[CameraNavigation] push IOView success")
                        viewModel.beginResultNavigation()
                    }
            } else {
                EmptyView()
                    .onAppear {
                        print("[CameraNavigation] fallback branch entered. takenImgExists=\(viewModel.takenImg != nil), capturedFrameExists=\(viewModel.capturedFrameImage != nil), frameManagerExists=\(frameManager.resultImage != nil)")
                        viewModel.beginResultNavigation()
                        viewModel.errorMessage = "프레임이 없습니다. 다시 촬영해주세요."
                        viewModel.showErrorAlert = true
                        viewModel.finishResultNavigation()
                    }
            }
        }
        .alert(isPresented: $viewModel.showErrorAlert) {
            Alert(title: Text("오류 발생"), message: Text(viewModel.errorMessage), dismissButton: .default(Text("확인")))
        }
        .onAppear {
            motionManager.startDeviceMotionUpdates()
            if isActuallyiPad() {
                viewModel.showOrientationAlert = true
            }
            viewModel.refreshRuntimeDependencies()
            viewModel.resetCaptureState()
            viewModel.checkVideoAuthorization()
            viewModel.isTakePic = false
            Analytics.logEvent("A1_카메라", parameters: nil)
        }
        .onDisappear {
            motionManager.stopDeviceMotionUpdates()
            viewModel.cancelCaptureIfNeeded(showCancellationError: false)
            viewModel.stopCameraSession()
        }
    }

    func isActuallyiPad() -> Bool {
        let size = UIScreen.main.bounds.size
        let longerSide = max(size.width, size.height)
        return longerSide > 1000
    }
}

private struct CameraUIKitContainerView: UIViewControllerRepresentable {
    let viewModel: CameraViewModel
    let motionManager: MotionManager
    let naviManager: NavigationManager
    let frameManager: FrameManager
    let imageModel: ImageListModel
    let viewContext: NSManagedObjectContext

    func makeUIViewController(context: Context) -> CameraUIKitViewController {
        CameraUIKitViewController(
            viewModel: viewModel,
            motionManager: motionManager,
            naviManager: naviManager,
            frameManager: frameManager,
            imageModel: imageModel,
            viewContext: viewContext
        )
    }

    func updateUIViewController(_ uiViewController: CameraUIKitViewController, context: Context) {
        uiViewController.updateDependencies(
            viewModel: viewModel,
            motionManager: motionManager,
            naviManager: naviManager,
            frameManager: frameManager,
            imageModel: imageModel,
            viewContext: viewContext
        )
    }
}

private enum CameraLayoutDebugLog {
    private static let forcedOnByArg = ProcessInfo.processInfo.arguments.contains("-cameraDebugLayout")
    private static let forcedOnByLaunchArg = ProcessInfo.processInfo.environment["CAMERA_LAYOUT_LOG"] == "1"
    static var isEnabled: Bool {
#if DEBUG
        return true
#else
        if let explicit = UserDefaults.standard.object(forKey: "debug.camera.layout.logging") as? NSNumber {
            return explicit.boolValue
        }
        if forcedOnByArg || forcedOnByLaunchArg {
            return true
        }
        return true
#endif
    }

    static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let log = Logger(subsystem: "2024-MacC-M4-6princess", category: "CameraLayout")
        let content = message()
        log.debug("\(content, privacy: .public)")
    }
}

private final class CameraUIKitViewController: UIViewController, UIGestureRecognizerDelegate {
    private enum ZoomOption: Double {
        case ultraWide = 1.0
        case wide = 2.0
        case telephoto = 3.0
        case maxZoom = 4.0

        func displayText(for position: AVCaptureDevice.Position, currentZoom: CGFloat, isUltraWide: Bool) -> String {
            if position == .back {
                if isUltraWide {
                    switch currentZoom {
                    case 1.0..<1.9: return ".5"
                    case 1.9..<2.9: return "1"
                    case 2.9..<3.9: return "2"
                    default: return "3"
                    }
                } else {
                    switch currentZoom {
                    case 1.0..<1.9: return "1"
                    case 1.9..<2.9: return "2"
                    default: return "3"
                    }
                }
            } else {
                switch self {
                case .ultraWide: return "1"
                case .wide: return "2"
                case .telephoto, .maxZoom: return "3"
                }
            }
        }

        func zoomFactor(for position: AVCaptureDevice.Position) -> CGFloat {
            if position == .back {
                switch self {
                case .ultraWide: return 1.0
                case .wide: return 2.0
                case .telephoto: return 3.0
                case .maxZoom: return 4.0
                }
            } else {
                switch self {
                case .ultraWide: return 1.0
                case .wide: return 2.0
                case .telephoto, .maxZoom: return 3.0
                }
            }
        }

        var tag: Int {
            Int(rawValue * 10)
        }
    }

    private var viewModel: CameraViewModel
    private var motionManager: MotionManager
    private var naviManager: NavigationManager
    private var frameManager: FrameManager
    private var imageModel: ImageListModel
    private var viewContext: NSManagedObjectContext

    private let previewContainerView = UIView()
    private let sampleImageView = UIImageView()
    private let topContainerView = UIView()
    private let zoomContainerView = UIView()
    private let bottomContainerView = UIView()

    private let timerControlView = CameraTimerControlView()
    private let cameraSwitchButton = UIButton(type: .custom)
#if DEBUG
    private let debugButton = UIButton(type: .system)
#endif

    private let zoomBackgroundView = UIView()
    private let zoomStackView = UIStackView()

    private let bottomOverlayView = UIView()
    private let topContainerHeight: CGFloat = 46
    private let shutterButtonSize: CGFloat = 80
    private let shutterTopOverflow: CGFloat = 4 // 바텀바 상단 위로 올라오는 값
    private let shutterBottomPaddingTall: CGFloat = 35
    private let shutterBottomPaddingCompact: CGFloat = 12
    private let newFrameButton = UIButton(type: .custom)
    private let newFrameIconView = UIImageView()
    private let newFrameLabel = UILabel()

    private let filterHostView = UIView()
    private var filterCollectionController: FilterCollectionViewController?
    private var filterCollectionSignature: [String] = []

    private var filterOverlayHostingController: UIHostingController<AnyView>?

    private var previewHeightConstraint: Constraint?
    private var previewWidthConstraint: Constraint?
    private var previewBottomConstraint: Constraint?
    private var bottomHeightConstraint: Constraint?
    private var bottomOverlayTopInsetConstraint: Constraint?

    private var newFrameButtonWidthConstraint: Constraint?
    private var newFrameButtonHeightConstraint: Constraint?
    private var newFrameIconWidthConstraint: Constraint?
    private var newFrameIconHeightConstraint: Constraint?

    private var isTallScreenLayout = true

    private var cancellables = Set<AnyCancellable>()
    private var contextSaveObserver: NSObjectProtocol?

    private var zoomButtons: [Int: UIButton] = [:]
    private var currentZoomOptions: [ZoomOption] = []

    private lazy var hitTestProbeTapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleHitTestProbeTap(_:)))
        gesture.cancelsTouchesInView = false
        gesture.delegate = self
        return gesture
    }()

    init(
        viewModel: CameraViewModel,
        motionManager: MotionManager,
        naviManager: NavigationManager,
        frameManager: FrameManager,
        imageModel: ImageListModel,
        viewContext: NSManagedObjectContext
    ) {
        self.viewModel = viewModel
        self.motionManager = motionManager
        self.naviManager = naviManager
        self.frameManager = frameManager
        self.imageModel = imageModel
        self.viewContext = viewContext
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let contextSaveObserver {
            NotificationCenter.default.removeObserver(contextSaveObserver)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupLayout()
        bindState()

        // 첫 레이아웃은 viewDidLayoutSubviews에서 처리하여 초기 임시 frame 오차로 인한 오탐을 방지
        updateFilterOverlay()
        timerControlView.update(delayTime: viewModel.delayTime)
        rebuildZoomButtonsIfNeeded(force: true)
        updateZoomButtonsAppearance(animated: false)
        setupFilterCollectionControllerIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.startCameraSession()
        refreshFilterCollectionController(forceReload: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopCameraSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateLayoutForCurrentBounds()
        updatePreviewContent()
    }

    func updateDependencies(
        viewModel: CameraViewModel,
        motionManager: MotionManager,
        naviManager: NavigationManager,
        frameManager: FrameManager,
        imageModel: ImageListModel,
        viewContext: NSManagedObjectContext
    ) {
        self.viewModel = viewModel
        self.motionManager = motionManager
        self.naviManager = naviManager
        self.frameManager = frameManager
        self.imageModel = imageModel
        self.viewContext = viewContext

        timerControlView.update(delayTime: viewModel.delayTime)
        refreshFilterCollectionController(forceReload: false)
        rebuildZoomButtonsIfNeeded(force: true)
        updateZoomButtonsAppearance(animated: false)
        updateLayoutForCurrentBounds()
        updatePreviewContent()
        updateFilterOverlay()
    }

    private func setupViews() {
        view.backgroundColor = .clear

        previewContainerView.clipsToBounds = true
        sampleImageView.contentMode = .scaleAspectFill
        sampleImageView.clipsToBounds = true

        previewContainerView.addSubview(sampleImageView)
        previewContainerView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:))))

        topContainerView.backgroundColor = .white
        bottomContainerView.backgroundColor = .white
        zoomContainerView.backgroundColor = .clear

        view.addSubview(previewContainerView)
        view.addSubview(topContainerView)
        view.addSubview(zoomContainerView)
        view.addSubview(bottomContainerView)

        previewContainerView.accessibilityIdentifier = "camera.preview"
        topContainerView.accessibilityIdentifier = "camera.top"
        zoomContainerView.accessibilityIdentifier = "camera.zoom"
        bottomContainerView.accessibilityIdentifier = "camera.bottom"

        previewContainerView.isAccessibilityElement = true
        topContainerView.isAccessibilityElement = true
        zoomContainerView.isAccessibilityElement = true
        bottomContainerView.isAccessibilityElement = true

        view.addGestureRecognizer(hitTestProbeTapGesture)

        sampleImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        setupTopControls()
        setupZoomControls()
        setupBottomControls()
        observeCoreDataChanges()
    }

    private func setupTopControls() {
        timerControlView.onDelaySelected = { [weak self] delayTime in
            self?.viewModel.delayTime = delayTime
        }

        cameraSwitchButton.setImage(UIImage(named: "cameraReverseIcon"), for: .normal)
        cameraSwitchButton.imageView?.contentMode = .scaleAspectFit
        cameraSwitchButton.addTarget(self, action: #selector(handleCameraSwitchTapped), for: .touchUpInside)

#if DEBUG
        debugButton.setImage(UIImage(systemName: "ladybug"), for: .normal)
        debugButton.tintColor = .black
        debugButton.addTarget(self, action: #selector(handleDebugTapped), for: .touchUpInside)
#endif

        topContainerView.addSubview(timerControlView)
        topContainerView.addSubview(cameraSwitchButton)
#if DEBUG
        topContainerView.addSubview(debugButton)
#endif

        cameraSwitchButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
#if DEBUG
            make.trailing.equalTo(debugButton.snp.leading).offset(-16)
#else
            make.trailing.equalToSuperview().offset(-20)
#endif
        }

#if DEBUG
        debugButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-16)
            make.width.height.equalTo(24)
        }
#endif

        timerControlView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(cameraSwitchButton.snp.leading).offset(-5)
            make.height.equalTo(30)
        }
    }

    private func setupZoomControls() {
        zoomBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        zoomBackgroundView.layer.cornerRadius = 19
        zoomBackgroundView.clipsToBounds = true

        zoomStackView.axis = .horizontal
        zoomStackView.alignment = .center
        zoomStackView.distribution = .fill
        zoomStackView.spacing = 14

        zoomContainerView.addSubview(zoomBackgroundView)
        zoomBackgroundView.addSubview(zoomStackView)

        zoomBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(40)
        }

        zoomStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(11)
            make.centerY.equalToSuperview()
            make.height.equalTo(30)
        }
    }

    private func setupBottomControls() {
        bottomOverlayView.backgroundColor = .white
        filterHostView.backgroundColor = .clear

        newFrameIconView.image = UIImage(named: "newFrameIcon")
        newFrameIconView.contentMode = .scaleAspectFit

        newFrameLabel.text = "새 프레임"
        newFrameLabel.textColor = .black
        newFrameLabel.font = .systemFont(ofSize: 12)
        newFrameLabel.numberOfLines = 2
        newFrameLabel.textAlignment = .center
        newFrameLabel.adjustsFontSizeToFitWidth = true
        newFrameLabel.minimumScaleFactor = 0.7

        let newFrameStack = UIStackView(arrangedSubviews: [newFrameIconView, newFrameLabel])
        newFrameStack.axis = .vertical
        newFrameStack.alignment = .center
        newFrameStack.spacing = 4

        newFrameButton.addTarget(self, action: #selector(handleNewFrameTapped), for: .touchUpInside)
        newFrameButton.addTarget(self, action: #selector(handleNewFrameTouchDown), for: .touchDown)
        newFrameButton.addSubview(newFrameStack)

        bottomContainerView.addSubview(bottomOverlayView)
        bottomOverlayView.addSubview(filterHostView)
        bottomOverlayView.addSubview(newFrameButton)

        bottomOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        filterHostView.snp.makeConstraints { make in
            bottomOverlayTopInsetConstraint = make.top.equalToSuperview().offset(20).constraint
            make.leading.trailing.bottom.equalToSuperview()
        }

        newFrameButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalTo(filterHostView.snp.centerY)
            newFrameButtonWidthConstraint = make.width.equalTo(70).constraint
            newFrameButtonHeightConstraint = make.height.equalTo(80).constraint
        }

        newFrameStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        newFrameIconView.snp.makeConstraints { make in
            newFrameIconWidthConstraint = make.width.equalTo(50).constraint
            newFrameIconHeightConstraint = make.height.equalTo(50).constraint
        }

        let shadowColor = UIColor.white.cgColor
        newFrameIconView.layer.shadowColor = shadowColor
        newFrameIconView.layer.shadowOpacity = 1
        newFrameIconView.layer.shadowRadius = 10
        newFrameIconView.layer.shadowOffset = CGSize(width: 20, height: 0)
    }

    private func bottomBarHeight(isTallScreen: Bool) -> CGFloat {
        let bottomPadding = isTallScreen ? shutterBottomPaddingTall : shutterBottomPaddingCompact
        return shutterButtonSize - shutterTopOverflow + bottomPadding
    }

    private func setupLayout() {
        topContainerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(topContainerHeight)
        }

        bottomContainerView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            bottomHeightConstraint = make.height.equalTo(bottomBarHeight(isTallScreen: true)).constraint
        }

        zoomContainerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(bottomContainerView.snp.top).offset(-20)
        }

        previewContainerView.snp.makeConstraints { make in
            previewBottomConstraint = make.bottom.equalTo(bottomContainerView.snp.top).constraint
            make.centerX.equalToSuperview()
            previewWidthConstraint = make.width.equalToSuperview().constraint
            previewHeightConstraint = make.height.equalTo(0).constraint
        }
    }

    private func bindState() {
        viewModel.$isUsingSampleCamera
            .combineLatest(viewModel.$samplePreviewImage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.updatePreviewContent()
            }
            .store(in: &cancellables)

        viewModel.$preview
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePreviewContent()
            }
            .store(in: &cancellables)

        viewModel.$frameRatio
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateLayoutForCurrentBounds()
            }
            .store(in: &cancellables)

        viewModel.$delayTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] delayTime in
                self?.timerControlView.update(delayTime: delayTime)
            }
            .store(in: &cancellables)

        viewModel.$currentZoomFactor
            .combineLatest(viewModel.$cameraPosition)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.rebuildZoomButtonsIfNeeded(force: false)
                self?.updateZoomButtonsAppearance(animated: true)
            }
            .store(in: &cancellables)

        frameManager.$selectedFrame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedFrameID in
                guard let self else { return }
                self.updateFilterOverlay()
                self.syncFilterSelection(selectedFrameID)
                if selectedFrameID != nil, self.frameManager.resultImage == nil {
                    self.loadSelectedFrameFromCoreDataIfNeeded()
                }
            }
            .store(in: &cancellables)

        motionManager.$currentOrientation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] orientation in
                self?.updateIconRotation(for: orientation)
            }
            .store(in: &cancellables)
    }

    private func observeCoreDataChanges() {
        contextSaveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshFilterCollectionController(forceReload: false)
        }
    }

    private func updateLayoutForCurrentBounds() {
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let ratio = max(viewModel.frameRatio, 0.01)
        let isTallScreen = bounds.height / bounds.width > 2.0
        isTallScreenLayout = isTallScreen

        // [iPhone 기준] SnapKit 레이아웃 정합 규칙
        // 1) top: 46pt
        // 2) preview: 화면폭 전체를 기본으로 하되, 화면 세로 여백을 넘지 않도록 안전하게 축소
        // 3) bottom: 셔터(80) + 상/하 패딩 기반 높이(상단 4pt 오버랩 정책 반영)
        // 4) zoom: bottom top - 20pt
        let effectiveTall = isTallScreen

        let bottomHeight: CGFloat = bottomBarHeight(isTallScreen: effectiveTall)
        let availablePreviewHeight = max(0, bounds.height - topContainerHeight - bottomHeight)
        let previewHeightFromWidth = bounds.width * ratio
        let previewHeight = min(previewHeightFromWidth, availablePreviewHeight)
        let previewWidth: CGFloat = ratio > 0 ? previewHeight / ratio : bounds.width
        let filterTopInset: CGFloat = effectiveTall ? 20 : 0
        let requiredHeight = previewHeight + bottomHeight + topContainerHeight
        let needsTopTransparent = requiredHeight > bounds.height
        applyTopBarBackground(isTransparent: needsTopTransparent)

        previewWidthConstraint?.update(offset: previewWidth)
        previewHeightConstraint?.update(offset: previewHeight)
        previewBottomConstraint?.update(offset: 0)
        bottomHeightConstraint?.update(offset: bottomHeight)
        bottomOverlayTopInsetConstraint?.update(offset: filterTopInset)

        newFrameButtonWidthConstraint?.update(offset: effectiveTall ? 70 : 56)
        newFrameButtonHeightConstraint?.update(offset: effectiveTall ? 80 : 56)
        newFrameIconWidthConstraint?.update(offset: effectiveTall ? 50 : 40)
        newFrameIconHeightConstraint?.update(offset: effectiveTall ? 50 : 40)
        newFrameIconView.layer.shadowOpacity = effectiveTall ? 1 : 0
        newFrameLabel.isHidden = !effectiveTall

        // 셔터 세로 배치 옵션
        // - topOverflow: 셔터 top이 바텀바(top)보다 4pt 위
        // - centerY: 필터 영역의 centerY에 정렬
        let shutterVerticalPlacement = RuntimeTestingOptions.shutterVerticalPlacement()
        let shutterVerticalOffset: CGFloat
        switch shutterVerticalPlacement {
        case .topOverflow:
            let desiredShutterCenterYFromBottomTop = (-shutterTopOverflow) + (shutterButtonSize / 2)
            let currentShutterCenterYFromBottomTop = (bottomHeight + filterTopInset) / 2
            shutterVerticalOffset = desiredShutterCenterYFromBottomTop - currentShutterCenterYFromBottomTop
        case .centerY:
            shutterVerticalOffset = 0
        }
        filterCollectionController?.setShutterVerticalOffset(shutterVerticalOffset)

        let newFrameSize = CGSize(width: previewWidth, height: previewHeight)
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.frameSize.size = newFrameSize
        }
        previewContainerView.layoutIfNeeded()
        viewModel.preview?.frame = previewContainerView.bounds

        updateIconRotation(for: motionManager.currentOrientation)

        CameraLayoutDebugLog.log("[CameraLayout] bounds=(\(bounds.width),\(bounds.height)) isTall=\(isTallScreen) ratio=\(String(format: "%.4f", ratio))")
        CameraLayoutDebugLog.log("[CameraLayout] topH=\(topContainerView.frame.height) bottomH=\(bottomContainerView.frame.height) zoomBottom=\(zoomContainerView.frame.maxY) bottomTop=\(bottomContainerView.frame.minY)")
        CameraLayoutDebugLog.log("[CameraLayout] previewBottomAligned=true")
        CameraLayoutDebugLog.log("[CameraLayout] preview=(\(previewContainerView.frame.origin.x),\(previewContainerView.frame.origin.y),\(previewContainerView.frame.size.width),\(previewContainerView.frame.size.height))")
        CameraLayoutDebugLog.log("[CameraLayout] shutterVerticalPlacement=\(shutterVerticalPlacement.rawValue) offset=\(shutterVerticalOffset)")
        CameraLayoutDebugLog.log("[CameraLayout] frameSize=(\(viewModel.frameSize.size.width),\(viewModel.frameSize.size.height))")
    }

    private func updatePreviewContent() {
        if viewModel.isUsingSampleCamera, let sample = viewModel.samplePreviewImage {
            sampleImageView.image = sample
            sampleImageView.isHidden = false
            viewModel.preview?.removeFromSuperlayer()
            return
        }

        sampleImageView.isHidden = true

        if viewModel.preview == nil || viewModel.preview.session !== viewModel.previewSession {
            viewModel.preview = AVCaptureVideoPreviewLayer(session: viewModel.previewSession)
            viewModel.preview.videoGravity = CameraDisplayPolicyStore.current.previewMode.videoGravity
        }

        // 미리보기는 가로 채움 우선
        viewModel.preview?.videoGravity = .resizeAspectFill

        guard let previewLayer = viewModel.preview else { return }

        CameraLayoutDebugLog.log("[CameraPreview] sessionId=\(ObjectIdentifier(previewLayer).hashValue), isSample=\(viewModel.isUsingSampleCamera)")

        previewContainerView.layoutIfNeeded()

        let previewBounds = previewContainerView.bounds
        CameraLayoutDebugLog.log("[CameraLayout] updatePreviewContent: frame=(\(previewContainerView.frame.origin.x),\(previewContainerView.frame.origin.y),\(previewContainerView.frame.size.width),\(previewContainerView.frame.size.height))")
        guard previewBounds.width > 1, previewBounds.height > 1 else { return }

        if previewLayer.superlayer !== previewContainerView.layer {
            previewLayer.removeFromSuperlayer()
            previewContainerView.layer.insertSublayer(previewLayer, at: 0)
        }
        previewLayer.frame = previewBounds
    }


    private func applyTopBarBackground(isTransparent: Bool) {
        topContainerView.backgroundColor = isTransparent ? UIColor.clear : UIColor.white
    }

    private func updateFilterOverlay() {
        guard let selectedFilterID = frameManager.selectedFrame else {
            if let filterOverlayHostingController {
                removeEmbedded(filterOverlayHostingController)
                self.filterOverlayHostingController = nil
            }
            return
        }

        let overlayView = AnyView(
            FilteredCoreDataImageView(filterID: selectedFilterID)
                .environment(\.managedObjectContext, viewContext)
                .allowsHitTesting(false)
        )

        if let filterOverlayHostingController {
            filterOverlayHostingController.rootView = overlayView
            return
        }

        let controller = UIHostingController(rootView: overlayView)
        controller.view.backgroundColor = .clear
        embed(controller, in: previewContainerView)
        previewContainerView.bringSubviewToFront(sampleImageView)
        previewContainerView.bringSubviewToFront(controller.view)
        filterOverlayHostingController = controller
    }

    private func availableZoomOptions() -> [ZoomOption] {
        let isUltraWide = viewModel.activeDeviceType == .builtInUltraWideCamera
        let isBackCamera = viewModel.cameraPosition == .back

        if isBackCamera {
            return isUltraWide ? [.ultraWide, .wide, .telephoto, .maxZoom] : [.wide, .telephoto, .maxZoom]
        } else {
            return [.ultraWide, .wide, .telephoto]
        }
    }

    private func isZoomSelected(option: ZoomOption, currentZoom: CGFloat) -> Bool {
        let isUltraWide = viewModel.activeDeviceType == .builtInUltraWideCamera

        if viewModel.cameraPosition == .back {
            if isUltraWide {
                switch option {
                case .ultraWide: return currentZoom >= 1.0 && currentZoom < 1.9
                case .wide: return currentZoom >= 1.9 && currentZoom < 2.9
                case .telephoto: return currentZoom >= 2.9 && currentZoom < 3.9
                case .maxZoom: return currentZoom >= 3.9
                }
            } else {
                switch option {
                case .wide: return currentZoom >= 1.0 && currentZoom < 1.9
                case .telephoto: return currentZoom >= 1.9 && currentZoom < 2.9
                case .maxZoom: return currentZoom >= 2.9
                case .ultraWide: return false
                }
            }
        } else {
            return currentZoom == option.rawValue
        }
    }

    private func rebuildZoomButtonsIfNeeded(force: Bool) {
        let options = availableZoomOptions()
        guard force || options != currentZoomOptions else { return }

        currentZoomOptions = options
        zoomButtons.removeAll()

        zoomStackView.arrangedSubviews.forEach {
            zoomStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        options.forEach { option in
            let button = UIButton(type: .system)
            button.tag = option.tag
            button.tintColor = .white
            button.titleLabel?.textAlignment = .center
            button.layer.masksToBounds = true
            button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            button.addTarget(self, action: #selector(handleZoomButtonTapped(_:)), for: .touchUpInside)

            button.snp.makeConstraints { make in
                make.width.height.equalTo(24)
            }

            zoomStackView.addArrangedSubview(button)
            zoomButtons[option.tag] = button
        }
    }

    private func updateZoomButtonsAppearance(animated: Bool) {
        let updates = { [self] in
            for option in currentZoomOptions {
                guard let button = zoomButtons[option.tag] else { continue }

                let selected = isZoomSelected(option: option, currentZoom: viewModel.currentZoomFactor)
                let text = option.displayText(
                    for: viewModel.cameraPosition,
                    currentZoom: selected ? viewModel.currentZoomFactor : option.zoomFactor(for: viewModel.cameraPosition),
                    isUltraWide: viewModel.activeDeviceType == .builtInUltraWideCamera
                )

                button.setTitle(selected ? "\(text)x" : text, for: .normal)
                button.setTitleColor(selected ? .yellow : .white, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: selected ? 13 : 12, weight: selected ? .semibold : .regular)

                let targetSize: CGFloat = selected ? 30 : 24
                button.layer.cornerRadius = targetSize / 2
                button.snp.remakeConstraints { make in
                    make.width.height.equalTo(targetSize)
                }
            }
            zoomStackView.layoutIfNeeded()
            zoomBackgroundView.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                updates()
            }
        } else {
            updates()
        }
    }

    private func setupFilterCollectionControllerIfNeeded() {
        if frameManager.selectedFrame != nil, frameManager.resultImage == nil {
            loadSelectedFrameFromCoreDataIfNeeded()
        }

        let filters = fetchFilterImages()
        let controller = FilterCollectionViewController(
            filterImages: filters,
            selectedFilter: { [weak self] uuid in
                self?.applySelectedFilter(uuid: uuid)
            },
            initialFilter: frameManager.selectedFrame,
            viewModel: viewModel,
            frameManager: frameManager
        )

        embed(controller, in: filterHostView)
        controller.loadViewIfNeeded()
        controller.currentSelectedFilter = frameManager.selectedFrame
        controller.scrollToSelectedFilter(animated: false)

        filterCollectionController = controller
        filterCollectionSignature = makeFilterSignature(filters)
    }

    private func refreshFilterCollectionController(forceReload: Bool) {
        guard let controller = filterCollectionController else {
            setupFilterCollectionControllerIfNeeded()
            return
        }

        let filters = fetchFilterImages()
        let newSignature = makeFilterSignature(filters)

        if forceReload || newSignature != filterCollectionSignature {
            controller.filterImages = filters
            controller.collectionView?.reloadData()
            filterCollectionSignature = newSignature
        }

        syncFilterSelection(frameManager.selectedFrame)
    }

    private func syncFilterSelection(_ selectedFrameID: UUID?) {
        guard let controller = filterCollectionController else { return }
        if controller.currentSelectedFilter != selectedFrameID {
            controller.currentSelectedFilter = selectedFrameID
            controller.scrollToSelectedFilter(animated: false)
        }
    }

    private func fetchFilterImages() -> [StoreImages] {
        let request: NSFetchRequest<StoreImages> = StoreImages.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdDate", ascending: true),
            NSSortDescriptor(key: "uuid", ascending: true)
        ]

        do {
            return try viewContext.fetch(request)
                .filter { $0.uuid != nil }
                .reversed()
        } catch {
            print("[CameraUIKit] 필터 목록 로딩 실패: \(error.localizedDescription)")
            return []
        }
    }

    private func makeFilterSignature(_ filters: [StoreImages]) -> [String] {
        filters.map { image in
            let uuid = image.uuid?.uuidString ?? "nil"
            let createdAt = image.createdDate?.timeIntervalSince1970 ?? 0
            return "\(uuid)-\(createdAt)"
        }
    }

    private func applySelectedFilter(uuid: UUID?) {
        guard let uuid else {
            frameManager.selectedFrame = nil
            frameManager.resultImage = nil
            return
        }

        if let cached = FilterImageCache.shared.image(for: uuid) {
            frameManager.selectedFrame = uuid
            frameManager.resultImage = cached
            return
        }

        let request: NSFetchRequest<StoreImages> = StoreImages.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", uuid as CVarArg)
        request.fetchLimit = 1

        do {
            let results = try viewContext.fetch(request)
            if let storedImage = results.first,
               let imageData = storedImage.image,
               let image = FilterImageCache.shared.image(for: uuid, data: imageData) {
                frameManager.selectedFrame = uuid
                frameManager.resultImage = image
            }
        } catch {
            print("[CameraUIKit] 선택 프레임 로딩 실패: \(error.localizedDescription)")
        }
    }

    private func loadSelectedFrameFromCoreDataIfNeeded() {
        guard let frameID = frameManager.selectedFrame else {
            frameManager.resultImage = nil
            return
        }

        if let cached = FilterImageCache.shared.image(for: frameID) {
            frameManager.resultImage = cached
            return
        }

        let request: NSFetchRequest<StoreImages> = StoreImages.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", frameID as CVarArg)
        request.fetchLimit = 1

        do {
            let results = try viewContext.fetch(request)
            if let storedImage = results.first,
               let data = storedImage.image,
               let image = FilterImageCache.shared.image(for: frameID, data: data) {
                frameManager.resultImage = image
            } else {
                frameManager.resultImage = nil
            }
        } catch {
            print("[CameraUIKit] 초기 선택 프레임 로딩 실패: \(error.localizedDescription)")
            frameManager.resultImage = nil
        }
    }

    private func updateIconRotation(for orientation: UIDeviceOrientation) {
        let angle = CGFloat(motionManager.rotationAngle(for: orientation).radians)
        cameraSwitchButton.transform = CGAffineTransform(rotationAngle: angle)
        timerControlView.updateIconRotation(angle: angle)

        if isTallScreenLayout {
            newFrameIconView.transform = .identity
        } else {
            newFrameIconView.transform = CGAffineTransform(rotationAngle: angle)
        }
    }

    private func presentDebugOptions() {
#if DEBUG
        let debugOptionsView = CameraDebugOptionsView { [weak self] in
            guard let self else { return }
            self.viewModel.refreshRuntimeDependencies()
            self.viewModel.checkVideoAuthorization()
            self.viewModel.startCameraSession()
            self.rebuildZoomButtonsIfNeeded(force: true)
            self.updateZoomButtonsAppearance(animated: false)
            self.updateLayoutForCurrentBounds()
            self.updatePreviewContent()
        }

        let controller = UIHostingController(rootView: debugOptionsView)
        present(controller, animated: true)
#endif
    }

    private func embed(_ child: UIViewController, in container: UIView) {
        addChild(child)
        container.addSubview(child.view)
        child.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        child.didMove(toParent: self)
    }

    private func removeEmbedded(_ child: UIViewController) {
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
    }

    private func isHitTestLoggingEnabled() -> Bool {
        RuntimeTestingOptions.isHitTestLoggingEnabled()
    }

    private func hitTestViewDescription(_ view: UIView?) -> String {
        guard let view else { return "nil" }
        return "\(type(of: view))(hidden=\(view.isHidden), alpha=\(String(format: "%.2f", view.alpha)), interaction=\(view.isUserInteractionEnabled))"
    }

    @objc
    private func handleHitTestProbeTap(_ gesture: UITapGestureRecognizer) {
        guard isHitTestLoggingEnabled() else { return }

        let pointInRoot = gesture.location(in: view)
        let rootHit = view.hitTest(pointInRoot, with: nil)

        let pointInNewFrame = gesture.location(in: newFrameButton)
        let isInsideNewFrame = newFrameButton.bounds.contains(pointInNewFrame)

        let pointInFilterHost = gesture.location(in: filterHostView)
        let isInsideFilterHost = filterHostView.bounds.contains(pointInFilterHost)

        print("[CameraHitTest] tapRoot=\(pointInRoot), rootHit=\(hitTestViewDescription(rootHit)), newFrameContains=\(isInsideNewFrame), filterHostContains=\(isInsideFilterHost)")

        if let filterView = filterCollectionController?.view {
            let pointInFilterVC = gesture.location(in: filterView)
            let filterHit = filterView.hitTest(pointInFilterVC, with: nil)
            print("[CameraHitTest] filterTap=\(pointInFilterVC), filterHit=\(hitTestViewDescription(filterHit))")
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    @objc
    private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .changed:
            viewModel.zoom(factor: gesture.scale)
        case .ended, .cancelled, .failed:
            viewModel.zoomInitialize()
        default:
            break
        }
    }

    @objc
    private func handleCameraSwitchTapped() {
        viewModel.changeCamera()
        rebuildZoomButtonsIfNeeded(force: true)
        updateZoomButtonsAppearance(animated: true)
    }

    @objc
    private func handleZoomButtonTapped(_ sender: UIButton) {
        guard let option = currentZoomOptions.first(where: { $0.tag == sender.tag }) else { return }
        viewModel.setZoom(factor: option.zoomFactor(for: viewModel.cameraPosition))
        updateZoomButtonsAppearance(animated: true)
    }

    @objc
    private func handleNewFrameTouchDown() {
        guard isHitTestLoggingEnabled() else { return }
        print("[CameraHitTest] newFrameButton touchDown")
    }

    @objc
    private func handleNewFrameTapped() {
        if isHitTestLoggingEnabled() {
            print("[CameraHitTest] newFrameButton touchUpInside -> navigate photoPicker")
        }

        Task { @MainActor in
            naviManager.push(screen: Screen.photoPicker)
        }
    }

    @objc
    private func handleDebugTapped() {
        presentDebugOptions()
    }
}

private final class CameraTimerControlView: UIControl {
    var onDelaySelected: ((TimeInterval) -> Void)?

    private let backgroundCapsuleView = UIView()

    private let collapsedStackView = UIStackView()
    private let collapsedIconView = UIImageView()
    private let collapsedTextLabel = UILabel()

    private let expandedStackView = UIStackView()
    private let expandedIconView = UIImageView()

    private var widthConstraint: Constraint?

    private var currentDelayTime: TimeInterval = 0
    private var isExpanded = false

    private var collapsedTapGesture: UITapGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(delayTime: TimeInterval) {
        currentDelayTime = delayTime
        collapsedTextLabel.text = delayTime == 0 ? "Off" : "\(Int(delayTime))초"
    }

    func updateIconRotation(angle: CGFloat) {
        collapsedIconView.transform = CGAffineTransform(rotationAngle: angle)
        expandedIconView.transform = CGAffineTransform(rotationAngle: angle)
    }

    private func setupView() {
        backgroundCapsuleView.layer.cornerRadius = 15
        backgroundCapsuleView.layer.borderWidth = 1
        backgroundCapsuleView.clipsToBounds = true

        addSubview(backgroundCapsuleView)
        backgroundCapsuleView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            widthConstraint = make.width.equalTo(60).priority(.high).constraint
            make.height.equalTo(30).priority(.high)
        }

        collapsedStackView.axis = .horizontal
        collapsedStackView.alignment = .center
        collapsedStackView.spacing = 8

        collapsedIconView.image = UIImage(named: "timerBlack")
        collapsedIconView.contentMode = .scaleAspectFit

        collapsedTextLabel.font = .systemFont(ofSize: 13)
        collapsedTextLabel.textColor = .black
        collapsedTextLabel.minimumScaleFactor = 0.5
        collapsedTextLabel.adjustsFontSizeToFitWidth = true

        collapsedStackView.addArrangedSubview(collapsedIconView)
        collapsedStackView.addArrangedSubview(collapsedTextLabel)

        collapsedIconView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }

        expandedStackView.axis = .horizontal
        expandedStackView.alignment = .center
        expandedStackView.spacing = 16

        expandedIconView.image = UIImage(named: "timerWhite")
        expandedIconView.contentMode = .scaleAspectFit

        expandedStackView.addArrangedSubview(expandedIconView)
        expandedIconView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }

        [
            ("Off", TimeInterval(0)),
            ("3초", TimeInterval(3)),
            ("5초", TimeInterval(5)),
            ("7초", TimeInterval(7))
        ].forEach { title, delay in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            button.addAction(UIAction { [weak self] _ in
                self?.selectDelay(delay)
            }, for: .touchUpInside)
            expandedStackView.addArrangedSubview(button)
        }

        backgroundCapsuleView.addSubview(collapsedStackView)
        backgroundCapsuleView.addSubview(expandedStackView)

        collapsedStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        expandedStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        collapsedTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCollapsedTap))
        if let collapsedTapGesture {
            addGestureRecognizer(collapsedTapGesture)
        }

        expandedStackView.isHidden = true
        applyStyle(animated: false)
        update(delayTime: currentDelayTime)
    }

    @objc
    private func handleCollapsedTap() {
        guard !isExpanded else { return }
        isExpanded = true
        applyStyle(animated: true)
    }

    private func selectDelay(_ delay: TimeInterval) {
        currentDelayTime = delay
        onDelaySelected?(delay)
        isExpanded = false
        applyStyle(animated: true)
    }

    private func applyStyle(animated: Bool) {
        let updates = { [self] in
            widthConstraint?.update(offset: isExpanded ? 185 : 60)
            backgroundCapsuleView.backgroundColor = isExpanded ? UIColor.black : UIColor.white
            backgroundCapsuleView.layer.borderColor = isExpanded ? UIColor.clear.cgColor : (UIColor(named: "gray01") ?? UIColor.lightGray).cgColor

            collapsedStackView.isHidden = isExpanded
            expandedStackView.isHidden = !isExpanded

            layoutIfNeeded()
            superview?.layoutIfNeeded()
        }

        if animated {
            UIView.animate(
                withDuration: 0.2,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0,
                options: [.curveEaseOut, .allowUserInteraction]
            ) {
                updates()
            }
        } else {
            updates()
        }
    }
}
