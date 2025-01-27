import Combine
import Foundation

public class SSDPClient {
    let backend: SSDPBackend

	public init(backend: SSDPBackend = NWBackend()) {
		self.backend = backend
    }

    public var isScanning: Bool {
        backend.isScanning
    }
	
	public func setRequiredInterfaceType(_ interfaceType: RequiredInterfaceType?) {
		backend.requiredInterfaceType = interfaceType
	}

    public func startScanning(for duration: TimeInterval) -> AnyPublisher<URL, Error> {
        backend.startScanning(for: duration)
    }
    
	@available(macOS 13.0, iOS 16.0, *)
    public func startScanning(for duration: Duration) -> AnyPublisher<URL, Error> {
        let timeInterval = TimeInterval(duration.components.seconds) + Double(duration.components.attoseconds)/1e18
        return backend.startScanning(for: timeInterval)
    }

    public func stopScanning() {
        backend.stopScanning()
    }
}
