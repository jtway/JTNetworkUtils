//
//  PingTests.swift
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

class PingTests: XCTestCase {
    var queue: dispatch_queue_t = dispatch_queue_create("com.jtway.PingQueue", nil)
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func printPingResponses(responses: [PingResponse]) {
        print("\(responses.first!.host.hostname!) (\(responses.first!.host.ipAddress!)):")

        for response: PingResponse in responses {
            let formattedLatency = String(format: "%.3f", response.latency)
            print("  Latency: \(formattedLatency)ms")
        }
    }

    func testPing() {

        let pingExpectation = expectationWithDescription("Ping call expectation")

        let pingTest = Ping(hostname: "www.jtway.com")
        pingTest.dispatchQueue = queue

        pingTest.completionHandler = { (responses) in
                // Do something
                self.printPingResponses(responses)
                pingTest.stop()
                pingExpectation.fulfill()
        }

        pingTest.start()

        waitForExpectationsWithTimeout(6.0) { error in
            if error != nil {
                print("Test completion handler called with error. \(error!.localizedDescription)")
            }
        }
    }

//    func testBadPing() {
//
//        let pingExpectation = expectationWithDescription("Ping call expectation")
//
//        let pingTest = Ping(hostname: "blah.jtway.com")
//        pingTest.dispatchQueue = queue
//        pingTest.configuration.timeoutInSeconds = 1.0
//
//        pingTest.completionHandler = { (responses) in
//            // Do something
//            self.printPingResponses(responses)
//            pingTest.stop()
//            pingExpectation.fulfill()
//        }
//
//        pingTest.start()
//
//        waitForExpectationsWithTimeout(6.0) { error in
//            if error != nil {
//                print("Test completion handler called with error. \(error!.localizedDescription)")
//            }
//        }
//    }

    func testMultiplePings() {
        let pingExpectation = expectationWithDescription("Ping call expectation")

        let numPings: UInt16 = 10

        let pingTest = Ping(hostname: "www.jtway.com")
        pingTest.configuration.count = numPings
        pingTest.dispatchQueue = queue

        pingTest.pingResponseHandler = { (response) in
            let formattedLatency = String(format: "%.3f", response.latency)
            print("\(response.host.hostname!) (\(response.host.ipAddress!)), Latency: \(formattedLatency)ms")
        }

        pingTest.completionHandler = { pingResponses in
            self.printPingResponses(pingResponses)
            pingExpectation.fulfill()
        }

        pingTest.start()

        waitForExpectationsWithTimeout(Double(numPings) * 2.0) { error in
            if error != nil {
                print("Test completion handler called with error. \(error!.localizedDescription)")
            }
        }
    }

    // Need a way to detect whether we actually have an IPv6 address and not just link local before using this.
    //    func testPing6() {
    //        let pingExpectation = expectationWithDescription("Ping call expectation")
    //
    //        let pingTest = Ping(hostname: "2600:3c02::f03c:91ff:fe6e:993c")
    //        pingTest.dispatchQueue = queue
    //
    //        pingTest.start { (response) in
    //            // Do something
    //            print("\(response.host.hostname!) (\(response.host.ipAddress!)), Latency: \(response.latency)ms")
    //            pingTest.stop()
    //            pingExpectation.fulfill()
    //        }
    //
    //        waitForExpectationsWithTimeout(6.0) { error in
    //            if error != nil {
    //                print("Test completion handler called with error. \(error!.localizedDescription)")
    //            }
    //        }
    //    }

    func testPingQueue() {

        let hostnames: [String] = [ "www.ox.ac.uk", "www.jtway.com", "www.google.com" ]

        let pingQueue: PingQueue = PingQueue()

        for hostname in hostnames {
            pingQueue.pingOnce(hostname) { (response) in
                let formattedLatency = String(format: "%.3f", response.latency)
                print("\(response.host.hostname!) (\(response.host.ipAddress!)), Latency: \(formattedLatency)ms")
            }
        }

        pingQueue.waitForPingsToComplete(5.0)
    }
}
