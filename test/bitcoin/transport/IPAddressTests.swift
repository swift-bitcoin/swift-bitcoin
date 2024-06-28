import Testing
import Bitcoin

struct IPAddressTests {

    @Test("IPv4")
    func ipv4() {
        let loopback = IPv4Address.loopback

        let loopbackString = loopback.description
        #expect(loopbackString == "127.0.0.1")

        let roundtrip = IPv4Address(stringLiteral: loopbackString)
        #expect(roundtrip == loopback)

        let literal: IPv4Address = "127.0.0.1"
        #expect(literal == loopback)

        // Extra numbers at the end does not change the address.
        let literal2: IPv4Address = "127.0.0.1.255"
        #expect(literal2 == loopback)

        // Too large numbers or non-numbers are zero
        let literal3: IPv4Address = "127.256.NaN.1"
        #expect(literal3 == loopback)

        // Extra dots don't change the address.
        let literal4: IPv4Address = "..127..0..0..1.."
        #expect(literal4 == loopback)

        // Pad with 0s
        let literal5: IPv4Address = "10"
        #expect(literal5 == "10.0.0.0")

        // Max
        let literal6: IPv4Address = "255.255.255.255"
        let nonLiteral6 = IPv4Address(.init([0xff, 0xff, 0xff, 0xff]))
        #expect(literal6 == "255.255.255.255")
        #expect(literal6 == nonLiteral6)
    }

    @Test("IPv6")
    func ipv6() {
        #expect(IPv6Address.unspecified == "::")

        #expect("1:0:0:0:1:0:0:0" as IPv6Address == "1::1:0:0:0")
        #expect("1:0:0:1:0:0:0:0" as IPv6Address == "1:0:0:1::")
        #expect("1:0:0:1:0:0:0:1" as IPv6Address == "1:0:0:1::1")

        let loopback = IPv6Address.loopback

        let loopbackString = loopback.description
        #expect(loopbackString == "::1")

        let roundtrip = IPv6Address(stringLiteral: loopbackString)
        #expect(roundtrip == loopback)

        let v4Loopback = IPv6Address.ipV4Loopback
        let v4LoopbackString = v4Loopback.description
        #expect(v4LoopbackString == "::ffff:7f00:1")

        let roundtrip2 = IPv6Address(stringLiteral: v4LoopbackString)
        #expect(roundtrip2 == v4Loopback)
    }
}
