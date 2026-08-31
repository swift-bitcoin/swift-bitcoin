#!/usr/bin/swift

/// To make this same substitution using Vim:
///
/// ```vim
/// :%s/"\(\(\x\x\)*\)"/\='['.substitute(submatch(1), '\(\x\x\)', '0x\L\1, ', 'g').']'/g
/// :%s/\,\s\]/]/g
/// ```
///

import Foundation

func encode(_ d: [UInt8]) -> String {
    var offset = 0
    let count = d.withUnsafeBytes { $0.count }
    var hexChars = [UInt8](repeating: 0, count: count * 2)
    d.withUnsafeBytes {
        for i in $0 {
            hexChars[Int(offset * 2)] = itoh((i >> 4) & 0xF)
            hexChars[Int(offset * 2 + 1)] = itoh(i & 0xF)
            offset += 1
        }
    }
    print("hexChars \(hexChars)")
    return String(bytes: hexChars, encoding: .utf8)!
}

func decode(_ hexString: String) -> [UInt8] {
    guard hexString.count.isMultiple(of: 2) else {
        fatalError("String length must be an even number.")
    }

    let stringBytes: [UInt8] = Array(hexString.lowercased().data(using: .utf8)!)

    var data = [UInt8]()
    for i in stride(from: stringBytes.startIndex, to: stringBytes.endIndex - 1, by: 2) {
        let char1 = stringBytes[i]
        let char2 = stringBytes[i + 1]

        data.append(htoi(char1) << 4 + htoi(char2))
    }
    return data
}

let charA = UInt8(UnicodeScalar("a").value) // 97
let char0 = UInt8(UnicodeScalar("0").value) // 48

private func itoh(_ value: UInt8) -> UInt8 {
    return (value > 9) ? (charA + value - 10) : (char0 + value)
}

private func htoi(_ value: UInt8) -> UInt8 {
    switch value {
    case char0...char0 + 9:
        return value - char0
    case charA...charA + 5:
        return value - charA + 10
    default:
        fatalError("Invalid hex value")
    }
}

print("Enter an arbitrary length hexadecimal (new line terminates input):")

var buffer = ""
while let line = readLine() {
    if line.isEmpty {
        break;
    }
    buffer += line.lowercased()
}

let decoded = decode(buffer)
let reversed = [UInt8](decoded.reversed())
let recoded = encode(reversed)
print(recoded)
