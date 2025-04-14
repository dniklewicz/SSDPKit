//  Copyright © 2016 Dariusz Niklewicz. All rights reserved.

import Combine
import Foundation
import Network

extension NWEndpoint.Host {
    static let ssdp: NWEndpoint.Host = "239.255.255.250"
}

extension NWEndpoint.Port {
    static let ssdp = NWEndpoint.Port(1900)
}

public class NWBackend: SSDPBackend {
	public var requiredInterfaceType: RequiredInterfaceType?
	
	public var publisher: PassthroughSubject<URL, Error>?

    private let listenerQueue = DispatchQueue(label: "Listener")

	public var isScanning: Bool {
        connectionGroup != nil
    }

    var connectionGroup: NWConnectionGroup?

	func sendBroadcast(for duration: Duration) {
		let message = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: \(Int(duration.components.seconds))\r\nST: ssdp:all\r\n\r\n".data(using: .utf8)

        connectionGroup?.send(content: message) { [weak self] error in
            if let error {
                self?.publisher?.send(completion: .failure(error))
            } else {
                print("SSDP: Broadcast sent")
            }
        }
    }

    public init() { }

	public func scan(for duration: Duration) {
        do {
            let endpoint = NWEndpoint.hostPort(host: .ssdp, port: .ssdp)
            let multicastGroup = try NWMulticastGroup(for: [endpoint])
            let parameters: NWParameters = .udp
			switch requiredInterfaceType {
			case .wifi:
				parameters.requiredInterfaceType = .wifi
			case .ethernet:
				parameters.requiredInterfaceType = .wiredEthernet
			case nil:
				break
			}
            parameters.allowLocalEndpointReuse = true
            connectionGroup = NWConnectionGroup(with: multicastGroup, using: parameters)
            connectionGroup?.stateUpdateHandler = { [weak self] newState in
                switch newState {
                case .setup:
                    print("SSDP NWBackend: Connection: Setup")
                case let .waiting(error):
                    print("SSDP NWBackend: Waiting:", error)
                case .ready:
                    print("SSDP NWBackend: Connection: Ready")
                    self?.sendBroadcast(for: duration)
                case let .failed(error):
                    print("SSDP NWBackend: Connection: Failed")
                    self?.publisher?.send(completion: .failure(error))
                case .cancelled:
                    print("SSDP NWBackend: Connection: Cancelled")
                @unknown default:
                    print("SSDP NWBackend: Connection: Unknown")
                }
            }

            connectionGroup?.setReceiveHandler { [weak self] message, data, isComplete in
                if let data = data,
                   let url = self?.locationURL(from: data) {
                    self?.publisher?.send(url)
                }
            }

            connectionGroup?.start(queue: listenerQueue)

			listenerQueue.asyncAfter(deadline: .now() + .seconds(Int(duration.components.seconds))) { [weak self] in
                self?.stopScanning()
            }
        } catch {
            publisher?.send(completion: .failure(error))
        }
    }

	public func stopScanning() {
        connectionGroup?.cancel()
        publisher?.send(completion: .finished)
		connectionGroup = nil
    }
}
