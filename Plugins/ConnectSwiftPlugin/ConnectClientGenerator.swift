// Copyright 2022-2025 The Connect Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ConnectPluginUtilities
import Foundation
import SwiftProtobufPluginLibrary

/// Responsible for generating services and RPCs that are compatible with the Connect library.
@main
final class ConnectClientGenerator: Generator {
    private var visibility = ""

    override var outputFileExtension: String {
        ".connect.swift"
    }

    override func printContent(for descriptor: FileDescriptor) {
        super.printContent(for: descriptor)

        self.printLine("// swiftlint:disable all")

        switch self.options.visibility {
        case .internal:
            self.visibility = "internal"
        case .public:
            self.visibility = "public"
        case .package:
            self.visibility = "package"
        }

        self.printModuleImports()

        for service in self.services {
            self.printLine()
            self.printService(service)
        }

        self.printLine("// swiftlint:enable all")
    }

    private func printService(_ service: ServiceDescriptor) {
        self.printCommentsIfNeeded(for: service)

        let protocolName = service.protocolName(using: self.namer)
        self.printLine("\(self.visibility) protocol \(protocolName): Sendable {")
        self.indent {
            for method in service.methods {
                self.printAsyncAwaitThrowingMethodInterface(for: method)
            }
        }
        self.printLine("}")

        self.printLine()

        let className = service.implementationName(using: self.namer)
        self.printLine("/// Concrete implementation of `\(protocolName)`.")
        self.printLine(
            "\(self.visibility) final class \(className): \(protocolName), Sendable {"
        )
        self.indent {
            self.printLine("private let client: Connect.ProtocolClientInterface")
            self.printLine()
            self.printLine("\(self.visibility) init(client: Connect.ProtocolClientInterface) {")
            self.indent {
                self.printLine("self.client = client")
            }
            self.printLine("}")

            for method in service.methods {
                self.printAsyncAwaitThrowingMethodImplementation(for: method)
            }
        }
        self.printLine("}")
    }

    private func printAsyncAwaitThrowingMethodInterface(for method: MethodDescriptor) {
        self.printLine()
        self.printCommentsIfNeeded(for: method)
        self.printLine(method.asyncAwaitAvailabilityAnnotation())
        self.printLine(
            method.asyncAwaitThrowingSignature(
                using: self.namer,
                options: self.options,
                includeDefaults: false
            )
        )
    }
    private func printAsyncAwaitThrowingMethodImplementation(for method: MethodDescriptor) {
        self.printLine()
        self.printLine(method.asyncAwaitAvailabilityAnnotation())
        self.printLine(
            "\(self.visibility) "
            + method.asyncAwaitThrowingSignature(
                using: self.namer,
                options: self.options,
                includeDefaults: true
            )
            + " {"
        )
        self.indent {
            self.printLine("\(method.asyncAwaitThrowingReturnValue(using: self.namer))")
        }
        self.printLine("}")
    }
}

private extension MethodDescriptor {
    func specStreamType() -> String {
        if self.clientStreaming && self.serverStreaming {
            return ".bidirectionalStream"
        } else if self.serverStreaming {
            return ".serverStream"
        } else if self.clientStreaming {
            return ".clientStream"
        } else {
            return ".unary"
        }
    }

    func idempotencyLevel() -> String {
        switch self.options.idempotencyLevel {
        case .idempotencyUnknown:
            return "unknown"
        case .noSideEffects:
            return "noSideEffects"
        case .idempotent:
            return "idempotent"
        }
    }

    func callbackAvailabilityAnnotation() -> String? {
        if self.options.deprecated {
            // swiftlint:disable line_length
            return """
            @available(iOS, introduced: 12, deprecated: 12, message: "This RPC has been marked as deprecated in its `.proto` file.")
            @available(macOS, introduced: 10.15, deprecated: 10.15, message: "This RPC has been marked as deprecated in its `.proto` file.")
            @available(tvOS, introduced: 13, deprecated: 13, message: "This RPC has been marked as deprecated in its `.proto` file.")
            @available(watchOS, introduced: 6, deprecated: 6, message: "This RPC has been marked as deprecated in its `.proto` file.")
            """
            // swiftlint:enable line_length
        } else {
            return nil
        }
    }

    func asyncAwaitAvailabilityAnnotation() -> String {
        if self.options.deprecated {
            // swiftlint:disable:next line_length
            return "@available(iOS, introduced: 13, deprecated: 13, message: \"This RPC has been marked as deprecated in its `.proto` file.\")"
        } else {
            return "@available(iOS 13, *)"
        }
    }

    func asyncAwaitThrowingReturnValue(
        using namer: SwiftProtobufNamer
    ) -> String {
        let inputName = namer.fullName(message: self.inputType)
        let outputName = namer.fullName(message: self.outputType)
        if self.clientStreaming && self.serverStreaming {
            return """
            let stream: any Connect.BidirectionalAsyncStreamInterface<\(inputName), \(outputName)> = self.client.bidirectionalStream(path: "\(self.methodPath)", headers: [:])
            var request = \(inputName)()
            populator?(&request)
            try stream.send(request)
            let asyncStream = AsyncThrowingStream<\(outputName), Error> { continuation in
                continuation.onTermination = { _ in
                    stream.cancel()
                }
                Task {
                    for await result in stream.results() {
                        switch result {
                        case .message(let message):
                            continuation.yield(message)
                        case .headers:
                            break
                        case let .complete(_, error, _):
                            if let error {
                                continuation.finish(throwing: error)
                            } else {
                                continuation.finish()
                            }
                        }
                    }
                }
            }
            return asyncStream
            """
        } else if self.serverStreaming {
            return """
            let stream: any Connect.ServerOnlyAsyncStreamInterface<\(inputName), \(outputName)> = self.client.serverOnlyStream(path: "\(self.methodPath)", headers: [:])
            var request = \(inputName)()
            populator?(&request)
            try stream.send(request)
            let asyncStream = AsyncThrowingStream<\(outputName), Error> { continuation in
                continuation.onTermination = { _ in
                    stream.cancel()
                }
                Task {
                    for await result in stream.results() {
                        switch result {
                        case .message(let message):
                            continuation.yield(message)
                        case .headers:
                            break
                        case let .complete(_, error, _):
                            if let error {
                                continuation.finish(throwing: error)
                            } else {
                                continuation.finish()
                            }
                        }
                    }
                }
            }
            return asyncStream
            """
        } else if self.clientStreaming {
            return """
            let stream: any Connect.ClientOnlyAsyncStreamInterface<\(inputName), \(outputName)> = self.client.clientOnlyStream(path: "\(self.methodPath)", headers: [:])
            return stream
            """
        } else {
            return """
            var request = \(inputName)()
            populator?(&request)
            let responseMessage: ResponseMessage<\(outputName)> = 
            await self.client.unary(\
            path: "\(self.methodPath)", \
            idempotencyLevel: .\(self.idempotencyLevel()), \
            request: request, \
            headers: [:])
            switch responseMessage.result {
            case .success(let successData):
                return successData
            case .failure(let error):
                throw error
            }
            """
        }
    }
}
