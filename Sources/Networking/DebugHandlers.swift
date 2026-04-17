//
//  DebugHandlers.swift
//  Networking
//
//  Created by Connor Gibbons  on 4/17/26.
//
import NIOCore
import NIOPosix
import Foundation

final class DebugInboundHandler: @unchecked Sendable, ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer
    
    init() {}
    
    func channelRegistered(context: ChannelHandlerContext) {
        print("I: Channel Registered To Event Loop: \(context.name)")
        context.fireChannelRegistered()
    }
    
    func channelUnregistered(context: ChannelHandlerContext) {
        print("I: Channel Unregistered From Event Loop: \(context.name)")
        context.fireChannelUnregistered()
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        print("I: Channel Read: \(buffer.readableBytes) bytes")
        context.fireChannelRead(data)
    }
    
    func channelReadComplete(context: ChannelHandlerContext) {
        print("I: Channel Read Complete")
        context.fireChannelReadComplete()
    }
    
    func channelWritabilityChanged(context: ChannelHandlerContext) {
        print("I: Channel Writability Changed: isWritable=\(context.channel.isWritable)")
        context.fireChannelWritabilityChanged()
    }
    
    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        print("I: User Inbound Event Triggered: \(event)")
        context.fireUserInboundEventTriggered(event)
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("I: Error Caught: \(error)")
        context.fireErrorCaught(error)
    }
    
}

final class DebugOutboundHandler: @unchecked Sendable, ChannelOutboundHandler {
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer
    
    init() {}
    
    func register(context: ChannelHandlerContext, promise: EventLoopPromise<Void>?) {
        print("O: Register")
        context.register(promise: promise)
    }
    
    func bind(context: ChannelHandlerContext, to address: SocketAddress, promise: EventLoopPromise<Void>?) {
        print("O: Bind: \(address)")
        context.bind(to: address, promise: promise)
    }
    
    func connect(context: ChannelHandlerContext, to address: SocketAddress, promise: EventLoopPromise<Void>?) {
        print("O: Connect: \(address)")
        context.connect(to: address, promise: promise)
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let buffer = unwrapOutboundIn(data)
        let stringData = String(data: Data(buffer.readableBytesView), encoding: .utf8)
        print("O: Write: \(buffer.readableBytes) bytes: \(stringData!)")
        context.write(wrapOutboundOut(buffer), promise: promise)
    }
    
    func flush(context: ChannelHandlerContext) {
        print("O: Flush")
        context.flush()
    }
    
    func read(context: ChannelHandlerContext) {
        print("O: Ready to Read")
        context.read()
    }
    
    func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        print("O: Close: mode=\(mode)")
        context.close(mode: mode, promise: promise)
    }
    
    func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
        print("O: Trigger User Outbound Event: \(event)")
        context.triggerUserOutboundEvent(event, promise: promise)
    }
    
}
