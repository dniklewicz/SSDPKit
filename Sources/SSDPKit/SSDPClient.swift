import Combine
import Foundation

public class SSDPClient {
    let backend: SSDPBackend
    
    public init() {
        // Apple needs to fix NWMulticastGroup first
        // https://developer.apple.com/forums/thread/680731
//        if #available(macOS 11.0, *) {
//            backend = NWBackend()
//        } else {
            backend = BlueSocketBackend()
//        }
    }
    
    public var isScanning: Bool {
        backend.isScanning
    }
    
    public func startScanning(for duration: TimeInterval) -> AnyPublisher<URL, Error> {
        backend.startScanning(for: duration)
    }
    
    public func stopScanning() {
        backend.stopScanning()
    }
}
