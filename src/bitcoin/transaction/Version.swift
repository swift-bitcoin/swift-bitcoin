import Foundation

/// The version of a ``Transaction``.
public struct Version: Equatable {

    private init(_ versionValue: Int) {
        self.versionValue = versionValue
    }

    private let versionValue: Int

    /// Transaction version 1.
    public static let v1 = Self(1)
}
