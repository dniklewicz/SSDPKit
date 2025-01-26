import Combine
import Foundation

protocol SSDPBackend: AnyObject {
    var isScanning: Bool { get }
    var publisher: PassthroughSubject<URL, Error>? { get set }

    func scan(for duration: TimeInterval)
    func startScanning(for duration: TimeInterval) -> AnyPublisher<URL, Error>
    func stopScanning()

    // Helper
    func locationURL(from data: Data) -> URL?
}

extension SSDPBackend {
    func startScanning(for duration: TimeInterval) -> AnyPublisher<URL, Error> {
        let publisher = PassthroughSubject<URL, Error>()
        self.publisher = publisher
        return publisher
            .removeDuplicates()
            .handleEvents { [weak self] _ in
                // Start scan only when subscriber appears
                if self?.isScanning == false {
                    self?.scan(for: duration)
                }
            } receiveCancel: { [weak self] in
                self?.stopScanning()
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
