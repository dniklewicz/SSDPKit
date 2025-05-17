import Combine
import Foundation

public enum RequiredInterfaceType {
	case wifi, ethernet
}

public protocol SSDPBackend: Actor {
    var isScanning: Bool { get }
    var publisher: PassthroughSubject<Result<URL, Error>, Never> { get }
	var requiredInterfaceType: RequiredInterfaceType? { get }
	
	func set(requiredInterfaceType: RequiredInterfaceType?)

	func scan(for duration: Duration)
    func startScanning(for duration: Duration) -> AnyPublisher<Result<URL, Error>, Never>
    func stopScanning()

    // Helper
    func locationURL(from data: Data) -> URL?
	
	var subscriptionsCount: Int { get }
	func incrementSubscriptionsCount()
	func decrementSubscriptionsCount()
}

public extension SSDPBackend {
	func startScanning(for duration: Duration) -> AnyPublisher<Result<URL, Error>, Never> {
        return publisher
            .handleEvents { [weak self] _ in
				Task { [weak self] in
					await self?.incrementSubscriptionsCount()
					// Start scan only when subscriber appears
					if await self?.isScanning == false {
						await self?.scan(for: duration)
					}
				}
            } receiveCancel: { [weak self] in
				Task { [weak self] in
					await self?.decrementSubscriptionsCount()
					if await self?.subscriptionsCount == 0 {
						await self?.stopScanning()
					}
				}
            }
            .eraseToAnyPublisher()
    }

    func locationURL(from data: Data) -> URL? {
        guard let ssdpResponseString = String(data: data, encoding: .utf8) else { return nil }

        // Tokenize SSDP response
        let header = headerDictionary(fromSSDPResponse: ssdpResponseString)

        // Extract description location, ip address and port
        guard let locationString = header["LOCATION"] ?? header["Location"],
              let locationURL = URL(string: locationString)
        else { return nil }

        return locationURL
    }

    func headerDictionary(fromSSDPResponse ssdpResponse: String) -> [String: String] {
        // Convert HTTP response string to dictionary of type `[String: String]`
        let ssdpHeaderLines = ssdpResponse.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        var response = [String: String]()

        for line in ssdpHeaderLines {
            let components = line.components(separatedBy: ":")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }

            guard components.count > 1 else { continue }

            response[components[0]] = components.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return response
    }
}
