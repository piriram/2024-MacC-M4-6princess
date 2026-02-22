import SwiftUI
import Photos
import FirebaseAnalytics

struct PhotosPickerView: View {
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var vm: PhotosPickerViewModel = PhotosPickerViewModel()
    @State private var isPresented: Bool = false
    @State private var photoAccessDenied = false
    @State private var permissionChecked = false
    @EnvironmentObject var naviManager: NavigationManager
    @EnvironmentObject var frameManager: FrameManager

    var body: some View {
        ZStack {
            VStack {
                toolbarButton
                if vm.models.isEmpty && permissionChecked {
                    emptyStateView
                        .padding(.top, 40)
                } else {
                    ImageScrollViewRepresentable(
                        images: vm.models,
                        onScrollToBottom: {
                            if vm.canLoadMorePages {
                                let addedRange = vm.fetchNextPage()
                                if addedRange.isEmpty {
                                    return
                                }

                                for i in addedRange {
                                    vm.loadImage(for: vm.album[i], index: i)
                                }
                            }
                        },
                        onVisibleIndexChange: { index in
                            vm.prefetchAround(index: index)
                        },
                        onImageTap: { index in
                            guard index < vm.models.count, index < vm.album.count else { return }

                            if vm.selectedIndex >= 0 {
                                vm.models[vm.selectedIndex].isSelected = false
                            }
                            vm.selectedIndex = index
                            vm.models[index].isSelected = true

                            let tappedModel = vm.models[index]
                            vm.getImage(image: tappedModel, for: vm.album[index]) { image in
                                guard let image, vm.selectedIndex == index else { return }
                                frameManager.pickedImage = image
                                naviManager.push(screen: Screen.frameEdit)
                            }
                        }
                    )
                    .padding(.top, 10)
                }
            }
            VStack {
                toastMessage
                    .padding(.bottom, UIScreen.main.bounds.height * 0.65)
                    .opacity(vm.messageOpacity)
            }
        }
        .onAppear {
            if vm.selectedIndex >= 0 {
                vm.models[vm.selectedIndex].isSelected = false
                vm.selectedIndex = -1
                frameManager.pickedImage = nil
            }

            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    permissionChecked = true

                    switch status {
                    case .authorized, .limited:
                        photoAccessDenied = false

                        if vm.firstAppear || vm.models.isEmpty {
                            let initialRange = vm.fetchInitialAlbum()
                            if !initialRange.isEmpty {
                                for i in initialRange {
                                    vm.loadImage(for: vm.album[i], index: i)
                                }
                            }
                            vm.firstAppear = false
                        }
                    case .denied, .restricted:
                        photoAccessDenied = true
                    case .notDetermined:
                        break
                    @unknown default:
                        break
                    }
                }
            }
            vm.changeOpacity()
            Analytics.logEvent("A3_사진선택", parameters: nil)
        }
        .navigationBarBackButtonHidden()
        .onChange(of: vm.selectedIndex) {
            if vm.selectedIndex >= 0 {
                Analytics.logEvent("A3_갤러리사진선택", parameters: nil)
            }
        }
    }
}

extension PhotosPickerView {
    var toastMessage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.message)
                .opacity(0.9)
                .frame(width: 202, height: 40)
            
            HStack {
                Image("paintImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                
                Text("최애의 사진을 선택하세요.")
                    .foregroundStyle(.white)
                    .font(.footnote)
                    .fontWeight(.bold)
            }
        }
    }
}

extension PhotosPickerView {
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: photoAccessDenied ? "lock.slash" : "photo.on.rectangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.gray)

            Text(photoAccessDenied ? "사진 접근 권한이 필요해요." : "표시할 사진이 없어요.")
                .font(.headline)
                .foregroundStyle(.gray01)

            Text(photoAccessDenied
                 ? "설정 > 개인정보 보호 및 보안 > 사진에서 접근 권한을 허용해 주세요."
                 : "앨범에 사진이 없거나 접근 가능한 사진이 없습니다.\n시뮬레이터라면 Photos 앱에 이미지를 먼저 추가해 주세요.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
    }

    var toolbarButton: some View {
        
        HStack {
            
            Button {
                naviManager.pop()
                //                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .resizable()
                    .foregroundStyle(.black)
                    .frame(width: 15, height: 15)
            }
            .disabled(vm.models.isEmpty ? true : false)
            .padding(.leading, UIScreen.main.bounds.width * 0.09)
            Spacer()
            
            Text("사진 선택")
                .fontWeight(.bold)
                .foregroundStyle(.gray01)
                .padding(.leading, UIScreen.main.bounds.width * 0.04)
                .padding(.trailing, UIScreen.main.bounds.height * 0.075)
            
            Spacer()
            
            
        }
        .padding(.top, 20)
    }
}

#Preview {
    PhotosPickerView()
}
