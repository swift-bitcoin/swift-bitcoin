#!/bin/bash

rm -f src/bitcoin-crypto/Documentation.docc/theme-settings.json
rm -f src/bitcoin-base/Documentation.docc/theme-settings.json
rm -f src/bitcoin-wallet/Documentation.docc/theme-settings.json
rm -f src/bitcoin-blockchain/Documentation.docc/theme-settings.json
rm -f src/bitcoin-transport/Documentation.docc/theme-settings.json
rm -f src/bitcoin-node/Documentation.docc/theme-settings.json
rm -f src/bitcoin-utility/Documentation.docc/theme-settings.json

cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-crypto/Documentation.docc/
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-base/Documentation.docc/
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-wallet/Documentation.docc/
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-blockchain/Documentation.docc/
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-transport/Documentation.docc/
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-node/Documentation.docc/
cp src/bitcoin/Documentation.docc/theme-settings.json src/bitcoin-utility/Documentation.docc/

rm -f src/bitcoin-crypto/Documentation.docc/header.html
rm -f src/bitcoin-base/Documentation.docc/header.html
rm -f src/bitcoin-wallet/Documentation.docc/header.html
rm -f src/bitcoin-blockchain/Documentation.docc/header.html
rm -f src/bitcoin-transport/Documentation.docc/header.html
rm -f src/bitcoin-node/Documentation.docc/header.html
rm -f src/bitcoin-utility/Documentation.docc/header.html

ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-crypto/Documentation.docc/
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-base/Documentation.docc/
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-wallet/Documentation.docc/
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-blockchain/Documentation.docc/
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-transport/Documentation.docc/
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-node/Documentation.docc/
ln -s ../../bitcoin/Documentation.docc/header.html src/bitcoin-utility/Documentation.docc/

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinCrypto --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docc/crypto --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinBase --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docc/base --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinWallet --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docc/wallet --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinBlockchain --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docc/blockchain --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinTransport --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docc/transport --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinUtility --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docc/bcutil --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target BitcoinNode --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --hosting-base-path docc/bcnode --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

swift package --allow-writing-to-directory .build generate-documentation --target Bitcoin --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --dependency .build/plugins/Swift-DocC/outputs/BitcoinCrypto.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinBase.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinWallet.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinBlockchain.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinTransport.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinUtility.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinNode.doccarchive --hosting-base-path docc --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

rm src/bitcoin-crypto/Documentation.docc/theme-settings.json
rm src/bitcoin-base/Documentation.docc/theme-settings.json
rm src/bitcoin-wallet/Documentation.docc/theme-settings.json
rm src/bitcoin-blockchain/Documentation.docc/theme-settings.json
rm src/bitcoin-transport/Documentation.docc/theme-settings.json
rm src/bitcoin-node/Documentation.docc/theme-settings.json
rm src/bitcoin-utility/Documentation.docc/theme-settings.json

rm src/bitcoin-crypto/Documentation.docc/header.html
rm src/bitcoin-base/Documentation.docc/header.html
rm src/bitcoin-wallet/Documentation.docc/header.html
rm src/bitcoin-blockchain/Documentation.docc/header.html
rm src/bitcoin-transport/Documentation.docc/header.html
rm src/bitcoin-node/Documentation.docc/header.html
rm src/bitcoin-utility/Documentation.docc/header.html

rm -rf $WWW_ROOT/docc
mkdir $WWW_ROOT/docc

cp -rp .build/plugins/Swift-DocC/outputs/BitcoinCrypto.doccarchive/. $WWW_ROOT/docc/crypto
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinBase.doccarchive/. $WWW_ROOT/docc/base
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinWallet.doccarchive/. $WWW_ROOT/docc/wallet
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinBlockchain.doccarchive/. $WWW_ROOT/docc/blockchain
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinTransport.doccarchive/. $WWW_ROOT/docc/transport
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinNode.doccarchive/. $WWW_ROOT/docc/bcnode
cp -rp .build/plugins/Swift-DocC/outputs/BitcoinUtility.doccarchive/. $WWW_ROOT/docc/bcutil
cp -rp .build/plugins/Swift-DocC/outputs/Bitcoin.doccarchive/. $WWW_ROOT/docc
