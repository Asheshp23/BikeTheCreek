//
//  BikeTheCreekUITests.swift
//  BikeTheCreekUITests
//
//  Created by Ashesh Patel on 2026-05-25.
//

import XCTest

final class BikeTheCreekUITests: XCTestCase {
    private let routeIDs = [
        "route-card-leisure",
        "route-card-family",
        "route-card-bramalea",
        "route-card-caledon",
        "route-card-regional"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEveryRouteCanPreviewFromStartToFinishAtHome() throws {
        let app = launchAppForUITesting()
        
        XCTAssertTrue(app.otherElements["route-selection-panel"].waitForExistence(timeout: 6))
        
        for routeID in routeIDs {
            tapRouteCard(routeID, in: app)
            
            let previewButton = app.buttons["preview-route-button"]
            XCTAssertTrue(previewButton.waitForExistence(timeout: 4), "Preview button should exist for \(routeID)")
            XCTAssertTrue(previewButton.isEnabled, "Preview button should be enabled for \(routeID)")
            previewButton.tap()
            
            let finishCue = app.otherElements["route-preview-finished"]
            XCTAssertTrue(finishCue.waitForExistence(timeout: 8), "Route preview should finish for \(routeID)")
        }
    }
    
    @MainActor
    func testRideControlsCanStartAndStopWithoutRoutePreview() throws {
        let app = launchAppForUITesting()
        
        let startStopButton = app.buttons["start-stop-ride-button"]
        XCTAssertTrue(startStopButton.waitForExistence(timeout: 6))
        XCTAssertTrue(startStopButton.isEnabled)
        
        startStopButton.tap()
        XCTAssertTrue(app.otherElements["navigation-cue-banner"].waitForExistence(timeout: 4))
        
        startStopButton.tap()
        XCTAssertTrue(startStopButton.waitForExistence(timeout: 4))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            _ = launchAppForUITesting()
        }
    }
    
    @MainActor
    private func launchAppForUITesting() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITESTING"]
        app.launch()
        return app
    }
    
    @MainActor
    private func tapRouteCard(_ identifier: String, in app: XCUIApplication) {
        let card = app.buttons[identifier]
        if card.waitForExistence(timeout: 2), card.isHittable {
            card.tap()
            return
        }
        
        let routeScrollView = app.scrollViews.firstMatch
        for _ in 0..<6 {
            routeScrollView.swipeLeft()
            if card.waitForExistence(timeout: 1), card.isHittable {
                card.tap()
                return
            }
        }
        
        XCTFail("Could not find route card \(identifier)")
    }
}
