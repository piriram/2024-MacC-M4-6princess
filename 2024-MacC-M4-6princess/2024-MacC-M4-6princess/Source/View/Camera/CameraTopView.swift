//
//  CameraTopView.swift
//  2024-MacC-M4-6princess
//
//  Created by 김이예은 on 11/4/24.
//

import SwiftUI

//메인뷰 상단 뷰
struct CameraTopView: View {
    @ObservedObject var viewModel: CameraViewModel
    @StateObject var motionManager = MotionManager()
    @State var showDebugOptions = false
    
    var body: some View {
        let isTallScreen = UIScreen.main.bounds.height / UIScreen.main.bounds.width > 2.0

        HStack {
            Spacer()
            CameraTimerView(viewModel: viewModel, motionManager: motionManager)
                .padding(.trailing, isTallScreen ? 5 : 0)
            Button {
                viewModel.changeCamera()
            } label: {
                Image("cameraReverseIcon")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .rotationEffect(motionManager.rotationAngle(for: motionManager.currentOrientation))
                    .animation(.easeInOut, value: motionManager.currentOrientation)
            }
            .padding(.trailing, isTallScreen ? 20 : 0)
#if DEBUG
            Button {
                showDebugOptions = true
            } label: {
                Image(systemName: "ladybug")
                    .font(.system(size: 20))
                    .foregroundStyle(.black)
            }
            .padding(.trailing, 16)
#endif
        }
        .frame(width: UIScreen.main.bounds.width, height: 46)
        .background(.white)
        .sheet(isPresented: $showDebugOptions) {
            CameraDebugOptionsView {
                viewModel.refreshRuntimeDependencies()
                viewModel.checkVideoAuthorization()
            }
        }
    }
}
