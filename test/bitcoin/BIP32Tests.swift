import XCTest
@testable import Bitcoin

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

    /// Test vector 2
    func testVector2() throws {

        // Seed (hex)
        let seed = "fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542"

        // Chain m
        var expectedXpub = "xpub661MyMwAqRbcFW31YEwpkMuc5THy2PSt5bDMsktWQcFF8syAmRUapSCGu8ED9W6oDMSgv6Zz8idoc4a6mr8BDzTJY47LJhkJ8UB7WEGuduB"
        var expectedXprv = "xprv9s21ZrQH143K31xYSDQpPDxsXRTUcvj2iNHm5NUtrGiGG5e2DtALGdso3pGz6ssrdK4PFmM8NSpSBHNqPqm55Qn3LqFtT2emdEXVYsCzC2U"
        let xprvM = try Wallet.computeHDMasterKey(seed)
        XCTAssertEqual(xprvM, expectedXprv)
        let xpubM = try Wallet.neuterHDPrivateKey(key: xprvM)
        XCTAssertEqual(xpubM, expectedXpub)

        // Chain m/0
        expectedXpub = "xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH"
        expectedXprv = "xprv9vHkqa6EV4sPZHYqZznhT2NPtPCjKuDKGY38FBWLvgaDx45zo9WQRUT3dKYnjwih2yJD9mkrocEZXo1ex8G81dwSM1fwqWpWkeS3v86pgKt"
        let xprvM0 = try Wallet.deriveHDKey(key: xprvM, index: 0)
        XCTAssertEqual(xprvM0, expectedXprv)
        let xpubM0 = try Wallet.neuterHDPrivateKey(key: xprvM0)
        XCTAssertEqual(xpubM0, expectedXpub)

        // Chain m/0/2147483647h
        expectedXpub = "xpub6ASAVgeehLbnwdqV6UKMHVzgqAG8Gr6riv3Fxxpj8ksbH9ebxaEyBLZ85ySDhKiLDBrQSARLq1uNRts8RuJiHjaDMBU4Zn9h8LZNnBC5y4a"
        expectedXprv = "xprv9wSp6B7kry3Vj9m1zSnLvN3xH8RdsPP1Mh7fAaR7aRLcQMKTR2vidYEeEg2mUCTAwCd6vnxVrcjfy2kRgVsFawNzmjuHc2YmYRmagcEPdU9"
        let xprvM0h27h = try Wallet.deriveHDKey(key: xprvM0, index: 2147483647, harden: true)
        XCTAssertEqual(xprvM0h27h, expectedXprv)
        var xpubM0h27h = try Wallet.neuterHDPrivateKey(key: xprvM0h27h)
        XCTAssertEqual(xpubM0h27h, expectedXpub)

        // Chain m/0/2147483647h/1
        expectedXpub = "xpub6DF8uhdarytz3FWdA8TvFSvvAh8dP3283MY7p2V4SeE2wyWmG5mg5EwVvmdMVCQcoNJxGoWaU9DCWh89LojfZ537wTfunKau47EL2dhHKon"
        expectedXprv = "xprv9zFnWC6h2cLgpmSA46vutJzBcfJ8yaJGg8cX1e5StJh45BBciYTRXSd25UEPVuesF9yog62tGAQtHjXajPPdbRCHuWS6T8XA2ECKADdw4Ef"
        let xprvM0h27h1 = try Wallet.deriveHDKey(key: xprvM0h27h, index: 1)
        XCTAssertEqual(xprvM0h27h1, expectedXprv)
        var xpubM0h27h1 = try Wallet.neuterHDPrivateKey(key: xprvM0h27h1)
        XCTAssertEqual(xpubM0h27h1, expectedXpub)
        xpubM0h27h1 = try Wallet.deriveHDKey(isPrivate: false, key: xpubM0h27h, index: 1)
        XCTAssertEqual(xpubM0h27h1, expectedXpub)

        // Chain m/0/2147483647h/1/2147483646h
        expectedXpub = "xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL"
        expectedXprv = "xprvA1RpRA33e1JQ7ifknakTFpgNXPmW2YvmhqLQYMmrj4xJXXWYpDPS3xz7iAxn8L39njGVyuoseXzU6rcxFLJ8HFsTjSyQbLYnMpCqE2VbFWc"
        let xprvM0h27h126h = try Wallet.deriveHDKey(key: xprvM0h27h1, index: 2147483646, harden: true)
        XCTAssertEqual(xprvM0h27h126h, expectedXprv)
        var xpubM0h27h126h = try Wallet.neuterHDPrivateKey(key: xprvM0h27h126h)
        XCTAssertEqual(xpubM0h27h126h, expectedXpub)

        // Chain m/0/2147483647h/1/2147483646h/2
        expectedXpub = "xpub6FnCn6nSzZAw5Tw7cgR9bi15UV96gLZhjDstkXXxvCLsUXBGXPdSnLFbdpq8p9HmGsApME5hQTZ3emM2rnY5agb9rXpVGyy3bdW6EEgAtqt"
        expectedXprv = "xprvA2nrNbFZABcdryreWet9Ea4LvTJcGsqrMzxHx98MMrotbir7yrKCEXw7nadnHM8Dq38EGfSh6dqA9QWTyefMLEcBYJUuekgW4BYPJcr9E7j"
        let xprvM0h27h126h2 = try Wallet.deriveHDKey(key: xprvM0h27h126h, index: 2)
        XCTAssertEqual(xprvM0h27h126h2, expectedXprv)
        var xpubM0h27h126h2 = try Wallet.neuterHDPrivateKey(key: xprvM0h27h126h2)
        XCTAssertEqual(xpubM0h27h126h2, expectedXpub)
        xpubM0h27h126h2 = try Wallet.deriveHDKey(isPrivate: false, key: xpubM0h27h126h, index: 2)
        XCTAssertEqual(xpubM0h27h126h2, expectedXpub)
    }

    /// Test vector 3
    /// These vectors test for the retention of leading zeros. See bitpay/bitcore-lib#47 and iancoleman/bip39#58 for more information.
    func testVector3() throws {

        // Seed (hex)
        let seed = "4b381541583be4423346c643850da4b320e46a87ae3d2a4e6da11eba819cd4acba45d239319ac14f863b8d5ab5a0d0c64d2e8a1e7d1457df2e5a3c51c73235be"

        // Chain m
        var expectedXpub = "xpub661MyMwAqRbcEZVB4dScxMAdx6d4nFc9nvyvH3v4gJL378CSRZiYmhRoP7mBy6gSPSCYk6SzXPTf3ND1cZAceL7SfJ1Z3GC8vBgp2epUt13"
        var expectedXprv = "xprv9s21ZrQH143K25QhxbucbDDuQ4naNntJRi4KUfWT7xo4EKsHt2QJDu7KXp1A3u7Bi1j8ph3EGsZ9Xvz9dGuVrtHHs7pXeTzjuxBrCmmhgC6"
        let xprvM = try Wallet.computeHDMasterKey(seed)
        XCTAssertEqual(xprvM, expectedXprv)
        let xpubM = try Wallet.neuterHDPrivateKey(key: xprvM)
        XCTAssertEqual(xpubM, expectedXpub)

        // Chain m/0h
        expectedXpub = "xpub68NZiKmJWnxxS6aaHmn81bvJeTESw724CRDs6HbuccFQN9Ku14VQrADWgqbhhTHBaohPX4CjNLf9fq9MYo6oDaPPLPxSb7gwQN3ih19Zm4Y"
        expectedXprv = "xprv9uPDJpEQgRQfDcW7BkF7eTya6RPxXeJCqCJGHuCJ4GiRVLzkTXBAJMu2qaMWPrS7AANYqdq6vcBcBUdJCVVFceUvJFjaPdGZ2y9WACViL4L"
        let xprvM0h = try Wallet.deriveHDKey(key: xprvM, index: 0, harden: true)
        XCTAssertEqual(xprvM0h, expectedXprv)
        let xpubM0h = try Wallet.neuterHDPrivateKey(key: xprvM0h)
        XCTAssertEqual(xpubM0h, expectedXpub)
    }

    /// Test vector 4
    /// These vectors test for the retention of leading zeros. See btcsuite/btcutil#172 for more information.
    func testVector4() throws {

        // Seed (hex)
        let seed = "3ddd5602285899a946114506157c7997e5444528f3003f6134712147db19b678"

        // Chain m
        var expectedXpub = "xpub661MyMwAqRbcGczjuMoRm6dXaLDEhW1u34gKenbeYqAix21mdUKJyuyu5F1rzYGVxyL6tmgBUAEPrEz92mBXjByMRiJdba9wpnN37RLLAXa"
        var expectedXprv = "xprv9s21ZrQH143K48vGoLGRPxgo2JNkJ3J3fqkirQC2zVdk5Dgd5w14S7fRDyHH4dWNHUgkvsvNDCkvAwcSHNAQwhwgNMgZhLtQC63zxwhQmRv"
        let xprvM = try Wallet.computeHDMasterKey(seed)
        XCTAssertEqual(xprvM, expectedXprv)
        let xpubM = try Wallet.neuterHDPrivateKey(key: xprvM)
        XCTAssertEqual(xpubM, expectedXpub)

        // Chain m/0h
        expectedXpub = "xpub69AUMk3qDBi3uW1sXgjCmVjJ2G6WQoYSnNHyzkmdCHEhSZ4tBok37xfFEqHd2AddP56Tqp4o56AePAgCjYdvpW2PU2jbUPFKsav5ut6Ch1m"
        expectedXprv = "xprv9vB7xEWwNp9kh1wQRfCCQMnZUEG21LpbR9NPCNN1dwhiZkjjeGRnaALmPXCX7SgjFTiCTT6bXes17boXtjq3xLpcDjzEuGLQBM5ohqkao9G"
        let xprvM0h = try Wallet.deriveHDKey(key: xprvM, index: 0, harden: true)
        XCTAssertEqual(xprvM0h, expectedXprv)
        let xpubM0h = try Wallet.neuterHDPrivateKey(key: xprvM0h)
        XCTAssertEqual(xpubM0h, expectedXpub)

        // Chain m/0h/1h
        expectedXpub = "xpub6BJA1jSqiukeaesWfxe6sNK9CCGaujFFSJLomWHprUL9DePQ4JDkM5d88n49sMGJxrhpjazuXYWdMf17C9T5XnxkopaeS7jGk1GyyVziaMt"
        expectedXprv = "xprv9xJocDuwtYCMNAo3Zw76WENQeAS6WGXQ55RCy7tDJ8oALr4FWkuVoHJeHVAcAqiZLE7Je3vZJHxspZdFHfnBEjHqU5hG1Jaj32dVoS6XLT1"
        let xprvM0h1h = try Wallet.deriveHDKey(key: xprvM0h, index: 1, harden: true)
        XCTAssertEqual(xprvM0h1h, expectedXprv)
        let xpubM0h1h = try Wallet.neuterHDPrivateKey(key: xprvM0h1h)
        XCTAssertEqual(xpubM0h1h, expectedXpub)
    }

    /// Test vector 5 - **NOT YET PASSING** see #143
    /// These vectors test that invalid extended keys are recognized as invalid.
    func testVector5() throws {
        // TODO: Enable actual checks after #143
        var invalidKey = "xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6LBpB85b3D2yc8sfvZU521AAwdZafEz7mnzBBsz4wKY5fTtTQBm"
        var hdKey = HDExtendedKey(invalidKey)
        // (pubkey version / prvkey mismatch)

        invalidKey = "xprv9s21ZrQH143K24Mfq5zL5MhWK9hUhhGbd45hLXo2Pq2oqzMMo63oStZzFGTQQD3dC4H2D5GBj7vWvSQaaBv5cxi9gafk7NF3pnBju6dwKvH"
        hdKey = HDExtendedKey(invalidKey)
        // (prvkey version / pubkey mismatch)
        invalidKey = "xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6Txnt3siSujt9RCVYsx4qHZGc62TG4McvMGcAUjeuwZdduYEvFn"
        hdKey = HDExtendedKey(invalidKey)
        // (invalid pubkey prefix 04)
        invalidKey = "xprv9s21ZrQH143K24Mfq5zL5MhWK9hUhhGbd45hLXo2Pq2oqzMMo63oStZzFGpWnsj83BHtEy5Zt8CcDr1UiRXuWCmTQLxEK9vbz5gPstX92JQ"
        hdKey = HDExtendedKey(invalidKey)
        // (invalid prvkey prefix 04)
        invalidKey = "xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6N8ZMMXctdiCjxTNq964yKkwrkBJJwpzZS4HS2fxvyYUA4q2Xe4"
        hdKey = HDExtendedKey(invalidKey)
        // (invalid pubkey prefix 01)
        invalidKey = "xprv9s21ZrQH143K24Mfq5zL5MhWK9hUhhGbd45hLXo2Pq2oqzMMo63oStZzFAzHGBP2UuGCqWLTAPLcMtD9y5gkZ6Eq3Rjuahrv17fEQ3Qen6J"
        hdKey = HDExtendedKey(invalidKey)
        // (invalid prvkey prefix 01)
        invalidKey = "xprv9s2SPatNQ9Vc6GTbVMFPFo7jsaZySyzk7L8n2uqKXJen3KUmvQNTuLh3fhZMBoG3G4ZW1N2kZuHEPY53qmbZzCHshoQnNf4GvELZfqTUrcv"
        hdKey = HDExtendedKey(invalidKey)
        // (zero depth with non-zero parent fingerprint)
        invalidKey = "xpub661no6RGEX3uJkY4bNnPcw4URcQTrSibUZ4NqJEw5eBkv7ovTwgiT91XX27VbEXGENhYRCf7hyEbWrR3FewATdCEebj6znwMfQkhRYHRLpJ"
        hdKey = HDExtendedKey(invalidKey)
        // (zero depth with non-zero parent fingerprint)
        invalidKey = "xprv9s21ZrQH4r4TsiLvyLXqM9P7k1K3EYhA1kkD6xuquB5i39AU8KF42acDyL3qsDbU9NmZn6MsGSUYZEsuoePmjzsB3eFKSUEh3Gu1N3cqVUN"
        hdKey = HDExtendedKey(invalidKey)
        // (zero depth with non-zero index)
        invalidKey = "xpub661MyMwAuDcm6CRQ5N4qiHKrJ39Xe1R1NyfouMKTTWcguwVcfrZJaNvhpebzGerh7gucBvzEQWRugZDuDXjNDRmXzSZe4c7mnTK97pTvGS8"
        hdKey = HDExtendedKey(invalidKey)
        // (zero depth with non-zero index)
        invalidKey = "DMwo58pR1QLEFihHiXPVykYB6fJmsTeHvyTp7hRThAtCX8CvYzgPcn8XnmdfHGMQzT7ayAmfo4z3gY5KfbrZWZ6St24UVf2Qgo6oujFktLHdHY4"
        hdKey = HDExtendedKey(invalidKey)
        // (unknown extended key version)
        invalidKey = "DMwo58pR1QLEFihHiXPVykYB6fJmsTeHvyTp7hRThAtCX8CvYzgPcn8XnmdfHPmHJiEDXkTiJTVV9rHEBUem2mwVbbNfvT2MTcAqj3nesx8uBf9"
        hdKey = HDExtendedKey(invalidKey)
        // (unknown extended key version)
        invalidKey = "xprv9s21ZrQH143K24Mfq5zL5MhWK9hUhhGbd45hLXo2Pq2oqzMMo63oStZzF93Y5wvzdUayhgkkFoicQZcP3y52uPPxFnfoLZB21Teqt1VvEHx"
        hdKey = HDExtendedKey(invalidKey)
        // (private key 0 not in 1..n-1)
        invalidKey = "xprv9s21ZrQH143K24Mfq5zL5MhWK9hUhhGbd45hLXo2Pq2oqzMMo63oStZzFAzHGBP2UuGCqWLTAPLcMtD5SDKr24z3aiUvKr9bJpdrcLg1y3G"
        hdKey = HDExtendedKey(invalidKey)
        // (private key n not in 1..n-1)
        invalidKey = "xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6Q5JXayek4PRsn35jii4veMimro1xefsM58PgBMrvdYre8QyULY"
        hdKey = HDExtendedKey(invalidKey)
        // (invalid pubkey 020000000000000000000000000000000000000000000000000000000000000007)
        invalidKey = "xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yu"
        hdKey = HDExtendedKey(invalidKey)
        //GBxrMPHL (invalid checksum)
    }
}
