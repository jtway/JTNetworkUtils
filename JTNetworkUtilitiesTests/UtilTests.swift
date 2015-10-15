//
//  UtilTests.swift
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


class UtilTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
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
    
}
