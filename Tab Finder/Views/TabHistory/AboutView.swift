import SwiftUI

struct AboutView: View {
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 41, height: 41)
                Text("Tab Finder")
                    .font(.system(size: 28, weight: .regular))
            }
            Spacer()
            HStack {
                Text("Made by designer and developer [Oleh Kopyl](https://kopyloleh.com/)")
                Spacer()
                Text("\(currentVersion)")
            }
            .font(.system(size: 14))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 41)
        .padding(.top, 33)
        .padding(.bottom, 41)
        .frame(minWidth: 444, minHeight: 240)
    }
}
