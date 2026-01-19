import Foundation
import PackagePlugin

@main
struct GenerateMiniscriptWrapperMashups: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let target = context.package.targets.first(where: { $0.name == "BitcoinMiniscript" })!
        let fileURL = target.directoryURL.appending(path: "dsl/WrapperCombinations.swift")

        // `FileHandle(forWritingTo:)` refuses to create new files.
        FileManager.default.createFile(atPath: fileURL.path(), contents: nil)
        let fileHandle = try FileHandle(forWritingTo: fileURL)
        defer { try? fileHandle.close() }

        // Delete existing contents
        try fileHandle.truncate(atOffset: 0)

        for firstWrapper in Wrapper.allCases {
            for secondWrapper in Wrapper.allCases where firstWrapper.requires == secondWrapper.type {
                // Write wrapper mashups composed of two wrappers
                let mashupOfTwo = """
                    /// Apply the `\(firstWrapper.rawValue)\(secondWrapper.rawValue):` Miniscript wrapper mashup to a `\(secondWrapper.requires)` expression.
                    /// - Parameters:
                    ///   - lhs: The ``\(firstWrapper.wrapper)\(secondWrapper.wrapper)(_:)`` wrapper function.
                    ///   - rhs: The input ``Exp\(secondWrapper.requires)`` expression.
                    /// - Returns: The wrapped expression.
                    public func ¦<X: Exp\(secondWrapper.requires)>(lhs: @escaping (_ x: X) -> \(firstWrapper.wrapper)_<\(secondWrapper.wrapper)_<X>>, rhs: X) -> \(firstWrapper.wrapper)_<\(secondWrapper.wrapper)_<X>> { lhs(rhs) }
                    /// The `\(firstWrapper.rawValue)\(secondWrapper.rawValue):` Miniscript wrapper mashup.
                    /// - Parameter x: The input ``Exp\(secondWrapper.requires)`` expression.
                    /// - Returns: The wrapped expression.
                    public func \(firstWrapper.wrapper)\(secondWrapper.wrapper)<X: Exp\(secondWrapper.requires)>(_ x: X) -> \(firstWrapper.wrapper)_<\(secondWrapper.wrapper)_<X>> { \(firstWrapper.wrapper)¦\(secondWrapper.wrapper)(x) }
                    \n
                    """
                if let mashupOfTwoData = mashupOfTwo.data(using: .utf8) {
                    try fileHandle.write(contentsOf: mashupOfTwoData)
                }

                // Write wrapper mashups composed of three wrappers
                for thirdWrapper in Wrapper.allCases where secondWrapper.requires == thirdWrapper.type {
                    let mashupOfThree = """
                        /// Apply the `\(firstWrapper.rawValue)\(secondWrapper.rawValue)\(thirdWrapper.rawValue):` Miniscript wrapper mashup to a `\(thirdWrapper.requires)` expression.
                        /// - Parameters:
                        ///   - lhs: The ``\(firstWrapper.wrapper)\(secondWrapper.wrapper)\(thirdWrapper.wrapper)(_:)`` wrapper function.
                        ///   - rhs: The input ``Exp\(thirdWrapper.requires)`` expression.
                        /// - Returns: The wrapped expression.
                        public func ¦<X: Exp\(thirdWrapper.requires)>(lhs: @escaping (_ x: X) -> \(firstWrapper.wrapper)_<\(secondWrapper.wrapper)_<\(thirdWrapper.wrapper)_<X>>>, rhs: X) -> \(firstWrapper.wrapper)_<\(secondWrapper.wrapper)_<\(thirdWrapper.wrapper)_<X>>> { lhs(rhs) }
                        /// The `\(firstWrapper.rawValue)\(secondWrapper.rawValue)\(thirdWrapper.rawValue):` Miniscript wrapper mashup.
                        /// - Parameter x: The input ``Exp\(thirdWrapper.requires)`` expression.
                        /// - Returns: The wrapped expression.
                        public func \(firstWrapper.wrapper)\(secondWrapper.wrapper)\(thirdWrapper.wrapper)<X: Exp\(thirdWrapper.requires)>(_ x: X) -> \(firstWrapper.wrapper)_<\(secondWrapper.wrapper)_<\(thirdWrapper.wrapper)_<X>>> { \(firstWrapper.wrapper)¦\(secondWrapper.wrapper)¦\(thirdWrapper.wrapper)(x) }
                        \n
                        """
                    if let mashupOfThreeData = mashupOfThree.data(using: .utf8) {
                        try fileHandle.write(contentsOf: mashupOfThreeData)
                    }
                }
            }
        }
    }
}

/// Represents a Miniscript wrapper (identity).
enum Wrapper: String, CaseIterable {
    case a, s, c, d, v, j, n, t, l, u

    /// The wrapper in uppercase form.
    var wrapper: String {
        self.rawValue.uppercased()
    }

    /// The required expression type for this wrapper.
    var requires: ExpType {
        switch self {
        case .a, .s, .v, .j, .n, .l, .u:
            .B
        case .c:
            .K
        case .d, .t:
            .V
        }
    }

    /// The resulting expression type after applying this wrapper.
    var type: ExpType {
        switch self {
        case .a, .s:
            .W
        case .c, .d, .j, .n, .t, .l, .u:
            .B
        case .v:
            .V
        }
    }
}

/// A Miniscript expression type.
enum ExpType: String {
    case B, W, K, V
}
