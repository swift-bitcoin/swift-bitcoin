import XCTest
import Bitcoin

/// [BIP32 Test Vectors ](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki#test-vectors)
final class BIP32Tests: XCTestCase {

    /// Test vector 1
    func testVector1() throws {

        // Seed (hex)
        let seed = "000102030405060708090a0b0c0d0e0f"

        // Chain m
        var expectedXpub = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8"
        var expectedXprv = "xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi"
        let xprvM = try Wallet.computeHDMasterKey(seed)
        XCTAssertEqual(xprvM, expectedXprv)
        let xpubM = try Wallet.neuterHDPrivateKey(key: xprvM)
        XCTAssertEqual(xpubM, expectedXpub)

        // Chain m/0H
        expectedXpub = "xpub68Gmy5EdvgibQVfPdqkBBCHxA5htiqg55crXYuXoQRKfDBFA1WEjWgP6LHhwBZeNK1VTsfTFUHCdrfp1bgwQ9xv5ski8PX9rL2dZXvgGDnw"
        expectedXprv = "xprv9uHRZZhk6KAJC1avXpDAp4MDc3sQKNxDiPvvkX8Br5ngLNv1TxvUxt4cV1rGL5hj6KCesnDYUhd7oWgT11eZG7XnxHrnYeSvkzY7d2bhkJ7"
        let xprvM0h = try Wallet.deriveHDKey(key: xprvM, index: 0, harden: true)
        XCTAssertEqual(xprvM0h, expectedXprv)
        let xpubM0h = try Wallet.neuterHDPrivateKey(key: xprvM0h)
        XCTAssertEqual(xpubM0h, expectedXpub)

        // Chain m/0H/1
        expectedXpub = "xpub6ASuArnXKPbfEwhqN6e3mwBcDTgzisQN1wXN9BJcM47sSikHjJf3UFHKkNAWbWMiGj7Wf5uMash7SyYq527Hqck2AxYysAA7xmALppuCkwQ"
        expectedXprv = "xprv9wTYmMFdV23N2TdNG573QoEsfRrWKQgWeibmLntzniatZvR9BmLnvSxqu53Kw1UmYPxLgboyZQaXwTCg8MSY3H2EU4pWcQDnRnrVA1xe8fs"
        let xprvM0h1 = try Wallet.deriveHDKey(key: xprvM0h, index: 1)
        XCTAssertEqual(xprvM0h1, expectedXprv)
        var xpubM0h1 = try Wallet.neuterHDPrivateKey(key: xprvM0h1)
        XCTAssertEqual(xpubM0h1, expectedXpub)
        xpubM0h1 = try Wallet.deriveHDKey(isPrivate: false, key: xpubM0h, index: 1)
        XCTAssertEqual(xpubM0h1, expectedXpub)

        // Chain m/0H/1/2H
        expectedXpub = "xpub6D4BDPcP2GT577Vvch3R8wDkScZWzQzMMUm3PWbmWvVJrZwQY4VUNgqFJPMM3No2dFDFGTsxxpG5uJh7n7epu4trkrX7x7DogT5Uv6fcLW5"
        expectedXprv = "xprv9z4pot5VBttmtdRTWfWQmoH1taj2axGVzFqSb8C9xaxKymcFzXBDptWmT7FwuEzG3ryjH4ktypQSAewRiNMjANTtpgP4mLTj34bhnZX7UiM"
        let xprvM0h12h = try Wallet.deriveHDKey(key: xprvM0h1, index: 2, harden: true)
        XCTAssertEqual(xprvM0h12h, expectedXprv)
        var xpubM0h12h = try Wallet.neuterHDPrivateKey(key: xprvM0h12h)
        XCTAssertEqual(xpubM0h12h, expectedXpub)
        XCTAssertThrowsError(
            xpubM0h12h = try Wallet.deriveHDKey(isPrivate: false, key: xpubM0h1, index: 2, harden: true)
        ) {
            guard let walletError = $0 as? WalletError else {
                XCTFail(); return
            }
            XCTAssertEqual(walletError, WalletError.attemptToDeriveHardenedPublicKey)
        }

        // Chain m/0H/1/2H/2
        expectedXpub = "xpub6FHa3pjLCk84BayeJxFW2SP4XRrFd1JYnxeLeU8EqN3vDfZmbqBqaGJAyiLjTAwm6ZLRQUMv1ZACTj37sR62cfN7fe5JnJ7dh8zL4fiyLHV"
        expectedXprv = "xprvA2JDeKCSNNZky6uBCviVfJSKyQ1mDYahRjijr5idH2WwLsEd4Hsb2Tyh8RfQMuPh7f7RtyzTtdrbdqqsunu5Mm3wDvUAKRHSC34sJ7in334"
        let xprvM0h12h2 = try Wallet.deriveHDKey(key: xprvM0h12h, index: 2)
        XCTAssertEqual(xprvM0h12h2, expectedXprv)
        var xpubM0h12h2 = try Wallet.neuterHDPrivateKey(key: xprvM0h12h2)
        XCTAssertEqual(xpubM0h12h2, expectedXpub)
        xpubM0h12h2 = try Wallet.deriveHDKey(isPrivate: false, key: xpubM0h12h, index: 2)
        XCTAssertEqual(xpubM0h12h2, expectedXpub)


        // Chain m/0H/1/2H/2/1000000000
        expectedXpub = "xpub6H1LXWLaKsWFhvm6RVpEL9P4KfRZSW7abD2ttkWP3SSQvnyA8FSVqNTEcYFgJS2UaFcxupHiYkro49S8yGasTvXEYBVPamhGW6cFJodrTHy"
        expectedXprv = "xprvA41z7zogVVwxVSgdKUHDy1SKmdb533PjDz7J6N6mV6uS3ze1ai8FHa8kmHScGpWmj4WggLyQjgPie1rFSruoUihUZREPSL39UNdE3BBDu76"
        let xprvM0h12h21000000000 = try Wallet.deriveHDKey(key: xprvM0h12h2, index: 1000000000)
        XCTAssertEqual(xprvM0h12h21000000000, expectedXprv)
        var xpubM0h12h21000000000 = try Wallet.neuterHDPrivateKey(key: xprvM0h12h21000000000)
        XCTAssertEqual(xpubM0h12h21000000000, expectedXpub)
        xpubM0h12h21000000000 = try Wallet.deriveHDKey(isPrivate: false, key: xpubM0h12h2, index: 1000000000)
        XCTAssertEqual(xpubM0h12h21000000000, expectedXpub)
    }
}
