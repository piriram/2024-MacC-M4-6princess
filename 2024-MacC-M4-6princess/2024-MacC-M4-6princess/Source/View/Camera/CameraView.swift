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
        .onChange(of: frameManager.isFrameLoading) { newValue in
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

private final class CameraUIKitViewController: UIViewController {
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

    private var topHostingController: UIHostingController<AnyView>?
    private var zoomHostingController: UIHostingController<AnyView>?
    private var bottomHostingController: UIHostingController<AnyView>?
    private var filterHostingController: UIHostingController<AnyView>?

    private var previewWidthConstraint: Constraint?
    private var previewHeightConstraint: Constraint?
    private var bottomHeightConstraint: Constraint?

    private var cancellables = Set<AnyCancellable>()

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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupLayout()
        setupHostingControllers()
        bindState()
        updateLayoutForCurrentBounds()
        updatePreviewContent()
        updateFilterOverlay()
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

        refreshHostingRootViews()
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

        view.addSubview(previewContainerView)
        view.addSubview(topContainerView)
        view.addSubview(zoomContainerView)
        view.addSubview(bottomContainerView)

        sampleImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupLayout() {
        topContainerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(46)
        }

        bottomContainerView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            bottomHeightConstraint = make.height.equalTo(111).constraint
        }

        zoomContainerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(bottomContainerView.snp.top)
        }

        previewContainerView.snp.makeConstraints { make in
            make.top.equalTo(topContainerView.snp.bottom)
            make.centerX.equalToSuperview()
            previewWidthConstraint = make.width.equalTo(0).constraint
            previewHeightConstraint = make.height.equalTo(0).constraint
        }
    }

    private func setupHostingControllers() {
        let top = UIHostingController(rootView: AnyView(makeTopView()))
        let zoom = UIHostingController(rootView: AnyView(makeZoomView()))
        let bottom = UIHostingController(rootView: AnyView(makeBottomView()))

        top.view.backgroundColor = .clear
        zoom.view.backgroundColor = .clear
        bottom.view.backgroundColor = .clear

        embed(top, in: topContainerView)
        embed(zoom, in: zoomContainerView)
        embed(bottom, in: bottomContainerView)

        topHostingController = top
        zoomHostingController = zoom
        bottomHostingController = bottom
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

        frameManager.$selectedFrame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFilterOverlay()
            }
            .store(in: &cancellables)
    }

    private func refreshHostingRootViews() {
        topHostingController?.rootView = AnyView(makeTopView())
        zoomHostingController?.rootView = AnyView(makeZoomView())
        bottomHostingController?.rootView = AnyView(makeBottomView())
    }

    private func makeTopView() -> some View {
        CameraTopView(viewModel: self.viewModel)
            .environment(\.managedObjectContext, self.viewContext)
    }

    private func makeZoomView() -> some View {
        CamZoomButtonView(viewModel: self.viewModel, motionManager: self.motionManager)
            .environment(\.managedObjectContext, self.viewContext)
    }

    private func makeBottomView() -> some View {
        CameraBottomView(viewModel: self.viewModel)
            .environmentObject(self.naviManager)
            .environmentObject(self.frameManager)
            .environmentObject(self.imageModel)
            .environment(\.managedObjectContext, self.viewContext)
    }

    private func updateLayoutForCurrentBounds() {
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let ratio = max(viewModel.frameRatio, 0.01)
        let isTallScreen = bounds.height / bounds.width > 2.0

        let previewWidth: CGFloat
        let previewHeight: CGFloat

        if isTallScreen {
            previewWidth = bounds.width
            previewHeight = previewWidth * ratio
        } else {
            previewHeight = max(bounds.height - 200, 0)
            previewWidth = previewHeight / ratio
        }

        previewWidthConstraint?.update(offset: previewWidth)
        previewHeightConstraint?.update(offset: previewHeight)
        bottomHeightConstraint?.update(offset: isTallScreen ? 111 : 60)

        viewModel.frameSize.size = CGSize(width: previewWidth, height: previewHeight)
        viewModel.preview?.frame = previewContainerView.bounds
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
            viewModel.preview.videoGravity = .resizeAspectFill
        }

        guard let previewLayer = viewModel.preview else { return }

        if previewLayer.superlayer !== previewContainerView.layer {
            previewLayer.removeFromSuperlayer()
            previewContainerView.layer.insertSublayer(previewLayer, at: 0)
        }
        previewLayer.frame = previewContainerView.bounds
    }

    private func updateFilterOverlay() {
        guard let selectedFilterID = frameManager.selectedFrame else {
            if let filterHostingController {
                removeEmbedded(filterHostingController)
                self.filterHostingController = nil
            }
            return
        }

        let overlayView = AnyView(
            FilteredCoreDataImageView(filterID: selectedFilterID)
                .environment(\.managedObjectContext, viewContext)
                .allowsHitTesting(false)
        )

        if let filterHostingController {
            filterHostingController.rootView = overlayView
            return
        }

        let controller = UIHostingController(rootView: overlayView)
        controller.view.backgroundColor = .clear
        embed(controller, in: previewContainerView)
        previewContainerView.bringSubviewToFront(sampleImageView)
        previewContainerView.bringSubviewToFront(controller.view)
        filterHostingController = controller
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
}
