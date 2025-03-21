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

import Foundation

/// Class containing an internal lock which can be used to ensure thread-safe access to an
/// underlying value. Conforms to `Sendable`, making it accessible from `@Sendable` closures.
final class Locked<Wrapped>: @unchecked Sendable {
    private let lock = Lock()
    private var wrappedValue: Wrapped

    /// Thread-safe access to the underlying value.
    var value: Wrapped {
        get { self.lock.perform { self.wrappedValue } }
        set { self.lock.perform { self.wrappedValue = newValue } }
    }

    /// Perform an action with the underlying value, potentially updating that value.
    ///
    /// - parameter action: Closure to perform with the underlying value.
    ///
    /// - returns: The value returned by the closure.
    @discardableResult
    func perform<Result>(action: @escaping (inout Wrapped) -> Result) -> Result {
        return self.lock.perform {
            action(&self.wrappedValue)
        }
    }

    init(_ value: Wrapped) {
        self.wrappedValue = value
    }
}
