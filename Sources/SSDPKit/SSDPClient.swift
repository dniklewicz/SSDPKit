import Combine
import Foundation

public actor SSDPClient {
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

	public func isScanning() async -> Bool {
        await backend.isScanning
    }
	
	public func setRequiredInterfaceType(_ interfaceType: RequiredInterfaceType?) async {
		await backend.set(requiredInterfaceType: interfaceType)
	}
	
	public func set(backend: Backend) async {
		if await self.backend.isScanning {
			await self.backend.stopScanning()
		}
		self.backend = backend.backend
	}

    public func startScanning(for duration: Duration) async -> AnyPublisher<Result<URL, Error>, Never> {
		await backend.startScanning(for: duration)
    }

    public func stopScanning() async {
		await backend.stopScanning()
    }
}
