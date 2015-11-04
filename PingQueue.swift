//
//  PingQueue.swift
//  JTNetworkUtilities
//
//  Created by Josh Tway on 10/15/15.
//  Copyright © 2015 Josh Tway. All rights reserved.
//

import Foundation

public class PingQueue {

    public typealias PingOnceCompletionHandler = (response: PingResponse) -> Void
    public typealias PingQueueCompletionHandler = (Void) -> Void

    private(set) var dispatchQueue: dispatch_queue_t

    private let dispatchGroup: dispatch_group_t = dispatch_group_create()

    var pings: [Ping] = [Ping]()

    init() {
        let queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_UTILITY, 0)
        dispatchQueue = dispatch_queue_create("com.jtway.PingQueue", queueAttributes)
    }

    func pingOnce(hostname: String, completionHandler: PingOnceCompletionHandler) {
        let ping: Ping = Ping(hostname: hostname)
        ping.dispatchQueue = dispatchQueue
        ping.completionHandler = { pingResponses in
            if pingResponses.count > 1 {
                // @TODO Add real error handling
                print("Unexpected number of ping responses")
            }

            if pingResponses.count == 0 {
                print("No pings!")
            }

            completionHandler(response: pingResponses.first!)

            // Remove from the array of pings. Hopefully this doesn't cause a strong retain cycle and once
            //   we leave the completionHandler we'll delete the Ping object
            if let pingIndex = self.pings.indexOf(ping) {
                self.pings.removeAtIndex(pingIndex)
            }

            dispatch_group_leave(self.dispatchGroup)
        }

        pings.append(ping)

        dispatch_group_enter(dispatchGroup)
        ping.start()
    }

    func waitForPingsToComplete(timeout: Double) {
        // If a ping doesn't get a reply this will wait forever, which isn't really what I want
        if dispatch_group_wait(dispatchGroup, dispatch_time(DISPATCH_TIME_NOW, Int64(timeout * Double(NSEC_PER_SEC)))) != 0 {
            for ping in pings {
                ping.stop()
            }
        }
    }
}
