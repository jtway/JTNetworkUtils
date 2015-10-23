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

// MARK: - IP Header

public struct IPHeader {
    var versionAndHeaderLength: UInt8   = 0
    var differentiatedServices: UInt8   = 0
    var totalLength:            UInt16  = 0
    var identification:         UInt16  = 0
    var flagsAndFragmentOffset: UInt16  = 0
    var timeToLive:             UInt8   = 0
    var ipProtocol:             UInt8   = 0
    var headerChecksum:         UInt16  = 0
    var sourceAddress:          in_addr = in_addr()
    var destinationAddress:     in_addr = in_addr()
}

public struct IP6Header {
    var versionAndTCAndFlow: UInt32   = 0
    var payloadLength:       UInt16   = 0
    var nextHeader:          UInt8    = 0
    var hopLimit:            UInt8    = 0
    var sourceAddress:       in6_addr = in6_addr()
    var destinationAddress:  in6_addr = in6_addr()

}

public struct PingResponse {
    public enum Result: UInt32 {
        case Success
        case Timeout
        case BadResponse
        case UnableToResolve
        case Error
    }

    init(host: Host, latency: Double) {
        self.host = host
        self.latency = latency
    }

    var host: Host
    var latency: Double = -1
    var result: Result = .Error
}

public func ==(lhs: Ping, rhs: Ping) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

public class Ping: Hashable {

    // MARK: - Ping enums

    public enum PingError: ErrorType {
        case NoSocketAddress
        case NoDispatchSource
        case BadFileDescriptor
        case Failed
        case FailedEndOfFile
        case InvalidPingResponse
        case POSIXErrorCode(posixError: Int32)
    }

    public enum ICMPType: UInt8 {
        case EchoReply   = 0
        case EchoRequest = 8
    }

    public enum ICMP6Type: UInt8 {
        case EchoRequest = 128
        case EchoReply   = 129
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
        var count:               UInt16 = 1
    }

    // MARK: - ICMP Echo Header

    public struct ICMPEchoHeader {
        var type:           UInt8  = 0
        var code:           UInt8  = 0
        var checksum:       UInt16 = 0
        var identifier:     UInt16 = 0
        var sequenceNumber: UInt16 = 0
    }

    struct ICMPv6PseudoHeader {
        var sourceAddress:       in6_addr = in6_addr()
        var destinationAddress:  in6_addr = in6_addr()
        var packetLength:          UInt32 = 0
        var checksumAndNextHeader: UInt32 = 0
    }

    // MARK: - completion handlers

    public typealias PingResponseHandler = (response: PingResponse) -> Void
    public typealias PingCompletionHandler = (responses: [PingResponse]) -> Void

    // MARK: - Public Properties

    /// A dispatch queue to read ping responses on
    public var dispatchQueue: dispatch_queue_t = dispatch_get_main_queue()
    public var configuration: Configuration = Configuration()

    // MARK: - Private Properties

    /// A dispatch source for reading data from the UDP socket.
    private var responseSource: dispatch_source_t?

    // Perhaps this should be moved into the configuraiton?
    private let identifier: UInt16 = UInt16(arc4random_uniform(UInt32(UINT16_MAX)))

    private var nextSequenceNumber: UInt16 = 1
    private var pingSentTime: NSTimeInterval = 0

    public var completionHandler: PingCompletionHandler!
    public var pingResponseHandler: PingResponseHandler!

    private var host: Host

    /// convenience variable for storing the address family
    private var family = AF_INET

    private var responses: [PingResponse] = [PingResponse]()


    // MARK: - Hashable
    
    public var hashValue: Int {
        return host.hostname!.hashValue ^ Int(identifier)
    }

    // MARK: - Initializers

    public init(hostname: String) {
        host = Host(hostname: hostname)
    }

    public init(host: Host) {
        self.host = host
    }

    // MARK: - Ping start/stop public methods

    public func start() -> Bool {
        guard let socketAddress = host.socketAddress else {
            return false
        }

        family = socketAddress.family

        var socketFd : Int32 = -1

        switch family {
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

        var socketAddressStorage = sockaddr_storage()
        var socketAddressLength = socklen_t(sizeof(sockaddr_storage.self))

        // This seems a bit hacky but it appears to be the best way to get "this" the way we want
        if family == AF_INET {
            if let socketAddress4: SocketAddress4 = socketAddress as? SocketAddress4 {
                memcpy(&socketAddressStorage, &socketAddress4.sin, sizeof(sockaddr_in))
                socketAddressLength = socklen_t(socketAddress4.sin.sin_len)
            }
        } else {
            if let socketAddress6: SocketAddress6 = socketAddress as? SocketAddress6 {
                memcpy(&socketAddressStorage, &socketAddress6.sin6, sizeof(sockaddr_in6))
                socketAddressLength = socklen_t(socketAddress6.sin6.sin6_len)
            }
        }

        let connectResult = withUnsafePointer(&socketAddressStorage) {
            Darwin.connect(socketFd, UnsafePointer($0), socketAddressLength)
        }

        guard connectResult == 0 else {
            print("Unable to connect to destination.")
            if let errorString = String(UTF8String: strerror(errno)) {
                print("connect failed: \(errorString)")
            }
            return false
        }

        guard let newResponseSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(socketFd), 0, dispatchQueue) else {
            print("Unable to set dispatch read source")
            close(socketFd)
            return false
        }

        dispatch_source_set_cancel_handler(newResponseSource) {
            // a bit circular here. stop calls dispatch_cancel, which in turn calls this.
            print("closing udp socket for connection \(self.identifier)")
            self.stop()
        }

        dispatch_source_set_event_handler(newResponseSource) {
            // @TOOD How to catch the error and do something useful with it? This could get called down the road
            //   so start would have already returned.
            self.readData()
        }

        dispatch_resume(newResponseSource)
        responseSource = newResponseSource

        print("Sending ping to \(host.hostname!)")
        
        try! sendPing()

        return true
    }

