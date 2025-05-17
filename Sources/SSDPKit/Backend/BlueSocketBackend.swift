import Combine
import Foundation
import Socket

public actor BlueSocketBackend: SSDPBackend {
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
	
	enum ErrorType: Error {
		case cannotCreateAddress
	}

	private var socket: Socket?

	public var publisher: PassthroughSubject<Result<URL, any Error>, Never> = .init()

	public var isScanning: Bool {
		socket != nil
	}

	// MARK: Initialisation

	init() {}

	// MARK: Private functions

	private func readResponses() {
		guard let socket else { return }
		do {
			var data = Data()
			let (bytesRead, _) = try socket.readDatagram(into: &data)

			if bytesRead > 0,
			   let url = locationURL(from: data) {
				publisher.send(.success(url))
			}
		} catch let error {
			forceStop()
			publisher.send(.failure(error))
		}
	}

	private func readResponses(forDuration duration: Duration) {
		let queue = DispatchQueue.global()

		queue.async { [weak self] in
			Task { [weak self] in
				while await self?.isScanning == true {
					await self?.readResponses()
				}
			}
		}

		queue.asyncAfter(deadline: .now() + .seconds(Int(duration.components.seconds))) { [weak self] in
			Task { [weak self] in
				await self?.stopScanning()
			}
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
			publisher.send(.failure(error))
		}
	}

	public func stopScanning() {
		if socket != nil {
			forceStop()
		}
	}
}
