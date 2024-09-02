import Testing
import Foundation
@testable import BitcoinWallet

/// [BIP32 Test Vectors ](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki#test-vectors)
struct BIP32Tests {

    /// Test vector 1
    @Test func vector1() throws {

        // Seed (hex)
        let seedData = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f])

        // Chain m
        var expectedXpub = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8"
        var expectedXprv = "xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi"
        let xprvM = try ExtendedKey(seed: seedData)
        #expect(xprvM.serialized == expectedXprv)
        let xpubM = xprvM.neutered
        #expect(xpubM.serialized == expectedXpub)

        // Chain m/0H
        expectedXpub = "xpub68Gmy5EdvgibQVfPdqkBBCHxA5htiqg55crXYuXoQRKfDBFA1WEjWgP6LHhwBZeNK1VTsfTFUHCdrfp1bgwQ9xv5ski8PX9rL2dZXvgGDnw"
        expectedXprv = "xprv9uHRZZhk6KAJC1avXpDAp4MDc3sQKNxDiPvvkX8Br5ngLNv1TxvUxt4cV1rGL5hj6KCesnDYUhd7oWgT11eZG7XnxHrnYeSvkzY7d2bhkJ7"
        let xprvM0h = xprvM.derive(child: 0, harden: true)
        #expect(xprvM0h.serialized == expectedXprv)
        let xpubM0h = xprvM0h.neutered
        #expect(xpubM0h.serialized == expectedXpub)

        // Chain m/0H/1
        expectedXpub = "xpub6ASuArnXKPbfEwhqN6e3mwBcDTgzisQN1wXN9BJcM47sSikHjJf3UFHKkNAWbWMiGj7Wf5uMash7SyYq527Hqck2AxYysAA7xmALppuCkwQ"
        expectedXprv = "xprv9wTYmMFdV23N2TdNG573QoEsfRrWKQgWeibmLntzniatZvR9BmLnvSxqu53Kw1UmYPxLgboyZQaXwTCg8MSY3H2EU4pWcQDnRnrVA1xe8fs"
        let xprvM0h1 = xprvM0h.derive(child: 1)
        #expect(xprvM0h1.serialized == expectedXprv)
        var xpubM0h1 = xprvM0h1.neutered
        #expect(xpubM0h1.serialized == expectedXpub)
        xpubM0h1 = xpubM0h.derive(child: 1)
        #expect(xpubM0h1.serialized == expectedXpub)

        // Chain m/0H/1/2H
        expectedXpub = "xpub6D4BDPcP2GT577Vvch3R8wDkScZWzQzMMUm3PWbmWvVJrZwQY4VUNgqFJPMM3No2dFDFGTsxxpG5uJh7n7epu4trkrX7x7DogT5Uv6fcLW5"
        expectedXprv = "xprv9z4pot5VBttmtdRTWfWQmoH1taj2axGVzFqSb8C9xaxKymcFzXBDptWmT7FwuEzG3ryjH4ktypQSAewRiNMjANTtpgP4mLTj34bhnZX7UiM"
        let xprvM0h12h = xprvM0h1.derive(child: 2, harden: true)
        #expect(xprvM0h12h.serialized == expectedXprv)
        let xpubM0h12h = xprvM0h12h.neutered
        #expect(xpubM0h12h.serialized == expectedXpub)

        // Chain m/0H/1/2H/2
        expectedXpub = "xpub6FHa3pjLCk84BayeJxFW2SP4XRrFd1JYnxeLeU8EqN3vDfZmbqBqaGJAyiLjTAwm6ZLRQUMv1ZACTj37sR62cfN7fe5JnJ7dh8zL4fiyLHV"
        expectedXprv = "xprvA2JDeKCSNNZky6uBCviVfJSKyQ1mDYahRjijr5idH2WwLsEd4Hsb2Tyh8RfQMuPh7f7RtyzTtdrbdqqsunu5Mm3wDvUAKRHSC34sJ7in334"
        let xprvM0h12h2 = xprvM0h12h.derive(child: 2)
        #expect(xprvM0h12h2.serialized == expectedXprv)
        var xpubM0h12h2 = xprvM0h12h2.neutered
        #expect(xpubM0h12h2.serialized == expectedXpub)
        xpubM0h12h2 = xpubM0h12h.derive(child: 2)
        #expect(xpubM0h12h2.serialized == expectedXpub)


        // Chain m/0H/1/2H/2/1000000000
        expectedXpub = "xpub6H1LXWLaKsWFhvm6RVpEL9P4KfRZSW7abD2ttkWP3SSQvnyA8FSVqNTEcYFgJS2UaFcxupHiYkro49S8yGasTvXEYBVPamhGW6cFJodrTHy"
        expectedXprv = "xprvA41z7zogVVwxVSgdKUHDy1SKmdb533PjDz7J6N6mV6uS3ze1ai8FHa8kmHScGpWmj4WggLyQjgPie1rFSruoUihUZREPSL39UNdE3BBDu76"
        let xprvM0h12h21000000000 = xprvM0h12h2.derive(child: 1000000000)
        #expect(xprvM0h12h21000000000.serialized == expectedXprv)
        var xpubM0h12h21000000000 = xprvM0h12h21000000000.neutered
        #expect(xpubM0h12h21000000000.serialized == expectedXpub)
        xpubM0h12h21000000000 = xpubM0h12h2.derive(child: 1000000000)
        #expect(xpubM0h12h21000000000.serialized == expectedXpub)
    }

    /// Test vector 2
    @Test func vector2() throws {

        // Seed (hex)
        let seedData = Data([0xff, 0xfc, 0xf9, 0xf6, 0xf3, 0xf0, 0xed, 0xea, 0xe7, 0xe4, 0xe1, 0xde, 0xdb, 0xd8, 0xd5, 0xd2, 0xcf, 0xcc, 0xc9, 0xc6, 0xc3, 0xc0, 0xbd, 0xba, 0xb7, 0xb4, 0xb1, 0xae, 0xab, 0xa8, 0xa5, 0xa2, 0x9f, 0x9c, 0x99, 0x96, 0x93, 0x90, 0x8d, 0x8a, 0x87, 0x84, 0x81, 0x7e, 0x7b, 0x78, 0x75, 0x72, 0x6f, 0x6c, 0x69, 0x66, 0x63, 0x60, 0x5d, 0x5a, 0x57, 0x54, 0x51, 0x4e, 0x4b, 0x48, 0x45, 0x42])

        // Chain m
        var expectedXpub = "xpub661MyMwAqRbcFW31YEwpkMuc5THy2PSt5bDMsktWQcFF8syAmRUapSCGu8ED9W6oDMSgv6Zz8idoc4a6mr8BDzTJY47LJhkJ8UB7WEGuduB"
        var expectedXprv = "xprv9s21ZrQH143K31xYSDQpPDxsXRTUcvj2iNHm5NUtrGiGG5e2DtALGdso3pGz6ssrdK4PFmM8NSpSBHNqPqm55Qn3LqFtT2emdEXVYsCzC2U"
        let xprvM = try ExtendedKey(seed: seedData)
        #expect(xprvM.serialized == expectedXprv)
        let xpubM = xprvM.neutered
        #expect(xpubM.serialized == expectedXpub)

        // Chain m/0
        expectedXpub = "xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH"
        expectedXprv = "xprv9vHkqa6EV4sPZHYqZznhT2NPtPCjKuDKGY38FBWLvgaDx45zo9WQRUT3dKYnjwih2yJD9mkrocEZXo1ex8G81dwSM1fwqWpWkeS3v86pgKt"
        let xprvM0 = xprvM.derive(child: 0)
        #expect(xprvM0.serialized == expectedXprv)
        let xpubM0 = xprvM0.neutered
        #expect(xpubM0.serialized == expectedXpub)

        // Chain m/0/2147483647h
        expectedXpub = "xpub6ASAVgeehLbnwdqV6UKMHVzgqAG8Gr6riv3Fxxpj8ksbH9ebxaEyBLZ85ySDhKiLDBrQSARLq1uNRts8RuJiHjaDMBU4Zn9h8LZNnBC5y4a"
        expectedXprv = "xprv9wSp6B7kry3Vj9m1zSnLvN3xH8RdsPP1Mh7fAaR7aRLcQMKTR2vidYEeEg2mUCTAwCd6vnxVrcjfy2kRgVsFawNzmjuHc2YmYRmagcEPdU9"
        let xprvM0h27h = xprvM0.derive(child: 2147483647, harden: true)
        #expect(xprvM0h27h.serialized == expectedXprv)
        let xpubM0h27h = xprvM0h27h.neutered
        #expect(xpubM0h27h.serialized == expectedXpub)

        // Chain m/0/2147483647h/1
        expectedXpub = "xpub6DF8uhdarytz3FWdA8TvFSvvAh8dP3283MY7p2V4SeE2wyWmG5mg5EwVvmdMVCQcoNJxGoWaU9DCWh89LojfZ537wTfunKau47EL2dhHKon"
        expectedXprv = "xprv9zFnWC6h2cLgpmSA46vutJzBcfJ8yaJGg8cX1e5StJh45BBciYTRXSd25UEPVuesF9yog62tGAQtHjXajPPdbRCHuWS6T8XA2ECKADdw4Ef"
        let xprvM0h27h1 = xprvM0h27h.derive(child: 1)
        #expect(xprvM0h27h1.serialized == expectedXprv)
        var xpubM0h27h1 = xprvM0h27h1.neutered
        #expect(xpubM0h27h1.serialized == expectedXpub)
        xpubM0h27h1 = xpubM0h27h.derive(child: 1)
        #expect(xpubM0h27h1.serialized == expectedXpub)

        // Chain m/0/2147483647h/1/2147483646h
        expectedXpub = "xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL"
        expectedXprv = "xprvA1RpRA33e1JQ7ifknakTFpgNXPmW2YvmhqLQYMmrj4xJXXWYpDPS3xz7iAxn8L39njGVyuoseXzU6rcxFLJ8HFsTjSyQbLYnMpCqE2VbFWc"
        let xprvM0h27h126h = xprvM0h27h1.derive(child: 2147483646, harden: true)
        #expect(xprvM0h27h126h.serialized == expectedXprv)
        let xpubM0h27h126h = xprvM0h27h126h.neutered
        #expect(xpubM0h27h126h.serialized == expectedXpub)

        // Chain m/0/2147483647h/1/2147483646h/2
        expectedXpub = "xpub6FnCn6nSzZAw5Tw7cgR9bi15UV96gLZhjDstkXXxvCLsUXBGXPdSnLFbdpq8p9HmGsApME5hQTZ3emM2rnY5agb9rXpVGyy3bdW6EEgAtqt"
        expectedXprv = "xprvA2nrNbFZABcdryreWet9Ea4LvTJcGsqrMzxHx98MMrotbir7yrKCEXw7nadnHM8Dq38EGfSh6dqA9QWTyefMLEcBYJUuekgW4BYPJcr9E7j"
        let xprvM0h27h126h2 = xprvM0h27h126h.derive(child: 2)
        #expect(xprvM0h27h126h2.serialized == expectedXprv)
        var xpubM0h27h126h2 = xprvM0h27h126h2.neutered
        #expect(xpubM0h27h126h2.serialized == expectedXpub)
        xpubM0h27h126h2 = xpubM0h27h126h.derive(child: 2)
        #expect(xpubM0h27h126h2.serialized == expectedXpub)
    }

    /// Test vector 3
    /// These vectors test for the retention of leading zeros. See bitpay/bitcore-lib#47 and iancoleman/bip39#58 for more information.
    @Test func vector3() throws {

        // Seed (hex)
        let seedData = Data([0x4b, 0x38, 0x15, 0x41, 0x58, 0x3b, 0xe4, 0x42, 0x33, 0x46, 0xc6, 0x43, 0x85, 0x0d, 0xa4, 0xb3, 0x20, 0xe4, 0x6a, 0x87, 0xae, 0x3d, 0x2a, 0x4e, 0x6d, 0xa1, 0x1e, 0xba, 0x81, 0x9c, 0xd4, 0xac, 0xba, 0x45, 0xd2, 0x39, 0x31, 0x9a, 0xc1, 0x4f, 0x86, 0x3b, 0x8d, 0x5a, 0xb5, 0xa0, 0xd0, 0xc6, 0x4d, 0x2e, 0x8a, 0x1e, 0x7d, 0x14, 0x57, 0xdf, 0x2e, 0x5a, 0x3c, 0x51, 0xc7, 0x32, 0x35, 0xbe])

        // Chain m
        var expectedXpub = "xpub661MyMwAqRbcEZVB4dScxMAdx6d4nFc9nvyvH3v4gJL378CSRZiYmhRoP7mBy6gSPSCYk6SzXPTf3ND1cZAceL7SfJ1Z3GC8vBgp2epUt13"
        var expectedXprv = "xprv9s21ZrQH143K25QhxbucbDDuQ4naNntJRi4KUfWT7xo4EKsHt2QJDu7KXp1A3u7Bi1j8ph3EGsZ9Xvz9dGuVrtHHs7pXeTzjuxBrCmmhgC6"
        let xprvM = try ExtendedKey(seed: seedData)
        #expect(xprvM.serialized == expectedXprv)
        let xpubM = xprvM.neutered
        #expect(xpubM.serialized == expectedXpub)

        // Chain m/0h
        expectedXpub = "xpub68NZiKmJWnxxS6aaHmn81bvJeTESw724CRDs6HbuccFQN9Ku14VQrADWgqbhhTHBaohPX4CjNLf9fq9MYo6oDaPPLPxSb7gwQN3ih19Zm4Y"
        expectedXprv = "xprv9uPDJpEQgRQfDcW7BkF7eTya6RPxXeJCqCJGHuCJ4GiRVLzkTXBAJMu2qaMWPrS7AANYqdq6vcBcBUdJCVVFceUvJFjaPdGZ2y9WACViL4L"
        let xprvM0h = xprvM.derive(child: 0, harden: true)
        #expect(xprvM0h.serialized == expectedXprv)
        let xpubM0h = xprvM0h.neutered
        #expect(xpubM0h.serialized == expectedXpub)
    }

    /// Test vector 4
    /// These vectors test for the retention of leading zeros. See btcsuite/btcutil#172 for more information.
    @Test func vector4() throws {

        // Seed (hex)
        let seedData = Data([0x3d, 0xdd, 0x56, 0x02, 0x28, 0x58, 0x99, 0xa9, 0x46, 0x11, 0x45, 0x06, 0x15, 0x7c, 0x79, 0x97, 0xe5, 0x44, 0x45, 0x28, 0xf3, 0x00, 0x3f, 0x61, 0x34, 0x71, 0x21, 0x47, 0xdb, 0x19, 0xb6, 0x78])

        // Chain m
        var expectedXpub = "xpub661MyMwAqRbcGczjuMoRm6dXaLDEhW1u34gKenbeYqAix21mdUKJyuyu5F1rzYGVxyL6tmgBUAEPrEz92mBXjByMRiJdba9wpnN37RLLAXa"
        var expectedXprv = "xprv9s21ZrQH143K48vGoLGRPxgo2JNkJ3J3fqkirQC2zVdk5Dgd5w14S7fRDyHH4dWNHUgkvsvNDCkvAwcSHNAQwhwgNMgZhLtQC63zxwhQmRv"
        let xprvM = try ExtendedKey(seed: seedData)
        #expect(xprvM.serialized == expectedXprv)
        let xpubM = xprvM.neutered
        #expect(xpubM.serialized == expectedXpub)

        // Chain m/0h
        expectedXpub = "xpub69AUMk3qDBi3uW1sXgjCmVjJ2G6WQoYSnNHyzkmdCHEhSZ4tBok37xfFEqHd2AddP56Tqp4o56AePAgCjYdvpW2PU2jbUPFKsav5ut6Ch1m"
        expectedXprv = "xprv9vB7xEWwNp9kh1wQRfCCQMnZUEG21LpbR9NPCNN1dwhiZkjjeGRnaALmPXCX7SgjFTiCTT6bXes17boXtjq3xLpcDjzEuGLQBM5ohqkao9G"
        let xprvM0h = xprvM.derive(child: 0, harden: true)
        #expect(xprvM0h.serialized == expectedXprv)
        let xpubM0h = xprvM0h.neutered
        #expect(xpubM0h.serialized == expectedXpub)

        // Chain m/0h/1h
        expectedXpub = "xpub6BJA1jSqiukeaesWfxe6sNK9CCGaujFFSJLomWHprUL9DePQ4JDkM5d88n49sMGJxrhpjazuXYWdMf17C9T5XnxkopaeS7jGk1GyyVziaMt"
        expectedXprv = "xprv9xJocDuwtYCMNAo3Zw76WENQeAS6WGXQ55RCy7tDJ8oALr4FWkuVoHJeHVAcAqiZLE7Je3vZJHxspZdFHfnBEjHqU5hG1Jaj32dVoS6XLT1"
        let xprvM0h1h = xprvM0h.derive(child: 1, harden: true)
        #expect(xprvM0h1h.serialized == expectedXprv)
        let xpubM0h1h = xprvM0h1h.neutered
        #expect(xpubM0h1h.serialized == expectedXpub)
    }

    /// Test vector 5
    /// These vectors test that invalid extended keys are recognized as invalid.
    @Test func vector5() throws {

        // (pubkey version / prvkey mismatch)
        var invalidKey = "xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6LBpB85b3D2yc8sfvZU521AAwdZafEz7mnzBBsz4wKY5fTtTQBm"
        #expect(throws: ExtendedKey.Error.invalidPublicKeyEncoding) {
            _ = try ExtendedKey(invalidKey)
        }

        // (prvkey version / pubkey mismatch)
        invalidKey = "xprv9s21ZrQH143K24Mfq5zL5MhWK9hUhhGbd45hLXo2Pq2oqzMMo63oStZzFGTQQD3dC4H2D5GBj7vWvSQaaBv5cxi9gafk7NF3pnBju6dwKvH"
        #expect(throws: ExtendedKey.Error.invalidPrivateKeyLength) {
            _ = try ExtendedKey(invalidKey)
        }

        // (invalid pubkey prefix 04)
        invalidKey = "xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6Txnt3siSujt9RCVYsx4qHZGc62TG4McvMGcAUjeuwZdduYEvFn"
        #expect(throws: ExtendedKey.Error.invalidPublicKeyEncoding) {
            _ = try ExtendedKey(invalidKey)
        }

        // (invalid prvkey prefix 04)
        invalidKey = "xprv9s21ZrQH143K24Mfq5zL5MhWK9hUhhGbd45hLXo2Pq2oqzMMo63oStZzFGpWnsj83BHtEy5Zt8CcDr1UiRXuWCmTQLxEK9vbz5gPstX92JQ"
        #expect(throws: ExtendedKey.Error.invalidPrivateKeyLength) {
            _ = try ExtendedKey(invalidKey)
        }

        // (invalid pubkey prefix 01)
        invalidKey = "xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6N8ZMMXctdiCjxTNq964yKkwrkBJJwpzZS4HS2fxvyYUA4q2Xe4"
        #expect(throws: ExtendedKey.Error.invalidPublicKeyEncoding) {
            _ = try ExtendedKey(invalidKey)
        }

        // (invalid prvkey prefix 01)
        invalidKey = "xprv9s21ZrQH143K24Mfq5zL5MhWK9hUhhGbd45hLXo2Pq2oqzMMo63oStZzFAzHGBP2UuGCqWLTAPLcMtD9y5gkZ6Eq3Rjuahrv17fEQ3Qen6J"
        #expect(throws: ExtendedKey.Error.invalidPrivateKeyLength) {
            _ = try ExtendedKey(invalidKey)
        }

        // (zero depth with non-zero parent fingerprint)
        invalidKey = "xprv9s2SPatNQ9Vc6GTbVMFPFo7jsaZySyzk7L8n2uqKXJen3KUmvQNTuLh3fhZMBoG3G4ZW1N2kZuHEPY53qmbZzCHshoQnNf4GvELZfqTUrcv"
        #expect(throws: ExtendedKey.Error.zeroDepthNonZeroFingerprint) {
            _ = try ExtendedKey(invalidKey)
        }

        // (zero depth with non-zero parent fingerprint)
        invalidKey = "xpub661no6RGEX3uJkY4bNnPcw4URcQTrSibUZ4NqJEw5eBkv7ovTwgiT91XX27VbEXGENhYRCf7hyEbWrR3FewATdCEebj6znwMfQkhRYHRLpJ"
        #expect(throws: ExtendedKey.Error.zeroDepthNonZeroFingerprint) {
            _ = try ExtendedKey(invalidKey)
        }

        // (zero depth with non-zero index)
        invalidKey = "xprv9s21ZrQH4r4TsiLvyLXqM9P7k1K3EYhA1kkD6xuquB5i39AU8KF42acDyL3qsDbU9NmZn6MsGSUYZEsuoePmjzsB3eFKSUEh3Gu1N3cqVUN"
        #expect(throws: ExtendedKey.Error.zeroDepthNonZeroIndex) {
            _ = try ExtendedKey(invalidKey)
        }

        // (zero depth with non-zero index)
        invalidKey = "xpub661MyMwAuDcm6CRQ5N4qiHKrJ39Xe1R1NyfouMKTTWcguwVcfrZJaNvhpebzGerh7gucBvzEQWRugZDuDXjNDRmXzSZe4c7mnTK97pTvGS8"
        #expect(throws: ExtendedKey.Error.zeroDepthNonZeroIndex) {
            _ = try ExtendedKey(invalidKey)
        }

        // (unknown extended key version)
        invalidKey = "DMwo58pR1QLEFihHiXPVykYB6fJmsTeHvyTp7hRThAtCX8CvYzgPcn8XnmdfHGMQzT7ayAmfo4z3gY5KfbrZWZ6St24UVf2Qgo6oujFktLHdHY4"
        #expect(throws: ExtendedKey.Error.unknownNetwork) {
            _ = try ExtendedKey(invalidKey)
        }

        // (unknown extended key version)
        invalidKey = "DMwo58pR1QLEFihHiXPVykYB6fJmsTeHvyTp7hRThAtCX8CvYzgPcn8XnmdfHPmHJiEDXkTiJTVV9rHEBUem2mwVbbNfvT2MTcAqj3nesx8uBf9"
        #expect(throws: ExtendedKey.Error.unknownNetwork) {
            _ = try ExtendedKey(invalidKey)
        }

        // (private key 0 not in 1..n-1)
        invalidKey = "xprv9s21ZrQH143K24Mfq5zL5MhWK9hUhhGbd45hLXo2Pq2oqzMMo63oStZzF93Y5wvzdUayhgkkFoicQZcP3y52uPPxFnfoLZB21Teqt1VvEHx"
        #expect(throws: ExtendedKey.Error.invalidSecretKey) {
            _ = try ExtendedKey(invalidKey)
        }

        // (private key n not in 1..n-1)
        invalidKey = "xprv9s21ZrQH143K24Mfq5zL5MhWK9hUhhGbd45hLXo2Pq2oqzMMo63oStZzFAzHGBP2UuGCqWLTAPLcMtD5SDKr24z3aiUvKr9bJpdrcLg1y3G"
        #expect(throws: ExtendedKey.Error.invalidSecretKey) {
            _ = try ExtendedKey(invalidKey)
        }

        // (invalid pubkey 020000000000000000000000000000000000000000000000000000000000000007)
        invalidKey = "xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6Q5JXayek4PRsn35jii4veMimro1xefsM58PgBMrvdYre8QyULY"
        #expect(throws: ExtendedKey.Error.invalidPublicKey) {
            _ = try ExtendedKey(invalidKey)
        }

        // GBxrMPHL (invalid checksum)
        invalidKey = "xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yu"
        #expect(throws: ExtendedKey.Error.invalidEncoding) {
            _ = try ExtendedKey(invalidKey)
        }
    }
}
