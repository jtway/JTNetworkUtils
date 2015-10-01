//
//  Ping.swift
//  JTNetworkUtilities
//
//  Created by Josh Tway on 9/24/15.
//  Copyright © 2015 Josh Tway. All rights reserved.
//

import Foundation
import Dispatch
import Darwin

// @TODO Add ICMP6EchoHeader

// MARK: - IP Header

// @TODO Find a new home for this and fix sourceAddress and destinationAddress (in C they are both an array of 4 uint8_t)
public struct IPHeader {
    var versionAndHeaderLength: UInt8  = 0
    var differentiatedServices: UInt8  = 0
    var totalLength:            UInt16 = 0
    var identification:         UInt16 = 0
    var flagsAndFragmentOffset: UInt16 = 0
    var timeToLive:             UInt8  = 0
    var ipProtocol:             UInt8  = 0
    var headerChecksum:         UInt16 = 0
    var sourceAddress:          UInt64 = 0
    var destinationAddress:     UInt64 = 0
}

public struct PingResponse {
    init(hostname: String, ipAddress: String, latency: Double) {
        self.hostname = hostname
        self.ipAddress = ipAddress
        self.latency = latency
    }

    var hostname: String
    var ipAddress: String
    var latency: Double = 0
}

public class Ping {

    // MARK: - Ping enums

    public enum PingError: ErrorType {
        case BadFileDescriptor
        case Failed
        case InvalidPingResponse
        case POSIXErrorCode(posixError: Int)
    }

    public enum ICMPType: UInt8 {
        case EchoReply = 0
        case EchoRequest = 8
    }

    // MARK: - Ping Configuration

    public struct Configuration {

        /// Interval in milliseconds between pings. Must be between 100ms and 60000ms (1 minute)
        var intervalInMS: UInt32 = 1000 {
            didSet {
                if intervalInMS < 100 {
                    intervalInMS = 100
                } else if intervalInMS > 60000 {
                    intervalInMS = 60000
                }
            }
        }

        var timeoutInSeconds:    Double = 10.0 // unused (should be though)
        var timeToLiveInSeconds: UInt32 = 0    // unused (should be though)
        var payloadSizeInBytes:  UInt16 = 64
        var count:               UInt32 = 1
    }

    // MARK: - ICMP Echo Header

    public struct ICMPEchoHeader {
        var type: UInt8 = 0
        var code: UInt8 = 0
        var checksum: UInt16 = 0
        var identifier: UInt16 = 0
        var sequenceNumber: UInt16 = 0
    }

    // MARK: - completion handlers

    public typealias PingResponseHandler = (ipAddress : String, latency : NSTimeInterval) -> Void
    public typealias PingCompletionHandler = (ipAddress : String, avgLatency : NSTimeInterval, successful : UInt, dropped : UInt) -> Void

    // MARK: - Public Properties

    /// A dispatch queue to read ping responses on
    public var dispatchQueue: dispatch_queue_t = dispatch_get_main_queue()
    public var configuration: Configuration = Configuration()

    // MARK: - Private Properties

    /// A dispatch source for reading data from the UDP socket.
    private var responseSource: dispatch_source_t?

    private let identifier: UInt16 = UInt16(arc4random_uniform(UInt32(UINT16_MAX)))
    private var nextSequenceNumber: UInt16 = 1
    private var pingSentTime: NSTimeInterval = 0

    private var completionHandler: PingCompletionHandler!
    private var pingResponseHandler: PingResponseHandler!

    private var hostname: String!
    private var hostIPAddress: String!

    private var socketAddress: SocketAddress!

    private var hostAddress: NSData!
    private var host: CFHostRef!
    private var socketFd: Int32 = -1

    // MARK: - Initializers

    public init(hostname: String) {
        self.hostname = hostname
    }

    // MARK: - Ping start/stop public methods

    public func start(responseHandler: PingResponseHandler) -> Bool {

        pingResponseHandler = responseHandler

        // @TODO Create a host class that is similar to NSHost
        let addresses = hostnameToAddress(hostname)

        socketAddress = addresses?.first

        guard socketAddress != nil else {
            return false
        }

        var socketFd : Int32 = -1
        switch socketAddress.family {
        case AF_INET:
            socketFd = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        case AF_INET6:
            socketFd = Darwin.socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6)
        default:
            break
        }

        // @TODO error handling
        guard socketFd > 0 else {
            print("Unable to create socket for ping")
            return false
        }

