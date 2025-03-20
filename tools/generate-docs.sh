#!/bin/bash

rm -f src/bitcoin-crypto/Documentation.docc/theme-settings.json
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-crypto/Documentation.docc/
rm -f src/bitcoin-crypto/Documentation.docc/header.html
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-crypto/Documentation.docc/

rm -f src/bitcoin-base/Documentation.docc/theme-settings.json
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-base/Documentation.docc/
rm -f src/bitcoin-base/Documentation.docc/header.html
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-base/Documentation.docc/

rm -f src/bitcoin-miniscript/Documentation.docc/theme-settings.json
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-miniscript/Documentation.docc/
rm -f src/bitcoin-miniscript/Documentation.docc/header.html
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-miniscript/Documentation.docc/

rm -f src/bitcoin-wallet/Documentation.docc/theme-settings.json
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-wallet/Documentation.docc/
rm -f src/bitcoin-wallet/Documentation.docc/header.html
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-wallet/Documentation.docc/

rm -f src/bitcoin-psbt/Documentation.docc/theme-settings.json
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-psbt/Documentation.docc/
rm -f src/bitcoin-psbt/Documentation.docc/header.html
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-psbt/Documentation.docc/

rm -f src/bitcoin-blockchain/Documentation.docc/theme-settings.json
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-blockchain/Documentation.docc/
rm -f src/bitcoin-blockchain/Documentation.docc/header.html
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-blockchain/Documentation.docc/

rm -f src/bitcoin-transport/Documentation.docc/theme-settings.json
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-transport/Documentation.docc/
rm -f src/bitcoin-transport/Documentation.docc/header.html
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-transport/Documentation.docc/

rm -f src/bitcoin-rpc/Documentation.docc/theme-settings.json
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-rpc/Documentation.docc/
rm -f src/bitcoin-rpc/Documentation.docc/header.html
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-rpc/Documentation.docc/

rm -f src/bitcoin-node/Documentation.docc/theme-settings.json
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-node/Documentation.docc/
rm -f src/bitcoin-node/Documentation.docc/header.html
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-node/Documentation.docc/

rm -f src/bitcoin-utility/Documentation.docc/theme-settings.json
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-utility/Documentation.docc/
rm -f src/bitcoin-utility/Documentation.docc/header.html
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-utility/Documentation.docc/

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinCrypto --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docs/crypto --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinBase --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docs/base --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinMiniscript --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docs/miniscript --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinWallet --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docs/wallet --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinPSBT --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docs/psbt --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinBlockchain --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docs/blockchain --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinTransport --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docs/transport --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinRPC --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docs/rpc --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinUtility --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docs/bcutil --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinNode --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docs/bcnode --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target Bitcoin --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --dependency .build/plugins/Swift-DocC/outputs/BitcoinCrypto.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinBase.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinMiniscript.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinWallet.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinPSBT.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinBlockchain.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinTransport.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinRPC.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinUtility.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinNode.doccarchive --hosting-base-path docs --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

rm src/bitcoin-crypto/Documentation.docc/header.html
rm src/bitcoin-crypto/Documentation.docc/theme-settings.json

rm src/bitcoin-base/Documentation.docc/header.html
rm src/bitcoin-base/Documentation.docc/theme-settings.json

rm src/bitcoin-miniscript/Documentation.docc/header.html
rm src/bitcoin-miniscript/Documentation.docc/theme-settings.json

rm src/bitcoin-wallet/Documentation.docc/header.html
rm src/bitcoin-wallet/Documentation.docc/theme-settings.json

rm src/bitcoin-psbt/Documentation.docc/header.html
rm src/bitcoin-psbt/Documentation.docc/theme-settings.json

rm src/bitcoin-blockchain/Documentation.docc/header.html
rm src/bitcoin-blockchain/Documentation.docc/theme-settings.json

rm src/bitcoin-transport/Documentation.docc/header.html
rm src/bitcoin-transport/Documentation.docc/theme-settings.json

rm src/bitcoin-rpc/Documentation.docc/header.html
rm src/bitcoin-rpc/Documentation.docc/theme-settings.json

rm src/bitcoin-node/Documentation.docc/header.html
rm src/bitcoin-node/Documentation.docc/theme-settings.json

rm src/bitcoin-utility/Documentation.docc/header.html
rm src/bitcoin-utility/Documentation.docc/theme-settings.json

rm -rf $WWW_ROOT
mkdir -p $WWW_ROOT

cp -rp .build/plugins/Swift-DocC/outputs/BitcoinCrypto.doccarchive/. $WWW_ROOT/crypto
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinBase.doccarchive/. $WWW_ROOT/base
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinMiniscript.doccarchive/. $WWW_ROOT/miniscript
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinWallet.doccarchive/. $WWW_ROOT/wallet
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinPSBT.doccarchive/. $WWW_ROOT/psbt
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinBlockchain.doccarchive/. $WWW_ROOT/blockchain
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinTransport.doccarchive/. $WWW_ROOT/transport
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinRPC.doccarchive/. $WWW_ROOT/rpc
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinNode.doccarchive/. $WWW_ROOT/bcnode
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinUtility.doccarchive/. $WWW_ROOT/bcutil
cp -rp .build/plugins/Swift-DocC/outputs/Bitcoin.doccarchive/. $WWW_ROOT
