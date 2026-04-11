//
//  SSEClient.swift
//  ClaudeIsland
//
//  Generic Server-Sent Events (SSE) client.
//  Supports both Unix domain sockets and TCP HTTP connections.
//  Used by CrushProvider and HermesProvider.
//

import Foundation
import os.log

/// A lightweight SSE (Server-Sent Events) client with auto-reconnect.
final class SSEClient: NSObject, @unchecked Sendable, URLSessionDataDelegate {

    // MARK: - Connection Target

    enum ConnectionTarget: Sendable {
        /// Connect via Unix domain socket (e.g., Crush at /tmp/crush-{uid}.sock)
        case unixSocket(path: String, urlPath: String)
        /// Connect via HTTP URL (e.g., Hermes at http://localhost:8642)
        case http(url: URL)
    }

    // MARK: - Properties

    private let target: ConnectionTarget
    private let logger: Logger
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var buffer = ""
    private var isRunning = false
    private var reconnectDelay: TimeInterval = 1.0
    private let maxReconnectDelay: TimeInterval = 30.0

    /// Called when an SSE event is received: (eventType, data)
    var onEvent: (@Sendable (String, String) -> Void)?

    /// Called when the connection is lost
    var onDisconnect: (@Sendable () -> Void)?

    // MARK: - Init

    init(target: ConnectionTarget, logger: Logger = Logger(subsystem: "com.codeisland", category: "SSE")) {
        self.target = target
        self.logger = logger
        super.init()
    }

    // MARK: - Connection

    func connect() {
        guard !isRunning else { return }
        isRunning = true
        reconnectDelay = 1.0
        startConnection()
    }

    func disconnect() {
        isRunning = false
        dataTask?.cancel()
        dataTask = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func startConnection() {
        guard isRunning else { return }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = .infinity  // SSE is long-lived
        config.timeoutIntervalForResource = .infinity

        let request: URLRequest

        switch target {
        case .unixSocket(let path, let urlPath):
            // For Unix socket connections, use a custom URLProtocol or direct socket
            // URLSession doesn't natively support Unix sockets, so we use a workaround:
            // connect via localhost with a custom connection proxy configuration
            config.connectionProxyDictionary = [
                "HTTPEnable": true,
                "HTTPProxy": path,
                "HTTPPort": 0
            ]
            var r = URLRequest(url: URL(string: "http://localhost\(urlPath)")!)
            r.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request = r
            logger.info("Connecting SSE via Unix socket: \(path, privacy: .public)\(urlPath, privacy: .public)")

        case .http(let url):
            var r = URLRequest(url: url)
            r.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request = r
            logger.info("Connecting SSE via HTTP: \(url.absoluteString, privacy: .public)")
        }

        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        dataTask = session?.dataTask(with: request)
        dataTask?.resume()
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text
        parseSSE()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as? NSError, error.code == NSURLErrorCancelled {
            return  // Intentional disconnect
        }

        if let error {
            logger.warning("SSE connection error: \(error.localizedDescription, privacy: .public)")
        }

        onDisconnect?()
        scheduleReconnect()
    }

    // MARK: - SSE Parsing

    private func parseSSE() {
        // SSE format: "event: <type>\ndata: <json>\n\n"
        while let doubleNewline = buffer.range(of: "\n\n") {
            let block = String(buffer[buffer.startIndex..<doubleNewline.lowerBound])
            buffer = String(buffer[doubleNewline.upperBound...])

            var eventType = "message"  // default SSE event type
            var eventData = ""

            for line in block.components(separatedBy: "\n") {
                if line.hasPrefix("event:") {
                    eventType = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    let data = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    if !eventData.isEmpty { eventData += "\n" }
                    eventData += data
                }
                // ignore "id:", "retry:", comments (lines starting with ":")
            }

            if !eventData.isEmpty {
                onEvent?(eventType, eventData)
            }
        }
    }

    // MARK: - Reconnect

    private func scheduleReconnect() {
        guard isRunning else { return }

        logger.info("Reconnecting in \(self.reconnectDelay, privacy: .public)s")

        DispatchQueue.global().asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self, self.isRunning else { return }
            self.startConnection()
        }

        // Exponential backoff with cap
        reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)
    }
}
