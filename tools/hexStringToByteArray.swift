#!/usr/bin/swift

print("Enter an arbitrary length hexadecimal (new line terminates input):")

var buffer = ""
while let line = readLine() {
    if line.isEmpty {
        break;
    }
    buffer += line
}

var bytesString = ""
for (i, char) in buffer.enumerated() {
    if i % 2 == 0 {
        bytesString += "0x\(char)"
    } else {
        bytesString += "\(char), "
    }
}

print(bytesString)
