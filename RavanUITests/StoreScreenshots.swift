import XCTest

/// Captures the App Store screenshots in light and dark mode.
///
/// Run the "Ravan Screenshots" scheme (Product › Test) on the iPhone 18 Pro Max simulator
/// (6.9", 1320 × 2868). The app starts in its debug screenshot mode with a sample study
/// history; images are attached to the test report and written to
/// `~/Documents/ravan-store-assets/ios-raw/<theme>/` on the Mac.
final class StoreScreenshots: XCTestCase {
    private let screens: [(name: String, screen: String)] = [
        ("01-home", "home"),
        ("02-word", "word:brave"),
        ("03-search", "search"),
        ("04-review-card", "session"),
        ("05-progress", "review"),
        ("06-library", "library"),
    ]

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testCaptureStoreScreenshots() throws {
        for theme in ["light", "dark"] {
            for item in screens {
                let app = XCUIApplication()
                app.launchArguments = ["-RavanScreenshots", "-RavanScreen", item.screen, "-settings.theme", theme]
                app.launch()
                waitUntilReady(app)

                switch item.screen {
                case "search":
                    let field = app.searchFields.firstMatch
                    if field.waitForExistence(timeout: 10) {
                        field.tap()
                        field.typeText("res\n")
                    }
                    sleep(2)
                case "session":
                    let reveal = app.buttons["نمایش پاسخ"]
                    if reveal.waitForExistence(timeout: 10) { reveal.tap() }
                    sleep(1)
                default:
                    break
                }
                save(XCUIScreen.main.screenshot(), theme: theme, name: item.name)
                app.terminate()
            }
        }
    }

    /// The first launch imports the 21k-word dictionary; wait until a tab bar or a review card shows.
    @MainActor
    private func waitUntilReady(_ app: XCUIApplication) {
        let deadline = Date().addingTimeInterval(240)
        while Date() < deadline {
            if app.tabBars.firstMatch.exists || app.buttons["نمایش پاسخ"].exists { break }
            sleep(1)
        }
        sleep(3) // let animations and the glass effects settle
    }

    private func save(_ screenshot: XCUIScreenshot, theme: String, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(theme)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return }
        for folder in ["Documents/ravan-store-assets/ios-raw", "Library/Caches/RavanScreenshots"] {
            let url = URL(fileURLWithPath: home)
                .appendingPathComponent(folder)
                .appendingPathComponent(theme)
                .appendingPathComponent("\(name).png")
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try screenshot.pngRepresentation.write(to: url)
                return
            } catch {
                continue
            }
        }
    }
}
