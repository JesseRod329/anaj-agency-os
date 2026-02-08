#if os(macOS)
import Foundation
import Network
import CryptoKit

final class OpenClawWebSocketHub {
    typealias CommandHandler = @Sendable (OpenClawCommandEnvelope) async -> OpenClawAckEnvelope

    private final class ClientSession {
        let id: UUID
        let connection: NWConnection
        var buffer: Data
        var lastSeen: Date

        init(id: UUID, connection: NWConnection, initialBuffer: Data = Data()) {
            self.id = id
            self.connection = connection
            self.buffer = initialBuffer
            self.lastSeen = Date()
        }
    }

    private let queue = DispatchQueue(label: "anaj.websocket.hub", qos: .userInitiated)
    private var listener: NWListener?
    private var clients: [UUID: ClientSession] = [:]
    private var heartbeatTimer: DispatchSourceTimer?

    private var requiredAPIKeyProvider: (() -> String)?
    private var commandHandler: CommandHandler?
    private let logger = ANAJLogger.shared

    func start(
        port: UInt16 = 18791,
        requiredAPIKeyProvider: @escaping () -> String,
        commandHandler: @escaping CommandHandler
    ) {
        guard listener == nil else { return }
        self.requiredAPIKeyProvider = requiredAPIKeyProvider
        self.commandHandler = commandHandler

        do {
            let nwPort = NWEndpoint.Port(rawValue: port) ?? 18791
            let listener = try NWListener(using: .tcp, on: nwPort)

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    self.logger.info("ws", "WebSocket hub ready", metadata: ["url": "ws://127.0.0.1:\(port)/ws/openclaw"])
                    print("ANAJ OpenClaw WebSocket listening on ws://127.0.0.1:\(port)/ws/openclaw")
                case .failed(let error):
                    self.logger.error("ws", "WebSocket hub failed", metadata: ["error": error.localizedDescription])
                    print("ANAJ OpenClaw WebSocket failed: \(error)")
                default:
                    break
                }
            }

