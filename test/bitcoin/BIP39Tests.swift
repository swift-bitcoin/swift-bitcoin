import XCTest
import Bitcoin

final class BIP39Tests: XCTestCase {

    func testAll() throws {
        let passphrase = "TREZOR"
        for language in ["en", "es", "jp", "zh", "zh-Hant"] {
            for testCase in testVector[language]! {
                let entropy = testCase[0]
                let expectedMnemonic = testCase[1]
                let expectedSeed = testCase[2]
                let expectedXPriv = testCase[3]
                let mnemonic = try Wallet.mnemonicNew(withEntropy: entropy, language: language)
                XCTAssertEqual(mnemonic, expectedMnemonic)
                let seed = try Wallet.mnemonicToSeed(mnemonic: mnemonic, passphrase: passphrase, language: language)
                XCTAssertEqual(seed, expectedSeed)
                let xpriv = try Wallet.computeHDMasterKey(seed)
                XCTAssertEqual(xpriv, expectedXPriv)
            }
        }
    }
}

let testVector: [String: [[String]]] = [
    "en": [
        [
            "00000000000000000000000000000000",
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
            "c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04",
            "xprv9s21ZrQH143K3h3fDYiay8mocZ3afhfULfb5GX8kCBdno77K4HiA15Tg23wpbeF1pLfs1c5SPmYHrEpTuuRhxMwvKDwqdKiGJS9XFKzUsAF"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "legal winner thank year wave sausage worth useful legal winner thank yellow",
            "2e8905819b8723fe2c1d161860e5ee1830318dbf49a83bd451cfb8440c28bd6fa457fe1296106559a3c80937a1c1069be3a3a5bd381ee6260e8d9739fce1f607",
            "xprv9s21ZrQH143K2gA81bYFHqU68xz1cX2APaSq5tt6MFSLeXnCKV1RVUJt9FWNTbrrryem4ZckN8k4Ls1H6nwdvDTvnV7zEXs2HgPezuVccsq"
        ],
        [
            "80808080808080808080808080808080",
            "letter advice cage absurd amount doctor acoustic avoid letter advice cage above",
            "d71de856f81a8acc65e6fc851a38d4d7ec216fd0796d0a6827a3ad6ed5511a30fa280f12eb2e47ed2ac03b5c462a0358d18d69fe4f985ec81778c1b370b652a8",
            "xprv9s21ZrQH143K2shfP28KM3nr5Ap1SXjz8gc2rAqqMEynmjt6o1qboCDpxckqXavCwdnYds6yBHZGKHv7ef2eTXy461PXUjBFQg6PrwY4Gzq"
        ],
        [
            "ffffffffffffffffffffffffffffffff",
            "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong",
            "ac27495480225222079d7be181583751e86f571027b0497b5b5d11218e0a8a13332572917f0f8e5a589620c6f15b11c61dee327651a14c34e18231052e48c069",
            "xprv9s21ZrQH143K2V4oox4M8Zmhi2Fjx5XK4Lf7GKRvPSgydU3mjZuKGCTg7UPiBUD7ydVPvSLtg9hjp7MQTYsW67rZHAXeccqYqrsx8LcXnyd"
        ],
        [
            "000000000000000000000000000000000000000000000000",
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon agent",
            "035895f2f481b1b0f01fcf8c289c794660b289981a78f8106447707fdd9666ca06da5a9a565181599b79f53b844d8a71dd9f439c52a3d7b3e8a79c906ac845fa",
            "xprv9s21ZrQH143K3mEDrypcZ2usWqFgzKB6jBBx9B6GfC7fu26X6hPRzVjzkqkPvDqp6g5eypdk6cyhGnBngbjeHTe4LsuLG1cCmKJka5SMkmU"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth useful legal will",
            "f2b94508732bcbacbcc020faefecfc89feafa6649a5491b8c952cede496c214a0c7b3c392d168748f2d4a612bada0753b52a1c7ac53c1e93abd5c6320b9e95dd",
            "xprv9s21ZrQH143K3Lv9MZLj16np5GzLe7tDKQfVusBni7toqJGcnKRtHSxUwbKUyUWiwpK55g1DUSsw76TF1T93VT4gz4wt5RM23pkaQLnvBh7"
        ],
        [
            "808080808080808080808080808080808080808080808080",
            "letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic avoid letter always",
            "107d7c02a5aa6f38c58083ff74f04c607c2d2c0ecc55501dadd72d025b751bc27fe913ffb796f841c49b1d33b610cf0e91d3aa239027f5e99fe4ce9e5088cd65",
            "xprv9s21ZrQH143K3VPCbxbUtpkh9pRG371UCLDz3BjceqP1jz7XZsQ5EnNkYAEkfeZp62cDNj13ZTEVG1TEro9sZ9grfRmcYWLBhCocViKEJae"
        ],
        [
            "ffffffffffffffffffffffffffffffffffffffffffffffff",
            "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo when",
            "0cd6e5d827bb62eb8fc1e262254223817fd068a74b5b449cc2f667c3f1f985a76379b43348d952e2265b4cd129090758b3e3c2c49103b5051aac2eaeb890a528",
            "xprv9s21ZrQH143K36Ao5jHRVhFGDbLP6FCx8BEEmpru77ef3bmA928BxsqvVM27WnvvyfWywiFN8K6yToqMaGYfzS6Db1EHAXT5TuyCLBXUfdm"
        ],
        [
            "0000000000000000000000000000000000000000000000000000000000000000",
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art",
            "bda85446c68413707090a52022edd26a1c9462295029f2e60cd7c4f2bbd3097170af7a4d73245cafa9c3cca8d561a7c3de6f5d4a10be8ed2a5e608d68f92fcc8",
            "xprv9s21ZrQH143K32qBagUJAMU2LsHg3ka7jqMcV98Y7gVeVyNStwYS3U7yVVoDZ4btbRNf4h6ibWpY22iRmXq35qgLs79f312g2kj5539ebPM"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth title",
            "bc09fca1804f7e69da93c2f2028eb238c227f2e9dda30cd63699232578480a4021b146ad717fbb7e451ce9eb835f43620bf5c514db0f8add49f5d121449d3e87",
            "xprv9s21ZrQH143K3Y1sd2XVu9wtqxJRvybCfAetjUrMMco6r3v9qZTBeXiBZkS8JxWbcGJZyio8TrZtm6pkbzG8SYt1sxwNLh3Wx7to5pgiVFU"
        ],
        [
            "8080808080808080808080808080808080808080808080808080808080808080",
            "letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic bless",
            "c0c519bd0e91a2ed54357d9d1ebef6f5af218a153624cf4f2da911a0ed8f7a09e2ef61af0aca007096df430022f7a2b6fb91661a9589097069720d015e4e982f",
            "xprv9s21ZrQH143K3CSnQNYC3MqAAqHwxeTLhDbhF43A4ss4ciWNmCY9zQGvAKUSqVUf2vPHBTSE1rB2pg4avopqSiLVzXEU8KziNnVPauTqLRo"
        ],
        [
            "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo vote",
            "dd48c104698c30cfe2b6142103248622fb7bb0ff692eebb00089b32d22484e1613912f0a5b694407be899ffd31ed3992c456cdf60f5d4564b8ba3f05a69890ad",
            "xprv9s21ZrQH143K2WFF16X85T2QCpndrGwx6GueB72Zf3AHwHJaknRXNF37ZmDrtHrrLSHvbuRejXcnYxoZKvRquTPyp2JiNG3XcjQyzSEgqCB"
        ],
        [
            "9e885d952ad362caeb4efe34a8e91bd2",
            "ozone drill grab fiber curtain grace pudding thank cruise elder eight picnic",
            "274ddc525802f7c828d8ef7ddbcdc5304e87ac3535913611fbbfa986d0c9e5476c91689f9c8a54fd55bd38606aa6a8595ad213d4c9c9f9aca3fb217069a41028",
            "xprv9s21ZrQH143K2oZ9stBYpoaZ2ktHj7jLz7iMqpgg1En8kKFTXJHsjxry1JbKH19YrDTicVwKPehFKTbmaxgVEc5TpHdS1aYhB2s9aFJBeJH"
        ],
        [
            "6610b25967cdcca9d59875f5cb50b0ea75433311869e930b",
            "gravity machine north sort system female filter attitude volume fold club stay feature office ecology stable narrow fog",
            "628c3827a8823298ee685db84f55caa34b5cc195a778e52d45f59bcf75aba68e4d7590e101dc414bc1bbd5737666fbbef35d1f1903953b66624f910feef245ac",
            "xprv9s21ZrQH143K3uT8eQowUjsxrmsA9YUuQQK1RLqFufzybxD6DH6gPY7NjJ5G3EPHjsWDrs9iivSbmvjc9DQJbJGatfa9pv4MZ3wjr8qWPAK"
        ],
        [
            "68a79eaca2324873eacc50cb9c6eca8cc68ea5d936f98787c60c7ebc74e6ce7c",
            "hamster diagram private dutch cause delay private meat slide toddler razor book happy fancy gospel tennis maple dilemma loan word shrug inflict delay length",
            "64c87cde7e12ecf6704ab95bb1408bef047c22db4cc7491c4271d170a1b213d20b385bc1588d9c7b38f1b39d415665b8a9030c9ec653d75e65f847d8fc1fc440",
            "xprv9s21ZrQH143K2XTAhys3pMNcGn261Fi5Ta2Pw8PwaVPhg3D8DWkzWQwjTJfskj8ofb81i9NP2cUNKxwjueJHHMQAnxtivTA75uUFqPFeWzk"
        ],
        [
            "c0ba5a8e914111210f2bd131f3d5e08d",
            "scheme spot photo card baby mountain device kick cradle pact join borrow",
            "ea725895aaae8d4c1cf682c1bfd2d358d52ed9f0f0591131b559e2724bb234fca05aa9c02c57407e04ee9dc3b454aa63fbff483a8b11de949624b9f1831a9612",
            "xprv9s21ZrQH143K3FperxDp8vFsFycKCRcJGAFmcV7umQmcnMZaLtZRt13QJDsoS5F6oYT6BB4sS6zmTmyQAEkJKxJ7yByDNtRe5asP2jFGhT6"
        ],
        [
            "6d9be1ee6ebd27a258115aad99b7317b9c8d28b6d76431c3",
            "horn tenant knee talent sponsor spell gate clip pulse soap slush warm silver nephew swap uncle crack brave",
            "fd579828af3da1d32544ce4db5c73d53fc8acc4ddb1e3b251a31179cdb71e853c56d2fcb11aed39898ce6c34b10b5382772db8796e52837b54468aeb312cfc3d",
            "xprv9s21ZrQH143K3R1SfVZZLtVbXEB9ryVxmVtVMsMwmEyEvgXN6Q84LKkLRmf4ST6QrLeBm3jQsb9gx1uo23TS7vo3vAkZGZz71uuLCcywUkt"
        ],
        [
            "9f6a2878b2520799a44ef18bc7df394e7061a224d2c33cd015b157d746869863",
            "panda eyebrow bullet gorilla call smoke muffin taste mesh discover soft ostrich alcohol speed nation flash devote level hobby quick inner drive ghost inside",
            "72be8e052fc4919d2adf28d5306b5474b0069df35b02303de8c1729c9538dbb6fc2d731d5f832193cd9fb6aeecbc469594a70e3dd50811b5067f3b88b28c3e8d",
            "xprv9s21ZrQH143K2WNnKmssvZYM96VAr47iHUQUTUyUXH3sAGNjhJANddnhw3i3y3pBbRAVk5M5qUGFr4rHbEWwXgX4qrvrceifCYQJbbFDems"
        ],
        [
            "23db8160a31d3e0dca3688ed941adbf3",
            "cat swing flag economy stadium alone churn speed unique patch report train",
            "deb5f45449e615feff5640f2e49f933ff51895de3b4381832b3139941c57b59205a42480c52175b6efcffaa58a2503887c1e8b363a707256bdd2b587b46541f5",
            "xprv9s21ZrQH143K4G28omGMogEoYgDQuigBo8AFHAGDaJdqQ99QKMQ5J6fYTMfANTJy6xBmhvsNZ1CJzRZ64PWbnTFUn6CDV2FxoMDLXdk95DQ"
        ],
        [
            "8197a4a47f0425faeaa69deebc05ca29c0a5b5cc76ceacc0",
            "light rule cinnamon wrap drastic word pride squirrel upgrade then income fatal apart sustain crack supply proud access",
            "4cbdff1ca2db800fd61cae72a57475fdc6bab03e441fd63f96dabd1f183ef5b782925f00105f318309a7e9c3ea6967c7801e46c8a58082674c860a37b93eda02",
            "xprv9s21ZrQH143K3wtsvY8L2aZyxkiWULZH4vyQE5XkHTXkmx8gHo6RUEfH3Jyr6NwkJhvano7Xb2o6UqFKWHVo5scE31SGDCAUsgVhiUuUDyh"
        ],
        [
            "066dca1a2bb7e8a1db2832148ce9933eea0f3ac9548d793112d9a95c9407efad",
            "all hour make first leader extend hole alien behind guard gospel lava path output census museum junior mass reopen famous sing advance salt reform",
            "26e975ec644423f4a4c4f4215ef09b4bd7ef924e85d1d17c4cf3f136c2863cf6df0a475045652c57eb5fb41513ca2a2d67722b77e954b4b3fc11f7590449191d",
            "xprv9s21ZrQH143K3rEfqSM4QZRVmiMuSWY9wugscmaCjYja3SbUD3KPEB1a7QXJoajyR2T1SiXU7rFVRXMV9XdYVSZe7JoUXdP4SRHTxsT1nzm"
        ],
        [
            "f30f8c1da665478f49b001d94c5fc452",
            "vessel ladder alter error federal sibling chat ability sun glass valve picture",
            "2aaa9242daafcee6aa9d7269f17d4efe271e1b9a529178d7dc139cd18747090bf9d60295d0ce74309a78852a9caadf0af48aae1c6253839624076224374bc63f",
            "xprv9s21ZrQH143K2QWV9Wn8Vvs6jbqfF1YbTCdURQW9dLFKDovpKaKrqS3SEWsXCu6ZNky9PSAENg6c9AQYHcg4PjopRGGKmdD313ZHszymnps"
        ],
        [
            "c10ec20dc3cd9f652c7fac2f1230f7a3c828389a14392f05",
            "scissors invite lock maple supreme raw rapid void congress muscle digital elegant little brisk hair mango congress clump",
            "7b4a10be9d98e6cba265566db7f136718e1398c71cb581e1b2f464cac1ceedf4f3e274dc270003c670ad8d02c4558b2f8e39edea2775c9e232c7cb798b069e88",
            "xprv9s21ZrQH143K4aERa2bq7559eMCCEs2QmmqVjUuzfy5eAeDX4mqZffkYwpzGQRE2YEEeLVRoH4CSHxianrFaVnMN2RYaPUZJhJx8S5j6puX"
        ],
        [
            "f585c11aec520db57dd353c69554b21a89b20fb0650966fa0a9d6f74fd989d8f",
            "void come effort suffer camp survey warrior heavy shoot primary clutch crush open amazing screen patrol group space point ten exist slush involve unfold",
            "01f5bced59dec48e362f2c45b5de68b9fd6c92c6634f44d6d40aab69056506f0e35524a518034ddc1192e1dacd32c1ed3eaa3c3b131c88ed8e7e54c49a5d0998",
            "xprv9s21ZrQH143K39rnQJknpH1WEPFJrzmAqqasiDcVrNuk926oizzJDDQkdiTvNPr2FYDYzWgiMiC63YmfPAa2oPyNB23r2g7d1yiK6WpqaQS"
        ]
    ],
    "es": [
        [
            "00000000000000000000000000000000",
            "ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco abierto",
            "29a2ee16de47d07025de37e7d9c596869439f9bcd26a702d2bae64db2bf0f68383841c5444b5b3bd39dd720d2ebe59969e110e5955c8e6d32c6c3294fd87439b",
            "xprv9s21ZrQH143K49iYfUTNyLe6mVRHvYSg58nfiLkcSREsu5QefrsvQ9KWsMtX7SXsXwvs6J1esWdna2weySpUFZNN6qiXuHcobEMWGLfyaHG"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "ligero vista talar yogur venta queso yacer trozo ligero vista talar zafiro",
            "1580aa5d5d67057b3a0a12253c283b93921851555529d0bbe9634349d641029216f791ddce3527819d44d833a0df3500b15fd8ba4cae7ca24e1464b9167de633",
            "xprv9s21ZrQH143K27g7EMkgY2F1fuyqSEKq6n1iJCHuiUX5F3oGESmJSS6DcKW5JZ6qWWJ7x8wS1FCrd1NhRS4xCWDn9Bb1HzBuNpitD7FeYGv"
        ],
        [
            "80808080808080808080808080808080",
            "lino admitir bolero abrir álbum dejar acelga aprender lino admitir bolero abogado",
            "a89366f7f9c4bd98afca8edf1242507506562b8eb8a3a60468cafcb6f3037aba1e4d9a7497f6d49fa94aca87c95703873741441a719325af371f8eda9b59dc83",
            "xprv9s21ZrQH143K2dG5ptughpsWSbdXdRVg6ZZtF8RehVMaDNM2TJ6NZAtorTDm2EVpt5nwpsgtjgYW3GD6oP8Nk3ZhibRQFRJ4f5JoDrunY1m"
        ],
        [
            "ffffffffffffffffffffffffffffffff",
            "zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo yodo",
            "a9d1f751178872cc53fc5433e9b2a97526448adc4b824cedeadd8a127c2416481345dfbef2bfc78275f3498e40b4e8e2e00560100e543aba3f324e752f032bc9",
            "xprv9s21ZrQH143K4TU3oETVCyPLTqmC8C7zqqSR7L8JpMiR68YNhyvfEmXpRh6pP8gPghpFbvNSQCQppPDf55iNnZhT9iza6HRpTvKeLSDNFCg"
        ],
        [
            "000000000000000000000000000000000000000000000000",
            "ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco afición",
            "6c9f21d46c56f723cd734e308f10ebf44b5b92a2e0d80fd66a2952b8d37af5219e0b93c59e1d8e63b47ac657ec2c524e5fb951d87cac824f84a3ac6264b7aaac",
            "xprv9s21ZrQH143K3AjqVTqs8gbpkEoSkCVEM6dAGvRm2TJgxTLih4TuPPSp6gheAkXpPRhG63Fb9Cr5MEto2j6hGJ4ZVPa3C1GHXUyPPwMRXCV"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "ligero vista talar yogur venta queso yacer trozo ligero vista talar yogur venta queso yacer trozo ligero violín",
            "f73b28d7e180e0a92c57276a29489c10a992c8a465ab61be0ade4708543436a682b2a3c22de57c48736ae6f29bebf3e506779c74bc1a835ad6b9f4e174126ca8",
            "xprv9s21ZrQH143K4PEMCi1dMq3ZwveC5um6cXR3tp4Z6LUGLhz4pmkaDU44UoSTiMQHv5icYPjH5EooZNorbDB7fLMDa531HHrKKnEEqCT5Tfs"
        ],
        [
            "808080808080808080808080808080808080808080808080",
            "lino admitir bolero abrir álbum dejar acelga aprender lino admitir bolero abrir álbum dejar acelga aprender lino alacrán",
            "f799e5c2782b50d0eb1d25b5f94984c5b4037ade236c6aa3b48b3df01b703d8ede5f94555f4e78f87a642a9676ba052865418c469c5739b3e93acc528fad30b7",
            "xprv9s21ZrQH143K2UeG5FGYFmkW7oTy35ZFgQ7qdR5tzBdKxGLCEfVJPPA98e2wUpfD3Eg6GS4833dFVVKafB3RNGMSZtxoWc56Yxo7PaBgYds"
        ],
        [
            "ffffffffffffffffffffffffffffffffffffffffffffffff",
            "zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo viejo",
            "2fd3964ac77c52232dc0eb2ab237fea2de9b7509005214101ecbbaeb40f34bce7735e848fca6339f76f289904c6db959fa573fc0aa607d969ac256693b4fb7af",
            "xprv9s21ZrQH143K3zwjASrAazc9EGeoVcQXA3unTmgxG9ZS7nc75inZw19oktj1y3n2Y7yetBatSN3v2UpS9ms3PvmrgQEMC4jox4ZV1ZrW6Qz"
        ],
        [
            "0000000000000000000000000000000000000000000000000000000000000000",
            "ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ábaco ancla",
            "f600536eca941ed937318828e9ebab24b3b571558250e7a8342fc3cf16c458b2d7b36c36155a86cc308f7bef6d87b05d5dbe347f1a83c3dfbabd89e9c45b7883",
            "xprv9s21ZrQH143K2J842VWEPWH3ssnSvZYhRCzPoEcifAN4UgETeYkTdvnMUgnuftLyeGttvdvec8F1YJCmQz5mS956jsb2m8yDXZtnxRgiYgX"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "ligero vista talar yogur venta queso yacer trozo ligero vista talar yogur venta queso yacer trozo ligero vista talar yogur venta queso yacer teatro",
            "3d2a3aec779195f2628e800879d600cfaf2d7fcfa998657068db53906a00608fcc94fc78ceab8c97d6191389c4e468815ea0d11ffa4280c34c3cf17721a27c73",
            "xprv9s21ZrQH143K2WBRPum95TFxfz8niK5sbiDpQjyr915SjEJc99BrYoRhPuYvfzFhPwqUNAFtEdw4khqQMK4ge8EnTZZASbv7oy8t6SMzVSM"
        ],
        [
            "8080808080808080808080808080808080808080808080808080808080808080",
            "lino admitir bolero abrir álbum dejar acelga aprender lino admitir bolero abrir álbum dejar acelga aprender lino admitir bolero abrir álbum dejar acelga aumento",
            "dd095dddb50de059f5cb6932d529ad37dd32d40f72da3d0c7671ffc6bd967b4392fe233e5e9a4d9e5e60413160ae215e34375db85e95ccbab4fd4712f32216ab",
            "xprv9s21ZrQH143K3SQcqhHXxwZ793d4RXPpUQJQm8Bpf799AZPzicBxB87hu4Sm2DvWBqFvmxEjN3bY6EVzUxhJbHKdtV2k6u4c3ZNRFGhZDma"
        ],
        [
            "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            "zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo zurdo varón",
            "deea21c6902df5ef4a8efab8e14de53004c68817ea3de421cdd184f4159a6e9947376ed794c3ce67534f37f80b46674e85335555b5c53f44fdfef27991fedc0e",
            "xprv9s21ZrQH143K4TyBobPSoDLEze5gKjiTZXzaJaND1QHqmrnx6kULMJhGvQkraSHgUsjmisepryPQqTfWyM3ETLjusTsW35KumQ3w3RyusSM"
        ],
        [
            "9e885d952ad362caeb4efe34a8e91bd2",
            "obra diadema gorila farmacia colgar gorra pausa talar cocina duda dragón optar",
            "fcf6ebfc7d9eebab56ca868cbd2d5d05a6f2142ba903c52855dad4ab8c0c2cf6b4e047a2dd97cf382ae717dc18d155a45fc798e6f0a0b89971a4224e2a285701",
            "xprv9s21ZrQH143K3pxsjjkbjzEu1f9qaeGb9wTLZ39rUF4CoP125zApXELXDspSNV1Cn8vjvXKNQymm8iwSRpJr9AZyKvHTVVbg1Tq6kY48iTV"
        ],
        [
            "6610b25967cdcca9d59875f5cb50b0ea75433311869e930b",
            "gráfico madera muro rutina suelo falso favor añadir variar firma casco semana fácil neón don sección morder fingir",
            "5b48222ce814960e3b2f507ba58e96b4fa655f76060943b47c7a1396d431c570849e6f1595add9474934a72110bd3da06824428650be819f8d093e0023fccee6",
            "xprv9s21ZrQH143K3JpnkDoEPYdCo6QEBW4eUfKe1CCweKfHF5DkonVNPQRkDcYEva6pBBfGLeRt56UB6oSnhemWzbSBXCpdefk3hBDWqUAPb2E"
        ],
        [
            "68a79eaca2324873eacc50cb9c6eca8cc68ea5d936f98787c60c7ebc74e6ce7c",
            "guion culebra parcela diluir buitre crecer parcela marzo roce tejado picar azafrán guitarra exilio goloso tabla mando curar loco voto reparto insecto crecer lince",
            "5dd9ecc2a8f504413ee001e4f27f25ad14533a35b3986b4ad505a9774740d0c0a6bbac6953a1ee47104357f4a5bc4acbc0f71813f9532fa667f3d3b6f2d6dd6d",
            "xprv9s21ZrQH143K4XB8BVsQ9TsrC12DWTkizmcY3X6kVqycT1pAVLhx3EHfWow3H27QV4YH8kMLum7nzjSexrAxh8tKZzHRYPPexmAaaM1KEYQ"
        ],
        [
            "c0ba5a8e914111210f2bd131f3d5e08d",
            "ración sapo opción brinco árbol mismo cueva lamer cigarro obrero júpiter azufre",
            "49b0de91db6c84527afe1bccb2525b93dbdae0306bd3ea8a1f629ea1704195d450a0a3211894c417f586fde217f024b4159a4f6ac7f5d18bb8b7bbf72c4f4d20",
            "xprv9s21ZrQH143K3W9fk6GQj1oNT2gYszJhNBhZjPmkTsR2jmoE89oRHHknYt8WLWREtopcnPs1ZWoJjV3A5QxrW5crBA5s6bWgp2DCfLUDA5Y"
        ],
        [
            "6d9be1ee6ebd27a258115aad99b7317b9c8d28b6d76431c3",
            "honor tabique lata sultán sanidad salón gafas carga payaso rostro rojizo vena retrato móvil soplar trabajo cifra balde",
            "484af722d01c9cdc9ac50f3fdfeec010c7f713fb90dbfe84dae21d8215b683e660ddeec44d685faf3e653f396ef8ce0d341097c50bffcf67ea094ebb44294df4",
            "xprv9s21ZrQH143K2ouVUYDQXJpeurwoTTmfvUThuo1vRhuSXrVrKgsxAtaet1U9M5WZDpqaiLAPz17LLSuHmQG4eMMAy48Zt4AMzUwgNnEXY1Q"
        ],
        [
            "9f6a2878b2520799a44ef18bc7df394e7061a224d2c33cd015b157d746869863",
            "océano eterno bestia golfo bomba ron moda sur médula danza rueda núcleo agrio salmón morir ficha cuidar linterna higiene pensar iris diario ganso jamón",
            "8cc9507c9ccafaf341a243e5b82c348e374b24c8c594131add8684cfc1e61ab51e5476a4006d4d780bd2b82e9d9581ae1af67c8845e40246d5b1110814a88088",
            "xprv9s21ZrQH143K3rpBRE8Wy6o6fZ6P6SX9ZrPCATgfgMHBHK4y9vbkj3VW19wRGR6tAeT7td2iB5bvwRXqXZ2FkBCmeCsJD4Uxf363BEuBwtx"
        ],
        [
            "23db8160a31d3e0dca3688ed941adbf3",
            "bucle sótano fibra donar seco aire campo salmón trato odio poco tierra",
            "55b603a9cd15a9769e21fd22a384d12de9afe0b9c0af0f07aee688cddd792b2863064767a6df9e8aebb4bf10d4482de07ffe6d7f7440df73f04fc544236fee06",
            "xprv9s21ZrQH143K31JznDuVnKRYfF538PE1GSe5W75rLGwpSuDFWaQrW48bSuzvkD7cPWqLHcjxi1AjQYFjzCEVkwpU8sq4XScgZigY4TQrSEk"
        ],
        [
            "8197a4a47f0425faeaa69deebc05ca29c0a5b5cc76ceacc0",
            "llaga pudor candil yate detalle voto papá saxofón tribu talla infiel exponer altivo sonoro cifra solapa pata abuso",
            "b63a7651d8655add895fd8a45f0fd4c0c71bd8863a8e0fd72782b2f36d43ef2fa8830ab46647afc8c437e701aed41b0bc6b2df9f11887c44457aefe2c11d413d",
            "xprv9s21ZrQH143K3CSbDbXN4ckMcyDHyLwkrQqvXL4xBRATernArEtGvZG8eFhxLbbRBZqaBnRc3ZyrN349dRxUeAozveLohZ5AWRKsDuk6XT1"
        ],
        [
            "066dca1a2bb7e8a1db2832148ce9933eea0f3ac9548d793112d9a95c9407efad",
            "águila hoyo maldad fértil libertad estilo historia agudo asilo grosor goloso leopardo odisea nueve butaca molde lacio mañana plomo exento rey adicto puño piña",
            "e4df51858246fe7a1f5b7e0045704ba76ff9d2b099707ea1d8b731dc3216c3de4edc63bad0911179d818b20e2c2a4e8da9e62dac242f6369221802e25abd0ceb",
            "xprv9s21ZrQH143K381uk3B2rYMvPGDjn8oqzxK2tGqoNmB9eN2puxmZtB3BximsnfUd6u3eKP58aVTrUmKW4xA4ckETJwd6YPVa7G8nLkdBknC"
        ],
        [
            "f30f8c1da665478f49b001d94c5fc452",
            "urbe lección ajuste enero faena reptil caimán abdomen sobre genio túnel óptica",
            "f5e417f1f68c479cd3058e836ce47aaa52629ac4cb93e99e8025ab38e76a6fab56f6b5a6c1f20637bf29e108f41bca76a1a061d8f8ea40f7c0e5a15552c23ae2",
            "xprv9s21ZrQH143K3sNRU3fx6SQaMRXAAJPHtmBFpXF5MhZ6AEURc2zE2gmVexqAA6EFyTBUBfxv982cwPLR2fM81SivaJXcN2FdbmgzrFbEdqs"
        ],
        [
            "c10ec20dc3cd9f652c7fac2f1230f7a3c828389a14392f05",
            "rama jeringa logro mando soldado pezuña pésimo vampiro cerrar mojar cupón dueño llover barro guerra mambo cerrar casero",
            "0ae0e69a6ab7c290e1319018a36a7481b6969f73745db1fe56ed4b928b17458bd86e580b6925ec6b64558e4a1431b4761d0928928b689c37efad8122edd7762c",
            "xprv9s21ZrQH143K2VwsYAPzaKfUBfB8WtQXQux4e5R2cnLhipQ7zQfwWqg2Hozhrh44r1ZtMDzxVDA2PyUqEBtu9o2BidJjQ2psh8QspU8siVK"
        ],
        [
            "f585c11aec520db57dd353c69554b21a89b20fb0650966fa0a9d6f74fd989d8f",
            "vampiro célula dos simio bono sondeo vencer haz remar papel castor codo nivel alarma rapaz ofensa gripe sagaz otro tabaco esfuerzo rojizo jinete traje",
            "c87970357a0faf4ebf604d9c486726e1af8d2874d40f3ba30e5774d615c6eb7ecc6cc04d85d6be4e3e36cf4771f8e15350152351f918bf4a555a33d57f90d61c",
            "xprv9s21ZrQH143K4UfkWbEcDPVrme1ea7d9BcQR6XtJ1VJucg1haNWCKCxqkXBshF3QkTSq3HHX2V3qiZmob9bJTnnj6ny5SbvwMp26v6HwxTd"
        ]
    ],
    "jp": [
        [
            "00000000000000000000000000000000",
            "あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あおぞら",
            "5a6c23b5abdd5c3e1f7d77ad25ecd715647bdafb44dab324c730a76a45d7421daccee1a4ff0739715a2c56a8a9f1e527a5e3496224d91293bfcd9b5393bfff83",
            "xprv9s21ZrQH143K2TDo8AAss7eUkUqLFzBnypFpqjQUMVUrSMvrrgLiRxQPrYnhfoS9NPp3rex725rcuN8pkDL6pwqWfdPtiqa9ib1B37vZwfy"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "そつう　れきだい　ほんやく　わかす　りくつ　ばいか　ろせん　やちん　そつう　れきだい　ほんやく　わかめ",
            "9d269b22155b3c915b09abfefd4e1104573c528f6977cde89c6a68152c3c714dc6c7e0e62f221c322f3f76e4d0bcca66c06e3d2f6a8d70d612c87dd6dee63976",
            "xprv9s21ZrQH143K3kavBMu7K49k18vjQHhNL1ciMgn7S9kDMKdyK1vEpF46UWyoXCvdBLEp8U2bhissPkC6iwXjMgRXyQ6SHbyYYGcnFqNXTW1"
        ],
        [
            "80808080808080808080808080808080",
            "そとづら　あまど　おおう　あこがれる　いくぶん　けいけん　あたえる　いよく　そとづら　あまど　おおう　あかちゃん",
            "17914bd3fe4b9e1224c968ec6b967fc6144a5795adbb2636a17f77da9b6b118200ad788672fd06096ca62683940523f5178f6ce3845c967cbd4ad2b3643cc660",
            "xprv9s21ZrQH143K2NAPUK7UVbLB4Dd7Hvb7fqysvFyKES5iujX4BfrwUmy1wvWJb3kBc1Zs2jxTTBxBPHuHziB1ZWWUxELrn8g8VLrbjaWDmRe"
        ],
        [
            "ffffffffffffffffffffffffffffffff",
            "われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　ろんぶん",
            "4bd21b75de4f262b0771a97d6fc877ee19329236ced6e974c4c81a094a5f896758033f7eae270216d727539eee3bc9ba5cad21132a1c6e41a50820e0ac928e83",
            "xprv9s21ZrQH143K43f5tXeZRJ2RMiS6nLhxcqvopg9mc84xTiX1UjLjVQDBHrwmypY45SPscFqT7zJet5b3riay95fJMM4dfZXtoBTcKKkKEao"
        ],
        [
            "000000000000000000000000000000000000000000000000",
            "あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あらいぐま",
            "a59401a14bb821cce86ec32add8f273a3e07e9c8b1ed430d5d1a06dbf3c083ff2ffb4bb26a384b8faecb58f6cb4c07cfbf2c91108385f6773f2fefd1581926b5",
            "xprv9s21ZrQH143K3VMwP9nGq47t86uaVENmykbCRuUDKFDSfgDFjJUFuF88JfPPMzwgwFPoaJaAD3YeqrCQBFY5S2jaCXXuc5Vg7u9jb6iB6XF"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "そつう　れきだい　ほんやく　わかす　りくつ　ばいか　ろせん　やちん　そつう　れきだい　ほんやく　わかす　りくつ　ばいか　ろせん　やちん　そつう　れいぎ",
            "809861f80877e3adc842b0204e401d5aeac1d16d24072f387107f9cf95b639d0a76141ab25d3dc90752472787307a7d8b1a534bea237c2bb348faac973e17488",
            "xprv9s21ZrQH143K29NaQCx2DxPkszvvbYj5FmZ7RMMAoCE932mUkfzaAYFf18JiaFC4bJujA7XAsm7TFddxdkXfn6U34te59Bp27CWp71mw55c"
        ],
        [
            "808080808080808080808080808080808080808080808080",
            "そとづら　あまど　おおう　あこがれる　いくぶん　けいけん　あたえる　いよく　そとづら　あまど　おおう　あこがれる　いくぶん　けいけん　あたえる　いよく　そとづら　いきなり",
            "01187da93480d0369fff3fc5331284ad6a60cd3ce1f60dbec60899191afa2a2b807cd030038a93ddaf14d4f75d6de4a0e049ee58c92197eb9ca995770b558486",
            "xprv9s21ZrQH143K312KY5MRB74dWa9BDHG7rV4oK7VAfA1eVKPDddPEUTXRZ5ShDzVQJp7d8q8xQLPYVcHYVuxb7sUo6EQpJUytZRHxyytSYbV"
        ],
        [
            "ffffffffffffffffffffffffffffffffffffffffffffffff",
            "われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　りんご",
            "a1385ef66f20a905bbfc70f8be6ecfec341ff76d208e89e1a400ccea34313c99e93f4fba9c6f0729397b9002972af93179dc9dd8af7704fa3d28e656248274dc",
            "xprv9s21ZrQH143K2LmZMWVM3JxKTHZEDZg1ZEUZH6hx9yJhBWRSgGGYD8TAaPa6MYto1t1bBXgPYFMLx1Gidw8fJADdFNzvqrAcXiadUPfTTVh"
        ],
        [
            "0000000000000000000000000000000000000000000000000000000000000000",
            "あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　あいこくしん　いってい",
            "c91afc204a8b098524c5e2134bf4955b9a9ddd5d4bb78c2184bb4378a306e851b60f3e4032fc910ecb48acfb9e441dd3ceaaab9e14700b11396b94e27e8ac2da",
            "xprv9s21ZrQH143K2WD9BSegbAkGzg4XbqeY7gzCYGWaWfmRifMJJtmDo1pjXmyuEwPnKcLwTZ1uqosvTRBAcPdUUvdHxY6rKj6R28vWVWGLKuu"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "そつう　れきだい　ほんやく　わかす　りくつ　ばいか　ろせん　やちん　そつう　れきだい　ほんやく　わかす　りくつ　ばいか　ろせん　やちん　そつう　れきだい　ほんやく　わかす　りくつ　ばいか　ろせん　まんきつ",
            "79aff5bc7868b9054f6c35bb3fa286c72a6931d5999c6c45a029ad31da550b71c8db72e594875e1d61788371b31a03b70fe1d9484840d403e56a1a2783bf9d7e",
            "xprv9s21ZrQH143K3ZPQiQ24sxzu5PsqazSLn1W48saAFWiDhugDPp7dKB3v5JLfMqzTbqjdwE8P2UxFSKwnFc5CpgMaH2dSmoWDRuaAbrZbJF2"
        ],
        [
            "8080808080808080808080808080808080808080808080808080808080808080",
            "そとづら　あまど　おおう　あこがれる　いくぶん　けいけん　あたえる　いよく　そとづら　あまど　おおう　あこがれる　いくぶん　けいけん　あたえる　いよく　そとづら　あまど　おおう　あこがれる　いくぶん　けいけん　あたえる　うめる",
            "0f46c02350b3f1227c3566dea2ff0f2caf716495a95725b320a31a3058d5d62596fdb816be75909d2c5f7094beb171dc504ea8ea60f5e2e40bd8aa0d9339aab0",
            "xprv9s21ZrQH143K2TSJ2oumYNzqQGKmvehh1NKNzAjpu6Ue5yPvtzFvX8aCvBk2eTg8TJfwjiGLfA2KCiajZ1VXBvtQXqk7Wryxgps4BYyNmZt"
        ],
        [
            "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            "われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　われる　らいう",
            "a0705c2feebefb61509dcc49c57586c35379c1981c688fc1d452da44443d9a651a374f1ad2ee3d7847b50655cf9241d7e607be436c0df7c8bac42f2a82985a79",
            "xprv9s21ZrQH143K2k4V9TkTiFB2LviDq1oSHbRha8AmnPvBtRRVAnf9WJERojPPdki6sbiuNbxv91VhhdreJnaZh29Ay892Mj6KB2aZnysqfvR"
        ],
        [
            "9e885d952ad362caeb4efe34a8e91bd2",
            "ておくれ　げざん　しねま　こりる　きぼう　しねん　ななおし　ほんやく　きない　けむり　けまり　てんない",
            "b80f83f27ec3a6cbe804be0661e9bcc30583484dbbd37f689d4952bdf4ad29d9b9f5774fc4c87b733169416418b81f272a3eab37feb22f5c8f6deea6bb08f8c1",
            "xprv9s21ZrQH143K3VLugmPmzLDwfFeo8cgoZ2ajCQwWhGKfXut8C1XhdSNuAnXjz5W2bbbNPmr87yMHAaPMaUhE6MNnfGc21WRc5Lj94Tbbnnh"
        ],
        [
            "6610b25967cdcca9d59875f5cb50b0ea75433311869e930b",
            "しはつ　たいちょう　ちめいど　ひりつ　ほくろ　こやく　こんかい　いひん　よろしい　さくら　がはく　ふっかつ　こまる　つごう　けぬき　ふすま　ちから　さくし",
            "926ce4647a8f91552ae00efa8880ed7e43b6f8e9cf51c38851b0e242569ea96d77a19c777d28dc33d8912c3e3bc6c59f7a82b6daa25add2c39a492fdebae79da",
            "xprv9s21ZrQH143K3eVmFcDa4FcZCGeNryYBv99mdgidpSeFBt6ppQQjE6MXegs3xmT4arCDXvtg6dGpr7vFY8A9bzzeJ7E9jyzWLPDSrixwqub"
        ],
        [
            "68a79eaca2324873eacc50cb9c6eca8cc68ea5d936f98787c60c7ebc74e6ce7c",
            "しやくしょ　くちこみ　どんぶり　けつじょ　おとしもの　くうぐん　どんぶり　たずさわる　ひたむき　みうち　にほん　うわさ　しゃけん　このよ　じどう　ほめる　たいよう　くふう　そんちょう　ろくが　はんこ　せあぶら　くうぐん　そっこう",
            "94308a93dc1bc12f8e917b2445581240d83cd82ad3c52f9ba4125aa6ce5490a3624fb3dfd7e22923ef7ff3b778157e8bec76392b122bf465fcc56ab4f5a73401",
            "xprv9s21ZrQH143K3ResRww4txupLREzrNjYYi6X5FKpKvFUoCwhJS1HtSn21gDkXcBYxQBd9RngafHfWqktMmLgPrVJTisEQbRn4strGawHGpQ"
        ],
        [
            "c0ba5a8e914111210f2bd131f3d5e08d",
            "はいち　ふかい　てんすう　おさない　いろえんぴつ　だんち　くださる　せんちょう　きさらぎ　てきとう　せもたれ　うんどう",
            "5fae92448afda85f10a50236144cee3068ce21e20a34447a9a4b6e9d5b000a4347a151d7024c2068c4d3c29c46a6f541a94b98624cc25b2c8ff42cafe6a3087b",
            "xprv9s21ZrQH143K3PD5fc3CCepnLDsenZAqyKpcbquY3BR9sfosi7rbjXMo5nL9qUb91FwYUFdN9wJt9v95YoKJJFm9V7a2Xb1sZgstQkZ54cL"
        ],
        [
            "6d9be1ee6ebd27a258115aad99b7317b9c8d28b6d76431c3",
            "すいえい　ほとんど　せんやく　ほしい　ふうふ　ひんそう　ざんしょ　がちょう　なにわ　ひはん　ひつじゅひん　られつ　はんぼうき　ちそう　ほいく　めだつ　きさま　えがお",
            "a49ff09e55b62b8fd3d4b88b4fae2c9062e18c06105c796505fde3cc7655cfb9c922c02817d18dd40832ecd19d80a71fd62d915c34cd8d95fc55591d12b6f677",
            "xprv9s21ZrQH143K4AKun3sek391JX1qnWpxriP3eyJviCUq6ouiH3RDzJ1f7Gm6c7dgAkxn18EcaZ6CBNvVkmLxVvB1fdBdLiGeHXf69j4eCR1"
        ],
        [
            "9f6a2878b2520799a44ef18bc7df394e7061a224d2c33cd015b157d746869863",
            "てそう　こつこつ　えんちょう　じてん　おおや　ぴっちり　だんねつ　ほそく　たなばた　くらべる　ひまん　ていき　あんい　ひんしゅ　ちきん　ざいげん　くたびれる　そなえる　しんか　にいがた　せきむ　けしょう　しあさって　せたい",
            "55d101db3cb8872853a3e84ec97fdeac63fdab33d92def4dc4694beff0f504da29f953bb463d9cbaf0c4d442672d40c5a58d6aed35d5fdbb2768dcc482b59bc0",
            "xprv9s21ZrQH143K2dmFtHdM2tu7mDdKwsbeU7ekYU2dsFDBt7dNbXcsLTnN2MNi3hQssGdcPgEfiXNJcgnoo76t1nAHaoyVBXZ1z6hP8L2UGTs"
        ],
        [
            "23db8160a31d3e0dca3688ed941adbf3",
            "おたく　ほうりつ　さいかい　げねつ　ふせい　いいだす　かいてん　ひんしゅ　もえる　てのひら　ねいき　むいか",
            "1b0fca340ccf977258987a793b3e61b0e20291f8c27645e74621e87c01d0e881cd601bbb0ed98388d22dea341498ed74aea32975a56bd3bdc6027196b7a21640",
            "xprv9s21ZrQH143K3Z6vsGR17YLtiGF2gTkCm9Z7XnJm1ffrLQ9ah7AVye6NyACmsWLZBoREcdCRS7tq4Hrx1NDWqHj3MctxWixcH7XBuigtJri"
        ],
        [
            "8197a4a47f0425faeaa69deebc05ca29c0a5b5cc76ceacc0",
            "そむく　のぞく　かいふく　ろてん　げきやく　ろくが　ともだち　ふじみ　やおや　まかせる　すらすら　こぼれる　いぜん　へんたい　きさま　へきが　なたでここ　あさひ",
            "d7919c8a5458fa4ff55431021938b15bf39b7542df902f371625d9f064a37b1d06a34cba920a9c8b8d6bf34514f542f5ee91b9eab81a063f9acfad932b43c62b",
            "xprv9s21ZrQH143K462YnNY39Q7Pq8ZXzCXs9k9GexnGbyjVvu3QhrNLCkPxNUtaKZBzqffnmiuU4ZiA5UQKtwVqr1WmXyM3QjVaVg8Cc93xMDQ"
        ],
        [
            "066dca1a2bb7e8a1db2832148ce9933eea0f3ac9548d793112d9a95c9407efad",
            "あんぜん　すうじつ　たいふう　こんぽん　そこそこ　こたつ　しんせいじ　あんこ　うしなう　しまる　じどう　そうり　てはい　ていし　おめでとう　たんまつ　せんげん　たおる　ぬめり　このまま　ひいき　あまい　のらねこ　にんそう",
            "1003a30a516cfa1c30de2a53fe6c5936dcb8ae893f944f459ea4e1f2202716320350dc2ee5d92289dae3c5b1771fec863fbbc40146fed04d0855c6af70b0c7aa",
            "xprv9s21ZrQH143K24jAnV3a4K7xAoD486pMXSvAj41fkB61DopHqcyznUX1zmkFgEGBpNkXi6dckNcpcwXB65i71eBwP25t24QZHVRGJYURZ2Y"
        ],
        [
            "f30f8c1da665478f49b001d94c5fc452",
            "ようきゅう　そあく　いきおい　こうつう　こもじ　はんだん　おんしゃ　あいさつ　へいたく　しすう　ゆうびんきょく　てんぷら",
            "17593d396c66d776bc15c06e5348bdfa38927daf92402c335041dc500d7c8ea9eccf4f4d1c187785b8c9128d06bd7048a1706006fab82abece74185448caa811",
            "xprv9s21ZrQH143K3P24yRmaXsA2pntRyM375Kb6cF4P73bMQNKyXUPPR86X5o83UmTi4iyQWaCL48EoJUVqC7KxsPXbrAC4nKxjMh7FZJcucRE"
        ],
        [
            "c10ec20dc3cd9f652c7fac2f1230f7a3c828389a14392f05",
            "はえる　せっさたくま　そんみん　たいよう　へこむ　になう　にっさん　よゆう　きあつ　だんぼう　くねくね　けらい　そんけい　えほうまき　しゃうん　たいむ　きあつ　かぶか",
            "2567b4dc469b5d1d7c4aece40e642dea3d5cebd80a577b5a4d72fc2b60da6ca657d3a01270c47530ac71f812e648bac01aaadc62c444749fddec8982430fce7c",
            "xprv9s21ZrQH143K2UfZfzss5CkDCtkRJvLN7DmM4sWjUaYMF4rfeWDERACvg7jGSSkGeFLrcHdpXUFty7wJ5yzyzcbRDqv7b9H6usZ16PnKy2c"
        ],
        [
            "f585c11aec520db57dd353c69554b21a89b20fb0650966fa0a9d6f74fd989d8f",
            "よゆう　かんけい　けぶかい　へいこう　おかず　べんごし　りえき　じゆう　はんい　ともる　かほご　きぬごし　つみき　いきる　はかる　てふだ　しほう　ひろう　とくてん　ほったん　こさめ　ひつじゅひん　せつぞく　めんどう",
            "909c8c992019adde332a11f0ebd1b0c0fbc9dd96e4d3d30ca4ecb0d06f743841cd25380f87b3a538f46dfa3fb3a5ab330487f99d128b1c6bcdbe476d3bbe2af2",
            "xprv9s21ZrQH143K3a5iyuaeKiPGQbhQLUaBhzfd7inUA5ndrmcYEc7zZzTLGM37Du2M11nXChrzXyZ8ZYtH2dG1CkWE39R749XhcKUcVs9avTR"
        ]
    ],
    "zh": [
        [
            "00000000000000000000000000000000",
            "的 的 的 的 的 的 的 的 的 的 的 在",
            "7f7c7f91ef81f0fb6a3b95b346c50e6472c1d554f8ba90637bad8afce4a4de87c322c1acafa2f6f5e9a8f9b2d2c40e9d389efdc2adbe4445c21a0939fb39e91f",
            "xprv9s21ZrQH143K2LTAgxJMxVMKie6n9HQHMUohP6x2cx1TVBr6dxnL3mnSLRiXjiCM7g2ZF3BHzpdbFuhdeh7ZRrzv2EEjg5Tv7kgKZrqbVLc"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "枪 疫 霉 尝 俩 闹 饿 贤 枪 疫 霉 卿",
            "816a69d6866891b246b4d33f54d6d2be624470141754396205d039bdd8003949fec4340253dde4c8e11437a181ad992f56d5b976eb9fbe48f4c5e5fec60a27e1",
            "xprv9s21ZrQH143K2t2fMBqtVAVWU3JSpmEbbddwouLX8NoBbcTykD1Tm4s9api6K9zvoKSESUsA7aVxbZRunM5yrjZRNZnZckve98hxUorv2Uv"
        ],
        [
            "80808080808080808080808080808080",
            "壤 对 据 人 三 谈 我 表 壤 对 据 不",
            "07b6eada2601141ef9748bdf5af296a134f0f9215a946813b84338dcfba93c8247b0c3429a91e0a1b85a93bd9f1275a9524acecadc9b516c3cf4c8990f44052c",
            "xprv9s21ZrQH143K2cgeQUKgCSmaRVXFjEGThqrnNFmH71qG8z3bWqYcbX9zakkRxmDp583tqf3cQzmxtn4C2XqinMNb2HkhXBDYhekCB8AwZWV"
        ],
        [
            "ffffffffffffffffffffffffffffffff",
            "歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 逻",
            "08ac5d9bed9441013b32bc317aaddeb8310011f219b48239faa4adeeb8b79cb0a3e4d1cb460d2dd37888c0a19bef6edd90ced0fd613d48899eab9ee649d77fcd",
            "xprv9s21ZrQH143K3Zkkh1w8EbXYQWAS5ekbitA2WVrswJY9uEJzig2BtairT72n98ySwQUAhYBsLW9EBjJ1XUinrSb69Ty4mttMLnaUooJwsJ3"
        ],
        [
            "000000000000000000000000000000000000000000000000",
            "的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 动",
            "b8fb8047e84951d846dbfbbce3edd0c9e316dc40f35b39f03a837db85f5587ac209088e883b5d924a0a43ad154a636fb65df28fdae821226f0f014a49e773356",
            "xprv9s21ZrQH143K36LufUjTLqXnTiY6ach28pUYMkJ63swx4FhjPkzqD9YRqDZ452whYcNzKpPC8yfBm1eomL2z3VLC4zcwU71oKvMQ5NnD4h1"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "枪 疫 霉 尝 俩 闹 饿 贤 枪 疫 霉 尝 俩 闹 饿 贤 枪 殿",
            "74187bbdce2dba25eed3b9aebdc65dcb7c61e74c58591451d47f9c7b7b17545a527880640bfb9cab36989eba1edddf57bfce7340697926de7f0b9ec1e0345c38",
            "xprv9s21ZrQH143K47jLpKzSgdpMLSKP2ZMLXHHUqYYGKbXNE4k3TA2czvJCx5JAJFNkWKZf2B1AbYoUBpc96YoiwM7yfxyr8gvfNNgL7sFNum6"
        ],
        [
            "808080808080808080808080808080808080808080808080",
            "壤 对 据 人 三 谈 我 表 壤 对 据 人 三 谈 我 表 壤 民",
            "e3629a601f4b87101c4bb36496e3dbd146063351f5e47c048211faddab78efdb91910f0eea5c8e53cfb851aa3e156b0bb5c501b83baaf5f5d4a1679a5bb7d885",
            "xprv9s21ZrQH143K4RfeWihCeh1FJL9SobvinRW4z76RL2X1TB6xreXgaMvJGggUgagkaNr7zX47YHEDYdzJmig8SG3Scuet8smspn7HicCtwHa"
        ],
        [
            "ffffffffffffffffffffffffffffffffffffffffffffffff",
            "歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 裕",
            "013c8d6868537176fac7bfa966e6219830008f03b650b0f18a12fd67d9ebf871c400c5f980aa073ddd1b23d60846e357aee193ce7644b574bf65e04cf913e39c",
            "xprv9s21ZrQH143K2YiskWzQq8kpFFCoFKKU4L8D6Y593dS2sExuVQ4GjnS57RhibwTWjnD7NTCE7ye4cQbCK6Bw674SHb3xWaQYH3NBLFCGYJb"
        ],
        [
            "0000000000000000000000000000000000000000000000000000000000000000",
            "的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 性",
            "1981c3e3ddfd80f6e9ee1c5ef27ba2697df3d1468496f1d56ae3d8e0b3f0677bbbdfca954e48eb86fe6a36fc0f597bf18ea00248757a01e82182badff94abbbd",
            "xprv9s21ZrQH143K25ttGBGbx6h9VBpa9ELbpw35XQqDR8deXRyVP2AbtgJ79Nq2cW8KaDizbwuoHUYR1o4tLPhYvSCTNMft4ZEfiDztmjXKPCj"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "枪 疫 霉 尝 俩 闹 饿 贤 枪 疫 霉 尝 俩 闹 饿 贤 枪 疫 霉 尝 俩 闹 饿 搭",
            "b1eb831927f1c488e233725f9c409dd9bdb9342324393fa56d958e8842623d222510c322f5ba2899428ae08ece8bd87788748c67bdfa73588669ab816c5f3555",
            "xprv9s21ZrQH143K4VNNDqCgnETDkPiihzHpxC9wGE6TBGXaeEd9VkQRHQPotwheeaNFGHGKaPWv5zTqfknzgdWiKFC6DqaqBFKjNSmxas968Vz"
        ],
        [
            "8080808080808080808080808080808080808080808080808080808080808080",
            "壤 对 据 人 三 谈 我 表 壤 对 据 人 三 谈 我 表 壤 对 据 人 三 谈 我 五",
            "470e61f7e976fa18c7d559e842ba7f39849b2f72ef15428f4276c5160002f36416cd22c2a86bb686d69f6b91818538aa57ae1aab27b3181b92132c59be2b329b",
            "xprv9s21ZrQH143K3bUoGmLq8aXRKzvUhseqrXw1t7XYCirduP5XLJtVxCos3rYLDvW8V7pK3voZ4EWSdeXiKdbWNjxmiPRDfet23Av9VRaR3ej"
        ],
        [
            "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            "歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 佳",
            "8e6607a07fa664d6e4ead23fcc08caf72216d6f078c3b2e5be94e4b6e8d64c784d36bf9b70144fa05840e9a49899128111be5093a2b552b6ab76c0906e9b0e65",
            "xprv9s21ZrQH143K2ghKxX47TRr4GnQh3diJFN5rJfybjxuwr3xP6pafXrBhwXJsw4HwoiPZ1f6fFPR964eoXybV2su498Ant3kYuYKE3CszLsU"
        ],
        [
            "9e885d952ad362caeb4efe34a8e91bd2",
            "蒙 台 脱 纪 构 硫 浆 霉 感 仅 鱼 汤",
            "decd71d2824a1bbadf8c3942f43504a648a8db5f1cac0ae1d0f787728353002a12644b1a6b725147c91682e7f33aec13493b9a779a7dd8ee15a5d10ab21d49e5",
            "xprv9s21ZrQH143K44Xrktko35a7gPGVo91Va79LNer1MzVokcrYKFP6GMLAcuJP3fBSdbRuG2DauFC48H6LmyZLfkUyjpm1R2AxYVbnT2P5tur"
        ],
        [
            "6610b25967cdcca9d59875f5cb50b0ea75433311869e930b",
            "父 泥 炼 胁 鞋 控 载 政 惨 逐 整 碗 环 惯 案 棒 订 移",
            "ff66373b70b72b34842f936bf3bb44d661fdafaee7740d574fed6aa2ef07783cb6111f2862cbd3fc5528e322dfe054557a74a568a1b46c020cb88938e2293ca0",
            "xprv9s21ZrQH143K3JLu5XeRDQA5RwHh6gUXaQfRf7ihtVguJvd6EFoAzsoyotvNTDZfC6cciies7fhcqaMRTEsZUSbRYqBdaviWRHatRMoHX6s"
        ],
        [
            "68a79eaca2324873eacc50cb9c6eca8cc68ea5d936f98787c60c7ebc74e6ce7c",
            "宁 照 违 材 交 养 违 野 悉 偷 梅 设 贵 帝 鲜 仰 圈 首 荷 钩 隙 抓 养 熟",
            "6ba622f907c61e29e44833b08441b7afa84889a48ca90ebf90f585e257662b2c1b0c35ad54088e745c73689921209fdd4b5b8ace5d850e366d7c2042a076e660",
            "xprv9s21ZrQH143K3dE2RQqFbapci6WBj47vZCkLVf4r14QsRZ6Ny2ck6s8tzZQzQaM55Tt4d2tRS9AuFrEJ4yBXsmP8yKeVGXT8E97iRVkDzCj"
        ],
        [
            "c0ba5a8e914111210f2bd131f3d5e08d",
            "伐 旱 泡 口 线 揭 县 杨 断 芳 额 件",
            "7346996be5f2b02c67ec465c677197375b589b6e8871c842505b139c2d47feca75a2a941623d6486aff6b21c95193a8177960d123cf610f03f3224a9fa7d0eed",
            "xprv9s21ZrQH143K3A2p7cttKM5L39rutYgY4jqZ16z7hpAEdyiT8fr5eKdaHGLMM2ZmsUFNvGcSfyGMp1sz9nVyg3ZXop1hesUbgAvVBzx4rix"
        ],
        [
            "6d9be1ee6ebd27a258115aad99b7317b9c8d28b6d76431c3",
            "福 惜 怀 叔 筋 酵 货 科 牙 冒 辈 罩 悬 耕 浇 呵 连 级",
            "09098e00fcc1bfa7d5b9f0c12dfe1993bbd5a0915200a53fb40b2d6d487b969a18463565c1e035569796a7d8b99f82a4c4b17002b0c582037da95bacfeb422b3",
            "xprv9s21ZrQH143K4LdjFgCrosa76XBrNQ4imGB7XNc5MhfkASrmAHVNWYLNGY6kNj8foXBLS9aUD8RDubyj3NKWarmXxRQ28AeWVPbLD3a1FEq"
        ],
        [
            "9f6a2878b2520799a44ef18bc7df394e7061a224d2c33cd015b157d746869863",
            "仪 未 九 茶 队 梯 妇 孤 托 病 泉 贺 产 绘 吹 测 局 碳 征 墨 晶 帮 息 延",
            "6d55f2dd8d42f1cc5e0b4ef6e8a95200580ff4e29d2a3dfa7f9ddb1af0aa2e93780d84d952d39776a379ddc017847ea01aa01b85dc208e7f69891d5b7cbf2eb0",
            "xprv9s21ZrQH143K2tkCCjLXj2L9Ds9FttWwH6Eqt3uvihwUvpSpTm3RmRtSkapxASEUW5HXE6Qx2H1viBxXbLZVKxyfQ7fyFn6NcDspgJfdPaT"
        ],
        [
            "23db8160a31d3e0dca3688ed941adbf3",
            "济 扶 块 言 穗 定 万 绘 姻 逃 颗 焰",
            "bf8dcc2fb4dc8fd2311943b527864feabfebd5fffb6641555519da3606265e895bab5aa1647f6e5afb0cb6ea4d0b27e8a9f2f49251b68ad6bf898937581351cb",
            "xprv9s21ZrQH143K2i53x2geCJi6A2QJpaHpxeGK8oeMxYs1tUrUwU3ddu9jHVucF3ePQ1koQ1TVFHnfP21ScWzp8xKnMinNUSW5itm7PicXWYW"
        ],
        [
            "8197a4a47f0425faeaa69deebc05ca29c0a5b5cc76ceacc0",
            "虑 铺 目 祸 英 钩 尤 添 醇 嘛 触 独 起 赋 连 剪 邦 中",
            "07e1a2dc2eea79bb12be53d6fb662edf87796cad60e8d10a655ba39a95c5a68eb21f865a1b2f37d780286adbbddeccba3f7844c8a2b1a82029e6a855c713aecf",
            "xprv9s21ZrQH143K4V2oh58ZSb1CAbYkwB6ThJmTpRC51uKha9hy51R6RVzzbcEog3n6h4u7FtotS9arBvLofX7A3Apvcaedmeg1jkt7Vkt9TtA"
        ],
        [
            "066dca1a2bb7e8a1db2832148ce9933eea0f3ac9548d793112d9a95c9407efad",
            "而 怕 夏 客 盖 古 松 面 解 谓 鲜 唯 障 烯 共 吴 永 丁 赤 副 醒 分 猛 埔",
            "0402ae511062cfacbd5e33637a95e57e2e14fde0c5dd471fe66fc1154b6373802aa8641a78b91658052bff0a5c5bd075f01fc74b0d73e95a890430ff6f0e728e",
            "xprv9s21ZrQH143K4LSoFcKBWtmUHjzuH56srzrkpPfGx3i36UXpVUEtGvCuZ3egRTyDkaqRN5Ec1HXvXGSGTXLyAKzCRnTspi1D9NdmQmWqM5x"
        ],
        [
            "f30f8c1da665478f49b001d94c5fc452",
            "昏 途 所 够 请 乃 风 一 雕 缺 垫 阀",
            "aa7e38f64810007db63e31c479b9848cd5ffda839546749669bf53476dd036a33fd77d0a13d4418fb536ea78b028fc19533db4bc9e0e12a14a9432cb9fd112a2",
            "xprv9s21ZrQH143K31afj91bWiGw2aC2xHJwrWsMs9MuvEWZETkpWr15ZNF6LFjkHh53iD2bwJYEawvCCvDRaqDsr37fhapgGDkA7UATtwBsZu3"
        ],
        [
            "c10ec20dc3cd9f652c7fac2f1230f7a3c828389a14392f05",
            "瓶 顾 床 圈 倡 励 炭 柄 且 招 价 紧 折 将 乎 硬 且 空",
            "2a6181cf2b069ba30a87228d54770ed5abf61e8151abdb0b27646a87a6100d4b7b496c3ca26f027d0b06724c6c5a469f43a7f1ffb7782e5afb01d143ca65973d",
            "xprv9s21ZrQH143K3ji6aQ9QQi4WkFhAqnrzRANJkYkRWkMqbr51mAV6JYUt85oR8Jt3D7DreQdsb9292ips6VKwpitAhLR7rfLdhYz7zgYei2F"
        ],
        [
            "f585c11aec520db57dd353c69554b21a89b20fb0650966fa0a9d6f74fd989d8f",
            "柄 需 固 姆 色 斥 霍 握 宾 琴 况 团 抵 经 摸 郭 沙 鸣 拖 妙 阳 辈 掉 迁",
            "4dccb0a3578716975b840c51e279c2af728567ff42e98dd09b9e61742b41d9f30d411a501172cce9b7d5706a480dd4d4e7fb26021a36a74381156b09d251d65a",
            "xprv9s21ZrQH143K2hLNNA7KnimwonwFXCiGVM3K29DgZiTcVUJ8t8jkc2mXUzFZmoFgXWh9UhJFbyKM44Qm2KeGsrEevajZZfKyoLyFmyoDpUx"
        ]
    ],
    "zh-Hant": [
        [
            "00000000000000000000000000000000",
            "的 的 的 的 的 的 的 的 的 的 的 在",
            "7f7c7f91ef81f0fb6a3b95b346c50e6472c1d554f8ba90637bad8afce4a4de87c322c1acafa2f6f5e9a8f9b2d2c40e9d389efdc2adbe4445c21a0939fb39e91f",
            "xprv9s21ZrQH143K2LTAgxJMxVMKie6n9HQHMUohP6x2cx1TVBr6dxnL3mnSLRiXjiCM7g2ZF3BHzpdbFuhdeh7ZRrzv2EEjg5Tv7kgKZrqbVLc"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "槍 疫 黴 嘗 倆 鬧 餓 賢 槍 疫 黴 卿",
            "f38af46f6bc3222b0f5aa14dd5b8b506e51131510f2450ec9fb52c28617cfa59d436055fe542e25dfa01415639d2171e41796f169f8bbc18516941dfdee8fb72",
            "xprv9s21ZrQH143K2HYJ8dR81cQGust8Gm4MeyfC6off5BvCfffAxE33WhiYxB4aLV6meXP6QmoKZkLX8UJgrZPcA4A2EKU4iaPWenb6Wg9kxzd"
        ],
        [
            "80808080808080808080808080808080",
            "壤 對 據 人 三 談 我 表 壤 對 據 不",
            "33f373da1a6b4300dad5cc70d2329ed614512e3c8a423673c294110521326ca66753b9663bdd7c844f17d81609a410a61809dd5113823009f729e2f2f940cab9",
            "xprv9s21ZrQH143K4SV7MzxYhSQtxP5gWGCD75QiUsp7z1s7Kuc8b4V4F6wRqKvhdczy3qi2uNeN9Vw4PnKYJtoaFdHFX4qbxweuRDmQqgMjKRJ"
        ],
        [
            "ffffffffffffffffffffffffffffffff",
            "歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 邏",
            "cfd5f4fa6f2a422811951739b1dad9f5291f9cbc977a14ae9dd35dc8ab17aeec9ee6f1455b20f881838f4f945850765dd002a9abcdbe7be002ffcdaf6f63fdaa",
            "xprv9s21ZrQH143K2BptXPaTm7CCWCs4v3tfG5jGAa9zLqSTKNL1ah8veMWc53hio5grKVriWhKjNKbCA2w6svkL4NC6pkiRwVkbwazVXtjdgEv"
        ],
        [
            "000000000000000000000000000000000000000000000000",
            "的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 動",
            "717f4f70c7550da57e42c6b49ac47b5bad3249605ed2f869900596c2de7653a8528380e5c31709ed9c2d19b868bc530158712e97276886b4863d036177bcab33",
            "xprv9s21ZrQH143K39TvGFp5nfiw3zXib4v4waTbxFYoDNoD4pp4DMBneg9MgSqfK4xL7hK1YjDEa5BWMXKVgTxMiNXNSdT3Wv59pD4PB3LDDKP"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "槍 疫 黴 嘗 倆 鬧 餓 賢 槍 疫 黴 嘗 倆 鬧 餓 賢 槍 殿",
            "2b219a8be0a8e27a6b50d0a74eb42175bd23e22cf4081518c9a74cbfe2cbace46f0adad8d390f8a2ac30feb26226db14fbc545d18ba0e56a853cbf103c92539e",
            "xprv9s21ZrQH143K2wC9BUJ9F5CsmV7a6PJQkxc9TT8gUrkoTXurPztKKosq5REGzdEzEuKn221vm2A5KnjrDBC1KcLo4VeYGSkkwxXWYrqSrXW"
        ],
        [
            "808080808080808080808080808080808080808080808080",
            "壤 對 據 人 三 談 我 表 壤 對 據 人 三 談 我 表 壤 民",
            "d29225f73231521784d98820ebf0ae4d827c5a9e0c0f8845fd63866cdc70b3a40a2281f3f6c6181c5a53e440528dbf83947a4b2056749cb9cc9c83dcd5c91b0f",
            "xprv9s21ZrQH143K2MQFKxX1ReLYY2rNunsfLpU8F5WRVWeLfauPhD5huvXEzxoPvmLhD3QtSj1Z5jnM51q9NrRjYBaHG5XJzfVsjXWYQop9pXz"
        ],
        [
            "ffffffffffffffffffffffffffffffffffffffffffffffff",
            "歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 裕",
            "013c8d6868537176fac7bfa966e6219830008f03b650b0f18a12fd67d9ebf871c400c5f980aa073ddd1b23d60846e357aee193ce7644b574bf65e04cf913e39c",
            "xprv9s21ZrQH143K2YiskWzQq8kpFFCoFKKU4L8D6Y593dS2sExuVQ4GjnS57RhibwTWjnD7NTCE7ye4cQbCK6Bw674SHb3xWaQYH3NBLFCGYJb"
        ],
        [
            "0000000000000000000000000000000000000000000000000000000000000000",
            "的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 的 性",
            "1981c3e3ddfd80f6e9ee1c5ef27ba2697df3d1468496f1d56ae3d8e0b3f0677bbbdfca954e48eb86fe6a36fc0f597bf18ea00248757a01e82182badff94abbbd",
            "xprv9s21ZrQH143K25ttGBGbx6h9VBpa9ELbpw35XQqDR8deXRyVP2AbtgJ79Nq2cW8KaDizbwuoHUYR1o4tLPhYvSCTNMft4ZEfiDztmjXKPCj"
        ],
        [
            "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f",
            "槍 疫 黴 嘗 倆 鬧 餓 賢 槍 疫 黴 嘗 倆 鬧 餓 賢 槍 疫 黴 嘗 倆 鬧 餓 搭",
            "fd50ad67903b2046356e67e55d67309b6f0ccd7c23bfefd049a5b8a40d56c507d73a5517e2d2785f024a7794854594aaad845dd0fbd0432c25a96f2a7181a2cc",
            "xprv9s21ZrQH143K4TP9sQD1LnxuSy6WUe1hF7JMPo4qN6TMX5udfEcJh9x4PqbetYoC9c1hpx7RxP6VcgzdPxPCJ91De4R1TgGNVC9AFhxMwkX"
        ],
        [
            "8080808080808080808080808080808080808080808080808080808080808080",
            "壤 對 據 人 三 談 我 表 壤 對 據 人 三 談 我 表 壤 對 據 人 三 談 我 五",
            "d029fc9737b801cb4f9aadf5feed02a117b76ead7058e055cc39cb44864023eb492e6a15c68569d6a03a5b11bf15a456c64e1781a553589b47ab569801239a00",
            "xprv9s21ZrQH143K4bYXrWpQYgiSHDM1iVkNVnyqbpjyZksLS2fmxKCbwQjz3sBFTD1aFY4xWrYdHTyeFYjnYWfKGLc5WCkpokdAZyP9XEGJCsa"
        ],
        [
            "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            "歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 歇 佳",
            "8e6607a07fa664d6e4ead23fcc08caf72216d6f078c3b2e5be94e4b6e8d64c784d36bf9b70144fa05840e9a49899128111be5093a2b552b6ab76c0906e9b0e65",
            "xprv9s21ZrQH143K2ghKxX47TRr4GnQh3diJFN5rJfybjxuwr3xP6pafXrBhwXJsw4HwoiPZ1f6fFPR964eoXybV2su498Ant3kYuYKE3CszLsU"
        ],
        [
            "9e885d952ad362caeb4efe34a8e91bd2",
            "蒙 台 脫 紀 構 硫 漿 黴 感 僅 魚 湯",
            "27ca577f0318b6c6067acce7aefacd12bc9fbbc8e365fdc16bfc0ffd76379b0768dc56877f19eee4c1222dfb5a94a5516c5707e6a6ad070af9a0fe7f7799ac5e",
            "xprv9s21ZrQH143K3FtWQPZHP7Gpf5qgbvXqPNo5iCSfkGhWnATeqM5FuQ3YTx4sSciJx1MjVnbM3XQ16N83x5gNwcsVG7PTf1cRDhvyGZ45EY5"
        ],
        [
            "6610b25967cdcca9d59875f5cb50b0ea75433311869e930b",
            "父 泥 煉 脅 鞋 控 載 政 慘 逐 整 碗 環 慣 案 棒 訂 移",
            "fcac6cdda6c67e46ea46e66d00df3cfb1e437aa05f1b280f5427c0ce521a94b5a01ab016d235b7944f36d76ba0a297968ae0d882fde95c96cae34e35f2433c82",
            "xprv9s21ZrQH143K4YANCnajhJxfsFsDEZGitTmP934osTHvUmTEtfSaYk8rmvj914uGUYaJH5ALjDgVyNYW5gRGPdQBFaqoSbGkHXhfdVkNVY2"
        ],
        [
            "68a79eaca2324873eacc50cb9c6eca8cc68ea5d936f98787c60c7ebc74e6ce7c",
            "寧 照 違 材 交 養 違 野 悉 偷 梅 設 貴 帝 鮮 仰 圈 首 荷 鉤 隙 抓 養 熟",
            "969aaf00b9af97a1c3fd0b7b35480aebf51577658067df966caaf5cace472d2ecdaa2978470be83463262340527c0564d8c57f86764d48e9bebd1ce594955a6e",
            "xprv9s21ZrQH143K3aULbWnFhpGS2h19R5JdizbLLLQTDsGmKP5A1sqQop1Ff8Q7NEetRHRNFR8AAsPm1kr5hGU5VLYKURZeiVe9k5hqVmhZ5zF"
        ],
        [
            "c0ba5a8e914111210f2bd131f3d5e08d",
            "伐 旱 泡 口 線 揭 縣 楊 斷 芳 額 件",
            "09c172005e7dd81fcd55b87d13f114207ce7726376ea74a1b9085a799b2afbd5ac5526059e722987a65f858e5301edd5f4c91deaf9d7b4f9bcc38919e5ec3725",
            "xprv9s21ZrQH143K2sMUzpWRrPMF1Xx29Yos3Kah6H4E9YaJqDm2yEMXypoKdX1ugkn1Vx3k9Pr2LsKNQnHqoDFP5Jepm2PCkUS1GrQZps1wxkD"
        ],
        [
            "6d9be1ee6ebd27a258115aad99b7317b9c8d28b6d76431c3",
            "福 惜 懷 叔 筋 酵 貨 科 牙 冒 輩 罩 懸 耕 澆 呵 連 級",
            "3e09d89450ae45cc1a07ab308649f291ad5c1452da509d7269daef52ddd04db8bbb6bcb8a71322c4d25ed4686d910e84156fccfbac2838ba482bdd1e4b2ea693",
            "xprv9s21ZrQH143K4bLxh3ir6ziqU7t6URBK7uA8Md4tzAd3TAuBNyZREqEoZBevwu8Uw6tfMujFRWrZvCy47nbnKgDhsFaC2hvFJwRdkhnoM1v"
        ],
        [
            "9f6a2878b2520799a44ef18bc7df394e7061a224d2c33cd015b157d746869863",
            "儀 未 九 茶 隊 梯 婦 孤 托 病 泉 賀 產 繪 吹 測 局 碳 徵 墨 晶 幫 息 延",
            "d687bb89cb435fe1de166e953b41500f3717a497ca35c78322f66cd63e675fe0c8aba92463544631cdd6a985db03bdfcbfd839002ec609879e8768a3ffdb5fea",
            "xprv9s21ZrQH143K2LB4bPuHTErkGLt8DV5BbRsS82ySFPdQr57fzBY5D7VadhJHruxFzVcYdEbDqK8QWPSqj6LCiyQgFFurfnWWm1v6N2nGovN"
        ],
        [
            "23db8160a31d3e0dca3688ed941adbf3",
            "濟 扶 塊 言 穗 定 萬 繪 姻 逃 顆 焰",
            "806655cee21d12c952d6a11c12e742809c4452b6e07458c6ddc2cc2a8920e308476f3c6ba7fbbdab3de3a7bcecd4de5dd82dee7a217d0cd071eaa2313ca390da",
            "xprv9s21ZrQH143K3Kcz7sz3UyDYJhSjUYujBdxFwDHCbqmKWqN3hSf1pjnqoxuAKsQXbnvrxzRBLqPN9BKxHUiYgn1DjhwaStTfZQTCsaTEWxZ"
        ],
        [
            "8197a4a47f0425faeaa69deebc05ca29c0a5b5cc76ceacc0",
            "慮 鋪 目 禍 英 鉤 尤 添 醇 嘛 觸 獨 起 賦 連 剪 邦 中",
            "b609a4e17fa8c3c0b4da704b1699631f0d85f5b7bcc7d1488270551670b5393a0dfcb4d8eba9860c2c211324bbf3b587763ad1ac6a9e61a4e2e015bb6cc6a58a",
            "xprv9s21ZrQH143K2Gmewuzc56mbdKTqPezqWqk7ih9AdnLc9A2865TYtywU9sZ547mKYFKnbVatAuUUGtqgAz1ENkv9FU85jARHkCmtAGLmExn"
        ],
        [
            "066dca1a2bb7e8a1db2832148ce9933eea0f3ac9548d793112d9a95c9407efad",
            "而 怕 夏 客 蓋 古 松 面 解 謂 鮮 唯 障 烯 共 吳 永 丁 赤 副 醒 分 猛 埔",
            "8ce6b92bf95337a49bfd3d80774c9a73d05046eb2cb41789092a3bfbe7005ca668c427a42f1a93982d9076511330817b6d0bd49ba4f5a39e5756472b162f7ba0",
            "xprv9s21ZrQH143K41g7SsRpGA4g25xDiqjkhq8DNbJD7jgSksvt9kakaTzukN4SfVrUM2A9yGVPggP9eFAmuriRSpPLahm4ngaxvNHyQp82cee"
        ],
        [
            "f30f8c1da665478f49b001d94c5fc452",
            "昏 途 所 夠 請 乃 風 一 雕 缺 墊 閥",
            "e62457aa7f30c24fa46b90aeba2cbb9e77c28fcafa0c10dab01f5323eb1cef22f23c0e52cb5dffa2b2911a29992213c2cb20564af268eed03ea11292fff1a737",
            "xprv9s21ZrQH143K3JPEGRnwbdy5xdTvVdXEDGJX8gc385oC3H4veWiCVDrdeeFPWrU7Pz3PNMHcZrbutLY1UGs5dE83U925xKXLUrXXpz2ihKw"
        ],
        [
            "c10ec20dc3cd9f652c7fac2f1230f7a3c828389a14392f05",
            "瓶 顧 床 圈 倡 勵 炭 柄 且 招 價 緊 折 將 乎 硬 且 空",
            "6b5591c758a069d3425bf93399398e8ef3e1c32c27f46e0a5284976dcacf25895f5d7747b84f38596247557debd133576932d394ad24c7a00aa24555fa668c5b",
            "xprv9s21ZrQH143K2hh1em7CqtG7uL1bTNG5hfP35X6Y8uwnTDiS9Cm87WNcZvmFHLf3JwoP2W82VzaRejpqr7oPnFLguhVSr5pWnG9YSV4SdeH"
        ],
        [
            "f585c11aec520db57dd353c69554b21a89b20fb0650966fa0a9d6f74fd989d8f",
            "柄 需 固 姆 色 斥 霍 握 賓 琴 況 團 抵 經 摸 郭 沙 鳴 拖 妙 陽 輩 掉 遷",
            "17ec1a79121f3541e2d78ece35c8cfe7f5763b39d93fa90492c4beca26ee69d3aa7f4b1e6a2ac5e8225e08dded19357ee44b852dca425792842ec8eae09ae43f",
            "xprv9s21ZrQH143K4RoVseL4UENdN7Ag1WmcK7Q6Pk329krQW4RifHJ5sNizkG1PiyRXAouyL7KDFJSQAD1VarGTPftD1yZZAni3QczW8V5gNVG"
        ]
    ],
]
