import XCTest
@testable import Networking

final class NetworkingTests: XCTestCase {
    
    /// Simple test to see if TCPConnection successfully opens connections.
    /// Relies on Cloudflare & Google being up & reachable.
    func testTCPConnect() async throws {
        _ = try await TCPConnection(onRead: printRead, host: "1.1.1.1", port: 53, debug: true)
        _ = try await TCPConnection(onRead: printRead, host: "google.com", port: 443, debug: true)
    }
    
    func testTCPConnectSend() async throws {
        let tcpBinConnection = try await TCPConnection(onRead: printRead, host: "tcpbin.com", port: 4242, debug: true)
        try await tcpBinConnection.sendLine("Hi!")
        delay(by: 1)
    }
    
    func testTCPServer() async throws {
        let connectionName: Wrapped<String> = .init(value: "")
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        let server = try TCPServer(port: 4242, maxConnections: 1, actionOnNewConnection: { connectionName.update(value: $0.connectionName) }, actionOnReceive: { _, data in
            continuation.yield(String(data: data, encoding: .ascii)!)
        })
        for await received in stream {
            print("Received: \(received) from: \(connectionName.getValue())")
        }
    }
    
    
}


func printRead(_ data: Data) {
    print("Received \(data.count) bytes: " + String(data: data, encoding: .ascii)!)
}

func delay(by: TimeInterval) {
    usleep(useconds_t(by * 1_000_000))
}

