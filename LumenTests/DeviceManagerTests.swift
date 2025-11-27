//
//  DeviceManagerTests.swift
//  LumenTests
//
//  Created by [Your Name] on 2025-11-27.
//

import XCTest
@testable import Lumen

class DeviceManagerTests: XCTestCase {
    
    var deviceManager: DeviceManager!
    
    override func setUp() {
        super.setUp()
        deviceManager = DeviceManager()
    }
    
    override func tearDown() {
        deviceManager = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertNotNil(deviceManager, "DeviceManager should be initialized")
        XCTAssertTrue(deviceManager.connectedDevices.isEmpty, "Initially no devices should be connected")
    }
    
    func testDeviceServiceRetrieval() {
        // Test that we can retrieve device services
        let mtpService = deviceManager.getDeviceService(for: .android)
        let iosService = deviceManager.getDeviceService(for: .ios)
        let noneService = deviceManager.getDeviceService(for: .none)
        
        XCTAssertTrue(mtpService is MTPService, "Android service should be MTPService")
        XCTAssertTrue(iosService is iOSDeviceService, "iOS service should be iOSDeviceService")
        XCTAssertNil(noneService, "None service should be nil")
    }
    
    func testObservableObjectConformance() {
        // Test that DeviceManager conforms to ObservableObject
        XCTAssertTrue(deviceManager is ObservableObject, "DeviceManager should conform to ObservableObject")
    }
}