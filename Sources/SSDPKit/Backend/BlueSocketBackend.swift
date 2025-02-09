import Combine
import Foundation
import Socket

public class BlueSocketBackend: SSDPBackend {
	public var requiredInterfaceType: RequiredInterfaceType?
	
	enum ErrorType: Error {
		case cannotCreateAddress
	}

	private var socket: Socket?

	public var publisher: PassthroughSubject<URL, Error>?

	public var isScanning: Bool {
		socket != nil
	}

	// MARK: Initialisation

	init() {}

	deinit {
		self.stopScanning()
	}

	// MARK: Private functions

	private func readResponses() {
		guard let socket = self.socket else {
			return
		}
		do {
			var data = Data()
			let (bytesRead, _) = try socket.readDatagram(into: &data)

			if bytesRead > 0,
			   let url = locationURL(from: data) {
				DispatchQueue.main.async { [weak self] in
					self?.publisher?.send(url)
				}
			}
		} catch let error {
			forceStop()
			DispatchQueue.main.async { [weak self] in
				self?.publisher?.send(completion: .failure(error))
			}
		}
	}

	private func readResponses(forDuration duration: Duration) {
		let queue = DispatchQueue.global()

		queue.async { [weak self] in
			while self?.isScanning == true {
				self?.readResponses()
			}
		}

		queue.asyncAfter(deadline: .now() + .seconds(Int(duration.components.seconds))) { [weak self] in
			self?.stopScanning()
		}
	}

	private func forceStop() {
		if self.isScanning {
			self.socket?.close()
		}
		self.socket = nil
	}

	// MARK: Public API

	public func scan(for duration: Duration = .seconds(10)) {
		let message = "M-SEARCH * HTTP/1.1\r\n" +
		"MAN: \"ssdp:discover\"\r\n" +
		"HOST: 239.255.255.250:1900\r\n" +
		"ST: ssdp:all\r\n" +
		"MX: \(Int(duration.components.seconds))\r\n\r\n"
		
		do {
			socket = try Socket.create(type: .datagram, proto: .udp)
			try socket?.listen(on: 0)

			readResponses(forDuration: duration)

			guard let address = Socket.createAddress(for: "239.255.255.250", on: 1900) else {
				throw ErrorType.cannotCreateAddress
			}
			try socket?.write(from: message, to: address)
		} catch let error {
			forceStop()
			DispatchQueue.main.async { [weak self] in
				self?.publisher?.send(completion: .failure(error))
			}
		}
	}

	public func stopScanning() {
		if socket != nil {
			forceStop()
			DispatchQueue.main.async { [weak self] in
				self?.publisher?.send(completion: .finished)
			}
		}
	}
}
