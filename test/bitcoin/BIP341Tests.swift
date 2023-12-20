import XCTest
@testable import Bitcoin

/// https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki#test-vectors
/// https://github.com/bitcoin/bips/blob/master/bip-0341/wallet-test-vectors.json
/// Validation test vectors used in the Bitcoin Core unit [test framework](https://github.com/bitcoin/bitcoin/blob/3820090bd619ac85ab35eff376c03136fe4a9f04/src/test/script_tests.cpp#L1718) can be found [here](https://raw.githubusercontent.com/bitcoin-core/qa-assets/main/unit_test_data/script_assets_test.json).
final class BIP341Tests: XCTestCase {

    override class func setUp() {
        eccStart()
    }

    override class func tearDown() {
        eccStop()
    }

    func testScriptPubKey() {
        let scriptPubKeyTestVector = [
            (
                given: (
                    internalPubkey: Data(hex: "d6889cb081036e0faefa3a35157ad71086b123b2b144b649798b494c300a961d")!,
                    scriptTree: ScriptTree?.none
                ),
                intermediary: (
                    leafHashes: [Data](),
                    merkleRoot: Data?.none,
                    tweak: Data(hex: "b86e7be8f39bab32a6f2c0443abbc210f0edac0e2c53d501b36b64437d9c6c70")!,
                    tweakedPubkey: Data(hex: "53a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda343")!
                ),
                expected: (
                    scriptPubKey: Data(hex: "512053a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda343")!,
                    bip350Address: "bc1p2wsldez5mud2yam29q22wgfh9439spgduvct83k3pm50fcxa5dps59h4z5",
                    scriptPathControlBlocks: [Data]()
                )
            ),
            (
                given: (
                    internalPubkey: Data(hex: "187791b6f712a8ea41c8ecdd0ee77fab3e85263b37e1ec18a3651926b3a6cf27")!,
                    scriptTree: .leaf(192, Data(hex: "20d85a959b0290bf19bb89ed43c916be835475d013da4b362117393e25a48229b8ac")!)
                ),
                intermediary: (
                    leafHashes: [
                        Data(hex: "5b75adecf53548f3ec6ad7d78383bf84cc57b55a3127c72b9a2481752dd88b21")!
                    ],
                    merkleRoot: Data(hex: "5b75adecf53548f3ec6ad7d78383bf84cc57b55a3127c72b9a2481752dd88b21")!,
                    tweak: Data(hex: "cbd8679ba636c1110ea247542cfbd964131a6be84f873f7f3b62a777528ed001")!,
                    tweakedPubkey: Data(hex: "147c9c57132f6e7ecddba9800bb0c4449251c92a1e60371ee77557b6620f3ea3")!
                ),
                expected: (
                    scriptPubKey: Data(hex: "5120147c9c57132f6e7ecddba9800bb0c4449251c92a1e60371ee77557b6620f3ea3")!,
                    bip350Address: "bc1pz37fc4cn9ah8anwm4xqqhvxygjf9rjf2resrw8h8w4tmvcs0863sa2e586",
                    scriptPathControlBlocks: [
                        Data(hex: "c1187791b6f712a8ea41c8ecdd0ee77fab3e85263b37e1ec18a3651926b3a6cf27")!
                    ]
                )
            ),
            (
                given: (
                    internalPubkey: Data(hex: "93478e9488f956df2396be2ce6c5cced75f900dfa18e7dabd2428aae78451820")!,
                    scriptTree:  ScriptTree?.some(.leaf(192, Data(hex: "20b617298552a72ade070667e86ca63b8f5789a9fe8731ef91202a91c9f3459007ac")!))
                ),
                intermediary: (
                    leafHashes: [
                        Data(hex: "c525714a7f49c28aedbbba78c005931a81c234b2f6c99a73e4d06082adc8bf2b")!
                    ],
                    merkleRoot: Data(hex: "c525714a7f49c28aedbbba78c005931a81c234b2f6c99a73e4d06082adc8bf2b")!,
                    tweak: Data(hex: "6af9e28dbf9d6aaf027696e2598a5b3d056f5fd2355a7fd5a37a0e5008132d30")!,
                    tweakedPubkey: Data(hex: "e4d810fd50586274face62b8a807eb9719cef49c04177cc6b76a9a4251d5450e")!
                ),
                expected: (
                    scriptPubKey: Data(hex: "5120e4d810fd50586274face62b8a807eb9719cef49c04177cc6b76a9a4251d5450e")!,
                    bip350Address: "bc1punvppl2stp38f7kwv2u2spltjuvuaayuqsthe34hd2dyy5w4g58qqfuag5",
                    scriptPathControlBlocks: [
                        Data(hex: "c093478e9488f956df2396be2ce6c5cced75f900dfa18e7dabd2428aae78451820")!
                    ]
                )
            ),
            (
                given: (
                    internalPubkey: Data(hex: "ee4fe085983462a184015d1f782d6a5f8b9c2b60130aff050ce221ecf3786592")!,
                    scriptTree: ScriptTree?.some(.branch(
                        .leaf(192, Data(hex: "20387671353e273264c495656e27e39ba899ea8fee3bb69fb2a680e22093447d48ac")!),
                        .leaf(250, Data(hex: "06424950333431")!)
                    ))
                ),
                intermediary: (
                    leafHashes: [
                        Data(hex: "8ad69ec7cf41c2a4001fd1f738bf1e505ce2277acdcaa63fe4765192497f47a7")!,
                        Data(hex: "f224a923cd0021ab202ab139cc56802ddb92dcfc172b9212261a539df79a112a")!
                    ],
                    merkleRoot: Data(hex: "6c2dc106ab816b73f9d07e3cd1ef2c8c1256f519748e0813e4edd2405d277bef")!,
                    tweak: Data(hex: "9e0517edc8259bb3359255400b23ca9507f2a91cd1e4250ba068b4eafceba4a9")!,
                    tweakedPubkey: Data(hex: "712447206d7a5238acc7ff53fbe94a3b64539ad291c7cdbc490b7577e4b17df5")!
                ),
                expected: (
                    scriptPubKey: Data(hex: "5120712447206d7a5238acc7ff53fbe94a3b64539ad291c7cdbc490b7577e4b17df5")!,
                    bip350Address: "bc1pwyjywgrd0ffr3tx8laflh6228dj98xkjj8rum0zfpd6h0e930h6saqxrrm",
                    scriptPathControlBlocks: [
                        Data(hex: "c0ee4fe085983462a184015d1f782d6a5f8b9c2b60130aff050ce221ecf3786592f224a923cd0021ab202ab139cc56802ddb92dcfc172b9212261a539df79a112a")!,
                        Data(hex: "faee4fe085983462a184015d1f782d6a5f8b9c2b60130aff050ce221ecf37865928ad69ec7cf41c2a4001fd1f738bf1e505ce2277acdcaa63fe4765192497f47a7")!
                    ]
                )
            ),
            (
                given: (
                    internalPubkey: Data(hex: "f9f400803e683727b14f463836e1e78e1c64417638aa066919291a225f0e8dd8")!,
                    scriptTree: ScriptTree?.some(.branch(
                        .leaf(192, Data(hex: "2044b178d64c32c4a05cc4f4d1407268f764c940d20ce97abfd44db5c3592b72fdac")!),
                        .leaf(192, Data(hex: "07546170726f6f74")!)
                    ))
                ),
                intermediary: (
                    leafHashes: [
                        Data(hex: "64512fecdb5afa04f98839b50e6f0cb7b1e539bf6f205f67934083cdcc3c8d89")!,
                        Data(hex: "2cb2b90daa543b544161530c925f285b06196940d6085ca9474d41dc3822c5cb")!
                    ],
                    merkleRoot: Data(hex: "ab179431c28d3b68fb798957faf5497d69c883c6fb1e1cd9f81483d87bac90cc")!,
                    tweak: Data(hex: "639f0281b7ac49e742cd25b7f188657626da1ad169209078e2761cefd91fd65e")!,
                    tweakedPubkey: Data(hex: "77e30a5522dd9f894c3f8b8bd4c4b2cf82ca7da8a3ea6a239655c39c050ab220")!
                ),
                expected: (
                    scriptPubKey: Data(hex: "512077e30a5522dd9f894c3f8b8bd4c4b2cf82ca7da8a3ea6a239655c39c050ab220")!,
                    bip350Address: "bc1pwl3s54fzmk0cjnpl3w9af39je7pv5ldg504x5guk2hpecpg2kgsqaqstjq",
                    scriptPathControlBlocks: [
                        Data(hex: "c1f9f400803e683727b14f463836e1e78e1c64417638aa066919291a225f0e8dd82cb2b90daa543b544161530c925f285b06196940d6085ca9474d41dc3822c5cb")!,
                        Data(hex: "c1f9f400803e683727b14f463836e1e78e1c64417638aa066919291a225f0e8dd864512fecdb5afa04f98839b50e6f0cb7b1e539bf6f205f67934083cdcc3c8d89")!
                    ]
                )
            ),
            (
                given: (
                    internalPubkey: Data(hex: "e0dfe2300b0dd746a3f8674dfd4525623639042569d829c7f0eed9602d263e6f")!,
                    scriptTree: ScriptTree?.some(.branch(
                        .leaf(192, Data(hex: "2072ea6adcf1d371dea8fba1035a09f3d24ed5a059799bae114084130ee5898e69ac")!),
                        .branch(
                            .leaf(192, Data(hex: "202352d137f2f3ab38d1eaa976758873377fa5ebb817372c71e2c542313d4abda8ac")!),
                            .leaf(192, Data(hex: "207337c0dd4253cb86f2c43a2351aadd82cccb12a172cd120452b9bb8324f2186aac")!)
                        )
                    ))
                ),
                intermediary: (
                    leafHashes: [
                        Data(hex: "2645a02e0aac1fe69d69755733a9b7621b694bb5b5cde2bbfc94066ed62b9817")!,
                        Data(hex: "ba982a91d4fc552163cb1c0da03676102d5b7a014304c01f0c77b2b8e888de1c")!,
                        Data(hex: "9e31407bffa15fefbf5090b149d53959ecdf3f62b1246780238c24501d5ceaf6")!
                    ],
                    merkleRoot: Data(hex: "ccbd66c6f7e8fdab47b3a486f59d28262be857f30d4773f2d5ea47f7761ce0e2")!,
                    tweak: Data(hex: "b57bfa183d28eeb6ad688ddaabb265b4a41fbf68e5fed2c72c74de70d5a786f4")!,
                    tweakedPubkey: Data(hex: "91b64d5324723a985170e4dc5a0f84c041804f2cd12660fa5dec09fc21783605")!
                ),
                expected: (
                    scriptPubKey: Data(hex: "512091b64d5324723a985170e4dc5a0f84c041804f2cd12660fa5dec09fc21783605")!,
                    bip350Address: "bc1pjxmy65eywgafs5tsunw95ruycpqcqnev6ynxp7jaasylcgtcxczs6n332e",
                    scriptPathControlBlocks: [
                        Data(hex: "c0e0dfe2300b0dd746a3f8674dfd4525623639042569d829c7f0eed9602d263e6fffe578e9ea769027e4f5a3de40732f75a88a6353a09d767ddeb66accef85e553")!,
                        Data(hex: "c0e0dfe2300b0dd746a3f8674dfd4525623639042569d829c7f0eed9602d263e6f9e31407bffa15fefbf5090b149d53959ecdf3f62b1246780238c24501d5ceaf62645a02e0aac1fe69d69755733a9b7621b694bb5b5cde2bbfc94066ed62b9817")!,
                        Data(hex: "c0e0dfe2300b0dd746a3f8674dfd4525623639042569d829c7f0eed9602d263e6fba982a91d4fc552163cb1c0da03676102d5b7a014304c01f0c77b2b8e888de1c2645a02e0aac1fe69d69755733a9b7621b694bb5b5cde2bbfc94066ed62b9817")!
                    ]
                )
            ),
            (
                given: (
                    internalPubkey: Data(hex: "55adf4e8967fbd2e29f20ac896e60c3b0f1d5b0efa9d34941b5958c7b0a0312d")!,
                    scriptTree: ScriptTree?.some(.branch(
                        .leaf(192, Data(hex: "2071981521ad9fc9036687364118fb6ccd2035b96a423c59c5430e98310a11abe2ac")!),
                        .branch(
                            .leaf(192, Data(hex: "20d5094d2dbe9b76e2c245a2b89b6006888952e2faa6a149ae318d69e520617748ac")!),
                            .leaf(192, Data(hex: "20c440b462ad48c7a77f94cd4532d8f2119dcebbd7c9764557e62726419b08ad4cac")!)
                        )
                    ))
                ),
                intermediary: (
                    leafHashes: [
                        Data(hex: "f154e8e8e17c31d3462d7132589ed29353c6fafdb884c5a6e04ea938834f0d9d")!,
                        Data(hex: "737ed1fe30bc42b8022d717b44f0d93516617af64a64753b7a06bf16b26cd711")!,
                        Data(hex: "d7485025fceb78b9ed667db36ed8b8dc7b1f0b307ac167fa516fe4352b9f4ef7")!
                    ],
                    merkleRoot: Data(hex: "2f6b2c5397b6d68ca18e09a3f05161668ffe93a988582d55c6f07bd5b3329def")!,
                    tweak: Data(hex: "6579138e7976dc13b6a92f7bfd5a2fc7684f5ea42419d43368301470f3b74ed9")!,
                    tweakedPubkey: Data(hex: "75169f4001aa68f15bbed28b218df1d0a62cbbcf1188c6665110c293c907b831")!
                ),
                expected: (
                    scriptPubKey: Data(hex: "512075169f4001aa68f15bbed28b218df1d0a62cbbcf1188c6665110c293c907b831")!,
                    bip350Address: "bc1pw5tf7sqp4f50zka7629jrr036znzew70zxyvvej3zrpf8jg8hqcssyuewe",
                    scriptPathControlBlocks: [
                        Data(hex: "c155adf4e8967fbd2e29f20ac896e60c3b0f1d5b0efa9d34941b5958c7b0a0312d3cd369a528b326bc9d2133cbd2ac21451acb31681a410434672c8e34fe757e91")!,
                        Data(hex: "c155adf4e8967fbd2e29f20ac896e60c3b0f1d5b0efa9d34941b5958c7b0a0312dd7485025fceb78b9ed667db36ed8b8dc7b1f0b307ac167fa516fe4352b9f4ef7f154e8e8e17c31d3462d7132589ed29353c6fafdb884c5a6e04ea938834f0d9d")!,
                        Data(hex: "c155adf4e8967fbd2e29f20ac896e60c3b0f1d5b0efa9d34941b5958c7b0a0312d737ed1fe30bc42b8022d717b44f0d93516617af64a64753b7a06bf16b26cd711f154e8e8e17c31d3462d7132589ed29353c6fafdb884c5a6e04ea938834f0d9d")!
                    ]
                )
            )
        ]

        for i in scriptPubKeyTestVector.indices {
            let testCase = scriptPubKeyTestVector[i]
            let merkleRoot: Data?
            let leafHashes: [Data]
            let controlBlocks: [Data]
            if let scriptTree = testCase.given.scriptTree {
                let treeInfo: [(ScriptTree, Data)]
                (treeInfo, merkleRoot) = scriptTree.calcMerkleRoot()
                guard let merkleRoot else {
                    fatalError()
                }
                leafHashes = treeInfo.map {
                    let (leaf, _) = $0
                    return leaf.leafHash
                }
                controlBlocks = treeInfo.map {
                    computeControlBlock(internalPublicKey: testCase.given.internalPubkey, leafInfo: $0, merkleRoot: merkleRoot)
                }
            } else {
                merkleRoot = .none
                leafHashes = []
                controlBlocks = []
            }
            let tweak = computeTapTweakHash(xOnlyPublicKey: testCase.given.internalPubkey, merkleRoot: merkleRoot)
            let (tweakedPubkey, _) = createTapTweak(publicKey: testCase.given.internalPubkey, merkleRoot: merkleRoot)
            let scriptPubKey = BitcoinScript([.constant(1), .pushBytes(tweakedPubkey)]).data

            // TODO: BIP350
            /* guard let bip350Address = try? SegwitAddrCoder(bech32m: true).encode(hrp: "bc", version: 1, program: tweakedPubkey) else {
             XCTFail()
             return
             }*/

            XCTAssertEqual(leafHashes, testCase.intermediary.leafHashes)
            XCTAssertEqual(merkleRoot, testCase.intermediary.merkleRoot)
            XCTAssertEqual(tweak, testCase.intermediary.tweak)
            XCTAssertEqual(tweakedPubkey, testCase.intermediary.tweakedPubkey)
            XCTAssertEqual(scriptPubKey, testCase.expected.scriptPubKey)
            // XCTAssertEqual(bip350Address, testCase.expected.bip350Address)
            XCTAssertEqual(controlBlocks, testCase.expected.scriptPathControlBlocks)

        }
    }

