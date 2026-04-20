//
//  TCPServer.swift
//  Networking
//
//  Created by Connor Gibbons  on 4/17/26.
//
import NIOCore
import NIOPosix
import Foundation

private class ConnectionList: @unchecked Sendable {
    var connections: [String: TCPConnection]
    var queue: DispatchQueue
    
    init() {
        self.connections = [:]
        self.queue = DispatchQueue(label: "TCP Server Connection List")
    }
    
    func connectionCount() -> Int {
        queue.sync {
            return self.connections.count
        }
    }
    func allConnections() -> [TCPConnection] {
        queue.sync {
            return Array(connections.values)
        }
    }
    func getConnection(id: String) -> TCPConnection? {
        queue.sync {
            self.connections[id]
        }
    }
    func addConnection(connection: TCPConnection) {
        _ = queue.sync {
            self.connections.updateValue(connection, forKey: connection.connectionName)
        }
    }
    func removeConnection(id: String) {
        _ = queue.sync {
            self.connections.removeValue(forKey: id)
        }
    }
}

public enum TCPServerErrors: Error {
    case connectionDoesNotExist
}

final class TCPServer: @unchecked Sendable {
    private let server: Channel
    private var connections: ConnectionList
    public let maxConnections: UInt
    public let port: UInt16
    
    public init(port: UInt16, maxConnections: UInt, actionOnNewConnection: @Sendable @escaping (TCPConnection) -> Void, actionOnReceive: @Sendable @escaping (String, Data) -> Void, debug: Bool = false) throws {
        self.port = port
        self.maxConnections = maxConnections
        let connections = ConnectionList.init()
        self.connections = connections
        self.server = try ServerBootstrap(group: globalManager.group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                let connectionName = channel.remoteAddress.map { "\($0)" } ?? "Unknown"
                
                let handler = ConnectionInboundHandler(
                    onRead: TCPServer.generateCallback(actionOnReceive, connectionName: connectionName),
                    onActive: {
                        if(connections.connectionCount() >= maxConnections) {
                            print("Failed to create new server connection, max connections reached (\(maxConnections))")
                            channel.close(promise: nil)
                            return
                        }
                        let newConnection = TCPConnection(channel: channel, connectionName: connectionName)
                        connections.addConnection(connection: newConnection)
                        actionOnNewConnection(newConnection)
                    },
                    onInactive: {
                        connections.removeConnection(id: connectionName)
                    }
                )
                if(debug) {
                    return channel.pipeline.addHandlers([DebugInboundHandler(), DebugOutboundHandler(), handler])
                }
                return channel.pipeline.addHandler(handler)
            }
            .bind(host: "0.0.0.0", port: Int(self.port))
            .wait()
    }
    
    public init(port: UInt16, maxConnections: UInt, actionOnNewConnection: @Sendable @escaping (TCPConnection) -> Void, actionOnReceive: @Sendable @escaping (String, Data) -> Void, debug: Bool = false) async throws {
        self.port = port
        self.maxConnections = maxConnections
        let connections = ConnectionList.init()
        self.connections = connections
        self.server = try await ServerBootstrap(group: globalManager.group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                let connectionName = channel.remoteAddress.map { "\($0)" } ?? "Unknown"
                
                let handler = ConnectionInboundHandler(
                    onRead: TCPServer.generateCallback(actionOnReceive, connectionName: connectionName),
                    onActive: {
                        if(connections.connectionCount() >= maxConnections) {
                            print("Failed to create new server connection, max connections reached (\(maxConnections))")
                            channel.close(promise: nil)
                            return
                        }
                        let newConnection = TCPConnection(channel: channel, connectionName: connectionName)
                        connections.addConnection(connection: newConnection)
                        actionOnNewConnection(newConnection)
                    },
                    onInactive: {
                        connections.removeConnection(id: connectionName)
                    }
                )
                if(debug) {
                    return channel.pipeline.addHandlers([DebugInboundHandler(), DebugOutboundHandler(), handler])
                }
                return channel.pipeline.addHandler(handler)
            }
            .bind(host: "0.0.0.0", port: Int(self.port))
            .get()
    }
    
    public func send(connectionName: String, data: Data) async throws {
        guard let connection = connections.getConnection(id: connectionName) else {
            print("Connection: \(connectionName) doesn't exist, can't send data")
            throw TCPServerErrors.connectionDoesNotExist
        }
        try await connection.send(data)
    }
    
    public func send(connectionName: String, data: Data) throws {
        guard let connection = connections.getConnection(id: connectionName) else {
            print("Connection: \(connectionName) doesn't exist, can't send data")
            throw TCPServerErrors.connectionDoesNotExist
        }
        try connection.send(data)
    }
    
   public func broadcast(data: Data) async {
        for connection in self.connections.allConnections() {
            do {
                try await connection.send(data)
            }
            catch {
                print("Failed to send data to connection \(connection.connectionName): \(error.localizedDescription)")
            }
        }
    }
    
    public func broadcast(data: Data) {
        for connection in self.connections.allConnections() {
            do {
                try connection.send(data)
            }
            catch {
                print("Failed to send data to connection \(connection.connectionName): \(error.localizedDescription)")
            }
        }
    }
    
    public func sendLine(connectionName: String, line: String, delimiter: String = "\r\n") async throws {
        let delimited = line + delimiter
        let data = Data(delimited.utf8)
        try await send(connectionName: connectionName, data: data)
    }
    
    public func sendLine(connectionName: String, line: String, delimiter: String = "\r\n") throws {
        let delimited = line + delimiter
        let data = Data(delimited.utf8)
        try send(connectionName: connectionName, data: data)
    }
    
    public func broadcastLine(line: String, delimiter: String = "\r\n") async {
        let delimited = line + delimiter
        let data = Data(delimited.utf8)
        await broadcast(data: data)
    }
    
    public func broadcastLine(line: String, delimiter: String = "\r\n") {
        let delimited = line + delimiter
        let data = Data(delimited.utf8)
        broadcast(data: data)
    }
    
    public func close() {
        self.server.close(promise: nil)
        for connection in self.connections.allConnections() {
            connection.close()
        }
    }
    
    deinit {
        self.close()
    }
    
    /// Transforms the (String, Data) -> Void user provided callback to (ByteBuffer) -> Void for ChannelInboundHandler
    private static func generateCallback(_ callback: @Sendable @escaping (String,Data) -> Void, connectionName: String) -> (ByteBuffer) -> Void {
        return { buffer in
            let bufferAsData = Data(buffer.readableBytesView) // This does do a copy
            callback(connectionName,bufferAsData)
        }
    }
    
}
