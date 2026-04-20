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
        let server = try await TCPServer(port: 55301, maxConnections: 1, actionOnNewConnection: { connectionName.update(value: $0.connectionName) }, actionOnReceive: { _, data in
            continuation.yield(String(data: data, encoding: .ascii)!)
        }) // The warning here is invalid, don't actually replace with '_', it'll deinit the object and fail the test
        let newConnection = try await TCPConnection(onRead: {_ in }, host: "0.0.0.0", port: 55301)
        for n in 0..<102 {
            try await newConnection.sendLine("meow! \(n)")
        }
        var recCount = 0
        for await received in stream {
            recCount += 1
            print("Received: \(received) from: \(connectionName.getValue()), \(recCount)")
            if(recCount >= 2) { break }
        }
    }
    
    func testTCPServerNonAsync() throws {
        let connectionName: Wrapped<String> = .init(value: "")
        let received: Wrapped<[String]> = .init(value: [])
        let sem = DispatchSemaphore(value: 0)
        let server = try TCPServer(port: 55302, maxConnections: 1, actionOnNewConnection: { connectionName.update(value: $0.connectionName) }, actionOnReceive: { _,data in received.value.append(String(data: data, encoding: .ascii)!); sem.signal() })
        let newConnection = try TCPConnection(onRead: {_ in }, host: "0.0.0.0", port: 55302)
        for n in 0..<102 {
            try newConnection.send(Data("meow! \(n)".utf8))
        }
        for _ in 0..<5 {
            sem.wait()
        }
        print(received.getValue())
    }
    
    
}


func printRead(_ data: Data) {
    print("Received \(data.count) bytes: " + String(data: data, encoding: .ascii)!)
}

func delay(by: TimeInterval) {
    usleep(useconds_t(by * 1_000_000))
}

