import SwiftUI

// =====================================================================
// ScreenReaderIosApp — standalone iOS fixture app for TE-22788
// (Screen Reader Automation). iOS twin of the Android ScreenReaderXmlApp:
// just the screen-reader pages, nothing else, so scans exercise exactly
// the SR fixtures. Views are shared verbatim with the full
// IOS_Accessibility_App demo (same element ids -> same QA test plan).
// =====================================================================

@main
struct ScreenReaderIosAppApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView { HomeView() }
                .navigationViewStyle(.stack)
        }
    }
}

struct HomeView: View {
    var body: some View {
        List {
            NavigationLink("Screen Reader Automation") {
                ScreenReaderTestView()
            }
            .accessibilityIdentifier("home_sr_rules")
            NavigationLink("Linear Navigation Fixture") {
                ScreenReaderLinearNavView()
            }
            .accessibilityIdentifier("home_sr_linear_nav")
            NavigationLink("pHash Similar Screens") {
                PHashSimilarView()
            }
            .accessibilityIdentifier("home_sr_phash_similar")
            NavigationLink("pHash Animated Screen") {
                PHashAnimatedView()
            }
            .accessibilityIdentifier("home_sr_phash_animated")
        }
        .navigationTitle("Screen Reader Tests")
    }
}