        guard let newResponseSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(socketFd), 0, dispatchQueue) else {
            print("Unable to set dispatch read source")
            close(socketFd)
            return false
        }

        dispatch_source_set_cancel_handler(newResponseSource) {
            print("closing udp socket for connection \(self.identifier)")
            self.stop()
        }

        dispatch_source_set_event_handler(newResponseSource) {
            self.readData()
        }

        dispatch_resume(newResponseSource)
        responseSource = newResponseSource

        print("Sending ping")
        
        try! sendPing()

        return true
    }

    public func stop() {
        close(socketFd)
        
        if let source = responseSource {
            dispatch_source_cancel(source)
            responseSource = nil
        }
    }

    // MARK: - Send Ping & Read Ping Response

    func sendPing() throws {

        var sent: Int = -1
        var error: Int32 = 0

        guard let source = responseSource else {
            return
        }

        let UDPSocket = Int32(dispatch_source_get_handle(source))

        guard UDPSocket >= 0 else {
            sent = -1
            throw PingError.BadFileDescriptor
        }

        let packet = generateICMPPacket()

        print(packet)

        // Send the packet.

        if hostname == nil {
            hostname = socketAddress.stringValue
        }

        if socketAddress.family == AF_INET {
            if let socketAddress4: SocketAddress4 = self.socketAddress as? SocketAddress4 {
                sent = withUnsafePointer(&socketAddress4.sin) {
                    sendto(UDPSocket, packet.bytes, packet.length, 0, UnsafePointer($0), socklen_t(socketAddress4.sin.sin_len))
                }
            }
        } else if socketAddress.family == AF_INET6 {
            if let socketAddress6: SocketAddress6 = self.socketAddress as? SocketAddress6 {
                sent = withUnsafePointer(&socketAddress6.sin6) {
                    sendto(UDPSocket, packet.bytes, packet.length, 0, UnsafePointer($0), socklen_t(socketAddress6.sin6.sin6_len))
                }
            }
        }

        pingSentTime = NSDate().timeIntervalSince1970

        error = 0;
        if sent < 0 {
            error = errno;
        }

        // Always increment the nextSequenceNumber
        nextSequenceNumber += 1;

        // Handle the results of the send.
        if sent <= 0 || sent != packet.length {
            print("Unable to send ping")
            if error == 0 {
                error = ENOBUFS
            }
            return
        }
    }

    func readData() {
        guard let source = self.responseSource else {
            print("Unable to get source")
            return
        }

        var socketAddress = sockaddr_storage()
        var socketAddressLength = socklen_t(sizeof(sockaddr_storage.self))

        // This seems a bit hacky but it appears to be the best way to get "this" the way we want
        if self.socketAddress.family == AF_INET {
            if let socketAddress4: SocketAddress4 = self.socketAddress as? SocketAddress4 {
                memcpy(&socketAddress, &socketAddress4.sin, sizeof(sockaddr_in))
            }
        } else {
            if let socketAddress6: SocketAddress6 = self.socketAddress as? SocketAddress6 {
                memcpy(&socketAddress, &socketAddress6.sin6, sizeof(sockaddr_in6))
            }
        }

        let response = [UInt8](count: 4096, repeatedValue: 0)
        let UDPSocket = Int32(dispatch_source_get_handle(source))

        let pingResponseTime = NSDate().timeIntervalSince1970

        let bytesRead = withUnsafeMutablePointer(&socketAddress) {
            recvfrom(UDPSocket, UnsafeMutablePointer<Void>(response), response.count, 0, UnsafeMutablePointer($0), &socketAddressLength)
        }

        guard bytesRead >= 0 else {
            if let errorString = String(UTF8String: strerror(errno)) {
                print("recvfrom failed: \(errorString)")
            }
            self.stop()
            return
        }

        guard bytesRead > 0 else {
            print("recvfrom returned EOF")
            self.stop()
            return
        }

        guard let endpoint = withUnsafePointer(&socketAddress, { self.getEndpointFromSocketAddress(UnsafePointer($0)) }) else {
            print("Failed to get the address and port from the socket address received from recvfrom")
            self.stop()
            return
        }

        let responseDatagram = NSData(bytes: UnsafePointer<Void>(response), length: bytesRead)
        print("UDP connection id \(self.identifier) received = \(bytesRead) bytes from host = \(endpoint.host) port = \(endpoint.port)")

        let host = (self.hostname != nil ? self.hostname : self.hostIPAddress)

        if !self.isValidPingResponsePacket(responseDatagram.mutableCopy() as! NSMutableData) {
            print("Did not receive a valid ping response")

            // Stop, aka close the socket
            self.stop()
            // Call ping response handler with negative time.
            self.pingResponseHandler(ipAddress: host, latency: -1)
            // @TODO Should I throw an error here? (Wish they would have called it emit error...)

            return
        }

        let latency = (pingResponseTime - self.pingSentTime) * 1000.0

        self.pingResponseHandler(ipAddress: host, latency: latency)
    }

    // MARK: - Utility methods

    /// Convert a sockaddr structure into an IP address string and port.
    func getEndpointFromSocketAddress(socketAddressPointer: UnsafePointer<sockaddr>) -> (host: String, port: Int)? {
        let socketAddress = UnsafePointer<sockaddr>(socketAddressPointer).memory

        switch Int32(socketAddress.sa_family) {
        case AF_INET:
            var socketAddressInet = UnsafePointer<sockaddr_in>(socketAddressPointer).memory
            let length = Int(INET_ADDRSTRLEN) + 2
            var buffer = [CChar](count: length, repeatedValue: 0)
            let hostCString = inet_ntop(AF_INET, &socketAddressInet.sin_addr, &buffer, socklen_t(length))
            let port = Int(UInt16(socketAddressInet.sin_port).byteSwapped)
            return (String.fromCString(hostCString)!, port)

        case AF_INET6:
            var socketAddressInet6 = UnsafePointer<sockaddr_in6>(socketAddressPointer).memory
            let length = Int(INET6_ADDRSTRLEN) + 2
            var buffer = [CChar](count: length, repeatedValue: 0)
            let hostCString = inet_ntop(AF_INET6, &socketAddressInet6.sin6_addr, &buffer, socklen_t(length))
            let port = Int(UInt16(socketAddressInet6.sin6_port).byteSwapped)
            return (String.fromCString(hostCString)!, port)

        default:
            return nil
        }
    }

    func generateICMPPacket() -> NSData {

        // Construct the ping packet.
        // @TODO Should probably use guard
        let payLoadLength = Int(configuration.payloadSizeInBytes) - sizeof(ICMPEchoHeader.self)
        let payload : NSMutableData = NSMutableData(length: payLoadLength)!

        SecRandomCopyBytes(kSecRandomDefault, payload.length, UnsafeMutablePointer<UInt8>(payload.mutableBytes))

        // @TODO Should probably use guard
        let packet : NSMutableData = NSMutableData(length: sizeof(ICMPEchoHeader.self) + payload.length)!

        // The following is normally done by using the bytes from the mutable packet directly.
        //   This has the effect of saving the additional 8 bytes that will need to be copied to the final packet.
        //   With that in mind for code readabilty we're going to copy the header and payload into the final packet.
        var icmpEchoPacket = ICMPEchoHeader()

        icmpEchoPacket.type = ICMPType.EchoRequest.rawValue
        icmpEchoPacket.code = 0
        icmpEchoPacket.checksum = 0
        icmpEchoPacket.identifier = CFSwapInt16HostToBig(identifier)
        icmpEchoPacket.sequenceNumber = CFSwapInt16HostToBig(nextSequenceNumber)


        memcpy(UnsafeMutablePointer<Void>(packet.mutableBytes), &icmpEchoPacket, sizeof(ICMPEchoHeader.self))
        memcpy(UnsafeMutablePointer<Void>(packet.mutableBytes) + sizeof(ICMPEchoHeader.self), payload.bytes, payload.length)

        // The IP checksum returns a 16-bit number that's already in correct byte order
        // (due to wacky 1's complement maths), so we just put it into the packet as a
        // 16-bit unit.
        icmpEchoPacket.checksum = Ping.checksumIn(packet.mutableBytes, length: packet.length)
        memcpy(UnsafeMutablePointer<Void>(packet.mutableBytes), &icmpEchoPacket, sizeof(ICMPEchoHeader.self))

        return packet
    }

    func isValidPingResponsePacket(packet: NSMutableData) -> Bool {

        print("Validating ping response")
        let icmpHeaderOffset: Int = Ping.icmpHeaderOffsetInPacket(packet)
        if icmpHeaderOffset == NSNotFound {
            return false
        }

        print("Found ping offset: \(icmpHeaderOffset)")
        let icmpHeaderPtr : UnsafePointer<ICMPEchoHeader> = UnsafePointer<ICMPEchoHeader>(packet.mutableBytes + icmpHeaderOffset)

        var icmpHeader: ICMPEchoHeader = icmpHeaderPtr.memory

        let receivedCheckSum: UInt16 = icmpHeader.checksum
        icmpHeader.checksum = 0

        memcpy(UnsafeMutablePointer<Void>(icmpHeaderPtr), &icmpHeader, sizeof(Ping.ICMPEchoHeader.self))

        let calculatedCheckSum: UInt16 = Ping.checksumIn(packet.mutableBytes + icmpHeaderOffset, length: packet.length - icmpHeaderOffset)

        if receivedCheckSum != calculatedCheckSum {
            print("Received checksum (\(receivedCheckSum)) and calculated checksum (\(calculatedCheckSum)) do not match")
            return false
        }

        if ICMPType(rawValue: icmpHeader.type) != .EchoReply {
            print ("Did not receive an icmp packet with echo reply for the type")
            return false
        }

        if icmpHeader.code != 0 {
            print("Expected icmp header code of 0, got \(icmpHeader.code)")
            return false
        }

        if identifier != CFSwapInt16BigToHost(icmpHeader.identifier) {
            print("Identifier did not match our identifier")
            return false
        }

        let receivedSequenceNumber = CFSwapInt16BigToHost(icmpHeader.sequenceNumber)
        if nextSequenceNumber <= receivedSequenceNumber {
            print("Invalid sequence number received. Next Sequence Number: \(nextSequenceNumber), received: \(receivedSequenceNumber)")
            return false
        }

        return true
    }

    // MARK: - Static member utilities
    
    static func icmpHeaderOffsetInPacket(packet: NSData) -> Int {
        // Returns the offset of the ICMPHeader within an IP packet.

        print("Size of IPHeader: \(sizeof(IPHeader.self)), size of ICMPEchoHeader: \(sizeof(Ping.ICMPEchoHeader.self))")

        let expectedLength: Int = sizeof(IPHeader.self) + sizeof(Ping.ICMPEchoHeader.self)

        print("Expected at least \(expectedLength) bytes, packet is \(packet.length) bytes")

        if packet.length < expectedLength {
            print("Ping response was too small. Was only \(packet.length) bytes")
            return NSNotFound
        }

        print("Grabbing IP Header. Packet bytes: \(packet.bytes)")
        let ipHeader = UnsafePointer<IPHeader>(packet.bytes).memory
        print(ipHeader)
        if (ipHeader.versionAndHeaderLength & 0xF0) != 0x40 {
            print("Version mismatch")
            return NSNotFound
        }

        if ipHeader.ipProtocol != 1 {
            print("Unexpected protocol")
            return NSNotFound
        }

        let ipHeaderLength = Int(ipHeader.versionAndHeaderLength & 0x0F) * sizeof(UInt32)
        if packet.length < ipHeaderLength + sizeof(Ping.ICMPEchoHeader.self) {
            print("Packet length too small")
            return NSNotFound
        }

        print("IP Header length: \(ipHeaderLength)")
        return ipHeaderLength
    }

    static func icmpInPacket(packet: NSData) -> ICMPEchoHeader {
        let header : ICMPEchoHeader = ICMPEchoHeader()

        return header
    }

    static func checksumIn(buffer : UnsafePointer<Void>, length : size_t) -> UInt16 {

        // This is the standard BSD checksum code, modified to use modern types.

        var sum : Int32 = 0
        var bytesRemaining = length

        let cursor : UnsafePointer<UInt16> = UnsafePointer<UInt16>(buffer)

        /*
        * Our algorithm is simple, using a 32 bit accumulator (sum), we add
        * sequential 16 bit words to it, and at the end, fold back all the
        * carry bits from the top 16 bits into the lower 16 bits.
        */
        var index: Int = 0
        while bytesRemaining > 1 {
            //            print("\(cursor[index] as UInt16)")
            sum += Int32(cursor[index])
            
            index++
            bytesRemaining -= 2
        }
        
        /* mop up an odd byte, if necessary */
        if bytesRemaining == 1 {
            // @TODO How the heck should I do this without creating another unsafe pointer?
            print("We should do something here")
        }
        
        /* add back carry outs from top 16 bits to low 16 bits */
        sum = (sum >> 16) + (sum & 0xffff);	/* add hi 16 to low 16 */
        sum += (sum >> 16);			/* add carry */
        
        let answer : UInt16 = UInt16(sum)
        
        return ~answer;
    }
}
