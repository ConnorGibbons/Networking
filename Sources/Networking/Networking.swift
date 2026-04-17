import NIOCore
import NIOPosix

/// Class to manage state of Networking library
final class NetworkingManager: Sendable {
    
    let group: MultiThreadedEventLoopGroup
    
    init(threads: Int = 1) {
        self.group = .init(numberOfThreads: threads)
    }
    
    deinit {
        try! group.syncShutdownGracefully()
    }
    
}

let globalManager = NetworkingManager()
