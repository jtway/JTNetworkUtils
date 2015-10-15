//
//  HostTests.swift
//  JTNetworkUtilities
//
//  Created by Josh Tway on 10/15/15.
//  Copyright © 2015 Josh Tway. All rights reserved.
//

import XCTest

#if os(iOS) || os(watchOS)
@testable import JTNetworkUtilities
#elseif os(OSX)
@testable import JTNetworkUtilitiesOSX
#endif


class HostTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
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
