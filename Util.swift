//
//  Util.swift
//  JTNetworkUtilities
//
//  Created by Josh Tway on 9/27/15.
//  Copyright © 2015 Josh Tway. All rights reserved.
//

import Foundation
import Darwin

// MARK: sockaddr Utilities

/// Convert a sockaddr structure to a string.
func saToString(sa: UnsafePointer<sockaddr>) -> String? {
    var hostBuffer = [CChar](count: Int(NI_MAXHOST), repeatedValue:0)
    var portBuffer = [CChar](count: Int(NI_MAXSERV), repeatedValue:0)

    guard getnameinfo(sa, socklen_t(sa.memory.sa_len), &hostBuffer, socklen_t(hostBuffer.count), &portBuffer, socklen_t(portBuffer.count), NI_NUMERICHOST | NI_NUMERICSERV) == 0
        else { return nil }

    return String.fromCString(hostBuffer)
}

func saToHostname(sa: UnsafePointer<sockaddr>) -> String? {
    var hostBuffer = [CChar](count: Int(NI_MAXHOST), repeatedValue:0)
    var portBuffer = [CChar](count: Int(NI_MAXSERV), repeatedValue:0)

    guard getnameinfo(sa, socklen_t(sa.memory.sa_len), &hostBuffer, socklen_t(hostBuffer.count), &portBuffer, socklen_t(portBuffer.count), NI_NAMEREQD) == 0
        else { return nil }

    return String.fromCString(hostBuffer)
}

// MARK: - Hostname Utilities

func hostnameToAddressStrings(hostname: String) -> [String]? {

    var hints = addrinfo(ai_flags: AI_ADDRCONFIG,
                         ai_family: AF_UNSPEC,
                         ai_socktype: SOCK_DGRAM,
                         ai_protocol: IPPROTO_IP,
                         ai_addrlen: 0,
                         ai_canonname: nil,
                         ai_addr: nil,
                         ai_next: nil)

    var results = UnsafeMutablePointer<addrinfo>()

    guard hostname.withCString({ cshostname in getaddrinfo(cshostname, nil, &hints, &results) }) == 0 else {
        return nil
    }

    var ipAddresses: [String] = [String]()

    for var result = results; result != nil; result = result.memory.ai_next {
        if (result.memory.ai_family == AF_INET) {

            var socketAddressInet = UnsafePointer<sockaddr_in>(result.memory.ai_addr).memory
            let length = Int(INET_ADDRSTRLEN) + 2
            var buffer = [CChar](count: length, repeatedValue: 0)

            let ipAddressCString = inet_ntop(AF_INET, &socketAddressInet.sin_addr, &buffer, socklen_t(length))

            if let ipAddress = String.fromCString(ipAddressCString) {
                ipAddresses.append(ipAddress)
            } else {
                print("Unable to convert ipAddress c-string to string")
            }
        } else if (result.memory.ai_family == AF_INET6) {

            var socketAddressInet6 = UnsafePointer<sockaddr_in6>(result.memory.ai_addr).memory
            let length = Int(INET6_ADDRSTRLEN) + 2
            var buffer = [CChar](count: length, repeatedValue: 0)

            let ipAddressCString = inet_ntop(AF_INET6, &socketAddressInet6.sin6_addr, &buffer, socklen_t(length))

            if let ipAddress = String.fromCString(ipAddressCString) {
                ipAddresses.append(ipAddress)
            } else {
                print("Unable to convert ipAddress c-string to string")
            }
        }
    }

    freeaddrinfo(results)

    return ipAddresses
}

func hostnameToAddress(hostname: String) -> [SocketAddress]? {

    var hints = addrinfo(ai_flags: 0,
        ai_family: AF_UNSPEC,
        ai_socktype: SOCK_STREAM,
        ai_protocol: IPPROTO_TCP,
        ai_addrlen: 0,
        ai_canonname: nil,
        ai_addr: nil,
        ai_next: nil)

    var results = UnsafeMutablePointer<addrinfo>()

    guard hostname.withCString({ cshostname in getaddrinfo(cshostname, nil, &hints, &results) }) == 0 else {
        return nil
    }

    var addresses: [SocketAddress] = [SocketAddress]()

    for var result = results; result != nil; result = result.memory.ai_next {
        if (result.memory.ai_family == AF_INET) {

            let socketAddressInet = UnsafePointer<sockaddr_in>(result.memory.ai_addr).memory

            let socketAddress = SocketAddress4()
            socketAddress.sin = socketAddressInet

            addresses.append(socketAddress)
        } else if (result.memory.ai_family == AF_INET6) {

            let socketAddressInet6 = UnsafePointer<sockaddr_in6>(result.memory.ai_addr).memory

            let socketAddress = SocketAddress6()
            socketAddress.sin6 = socketAddressInet6

            addresses.append(socketAddress)
        }
    }
    
    freeaddrinfo(results)
    
    return addresses
}
