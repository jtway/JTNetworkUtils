//
//  SocketAddress.swift
//  JTNetworkUtilities
//
//  Created by Josh Tway on 9/24/15.
//  Sourced from: https://developer.apple.com/library/ios/samplecode/SimpleTunnel/Introduction/Intro.html#//apple_ref/doc/uid/TP40016140
//

import Foundation

public protocol SocketAddress {

    var stringValue: String? { get }

    var family: Int32 { get }

    func setFromString(str: String) -> Bool

    func setPort(port: Int)
}

/// A object containing a sockaddr_in6 structure.
public class SocketAddress6: SocketAddress {

    // MARK: Properties

    /// The sockaddr_in6 structure.
    public var sin6: sockaddr_in6

    /// The IPv6 address as a string.
    public var stringValue: String? {
        return withUnsafePointer(&sin6) { saToString(UnsafePointer<sockaddr>($0)) }
    }

    public var family: Int32 {
        return AF_INET6
    }

    // MARK: Initializers

    public init() {
        sin6 = sockaddr_in6()
        sin6.sin6_len = __uint8_t(sizeof(sockaddr_in6))
        sin6.sin6_family = sa_family_t(AF_INET6)
        sin6.sin6_port = in_port_t(0)
        sin6.sin6_addr = in6addr_any
        sin6.sin6_scope_id = __uint32_t(0)
        sin6.sin6_flowinfo = __uint32_t(0)
    }

    public convenience init(otherAddress: SocketAddress6) {
        self.init()
        sin6 = otherAddress.sin6
    }

    /// Set the IPv6 address from a string.
    public func setFromString(str: String) -> Bool {
        return str.withCString({ cs in inet_pton(AF_INET6, cs, &sin6.sin6_addr) }) == 1
    }

    /// Set the port.
    public func setPort(port: Int) {
        sin6.sin6_port = in_port_t(UInt16(port).bigEndian)
    }
}

/// An object containing a sockaddr_in structure.
public class SocketAddress4: SocketAddress {

    // MARK: Properties

    /// The sockaddr_in structure.
    public var sin: sockaddr_in

    /// The IPv4 address in string form.
    public var stringValue: String? {
        return withUnsafePointer(&sin) { saToString(UnsafePointer<sockaddr>($0)) }
    }

    public var family: Int32 {
        return AF_INET
    }

    // MARK: Initializers

    public init() {
        sin = sockaddr_in(sin_len:__uint8_t(sizeof(sockaddr_in.self)), sin_family:sa_family_t(AF_INET), sin_port:in_port_t(0), sin_addr:in_addr(s_addr: 0), sin_zero:(Int8(0), Int8(0), Int8(0), Int8(0), Int8(0), Int8(0), Int8(0), Int8(0)))
    }

    public convenience init(otherAddress: SocketAddress4) {
        self.init()
        sin = otherAddress.sin
    }

    /// Set the IPv4 address from a string.
    public func setFromString(str: String) -> Bool {
        return str.withCString({ cs in inet_pton(AF_INET, cs, &sin.sin_addr) }) == 1
    }

    /// Set the port.
    public func setPort(port: Int) {
        sin.sin_port = in_port_t(UInt16(port).bigEndian)
    }

    /// Increment the address by a given amount.
    public func increment(amount: UInt32) {
        let networkAddress = sin.sin_addr.s_addr.byteSwapped + amount
        sin.sin_addr.s_addr = networkAddress.byteSwapped
    }

    /// Get the difference between this address and another address.
    public func difference(otherAddress: SocketAddress4) -> Int64 {
        return Int64(sin.sin_addr.s_addr.byteSwapped - otherAddress.sin.sin_addr.s_addr.byteSwapped)
    }
}
