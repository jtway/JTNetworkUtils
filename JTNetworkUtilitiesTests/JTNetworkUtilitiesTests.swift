//
//  JTNetworkUtilitiesTests.swift
//  JTNetworkUtilitiesTests
//
//  Created by Josh Tway on 9/24/15.
//  Copyright © 2015 Josh Tway. All rights reserved.
//

import XCTest
@testable import JTNetworkUtilities

class JTNetworkUtilitiesTests: XCTestCase {
    var queue: dispatch_queue_t = dispatch_queue_create("com.jtway.pingplayground.PingQueue", nil)

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testPing() {

        let pingExpectation = expectationWithDescription("Ping call expectation")

        let pingTest = Ping(hostname: "74.207.230.99")
        pingTest.dispatchQueue = queue

        pingTest.start { (ipAddress, latency) in
            // Do something
            print("Ping response handler called. IP: \(ipAddress), Latency: \(latency)ms")
            pingTest.stop()
            pingExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(6.0) { error in
            if error != nil {
                print("Test completion handler called with error. \(error?.localizedDescription)")
            }
        }
    }

    func testHostResolution() {
        let hostname = "www.jtway.com"

        if let ipAddresses = hostnameToAddress(hostname) {
            print("Number of results: \(ipAddresses.count)")
            for ipAddress in ipAddresses {
                print("\(hostname): \(ipAddress)")
            }
        } else {
            XCTAssert(true)
        }
    }

    func testHostWithIPAddress() {
        let hostname = "74.207.230.99"

        if let ipAddresses = hostnameToAddressStrings(hostname) {
            print("Number of results: \(ipAddresses.count)")
            for ipAddress in ipAddresses {
                print("\(hostname): \(ipAddress)")
            }
        } else {
            XCTAssert(true)
        }
    }

    func testIPToHostname() {
        let socketAddress = SocketAddress4()
        socketAddress.setFromString("74.207.230.99")

        guard let hostname = withUnsafePointer(&socketAddress.sin, { saToHostname(UnsafePointer<sockaddr>($0)) }) else {
            XCTAssert(true)
            return
        }

        print("Hostname: \(hostname)")

    }

    func testHostnameToAddress() {
        let hostname = "www.jtway.com"

        if let addresses = hostnameToAddress(hostname) {
            print("Number of results: \(addresses.count)")
            for address in addresses {
                print("\(hostname): \(address.stringValue!)")
            }
        } else {
            XCTAssert(true)
        }
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
