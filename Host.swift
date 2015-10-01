//
//  Host.swift
//  JTNetworkUtilities
//
//  Created by Josh Tway on 9/26/15.
//  Copyright © 2015 Josh Tway. All rights reserved.
//

import Foundation

/// Container for hostnames and IP addresses. Can be created using a hostname, IPv4, or IPv6 addres.
public class Host {

    /// Internal socket address structure for storing the socket address objects
    private var socketAddresses: [SocketAddress] = [SocketAddress]()

    // MARK: Hostname and ip address arrays

    /// hostnames usually only a single name (need to look into just keeping one)
    ///  - note: If Host is created with a hostname no hostname resolution is done. If it is created with an IP the
    ///     hostname will be the rdns resolved hostname for that address.
    private(set) var hostnames: [String] = [String]()

    /// All addresses associated with the host. If created with an IP Address we'll usually only have one
    public var addresses: [String] {
        var ipAddresses = [String]()
        for socketAddress in socketAddresses {
            if let ipAddress = socketAddress.stringValue {
                ipAddresses.append(ipAddress)
            }
        }

        return ipAddresses
    }

    // MARK: Single address/hostname accessors

    /// First IP Address in array of ip addresses, if any.
    public var address: String? {
        if socketAddresses.count == 0 {
            return nil
        }

        return socketAddresses.first?.stringValue
    }

    /// First hostname value in the array of hostnames, if any.
    public var hostname: String? {
        if hostnames.count == 0 {
            return nil
        }

        return hostnames.first
    }

    // MARK: Initializers

    init(hostname: String) {
        hostnames.append(hostname)

        if let addresses = hostnameToAddress(hostname) {
            socketAddresses.appendContentsOf(addresses)
        }
    }

    init(address: String) {
        if let addresses = hostnameToAddress(address) {
            socketAddresses.appendContentsOf(addresses)
        }

        // Perhaps I should be doing the resolving on demand?
        for socketAddress in socketAddresses {
            if let socketAddress4 = socketAddress as? SocketAddress4 {
                let hostname: String? = withUnsafePointer(&socketAddress4.sin) { saToHostname(UnsafePointer<sockaddr>($0)) }
                if hostname != nil {
                    hostnames.append(hostname!)
                }
            } else if let socketAddress6 = socketAddress as? SocketAddress6 {
                let hostname: String? = withUnsafePointer(&socketAddress6.sin6) { saToHostname(UnsafePointer<sockaddr>($0)) }
                if hostname != nil {
                    hostnames.append(hostname!)
                }
            }
        }
    }

    init(anotherHost: Host) {
        socketAddresses = anotherHost.socketAddresses
    }
}