    func testKeyPathSpending() {

        // NOTE: Output script does not actually parse fully.
        let tx = BitcoinTransaction(.init(hex: "02000000097de20cbff686da83a54981d2b9bab3586f4ca7e48f57f5b55963115f3b334e9c010000000000000000d7b7cab57b1393ace2d064f4d4a2cb8af6def61273e127517d44759b6dafdd990000000000fffffffff8e1f583384333689228c5d28eac13366be082dc57441760d957275419a418420000000000fffffffff0689180aa63b30cb162a73c6d2a38b7eeda2a83ece74310fda0843ad604853b0100000000feffffffaa5202bdf6d8ccd2ee0f0202afbbb7461d9264a25e5bfd3c5a52ee1239e0ba6c0000000000feffffff956149bdc66faa968eb2be2d2faa29718acbfe3941215893a2a3446d32acd050000000000000000000e664b9773b88c09c32cb70a2a3e4da0ced63b7ba3b22f848531bbb1d5d5f4c94010000000000000000e9aa6b8e6c9de67619e6a3924ae25696bb7b694bb677a632a74ef7eadfd4eabf0000000000ffffffffa778eb6a263dc090464cd125c466b5a99667720b1c110468831d058aa1b82af10100000000ffffffff0200ca9a3b000000001976a91406afd46bcdfd22ef94ac122aa11f241244a37ecc88ac807840cb0000000020ac9a87f5594be208f8532db38cff670c450ed2fea8fcdefcc9a663f78bab962b0065cd1d")!)!

        let utxosSpent = [
            TransactionOutput(value: 420000000, script: .init(Data(hex: "512053a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda343")!)),
            TransactionOutput(value: 462000000, script: .init(Data(hex: "5120147c9c57132f6e7ecddba9800bb0c4449251c92a1e60371ee77557b6620f3ea3")!)),
            TransactionOutput(value: 294000000, script: .init(Data(hex: "76a914751e76e8199196d454941c45d1b3a323f1433bd688ac")!)),
            TransactionOutput(value: 504000000, script: .init(Data(hex: "5120e4d810fd50586274face62b8a807eb9719cef49c04177cc6b76a9a4251d5450e")!)),
            TransactionOutput(value: 630000000, script: .init(Data(hex: "512091b64d5324723a985170e4dc5a0f84c041804f2cd12660fa5dec09fc21783605")!)),
            TransactionOutput(value: 378000000, script: .init(Data(hex: "00147dd65592d0ab2fe0d0257d571abf032cd9db93dc")!)),
            TransactionOutput(value: 672000000, script: .init(Data(hex: "512075169f4001aa68f15bbed28b218df1d0a62cbbcf1188c6665110c293c907b831")!)),
            TransactionOutput(value: 546000000, script: .init(Data(hex: "5120712447206d7a5238acc7ff53fbe94a3b64539ad291c7cdbc490b7577e4b17df5")!)),
            TransactionOutput(value: 588000000, script: .init(Data(hex: "512077e30a5522dd9f894c3f8b8bd4c4b2cf82ca7da8a3ea6a239655c39c050ab220")!))
        ]

        let intermediary = (
            hashAmounts: Data(hex: "58a6964a4f5f8f0b642ded0a8a553be7622a719da71d1f5befcefcdee8e0fde6")!,
            hashOutputs: Data(hex: "a2e6dab7c1f0dcd297c8d61647fd17d821541ea69c3cc37dcbad7f90d4eb4bc5")!,
            hashPrevouts: Data(hex: "e3b33bb4ef3a52ad1fffb555c0d82828eb22737036eaeb02a235d82b909c4c3f")!,
            hashScriptPubkeys: Data(hex: "23ad0f61ad2bca5ba6a7693f50fce988e17c3780bf2b1e720cfbb38fbdd52e21")!,
            hashSequences: Data(hex: "18959c7221ab5ce9e26c3cd67b22c24f8baa54bac281d8e6b05e400e6c3a957e")!
        )

        var cache = SighashCache()
        _ = tx.signatureMessageSchnorr(sighashType: SighashType?.none, inputIndex: 0, previousOutputs: utxosSpent, sighashCache: &cache)
        if let shaAmounts = cache.shaAmounts, let shaOuts = cache.shaOuts, let shaPrevouts = cache.shaPrevouts, let shaScriptPubKeys = cache.shaScriptPubKeys, let shaSequences = cache.shaSequences {
            XCTAssertEqual(shaAmounts, intermediary.hashAmounts)
            XCTAssertEqual(shaOuts, intermediary.hashOutputs)
            XCTAssertEqual(shaPrevouts, intermediary.hashPrevouts)
            XCTAssertEqual(shaScriptPubKeys, intermediary.hashScriptPubkeys)
            XCTAssertEqual(shaSequences, intermediary.hashSequences)
        } else {
            XCTFail("Could not produce some of the hashes required for the signature message.")
        }

        let inputSpending = [
            (
                given: (
                    txinIndex: 0,
                    internalSecretKey: Data(hex: "6b973d88838f27366ed61c9ad6367663045cb456e28335c109e30717ae0c6baa")!,
                    merkleRoot: Data?.none,
                    sighashType: SighashType?.some(.single)
                ),
                intermediary: (
                    internalPubkey: Data(hex: "d6889cb081036e0faefa3a35157ad71086b123b2b144b649798b494c300a961d")!,
                    tweak: Data(hex: "b86e7be8f39bab32a6f2c0443abbc210f0edac0e2c53d501b36b64437d9c6c70")!,
                    tweakedSecretKey: Data(hex: "2405b971772ad26915c8dcdf10f238753a9b837e5f8e6a86fd7c0cce5b7296d9")!,
                    sigMsg: Data(hex: "0003020000000065cd1de3b33bb4ef3a52ad1fffb555c0d82828eb22737036eaeb02a235d82b909c4c3f58a6964a4f5f8f0b642ded0a8a553be7622a719da71d1f5befcefcdee8e0fde623ad0f61ad2bca5ba6a7693f50fce988e17c3780bf2b1e720cfbb38fbdd52e2118959c7221ab5ce9e26c3cd67b22c24f8baa54bac281d8e6b05e400e6c3a957e0000000000d0418f0e9a36245b9a50ec87f8bf5be5bcae434337b87139c3a5b1f56e33cba0")!,
                    precomputedUsed: (
                        hashAmounts: true,
                        hashPrevouts: true,
                        hashScriptPubkeys: true,
                        hashSequences: true,
                        hashOutputs: false
                    ),
                    sighash: Data(hex: "2514a6272f85cfa0f45eb907fcb0d121b808ed37c6ea160a5a9046ed5526d555")!
                ),
                expectedWitness:[
                    Data(hex: "ed7c1647cb97379e76892be0cacff57ec4a7102aa24296ca39af7541246d8ff14d38958d4cc1e2e478e4d4a764bbfd835b16d4e314b72937b29833060b87276c03")!
                ]
            ),
            (
                given: (
                    txinIndex: 1,
                    internalSecretKey: Data(hex: "1e4da49f6aaf4e5cd175fe08a32bb5cb4863d963921255f33d3bc31e1343907f")!,
                    merkleRoot: Data?.some(Data(hex: "5b75adecf53548f3ec6ad7d78383bf84cc57b55a3127c72b9a2481752dd88b21")!),
                    sighashType: SighashType?.some(.singleAnyCanPay) // .init(rawValue: 131)
                ),
                intermediary: (
                    internalPubkey: Data(hex: "187791b6f712a8ea41c8ecdd0ee77fab3e85263b37e1ec18a3651926b3a6cf27")!,
                    tweak: Data(hex: "cbd8679ba636c1110ea247542cfbd964131a6be84f873f7f3b62a777528ed001")!,
                    tweakedSecretKey: Data(hex: "ea260c3b10e60f6de018455cd0278f2f5b7e454be1999572789e6a9565d26080")!,
                    sigMsg: Data(hex: "0083020000000065cd1d00d7b7cab57b1393ace2d064f4d4a2cb8af6def61273e127517d44759b6dafdd9900000000808f891b00000000225120147c9c57132f6e7ecddba9800bb0c4449251c92a1e60371ee77557b6620f3ea3ffffffffffcef8fb4ca7efc5433f591ecfc57391811ce1e186a3793024def5c884cba51d")!,
                    precomputedUsed: (
                        hashAmounts: false,
                        hashPrevouts: false,
                        hashScriptPubkeys: false,
                        hashSequences: false,
                        hashOutputs: false
                    ),
                    sighash: Data(hex: "325a644af47e8a5a2591cda0ab0723978537318f10e6a63d4eed783b96a71a4d")!
                ),
                expectedWitness:[
                    Data(hex: "052aedffc554b41f52b521071793a6b88d6dbca9dba94cf34c83696de0c1ec35ca9c5ed4ab28059bd606a4f3a657eec0bb96661d42921b5f50a95ad33675b54f83")!
                ]
            ),
            (
                given: (
                    txinIndex: 3,
                    internalSecretKey: Data(hex: "d3c7af07da2d54f7a7735d3d0fc4f0a73164db638b2f2f7c43f711f6d4aa7e64")!,
                    merkleRoot: Data?.some(Data(hex: "c525714a7f49c28aedbbba78c005931a81c234b2f6c99a73e4d06082adc8bf2b")!),
                    sighashType: .all
                ),
                intermediary: (
                    internalPubkey: Data(hex: "93478e9488f956df2396be2ce6c5cced75f900dfa18e7dabd2428aae78451820")!,
                    tweak: Data(hex: "6af9e28dbf9d6aaf027696e2598a5b3d056f5fd2355a7fd5a37a0e5008132d30")!,
                    tweakedSecretKey: Data(hex: "97323385e57015b75b0339a549c56a948eb961555973f0951f555ae6039ef00d")!,
                    sigMsg: Data(hex: "0001020000000065cd1de3b33bb4ef3a52ad1fffb555c0d82828eb22737036eaeb02a235d82b909c4c3f58a6964a4f5f8f0b642ded0a8a553be7622a719da71d1f5befcefcdee8e0fde623ad0f61ad2bca5ba6a7693f50fce988e17c3780bf2b1e720cfbb38fbdd52e2118959c7221ab5ce9e26c3cd67b22c24f8baa54bac281d8e6b05e400e6c3a957ea2e6dab7c1f0dcd297c8d61647fd17d821541ea69c3cc37dcbad7f90d4eb4bc50003000000")!,
                    precomputedUsed: (
                        hashAmounts: true,
                        hashPrevouts: true,
                        hashScriptPubkeys: true,
                        hashSequences: true,
                        hashOutputs: true
                    ),
                    sighash: Data(hex: "bf013ea93474aa67815b1b6cc441d23b64fa310911d991e713cd34c7f5d46669")!
                ),
                expectedWitness:[
                    Data(hex: "ff45f742a876139946a149ab4d9185574b98dc919d2eb6754f8abaa59d18b025637a3aa043b91817739554f4ed2026cf8022dbd83e351ce1fabc272841d2510a01")!
                ]
            ),
            (
                given: (
                    txinIndex: 4,
                    internalSecretKey: Data(hex: "f36bb07a11e469ce941d16b63b11b9b9120a84d9d87cff2c84a8d4affb438f4e")!,
                    merkleRoot: Data?.some(Data(hex: "ccbd66c6f7e8fdab47b3a486f59d28262be857f30d4773f2d5ea47f7761ce0e2")!),
                    sighashType: Optional.none
                ),
                intermediary: (
                    internalPubkey: Data(hex: "e0dfe2300b0dd746a3f8674dfd4525623639042569d829c7f0eed9602d263e6f")!,
                    tweak: Data(hex: "b57bfa183d28eeb6ad688ddaabb265b4a41fbf68e5fed2c72c74de70d5a786f4")!,
                    tweakedSecretKey: Data(hex: "a8e7aa924f0d58854185a490e6c41f6efb7b675c0f3331b7f14b549400b4d501")!,
                    sigMsg: Data(hex: "0000020000000065cd1de3b33bb4ef3a52ad1fffb555c0d82828eb22737036eaeb02a235d82b909c4c3f58a6964a4f5f8f0b642ded0a8a553be7622a719da71d1f5befcefcdee8e0fde623ad0f61ad2bca5ba6a7693f50fce988e17c3780bf2b1e720cfbb38fbdd52e2118959c7221ab5ce9e26c3cd67b22c24f8baa54bac281d8e6b05e400e6c3a957ea2e6dab7c1f0dcd297c8d61647fd17d821541ea69c3cc37dcbad7f90d4eb4bc50004000000")!,
                    precomputedUsed: (
                        hashAmounts: true,
                        hashPrevouts: true,
                        hashScriptPubkeys: true,
                        hashSequences: true,
                        hashOutputs: true
                    ),
                    sighash: Data(hex: "4f900a0bae3f1446fd48490c2958b5a023228f01661cda3496a11da502a7f7ef")!
                ),
                expectedWitness:[
                    Data(hex: "b4010dd48a617db09926f729e79c33ae0b4e94b79f04a1ae93ede6315eb3669de185a17d2b0ac9ee09fd4c64b678a0b61a0a86fa888a273c8511be83bfd6810f")!
                ]
            ),
            (
                given: (
                    txinIndex: 6,
                    internalSecretKey: Data(hex: "415cfe9c15d9cea27d8104d5517c06e9de48e2f986b695e4f5ffebf230e725d8")!,
                    merkleRoot: Data?.some(Data(hex: "2f6b2c5397b6d68ca18e09a3f05161668ffe93a988582d55c6f07bd5b3329def")!),
                    sighashType: SighashType.none
                ),
                intermediary: (
                    internalPubkey: Data(hex: "55adf4e8967fbd2e29f20ac896e60c3b0f1d5b0efa9d34941b5958c7b0a0312d")!,
                    tweak: Data(hex: "6579138e7976dc13b6a92f7bfd5a2fc7684f5ea42419d43368301470f3b74ed9")!,
                    tweakedSecretKey: Data(hex: "241c14f2639d0d7139282aa6abde28dd8a067baa9d633e4e7230287ec2d02901")!,
                    sigMsg: Data(hex: "0002020000000065cd1de3b33bb4ef3a52ad1fffb555c0d82828eb22737036eaeb02a235d82b909c4c3f58a6964a4f5f8f0b642ded0a8a553be7622a719da71d1f5befcefcdee8e0fde623ad0f61ad2bca5ba6a7693f50fce988e17c3780bf2b1e720cfbb38fbdd52e2118959c7221ab5ce9e26c3cd67b22c24f8baa54bac281d8e6b05e400e6c3a957e0006000000")!,
                    precomputedUsed: (
                        hashAmounts: true,
                        hashPrevouts: true,
                        hashScriptPubkeys: true,
                        hashSequences: true,
                        hashOutputs: false
                    ),
                    sighash: Data(hex: "15f25c298eb5cdc7eb1d638dd2d45c97c4c59dcaec6679cfc16ad84f30876b85")!
                ),
                expectedWitness: [
                    Data(hex: "a3785919a2ce3c4ce26f298c3d51619bc474ae24014bcdd31328cd8cfbab2eff3395fa0a16fe5f486d12f22a9cedded5ae74feb4bbe5351346508c5405bcfee002")!
                ]
            ),
            (
                given: (
                    txinIndex: 7,
                    internalSecretKey: Data(hex: "c7b0e81f0a9a0b0499e112279d718cca98e79a12e2f137c72ae5b213aad0d103")!,
                    merkleRoot: Data?.some(Data(hex: "6c2dc106ab816b73f9d07e3cd1ef2c8c1256f519748e0813e4edd2405d277bef")!),
                    sighashType: .noneAnyCanPay
                ),
                intermediary: (
                    internalPubkey: Data(hex: "ee4fe085983462a184015d1f782d6a5f8b9c2b60130aff050ce221ecf3786592")!,
                    tweak: Data(hex: "9e0517edc8259bb3359255400b23ca9507f2a91cd1e4250ba068b4eafceba4a9")!,
                    tweakedSecretKey: Data(hex: "65b6000cd2bfa6b7cf736767a8955760e62b6649058cbc970b7c0871d786346b")!,
                    sigMsg: Data(hex: "0082020000000065cd1d00e9aa6b8e6c9de67619e6a3924ae25696bb7b694bb677a632a74ef7eadfd4eabf00000000804c8b2000000000225120712447206d7a5238acc7ff53fbe94a3b64539ad291c7cdbc490b7577e4b17df5ffffffff")!,
                    precomputedUsed: (
                        hashAmounts: false,
                        hashPrevouts: false,
                        hashScriptPubkeys: false,
                        hashSequences: false,
                        hashOutputs: false
                    ),
                    sighash: Data(hex: "cd292de50313804dabe4685e83f923d2969577191a3e1d2882220dca88cbeb10")!
                ),
                expectedWitness: [
                    Data(hex: "ea0c6ba90763c2d3a296ad82ba45881abb4f426b3f87af162dd24d5109edc1cdd11915095ba47c3a9963dc1e6c432939872bc49212fe34c632cd3ab9fed429c482")!
                ]
            ),
            (
                given: (
                    txinIndex: 8,
                    internalSecretKey: Data(hex: "77863416be0d0665e517e1c375fd6f75839544eca553675ef7fdf4949518ebaa")!,
                    merkleRoot: Data(hex: "ab179431c28d3b68fb798957faf5497d69c883c6fb1e1cd9f81483d87bac90cc")!,
                    sighashType: .allAnyCanPay
                ),
                intermediary: (
                    internalPubkey: Data(hex: "f9f400803e683727b14f463836e1e78e1c64417638aa066919291a225f0e8dd8")!,
                    tweak: Data(hex: "639f0281b7ac49e742cd25b7f188657626da1ad169209078e2761cefd91fd65e")!,
                    tweakedSecretKey: Data(hex: "ec18ce6af99f43815db543f47b8af5ff5df3b2cb7315c955aa4a86e8143d2bf5")!,
                    sigMsg: Data(hex: "0081020000000065cd1da2e6dab7c1f0dcd297c8d61647fd17d821541ea69c3cc37dcbad7f90d4eb4bc500a778eb6a263dc090464cd125c466b5a99667720b1c110468831d058aa1b82af101000000002b0c230000000022512077e30a5522dd9f894c3f8b8bd4c4b2cf82ca7da8a3ea6a239655c39c050ab220ffffffff")!,
                    precomputedUsed: (
                        hashAmounts: false,
                        hashPrevouts: false,
                        hashScriptPubkeys: false,
                        hashSequences: false,
                        hashOutputs: true
                    ),
                    sighash: Data(hex: "cccb739eca6c13a8a89e6e5cd317ffe55669bbda23f2fd37b0f18755e008edd2")!
                ),
                expectedWitness: [
                    Data(hex: "bbc9584a11074e83bc8c6759ec55401f0ae7b03ef290c3139814f545b58a9f8127258000874f44bc46db7646322107d4d86aec8e73b8719a61fff761d75b5dd981")!
                ]
            )
        ]

        for testCase in inputSpending {
            // Given
            let secretKey = testCase.given.internalSecretKey
            let merkleRoot = testCase.given.merkleRoot
            let sighashType = testCase.given.sighashType
            let inputIndex = testCase.given.txinIndex

            // Expected
            let expectedInternalPublicKey = testCase.intermediary.internalPubkey
            let expectedTweak = testCase.intermediary.tweak
            let expectedTweakedSecretKey = testCase.intermediary.tweakedSecretKey
            let expectedSigMsg = testCase.intermediary.sigMsg
            let expectedSighash = testCase.intermediary.sighash
            let expectedWitness = testCase.expectedWitness

            let internalPublicKey = getInternalKey(secretKey: secretKey)
            XCTAssertEqual(internalPublicKey, expectedInternalPublicKey)

            let tweak = computeTapTweakHash(xOnlyPublicKey: internalPublicKey, merkleRoot: merkleRoot)
            XCTAssertEqual(tweak, expectedTweak)

            let tweakedSecretKey = createSecretKeyTapTweak(secretKey: secretKey, merkleRoot: merkleRoot)
            XCTAssertEqual(tweakedSecretKey, expectedTweakedSecretKey)

            let sigMsg = tx.signatureMessageSchnorr(sighashType: sighashType, inputIndex: inputIndex, previousOutputs: utxosSpent, sighashCache: &cache)

            XCTAssertEqual(cache.shaAmountsUsed, testCase.intermediary.precomputedUsed.hashAmounts)
            XCTAssertEqual(cache.shaOutsUsed, testCase.intermediary.precomputedUsed.hashOutputs)
            XCTAssertEqual(cache.shaPrevoutsUsed, testCase.intermediary.precomputedUsed.hashPrevouts)
            XCTAssertEqual(cache.shaSequencesUsed, testCase.intermediary.precomputedUsed.hashSequences)
            XCTAssertEqual(cache.shaScriptPubKeysUsed, testCase.intermediary.precomputedUsed.hashScriptPubkeys)
            XCTAssertEqual(sigMsg, expectedSigMsg)

            let sighash = tx.signatureHashSchnorr(sighashType: sighashType, inputIndex: inputIndex, previousOutputs: utxosSpent, sighashCache: &cache)
            XCTAssertEqual(sighash, expectedSighash)

            let hashTypeSuffix: Data
            if let sighashType {
                hashTypeSuffix = sighashType.data
            } else {
                hashTypeSuffix = Data()
            }
            let sig = signSchnorr(msg: sighash, secretKey: secretKey, merkleRoot: merkleRoot, aux: Data(repeating: 0, count: 256)) + hashTypeSuffix
            XCTAssertEqual([sig], expectedWitness)
        }

        // TODO: Figure out how to sign input 2 (legacy) and 5 (segwit v0)
        // NOTE: Output script does not actually parse fully.
        // var expectedSignedTx =
        _ = BitcoinTransaction(.init(hex: "020000000001097de20cbff686da83a54981d2b9bab3586f4ca7e48f57f5b55963115f3b334e9c010000000000000000d7b7cab57b1393ace2d064f4d4a2cb8af6def61273e127517d44759b6dafdd990000000000fffffffff8e1f583384333689228c5d28eac13366be082dc57441760d957275419a41842000000006b4830450221008f3b8f8f0537c420654d2283673a761b7ee2ea3c130753103e08ce79201cf32a022079e7ab904a1980ef1c5890b648c8783f4d10103dd62f740d13daa79e298d50c201210279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798fffffffff0689180aa63b30cb162a73c6d2a38b7eeda2a83ece74310fda0843ad604853b0100000000feffffffaa5202bdf6d8ccd2ee0f0202afbbb7461d9264a25e5bfd3c5a52ee1239e0ba6c0000000000feffffff956149bdc66faa968eb2be2d2faa29718acbfe3941215893a2a3446d32acd050000000000000000000e664b9773b88c09c32cb70a2a3e4da0ced63b7ba3b22f848531bbb1d5d5f4c94010000000000000000e9aa6b8e6c9de67619e6a3924ae25696bb7b694bb677a632a74ef7eadfd4eabf0000000000ffffffffa778eb6a263dc090464cd125c466b5a99667720b1c110468831d058aa1b82af10100000000ffffffff0200ca9a3b000000001976a91406afd46bcdfd22ef94ac122aa11f241244a37ecc88ac807840cb0000000020ac9a87f5594be208f8532db38cff670c450ed2fea8fcdefcc9a663f78bab962b0141ed7c1647cb97379e76892be0cacff57ec4a7102aa24296ca39af7541246d8ff14d38958d4cc1e2e478e4d4a764bbfd835b16d4e314b72937b29833060b87276c030141052aedffc554b41f52b521071793a6b88d6dbca9dba94cf34c83696de0c1ec35ca9c5ed4ab28059bd606a4f3a657eec0bb96661d42921b5f50a95ad33675b54f83000141ff45f742a876139946a149ab4d9185574b98dc919d2eb6754f8abaa59d18b025637a3aa043b91817739554f4ed2026cf8022dbd83e351ce1fabc272841d2510a010140b4010dd48a617db09926f729e79c33ae0b4e94b79f04a1ae93ede6315eb3669de185a17d2b0ac9ee09fd4c64b678a0b61a0a86fa888a273c8511be83bfd6810f0247304402202b795e4de72646d76eab3f0ab27dfa30b810e856ff3a46c9a702df53bb0d8cc302203ccc4d822edab5f35caddb10af1be93583526ccfbade4b4ead350781e2f8adcd012102f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f90141a3785919a2ce3c4ce26f298c3d51619bc474ae24014bcdd31328cd8cfbab2eff3395fa0a16fe5f486d12f22a9cedded5ae74feb4bbe5351346508c5405bcfee0020141ea0c6ba90763c2d3a296ad82ba45881abb4f426b3f87af162dd24d5109edc1cdd11915095ba47c3a9963dc1e6c432939872bc49212fe34c632cd3ab9fed429c4820141bbc9584a11074e83bc8c6759ec55401f0ae7b03ef290c3139814f545b58a9f8127258000874f44bc46db7646322107d4d86aec8e73b8719a61fff761d75b5dd9810065cd1d")!)
    }
}
