import Combine
import Foundation

public class SSDPClient {
	public enum Backend: String {
		case network
		case blueSocket
		
		var backend: SSDPBackend {
			switch self {
			case .network:
				NWBackend()
			case .blueSocket:
				BlueSocketBackend()
			}
		}
	}
	
    public private(set) var backend: SSDPBackend

	public init(backend: Backend) {
		self.backend = backend.backend
    }

    public var isScanning: Bool {
        backend.isScanning
    }
	
	public func setRequiredInterfaceType(_ interfaceType: RequiredInterfaceType?) {
		backend.requiredInterfaceType = interfaceType
	}
	
	public func set(backend: Backend) {
		if self.backend.isScanning {
			self.backend.stopScanning()
		}
		self.backend = backend.backend
	}

    public func startScanning(for duration: Duration) -> AnyPublisher<URL, Error> {
        backend.startScanning(for: duration)
    }

    public func stopScanning() {
        backend.stopScanning()
    }
}
