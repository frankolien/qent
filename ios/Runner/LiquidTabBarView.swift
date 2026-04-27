import SwiftUI

/// SwiftUI tab bar that uses iOS 26 Liquid Glass styling.
/// Owns no app content — just renders the bar and reports taps via the closure.
@available(iOS 26.0, *)
struct LiquidTabBarView: View {
    let onSelect: (Int) -> Void

    @State private var selection: Int = 0
    @State private var profilePhotoUrl: String? = nil

    var body: some View {
        tabViewBody
            .background(Color.clear)
            .scrollContentBackground(.hidden)
    }

    private var tabViewBody: some View {
        TabView(selection: tabSelection) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                Color.clear
            }
            Tab("Search", systemImage: "magnifyingglass", value: 1) {
                Color.clear
            }
            Tab("Messages", systemImage: "bubble.left.and.bubble.right.fill", value: 2) {
                Color.clear
            }
            Tab("Trips", systemImage: "suitcase.fill", value: 3) {
                Color.clear
            }
            Tab(value: 4) {
                Color.clear
            } label: {
                if let urlString = profilePhotoUrl, let url = URL(string: urlString) {
                    Label {
                        Text("Profile")
                    } icon: {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.crop.circle.fill")
                        }
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                    }
                } else {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selection },
            set: { newValue in
                selection = newValue
                onSelect(newValue)
            }
        )
    }

    func setSelection(_ index: Int) {
        if index != selection {
            selection = index
        }
    }

    func setProfilePhotoUrl(_ url: String?) {
        profilePhotoUrl = url
    }
}
