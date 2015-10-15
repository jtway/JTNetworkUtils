//
//  JTNetworkUtilitiesTests.swift
//  JTNetworkUtilitiesTests
//
//  Created by Josh Tway on 9/24/15.
//  Copyright © 2015 Josh Tway. All rights reserved.
//

import XCTest

#if os(iOS) || os(watchOS)
@testable import JTNetworkUtilities
#elseif os(OSX)
@testable import JTNetworkUtilitiesOSX
#endif


class JTNetworkUtilitiesTests: XCTestCase {
    var queue: dispatch_queue_t = dispatch_queue_create("com.jtway.PingQueue", nil)

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }


}
