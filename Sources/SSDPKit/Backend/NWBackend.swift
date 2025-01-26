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
    var publisher: PassthroughSubject<URL, Error>?

    private let listenerQueue = DispatchQueue(label: "Listener")

    var isScanning: Bool {
        connectionGroup != nil
    }

    var connectionGroup: NWConnectionGroup?

    func sendBroadcast(for duration: TimeInterval) {
        let message = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: \(Int(duration))\r\nST: ssdp:all\r\n\r\n".data(using: .utf8)

        connectionGroup?.send(content: message) { [weak self] error in
            if let error = error {
                self?.publisher?.send(completion: .failure(error))
            } else {
                print("SSDP: Broadcast sent")
            }
        }
    }

    init() { }

    func scan(for duration: TimeInterval) {
        do {
            let endpoint = NWEndpoint.hostPort(host: .ssdp, port: .ssdp)
            let multicastGroup = try NWMulticastGroup(for: [endpoint])
            let parameters: NWParameters = .udp
            parameters.allowLocalEndpointReuse = true
            connectionGroup = NWConnectionGroup(with: multicastGroup, using: parameters)
            connectionGroup?.stateUpdateHandler = { [weak self] newState in
                switch newState {
                case .setup:
                    print("SSDP: Connection: Setup")
                case let .waiting(error):
                    print("SSDP: Waiting:", error)
                case .ready:
                    print("SSDP: Connection: Ready")
                    self?.sendBroadcast(for: duration)
                case let .failed(error):
                    print("SSDP: Connection: Failed")
                    self?.publisher?.send(completion: .failure(error))
                case .cancelled:
                    print("SSDP: Connection: Cancelled")
                @unknown default:
                    print("SSDP: Connection: Unknown")
                }
            }

            connectionGroup?.setReceiveHandler { [weak self] message, data, isComplete in
                if let data = data,
                   let url = self?.locationURL(from: data) {
                    self?.publisher?.send(url)
                }
            }

            connectionGroup?.start(queue: listenerQueue)

            listenerQueue.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.stopScanning()
            }
        } catch {
            publisher?.send(completion: .failure(error))
        }
    }

    func stopScanning() {
        connectionGroup?.cancel()
        publisher?.send(completion: .finished)
    }
}
