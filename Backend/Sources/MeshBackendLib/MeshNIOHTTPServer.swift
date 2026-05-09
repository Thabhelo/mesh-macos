import Foundation
import MeshBackendCore
import NIOCore
import NIOHTTP1
import NIOPosix

/// Minimal HTTP/1.1 server using SwiftNIO (Linux + macOS).
final class MeshNIOHTTPServer: @unchecked Sendable {
    private let router: MeshBackendRouter
    private let port: UInt16
    private let group: MultiThreadedEventLoopGroup

    init(router: MeshBackendRouter, port: UInt16) {
        self.router = router
        self.port = port
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    func start() async throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { [router] channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(MeshHTTPHandler(router: router))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        let bindFuture = bootstrap.bind(host: "0.0.0.0", port: Int(port))
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Channel, Error>) in
            bindFuture.whenComplete { result in
                switch result {
                case .success(let channel):
                    continuation.resume(returning: channel)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func shutdown() throws {
        try group.syncShutdownGracefully()
    }
}

private final class MeshHTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private var requestHead: HTTPRequestHead?
    private let router: MeshBackendRouter

    init(router: MeshBackendRouter) {
        self.router = router
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        switch part {
        case .head(let head):
            requestHead = head
        case .body:
            break
        case .end:
            guard let head = requestHead else {
                context.close(promise: nil)
                return
            }
            requestHead = nil
            let (pathOnly, queryString) = pathAndQuery(from: head.uri)
            let method = "\(head.method)"
            let queryItems = parseQueryString(queryString)

            Task {
                let meshResponse = await router.route(method: method, path: pathOnly, queryItems: queryItems)
                context.eventLoop.execute {
                    Self.send(meshResponse, context: context)
                }
            }
        }
    }

    private func pathAndQuery(from uri: String) -> (path: String, query: String?) {
        if uri.hasPrefix("/") {
            let parts = uri.split(separator: "?", maxSplits: 1)
            let path = String(parts[0])
            let query = parts.count > 1 ? String(parts[1]) : nil
            return (path, query)
        }
        if let url = URL(string: uri) {
            let path = url.path.isEmpty ? "/" : url.path
            return (path, url.query)
        }
        return (uri, nil)
    }

    private func parseQueryString(_ string: String?) -> [URLQueryItem] {
        guard let string, !string.isEmpty else {
            return []
        }
        var components = URLComponents()
        components.query = string
        return components.queryItems ?? []
    }

    private static func send(_ response: MeshBackendCore.HTTPResponse, context: ChannelHandlerContext) {
        var headers = HTTPHeaders()
        for (key, value) in response.headers {
            headers.add(name: key, value: value)
        }
        headers.add(name: "Content-Length", value: String(response.body.count))
        headers.add(name: "Connection", value: "close")

        let status = HTTPResponseStatus(statusCode: response.statusCode)
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)

        context.write(wrapOutboundOut(.head(head)), promise: nil)

        var buffer = context.channel.allocator.buffer(capacity: response.body.count)
        buffer.writeBytes(response.body)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
            context.close(promise: nil)
        }
    }
}
