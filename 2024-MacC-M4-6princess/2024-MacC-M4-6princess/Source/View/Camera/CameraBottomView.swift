//
//  CameraBottomView.swift
//  2024-MacC-M4-6princess
//
//  Created by 김이예은 on 11/4/24.
//

import SwiftUI
import FirebaseAnalytics

//메인뷰 하단 뷰(셔터버튼, 기타 버튼 등)
struct CameraBottomView: View {
    @EnvironmentObject var naviManager: NavigationManager
    @EnvironmentObject var frameManager: FrameManager
    @EnvironmentObject var imageModel: ImageListModel
    @ObservedObject var viewModel: CameraViewModel

    
    var body: some View {
        let isTallScreen = UIScreen.main.bounds.height / UIScreen.main.bounds.width > 2.0
        let buttonSize = isTallScreen ? CGSize(width: 70, height: 80) : CGSize(width: 56, height: 56)
        let iconSize: CGFloat = isTallScreen ? 50 : 40
        let containerHeight: CGFloat = isTallScreen ? 111 : 60
        let frameHeight: CGFloat = isTallScreen ? 111 : 60
        let filteredHeight: CGFloat = isTallScreen ? 111 : 124
        let filterTopPadding: CGFloat = isTallScreen ? 20 : 0

        VStack {
            ZStack(alignment: .center) {
                FilteredImageView(viewModel: viewModel)
                    .environmentObject(frameManager)
                    .environmentObject(imageModel)
                    .frame(height: filteredHeight)
                HStack {
                    Button {
                        naviManager.push(screen: Screen.photoPicker)
                    } label: {
                        VStack(alignment: .center, spacing: 4) {
                            Image("newFrameIcon")
                                .resizable()
                                .frame(width: iconSize, height: iconSize)
                                .shadow(
                                    color: .white,
                                    radius: 10,
                                    x: 20, y: 0)
                            Text(String(localized:"새 프레임"))
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.leading, 20)
                    .frame(width: buttonSize.width, height: buttonSize.height)
                    .background(.white)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .padding(.top, filterTopPadding)
            .frame(height: containerHeight)

        }
        .frame(width: UIScreen.main.bounds.width, height: frameHeight)
        .background(.white)
    }
}

