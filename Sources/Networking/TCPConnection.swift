//
//  Connection.swift
//  Networking
//
//  Created by Connor Gibbons  on 4/17/26.
//
import NIOCore
import NIOPosix
import Foundation

public final class TCPConnection: @unchecked Sendable {
    private let channel: Channel
    private var active: Bool {
        return channel.isActive
    }
    
    public let connectionName: String
    
    public init(onRead: @Sendable @escaping (Data) -> Void, onActive: @Sendable @escaping () -> Void = {}, onInactive: @Sendable @escaping () -> Void = {}, host: String, port: Int, debug: Bool = false) async throws {
        let bootstrap = ClientBootstrap(group: globalManager.group)
        let handler = ConnectionInboundHandler(onRead: TCPConnection.generateCallback(onRead), onActive: onActive, onInactive: onInactive)
        
        self.connectionName = TCPConnection.generateConnectionName(host: host, port: port)
        self.channel = try await bootstrap
            .channelInitializer { channel in
                if(debug) {
                    return channel.pipeline.addHandlers([DebugInboundHandler(),DebugOutboundHandler(),handler])
                }
                return channel.pipeline.addHandler(handler)
            }
            .connect(host: host, port: port)
            .get()
    }
    
    public init(onRead: @Sendable @escaping (Data) -> Void, onActive: @Sendable @escaping () -> Void = {}, onInactive: @Sendable @escaping () -> Void = {}, host: String, port: Int, debug: Bool = false) throws {
        let bootstrap = ClientBootstrap(group: globalManager.group)
        let handler = ConnectionInboundHandler(onRead: TCPConnection.generateCallback(onRead), onActive: onActive, onInactive: onInactive)
        
        self.connectionName = TCPConnection.generateConnectionName(host: host, port: port)
        self.channel = try bootstrap
            .channelInitializer { channel in
                if(debug) {
                    return channel.pipeline.addHandlers([DebugInboundHandler(),DebugOutboundHandler(),handler])
                }
                return channel.pipeline.addHandler(handler)
            }
            .connect(host: host, port: port)
            .wait()
    }
    
    
    
    init(channel: Channel, connectionName: String) {
        self.channel = channel
        self.connectionName = connectionName
    }
    
    /// Transforms the (Data) -> Void user provided callback to (ByteBuffer) -> Void for ChannelInboundHandler
    private static func generateCallback(_ callback: @Sendable @escaping (Data) -> Void) -> (ByteBuffer) -> Void {
        return { buffer in
            let bufferAsData = Data(buffer.readableBytesView) // This does do a copy
            callback(bufferAsData)
        }
    }
    
    private static func generateConnectionName(host: String, port: Int) -> String {
        return "\(host):\(port)"
    }
    
    public func send(_ data: Data) async throws {
        let dataAsByteBuffer = self.channel.allocator.buffer(bytes: data)
        try await self.channel.writeAndFlush(dataAsByteBuffer)
    }
    
    /// Non-async overload for where it's not practical. Will block until writeAndFlush returns.
    public func send(_ data: Data) throws {
        let dataAsByteBuffer = self.channel.allocator.buffer(bytes: data)
        try self.channel.writeAndFlush(dataAsByteBuffer).wait()
    }
    
    public func sendLine(_ text: String) async throws {
        let textAsData = Data((text + "\r\n").utf8)
        try await self.send(textAsData)
    }
    
    public func sendLine(_ text: String) throws {
        let textAsData = Data((text + "\r\n").utf8)
        try self.send(textAsData)
    }
    
    public func close() async throws {
        if(self.active) {
            try await self.channel.close()
        }
    }
    
    public func close() {
        if(self.active) {
            self.channel.close(promise: nil)
        }
    }
    
    deinit {
        self.close()
    }
    
}

/// -- Relevant info from SwiftNIO docs ---
/// Despite the fact that `channelRead` is one of the methods on this protocol, you should avoid assuming that "inbound" events are to do with
/// reading from channel sources. Instead, "inbound" events are events that originate *from* the channel source (e.g. the socket): that is, events that the
/// channel source tells you about. This includes things like `channelRead` ("there is some data to read"), but it also includes things like
/// `channelWritabilityChanged` ("this source is no longer marked writable").
///
final class ConnectionInboundHandler: @unchecked Sendable, ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    
    var onRead: (ByteBuffer) -> Void
    var onActive: () -> Void
    var onInactive: () -> Void
    
    init(onRead: @escaping (ByteBuffer) -> Void, onActive: @escaping () -> Void, onInactive: @escaping () -> Void) {
        self.onRead = onRead
        self.onActive = onActive
        self.onInactive = onInactive
    }
    
    func setOnRead(_ onRead: @escaping (ByteBuffer) -> Void) {
        self.onRead = onRead
    }
    
    func setOnActive(_ onActive: @escaping () -> Void) {
        self.onActive = onActive
    }
    
    func setOnInactive(_ onInactive: @escaping () -> Void) {
        self.onInactive = onInactive
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        self.onRead(buffer)
        context.fireChannelRead(data)
    }
    
    func channelActive(context: ChannelHandlerContext) {
        self.onActive()
        context.fireChannelActive()
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        self.onInactive()
        context.fireChannelInactive()
    }
}