    public func stop() {
        if let source: dispatch_source_t = self.responseSource {
            let UDPSocket = Int32(dispatch_source_get_handle(source))
            close(UDPSocket)

            // This causes stop to be called again.
            dispatch_source_cancel(source)
            responseSource = nil

            if completionHandler != nil {
                completionHandler(responses: responses)
            }
        }
    }

    // MARK: - Send Ping & Read Ping Response

    // We're async here so throw probably won't help us
    func sendPing() throws {

        guard let source = responseSource else {
            throw PingError.NoDispatchSource
        }

        let UDPSocket = Int32(dispatch_source_get_handle(source))

        guard UDPSocket >= 0 else {
            throw PingError.BadFileDescriptor
        }

        let packet = generateICMPPacket()

        // Send the packet.

        let sent = send(UDPSocket, packet.bytes, packet.length, 0)

        pingSentTime = NSDate().timeIntervalSince1970

        var error: Int32 = 0

        if sent < 0 {
            error = errno;
        }

        // Always increment the nextSequenceNumber
        nextSequenceNumber += 1;

        // Handle the results of the send.
        if sent <= 0 || sent != packet.length {
            if let errorString = String(UTF8String: strerror(errno)) {
                print("Unable to send ping: \(errorString)")
            } else {
                print("Unable to send ping")
            }

            if error == 0 {
                error = ENOBUFS
            }

            throw PingError.POSIXErrorCode(posixError: error)
        }

        if nextSequenceNumber <= configuration.count {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(configuration.intervalInMS) * Int64(NSEC_PER_MSEC)), dispatchQueue) {
                try! self.sendPing()
            }
        }
    }

    func readData() {
        var pingResponse = PingResponse(host: host, latency: -1)

        guard let socketAddress = host.socketAddress else {
            pingResponseHandler(response: pingResponse)
            stop()

            return
        }

        guard let source = self.responseSource else {
            print("Unable to get source")

            if pingResponseHandler != nil {
                pingResponseHandler(response: pingResponse)
            }
            stop()

            return
        }

        var socketAddressStorage = sockaddr_storage()
        var socketAddressLength = socklen_t(sizeof(sockaddr_storage.self))

        // This seems a bit hacky but it appears to be the best way to get "this" the way we want
        if family == AF_INET {
            if let socketAddress4: SocketAddress4 = socketAddress as? SocketAddress4 {
                memcpy(&socketAddressStorage, &socketAddress4.sin, sizeof(sockaddr_in))
            }
        } else {
            if let socketAddress6: SocketAddress6 = socketAddress as? SocketAddress6 {
                memcpy(&socketAddressStorage, &socketAddress6.sin6, sizeof(sockaddr_in6))
            }
        }

        let response = [UInt8](count: 4096, repeatedValue: 0)
        let UDPSocket = Int32(dispatch_source_get_handle(source))

        let pingResponseTime = NSDate().timeIntervalSince1970

        let bytesRead = withUnsafeMutablePointer(&socketAddressStorage) {
            recvfrom(UDPSocket, UnsafeMutablePointer<Void>(response), response.count, 0, UnsafeMutablePointer($0), &socketAddressLength)
        }

        var error: Int32 = 0

        if bytesRead < 0 {
            error = errno

            if error == 0 {
                error = ENOBUFS
            }

            if let errorString = String(UTF8String: strerror(error)) {
                print("recvfrom failed: \(errorString)")
            }

            responses.append(pingResponse)
            // @TODO Be more specific here, but I'm not sure I want to use an associated value enum for PingResponse.Result
            if pingResponseHandler != nil {
                pingResponseHandler(response: pingResponse)
            }
            self.stop()

            return
        }

        guard bytesRead > 0 else {
            print("recvfrom returned EOF")

            responses.append(pingResponse)
            if pingResponseHandler != nil {
                pingResponseHandler(response: pingResponse)
            }
            self.stop()

            return
        }

        let responseDatagram = NSData(bytes: UnsafePointer<Void>(response), length: bytesRead)

        if !self.isValidPingResponsePacket(responseDatagram.mutableCopy() as! NSMutableData) {

            pingResponse.result = .BadResponse
            if pingResponseHandler != nil {
                pingResponseHandler(response: pingResponse)
            }

            // Stop, aka close the socket
            self.stop()

            return
        }

        pingResponse.result = .Success
        pingResponse.latency = (pingResponseTime - self.pingSentTime) * 1000.0

        responses.append(pingResponse)
        
        if pingResponseHandler != nil {
            pingResponseHandler(response: pingResponse)
        }

        if nextSequenceNumber > configuration.count {
            stop()
        }
    }

    // MARK: - Utility methods

    func generateICMPPacket() -> NSData {

        // Construct the ping packet.

        let payLoadLength = Int(configuration.payloadSizeInBytes) - sizeof(ICMPEchoHeader.self)
        let payload : NSMutableData = NSMutableData(length: payLoadLength)!

        SecRandomCopyBytes(kSecRandomDefault, payload.length, UnsafeMutablePointer<UInt8>(payload.mutableBytes))

        // @TODO Should probably use guard
        let packet : NSMutableData = NSMutableData(length: sizeof(ICMPEchoHeader.self) + payload.length)!

        // The following is normally done by using the bytes from the mutable packet directly.
        //   This has the effect of saving the additional 8 bytes that will need to be copied to the final packet.
        //   With that in mind for code readabilty we're going to copy the header and payload into the final packet.
        var icmpEchoPacket = ICMPEchoHeader()

        if host.socketAddress?.family == AF_INET6 {
            icmpEchoPacket.type = ICMP6Type.EchoRequest.rawValue
        } else {
            icmpEchoPacket.type = ICMPType.EchoRequest.rawValue
        }

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

        let icmpHeaderOffset: Int

        if (family == AF_INET) {
            icmpHeaderOffset = Ping.icmpHeaderOffsetInPacket(packet)
        } else {
            // The IP header is not passed back from ICMPv6 using UDP
            icmpHeaderOffset = 0
        }

        if icmpHeaderOffset == NSNotFound {
            return false
        }

        let icmpHeaderPtr : UnsafePointer<ICMPEchoHeader> = UnsafePointer<ICMPEchoHeader>(packet.mutableBytes + icmpHeaderOffset)

        var icmpHeader: ICMPEchoHeader = icmpHeaderPtr.memory

        let receivedCheckSum: UInt16 = icmpHeader.checksum
        icmpHeader.checksum = 0

        memcpy(UnsafeMutablePointer<Void>(icmpHeaderPtr), &icmpHeader, sizeof(ICMPEchoHeader.self))

        if (family == AF_INET) {
            let calculatedCheckSum: UInt16 = Ping.checksumIn(packet.mutableBytes + icmpHeaderOffset, length: packet.length - icmpHeaderOffset)

            if receivedCheckSum != calculatedCheckSum {
                print("Received checksum (\(receivedCheckSum)) and calculated checksum (\(calculatedCheckSum)) do not match")
                return false
            }

            if ICMPType(rawValue: icmpHeader.type) != .EchoReply {
                print ("Did not receive an icmp packet with echo reply for the type")
                return false
            }
        } else {
            if ICMP6Type(rawValue: icmpHeader.type) != .EchoReply {
                print ("Did not receive an icmpv6 packet with echo reply for the type")
                return false
            }
        }

        if icmpHeader.code != 0 {
            print("Expected icmp header code of 0, got \(icmpHeader.code)")
            return false
        }

        if identifier != CFSwapInt16BigToHost(icmpHeader.identifier) {
            print("Identifier did not match our identifier. Ours: \(identifier), theirs: \(CFSwapInt16BigToHost(icmpHeader.identifier))")
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

        let expectedLength: Int = sizeof(IPHeader.self) + sizeof(Ping.ICMPEchoHeader.self)

        if packet.length < expectedLength {
            print("Ping response was too small. Was only \(packet.length) bytes")
            return NSNotFound
        }

        let ipHeader = UnsafePointer<IPHeader>(packet.bytes).memory

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

        // Our algorithm is simple, using a 32 bit accumulator (sum), we add sequential 16 bit words to it, 
        // and at the end, fold back all the carry bits from the top 16 bits into the lower 16 bits.
        var index: Int = 0

        while bytesRemaining > 1 {
            sum += Int32(cursor[index])
            
            index++
            bytesRemaining -= 2
        }
        
        // mop up an odd byte, if necessary
        if bytesRemaining == 1 {
            // @TODO How the heck should I do this without creating another unsafe pointer?
            print("We should do something here")
        }
        
        // add back carry outs from top 16 bits to low 16 bits
        sum = (sum >> 16) + (sum & 0xffff);	// add hi 16 to low 16
        sum += (sum >> 16);			        // add carry
        
        let answer : UInt16 = UInt16(sum)
        
        return ~answer;
    }
}
