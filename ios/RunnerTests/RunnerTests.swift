import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {
  func testHostIdentityAndVersion() {
    XCTAssertEqual(Bundle.main.bundleIdentifier, "com.xennzeru.xenndo")
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "XennDo")
    XCTAssertFalse((Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "").isEmpty)
    XCTAssertFalse((Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "").isEmpty)
  }

  func testPrivateDocumentsAreNotExposedThroughFileSharing() {
    XCTAssertNotEqual(Bundle.main.object(forInfoDictionaryKey: "UIFileSharingEnabled") as? Bool, true)
  }
}
