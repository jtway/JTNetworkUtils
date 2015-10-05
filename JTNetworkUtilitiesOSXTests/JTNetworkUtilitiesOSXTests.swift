//
//  JTNetworkUtilitiesOSXTests.swift
//  JTNetworkUtilitiesOSXTests
//
//  Created by Josh Tway on 10/4/15.
//  Copyright © 2015 Josh Tway. All rights reserved.
//

import XCTest
@testable import JTNetworkUtilitiesOSX

class JTNetworkUtilitiesOSXTests: XCTestCase {
    var queue: dispatch_queue_t = dispatch_queue_create("com.jtway.PingQueue", nil)
    
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

        let pingTest = Ping(hostname: "www.jtway.com")
        pingTest.dispatchQueue = queue

        pingTest.start { (ipAddress, latency) in
            // Do something
            print("Ping response handler called. IP: \(ipAddress), Latency: \(latency)ms")
            pingTest.stop()
            pingExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(6.0) { error in
            if error != nil {
                print("Test completion handler called with error. \(error!.localizedDescription)")
            }
        }
    }

    func testPing6() {
        let pingExpectation = expectationWithDescription("Ping call expectation")

        let pingTest = Ping(hostname: "2600:3c02::f03c:91ff:fe6e:993c")
        pingTest.dispatchQueue = queue

        pingTest.start { (ipAddress, latency) in
            // Do something
            print("Ping response handler called. IP: \(ipAddress), Latency: \(latency)ms")
            pingTest.stop()
            pingExpectation.fulfill()
        }

        waitForExpectationsWithTimeout(6.0) { error in
            if error != nil {
                print("Test completion handler called with error. \(error!.localizedDescription)")
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

    func testHostFromHostname() {
        let host: Host = Host(hostname: "www.google.com")

        XCTAssertNotNil(host.hostname)
        XCTAssertNotNil(host.ipAddress)

        XCTAssertGreaterThan(host.ipAddresses.count, 0)
        XCTAssertGreaterThan(host.hostnames.count, 0)

        print("Hostnme: \(host.hostname!)")
        print("IP Address: \(host.ipAddress!)")

        var sIPAddresses = ""
        for ipAddress in host.ipAddresses {
            sIPAddresses += ipAddress + " "
        }

        print("All IP Adddresses: \(sIPAddresses)")

        let anotherHost: Host = Host(hostname: "www.jtway.com")

        XCTAssertNotNil(anotherHost.hostname)
        XCTAssertNotNil(anotherHost.ipAddress)

        XCTAssertGreaterThan(anotherHost.ipAddresses.count, 0)
        XCTAssertGreaterThan(anotherHost.hostnames.count, 0)

        print("Hostnme: \(anotherHost.hostname!)")
        print("IP Address: \(anotherHost.ipAddress!)")

        sIPAddresses = ""
        for ipAddress in anotherHost.ipAddresses {
            sIPAddresses += ipAddress + " "
        }

        print("All IP Adddresses: \(sIPAddresses)")
    }

    func testHostFromIPAddress() {
        let host: Host = Host(address: "65.196.188.54")

        XCTAssertNotNil(host.hostname)
        XCTAssertNotNil(host.ipAddress)

        XCTAssertGreaterThan(host.ipAddresses.count, 0)
        XCTAssertGreaterThan(host.hostnames.count, 0)

        print("Hostnme: \(host.hostname!)")
        print("IP Address: \(host.ipAddress!)")

        var sIPAddresses = ""
        for ipAddress in host.ipAddresses {
            sIPAddresses += ipAddress + " "
        }

        print("All IP Adddresses: \(sIPAddresses)")
    }

    func testHostFromIPv6Address() {
        let host: Host = Host(address: "2600:3c02::f03c:91ff:fe6e:993c")

        XCTAssertNotNil(host.hostname)
        XCTAssertNotNil(host.ipAddress)

        XCTAssertGreaterThan(host.ipAddresses.count, 0)
        XCTAssertGreaterThan(host.hostnames.count, 0)

        print("Hostnme: \(host.hostname!)")
        print("IP Address: \(host.ipAddress!)")

        var sIPAddresses = ""
        for ipAddress in host.ipAddresses {
            sIPAddresses += ipAddress + " "
        }

        print("All IP Adddresses: \(sIPAddresses)")
    }

    func testPerformanceExample() {
        
        self.measureBlock {
            let host: Host = Host(hostname: "www.google.com")
            print("IP Address: \(host.ipAddress!)")
        }
    }
}
