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

import SwiftProtobufPluginLibrary

extension MethodDescriptor {
    public var methodPath: String {
        return "/\(self.service.servicePath)/\(self.name)"
    }

    public func name(using options: GeneratorOptions) -> String {
        return options.keepMethodCasing
        ? self.name
        : NamingUtils.toLowerCamelCase(self.name)
    }

    public func asyncAwaitThrowingSignature(
        using namer: SwiftProtobufNamer,
        options: GeneratorOptions,
        includeDefaults: Bool
    ) -> String {
        let methodName = self.name(using: options)
        let inputName = namer.fullName(message: self.inputType)

        // Note that the method name is escaped to avoid using Swift keywords.
        if self.clientStreaming && self.serverStreaming {
            return """
            func `\(methodName)`\
            (_ populator: ((inout \(inputName)) -> Void)?\(includeDefaults ? " = nil" : "")) \
            throws -> \(returnValue(using: namer))
            """
        } else if self.serverStreaming {
            return """
            func `\(methodName)`\
            (_ populator: ((inout \(inputName)) -> Void)?\(includeDefaults ? " = nil" : "")) \
            throws -> \(returnValue(using: namer))
            """
        } else if self.clientStreaming {
            return """
            func `\(methodName)`\
            (_ populator: ((inout \(inputName)) -> Void)?\(includeDefaults ? " = nil" : "")) \
            throws -> \(returnValue(using: namer))
            """
        } else {
            return """
            func `\(methodName)`\
            (_ populator: ((inout \(inputName)) -> Void)?\(includeDefaults ? " = nil" : "")) \
            async throws -> \(returnValue(using: namer))
            """
        }
    }
    
    public func returnValue(
        using namer: SwiftProtobufNamer
    ) -> String {
        let outputName = namer.fullName(message: self.outputType)

        // Note that the method name is escaped to avoid using Swift keywords.
        if self.clientStreaming && self.serverStreaming {
            return "AsyncThrowingStream<\(outputName), Error>"
        } else if self.serverStreaming {
            return "AsyncThrowingStream<\(outputName), Error>"
        } else if self.clientStreaming {
            return "AsyncThrowingStream<\(outputName), Error>"
        } else {
            return "\(outputName)"
        }
    }
}