            listener.start(queue: queue)
            self.listener = listener
            startHeartbeat()
        } catch {
            logger.error("ws", "Failed to start WebSocket hub", metadata: ["error": error.localizedDescription])
            print("Failed to start OpenClaw WebSocket hub: \(error)")
        }
    }

    func stop() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil

        for session in clients.values {
            sendCloseFrame(code: 1001, reason: "Server shutting down", to: session)
            session.connection.cancel()
        }
        clients.removeAll()

        listener?.cancel()
        listener = nil
    }

    func broadcast(event: OpenClawEventEnvelope) {
        guard let payload = encodeJSON(event) else { return }
        queue.async { [weak self] in
            guard let self else { return }
            self.logger.debug(
                "ws",
                "Broadcasting event",
                metadata: [
                    "event": event.event,
                    "entity": event.entity,
                    "clients": "\(self.clients.count)"
                ]
            )
            for session in self.clients.values {
                self.sendTextFrame(payload, to: session)
            }
        }
    }

    private func startHeartbeat() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in
            self?.heartbeatTick()
        }
        timer.resume()
        heartbeatTimer = timer
    }

    private func heartbeatTick() {
        let staleCutoff = Date().addingTimeInterval(-90)
        let staleIDs = clients.values
            .filter { $0.lastSeen < staleCutoff }
            .map(\.id)

        for id in staleIDs {
            logger.warn("ws", "Disconnecting stale client", metadata: ["clientId": id.uuidString])
            disconnectClient(id: id, reason: "Heartbeat timeout")
        }

        for session in clients.values {
            sendPingFrame(to: session)
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveHandshake(on: connection, buffer: Data())
    }

    private func receiveHandshake(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            if isComplete || error != nil {
                connection.cancel()
                return
            }

            guard let data, !data.isEmpty else {
                connection.cancel()
                return
            }

            var accumulated = buffer
            accumulated.append(data)

            guard let headerRange = accumulated.range(of: Data("\r\n\r\n".utf8)) else {
                self.receiveHandshake(on: connection, buffer: accumulated)
                return
            }

            let headerData = Data(accumulated[..<headerRange.upperBound])
            let remainder = Data(accumulated[headerRange.upperBound...])
            self.handleHandshake(connection: connection, headerData: headerData, remainder: remainder)
        }
    }

    private func handleHandshake(connection: NWConnection, headerData: Data, remainder: Data) {
        guard let request = HandshakeRequest.parse(headerData) else {
            sendHTTPResponse(status: 400, reason: "Bad Request", body: "Malformed WebSocket handshake", on: connection)
            return
        }

        guard request.method == "GET" else {
            sendHTTPResponse(status: 405, reason: "Method Not Allowed", body: "Use GET for WebSocket upgrade", allow: "GET", on: connection)
            return
        }

        guard request.path == "/ws/openclaw" else {
            sendHTTPResponse(status: 404, reason: "Not Found", body: "WebSocket endpoint not found", on: connection)
            return
        }

        let requiredAPIKey = requiredAPIKeyProvider?().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !requiredAPIKey.isEmpty && !request.isAuthorized(requiredAPIKey: requiredAPIKey) {
            logger.warn(
                "ws",
                "Rejected unauthorized WebSocket handshake",
                metadata: ["path": request.path]
            )
            sendHTTPResponse(status: 401, reason: "Unauthorized", body: "Valid x-anaj-key or Bearer token required", on: connection)
            return
        }

        guard let webSocketKey = request.headers["sec-websocket-key"] else {
            sendHTTPResponse(status: 400, reason: "Bad Request", body: "Missing Sec-WebSocket-Key", on: connection)
            return
        }

        let accept = makeWebSocketAccept(from: webSocketKey)
        let response = [
            "HTTP/1.1 101 Switching Protocols",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Accept: \(accept)",
            "\r\n"
        ].joined(separator: "\r\n")

        connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] error in
            guard let self else {
                connection.cancel()
                return
            }
            if error != nil {
                connection.cancel()
                return
            }
            let clientID = UUID()
            let session = ClientSession(id: clientID, connection: connection, initialBuffer: remainder)
            self.clients[clientID] = session
            self.logger.info("ws", "WebSocket client connected", metadata: ["clientId": clientID.uuidString])
            self.handleBufferedFrames(for: clientID)
            self.receiveFrameData(for: clientID)
        })
    }

    private func receiveFrameData(for clientID: UUID) {
        guard let session = clients[clientID] else { return }

        session.connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if isComplete || error != nil {
                self.disconnectClient(id: clientID, reason: "Connection closed")
                return
            }

            guard let data, !data.isEmpty else {
                self.disconnectClient(id: clientID, reason: "Connection closed")
                return
            }

            guard let session = self.clients[clientID] else { return }
            session.buffer.append(data)
            session.lastSeen = Date()
            self.handleBufferedFrames(for: clientID)
            self.receiveFrameData(for: clientID)
        }
    }

    private func handleBufferedFrames(for clientID: UUID) {
        guard let session = clients[clientID] else { return }

        while let frame = popFrame(from: &session.buffer) {
            session.lastSeen = Date()
            switch frame.opcode {
            case 0x1: // Text
                handleTextFrame(frame.payload, from: clientID)
            case 0x8: // Close
                sendCloseFrame(code: 1000, reason: "Closing", to: session)
                disconnectClient(id: clientID, reason: "Peer closed connection")
                return
            case 0x9: // Ping
                sendPongFrame(payload: frame.payload, to: session)
            case 0xA: // Pong
                continue
            default:
                continue
            }
        }
    }

    private func handleTextFrame(_ payload: Data, from clientID: UUID) {
        do {
            let envelope = try JSONDecoder().decode(OpenClawCommandEnvelope.self, from: payload)
            logger.info(
                "ws",
                "Received command envelope",
                requestID: envelope.id,
                metadata: [
                    "clientId": clientID.uuidString,
                    "command": envelope.command
                ]
            )
            Task { [weak self] in
                guard let self else { return }
                let ack: OpenClawAckEnvelope
                if let commandHandler = self.commandHandler {
                    ack = await commandHandler(envelope)
                } else {
                    ack = OpenClawAckEnvelope(
                        type: "ack",
                        id: UUID().uuidString,
                        requestId: envelope.id,
                        status: "failed",
                        command: envelope.command,
                        result: [:],
                        error: "No command handler configured",
                        sentAt: Date().wsISO8601
                    )
                }
                self.queue.async {
                    self.sendAck(ack, to: clientID)
                }
            }
        } catch {
            logger.warn(
                "ws",
                "Invalid command envelope",
                metadata: [
                    "clientId": clientID.uuidString,
                    "error": error.localizedDescription
                ]
            )
            let ack = OpenClawAckEnvelope(
                type: "ack",
                id: UUID().uuidString,
                requestId: UUID().uuidString,
                status: "failed",
                command: "unknown",
                result: [:],
                error: "Invalid command envelope: \(error.localizedDescription)",
                sentAt: Date().wsISO8601
            )
            sendAck(ack, to: clientID)
        }
    }

    private func sendAck(_ ack: OpenClawAckEnvelope, to clientID: UUID) {
        guard let session = clients[clientID], let data = encodeJSON(ack) else { return }
        logger.info(
            "ws",
            "Sent command ack",
            requestID: ack.requestId,
            metadata: [
                "clientId": clientID.uuidString,
                "command": ack.command,
                "status": ack.status
            ]
        )
        sendTextFrame(data, to: session)
    }

    private func sendTextFrame(_ textPayload: Data, to session: ClientSession) {
        let frame = makeFrame(opcode: 0x1, payload: textPayload)
        session.connection.send(content: frame, completion: .contentProcessed { _ in })
    }

    private func sendPingFrame(to session: ClientSession) {
        let payload = Data(Date().wsISO8601.utf8)
        let frame = makeFrame(opcode: 0x9, payload: payload)
        session.connection.send(content: frame, completion: .contentProcessed { _ in })
    }

    private func sendPongFrame(payload: Data, to session: ClientSession) {
        let frame = makeFrame(opcode: 0xA, payload: payload)
        session.connection.send(content: frame, completion: .contentProcessed { _ in })
    }

    private func sendCloseFrame(code: UInt16, reason: String, to session: ClientSession) {
        var payload = Data()
        payload.append(UInt8((code >> 8) & 0xFF))
        payload.append(UInt8(code & 0xFF))
        payload.append(contentsOf: reason.utf8)
        let frame = makeFrame(opcode: 0x8, payload: payload)
        session.connection.send(content: frame, completion: .contentProcessed { _ in })
    }

    private func disconnectClient(id: UUID, reason: String) {
        guard let session = clients.removeValue(forKey: id) else { return }
        session.connection.cancel()
        logger.info("ws", "WebSocket client disconnected", metadata: ["clientId": id.uuidString, "reason": reason])
        print("OpenClaw WebSocket client disconnected (\(id.uuidString)): \(reason)")
    }

    private func sendHTTPResponse(
        status: Int,
        reason: String,
        body: String,
        allow: String? = nil,
        on connection: NWConnection
    ) {
        var lines = [
            "HTTP/1.1 \(status) \(reason)",
            "Content-Type: text/plain; charset=utf-8",
            "Content-Length: \(body.utf8.count)",
            "Connection: close"
        ]
        if let allow {
            lines.append("Allow: \(allow)")
        }
        lines.append("\r\n")
        let payload = (lines.joined(separator: "\r\n") + body).data(using: .utf8) ?? Data()
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func makeFrame(opcode: UInt8, payload: Data) -> Data {
        var frame = Data()
        frame.append(0x80 | (opcode & 0x0F))

        let count = payload.count
        if count <= 125 {
            frame.append(UInt8(count))
        } else if count <= 65_535 {
            frame.append(126)
            frame.append(UInt8((count >> 8) & 0xFF))
            frame.append(UInt8(count & 0xFF))
        } else {
            frame.append(127)
            let length = UInt64(count)
            for shift in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((length >> UInt64(shift)) & 0xFF))
            }
        }
        frame.append(payload)
        return frame
    }

    private func popFrame(from buffer: inout Data) -> WebSocketFrame? {
        guard buffer.count >= 2 else { return nil }

        let first = buffer[buffer.startIndex]
        let second = buffer[buffer.index(buffer.startIndex, offsetBy: 1)]
        let opcode = first & 0x0F
        let masked = (second & 0x80) != 0
        var payloadLength = Int(second & 0x7F)
        var offset = 2

        if payloadLength == 126 {
            guard buffer.count >= offset + 2 else { return nil }
            payloadLength = Int(UInt16(buffer[buffer.index(buffer.startIndex, offsetBy: offset)]) << 8 |
                                UInt16(buffer[buffer.index(buffer.startIndex, offsetBy: offset + 1)]))
            offset += 2
        } else if payloadLength == 127 {
            guard buffer.count >= offset + 8 else { return nil }
            var value: UInt64 = 0
            for idx in 0..<8 {
                value = (value << 8) | UInt64(buffer[buffer.index(buffer.startIndex, offsetBy: offset + idx)])
            }
            payloadLength = Int(value)
            offset += 8
        }

        var maskKey: [UInt8] = []
        if masked {
            guard buffer.count >= offset + 4 else { return nil }
            maskKey = [
                buffer[buffer.index(buffer.startIndex, offsetBy: offset)],
                buffer[buffer.index(buffer.startIndex, offsetBy: offset + 1)],
                buffer[buffer.index(buffer.startIndex, offsetBy: offset + 2)],
                buffer[buffer.index(buffer.startIndex, offsetBy: offset + 3)]
            ]
            offset += 4
        }

        guard buffer.count >= offset + payloadLength else { return nil }

        let payloadStart = buffer.index(buffer.startIndex, offsetBy: offset)
        let payloadEnd = buffer.index(payloadStart, offsetBy: payloadLength)
        var payload = Data(buffer[payloadStart..<payloadEnd])

        if masked {
            var bytes = [UInt8](payload)
            for index in bytes.indices {
                bytes[index] ^= maskKey[index % 4]
            }
            payload = Data(bytes)
        }

        buffer.removeSubrange(buffer.startIndex..<payloadEnd)
        return WebSocketFrame(opcode: opcode, payload: payload)
    }

    private func encodeJSON<T: Encodable>(_ value: T) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(value)
    }

    private func makeWebSocketAccept(from key: String) -> String {
        let source = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let digest = Insecure.SHA1.hash(data: Data(source.utf8))
        return Data(digest).base64EncodedString()
    }
}

