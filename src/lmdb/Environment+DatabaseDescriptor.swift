import CLMDB
import Foundation

extension Database {

    package struct Descriptor: ExpressibleByStringLiteral, ExpressibleByNilLiteral {

        package init(_ name: String? = nil, options: Database.Options = []) {
            self.name = name
            self.options = options
        }

        package init(stringLiteral name: StringLiteralType) {
            self.init(name)
        }

        package init(nilLiteral: ()) {
            self.init()
        }

        let name: String?
        var options: Database.Options

        package static func create(_ name: String? = nil) -> Self {
            Self(name, options: [.create])
        }
    }
}
