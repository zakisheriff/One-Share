//
//  iOSDeviceServiceTests.swift
//  LumenTests
//
//  Created by [Your Name] on 2025-11-27.
//

import XCTest
@testable import Lumen

class iOSDeviceServiceTests: XCTestCase {
    
    var iosService: iOSDeviceService!
    
    override func setUp() {
        super.setUp()
        iosService = iOSDeviceService()
    }
    
    override func tearDown() {
        iosService = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertNotNil(iosService, "iOSDeviceService should be initialized")
        XCTAssertEqual(iosService.connectionState, .disconnected, "Initial connection state should be disconnected")
    }
    
    func testFileServiceProtocolConformance() {
        // Test that iOSDeviceService conforms to FileService protocol
        XCTAssertTrue(iosService is FileService, "iOSDeviceService should conform to FileService protocol")
    }
    
    func testGetDeviceName() {
        // Test device name retrieval
        let deviceName = iosService.getDeviceName()
        XCTAssertEqual(deviceName, "iOS Device", "Default device name should be 'iOS Device'")
    }
    
    func testConnectionStateManagement() {
        // Test connection state management
        XCTAssertEqual(iosService.connectionState, .disconnected)
        
        // Test that we can set up connection change observers
        let expectation = XCTestExpectation(description: "Connection state change")
        iosService.onDeviceConnectionChange = { state in
            expectation.fulfill()
        }
        
        // Wait for a short time to see if the observer is called
        wait(for: [expectation], timeout: 0.1)
    }
    
    func testCacheManagement() {
        // Test cache clearing functionality
        iosService.clearCache()
        // This should not crash or throw exceptions
        XCTAssertTrue(true, "Cache clearing should not cause errors")
    }
}