private struct WebSocketFrame {
    let opcode: UInt8
    let payload: Data
}

private struct HandshakeRequest {
    let method: String
    let target: String
    let path: String
    let query: [String: String]
    let headers: [String: String]

    static func parse(_ headerData: Data) -> HandshakeRequest? {
        guard let raw = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = raw.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        guard let requestLine = lines.first else { return nil }
        let pieces = requestLine.split(separator: " ").map(String.init)
        guard pieces.count >= 2 else { return nil }

        let method = pieces[0].uppercased()
        let target = pieces[1]
        let components = URLComponents(string: "ws://localhost\(target)")

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let split = line.split(separator: ":", maxSplits: 1).map(String.init)
            if split.count == 2 {
                headers[split[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] =
                    split[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        var query: [String: String] = [:]
        for item in components?.queryItems ?? [] {
            query[item.name] = item.value ?? ""
        }

        return HandshakeRequest(
            method: method,
            target: target,
            path: components?.path ?? "/",
            query: query,
            headers: headers
        )
    }

    func isAuthorized(requiredAPIKey: String) -> Bool {
        if let direct = headers["x-anaj-key"], direct == requiredAPIKey {
            return true
        }

        if let bearer = headers["authorization"], bearer.lowercased().hasPrefix("bearer ") {
            let token = String(bearer.dropFirst("bearer ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if token == requiredAPIKey {
                return true
            }
        }

        if let queryToken = query["apiKey"], queryToken == requiredAPIKey {
            return true
        }

        return false
    }
}

private extension Date {
    var wsISO8601: String {
        OpenClawISO8601.shared.string(from: self)
    }
}

private final class OpenClawISO8601 {
    static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

#endif
