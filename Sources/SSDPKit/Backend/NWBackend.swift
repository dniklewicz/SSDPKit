//  Copyright © 2016 Dariusz Niklewicz. All rights reserved.

import Combine
import Foundation
import Network

// MARK: - SSDP Constants

extension NWEndpoint.Host {
    static let ssdp: NWEndpoint.Host = "239.255.255.250"
}

extension NWEndpoint.Port {
    static let ssdp = NWEndpoint.Port(1900)
}

public actor NWBackend: SSDPBackend {
	public var subscriptionsCount: Int = 0
	
	public func incrementSubscriptionsCount() {
		subscriptionsCount += 1
	}
	
	public func decrementSubscriptionsCount() {
		subscriptionsCount -= 1
	}
	
	public func set(requiredInterfaceType: RequiredInterfaceType?) {
		self.requiredInterfaceType = requiredInterfaceType
	}
	
	public var requiredInterfaceType: RequiredInterfaceType?
	
	public var publisher: PassthroughSubject<Result<URL, any Error>, Never> = .init()

    private let listenerQueue = DispatchQueue(label: "NWBackend.ListenerQueue")

	public var isScanning: Bool {
        connectionGroup != nil
    }

    var connectionGroup: NWConnectionGroup?
	private var isGroupStarted = false

    public init() { }
	
	public func scan(for duration: Duration) {
		startConnectionGroupIfNeeded(duration: duration)

		let message = """
		M-SEARCH * HTTP/1.1\r
		HOST: 239.255.255.250:1900\r
		MAN: "ssdp:discover"\r
		MX: \(Int(duration.components.seconds))\r
		ST: ssdp:all\r
		USER-AGENT: DarSSDP/1.0 UPnP/1.1 macOS/\(ProcessInfo.processInfo.operatingSystemVersionString)\r
		\r
		""".data(using: .utf8)

		connectionGroup?.send(content: message) { [weak self] error in
			if let error {
				Task {
					await self?.publisher.send(.failure(error))
				}
			} else {
				print("📡 SSDP: Broadcast sent")
			}
		}
	}
	
	func setGroupStarted(_ started: Bool) {
		self.isGroupStarted = started
	}

	private func startConnectionGroupIfNeeded(duration: Duration) {
		guard !isGroupStarted else { return }
		
		do {
			let endpoint = NWEndpoint.hostPort(host: .ssdp, port: .ssdp)
			let group = try NWMulticastGroup(for: [endpoint])
			let parameters: NWParameters = .udp
			
			switch self.requiredInterfaceType {
			case .wifi:
				parameters.requiredInterfaceType = .wifi
			case .ethernet:
				parameters.requiredInterfaceType = .wiredEthernet
			case nil:
				break
			}
			
			parameters.allowLocalEndpointReuse = true
			
			let connectionGroup = NWConnectionGroup(with: group, using: parameters)
			self.connectionGroup = connectionGroup
			
			connectionGroup.stateUpdateHandler = { [weak self] state in
				Task {
					guard let self else { return }
					
					switch state {
					case .ready:
						print("✅ SSDP Connection: Ready")
						await self.setGroupStarted(true)
						
					case .failed(let error):
						print("❌ SSDP Connection: Failed", error)
						await self.publisher.send(.failure(error))
						await self.cleanupConnectionGroup()
						
					case .cancelled:
						print("🛑 SSDP Connection: Cancelled")
						await self.cleanupConnectionGroup()
						
					default:
						break
					}
				}
			}
			
			connectionGroup.setReceiveHandler { [weak self] message, data, _ in
				Task { [weak self] in
					if let data = data,
					   let url = await self?.locationURL(from: data) {
						await self?.publisher.send(.success(url))
					}
				}
			}
			
			connectionGroup.start(queue: self.listenerQueue)
			
		} catch {
			self.publisher.send(.failure(error))
		}
	}
	
	public func stopScanning() {
		connectionGroup?.cancel()
		connectionGroup = nil
		isGroupStarted = false
		publisher.send(completion: .finished)
	}
	
	private func cleanupConnectionGroup() {
		connectionGroup = nil
		isGroupStarted = false
	}
}
