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

rm -rf $WWW_ROOT
mkdir -p $WWW_ROOT

swift package \
    --allow-writing-to-directory $WWW_ROOT \
    generate-documentation \
    --target Bitcoin \
    --target BitcoinCrypto \
    --target BitcoinBase \
    --target BitcoinBlockchain \
    --target BitcoinMiniscript \
    --target BitcoinWallet \
    --target BitcoinPSBT  \
    --target BitcoinTransport \
    --target BitcoinRPC \
    --target BitcoinNode \
    --target BitcoinUtility \
    --disable-indexing \
    --symbol-graph-minimum-access-level internal \
    --transform-for-static-hosting \
    --hosting-base-path docs \
    --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop \
    --checkout-path $PWD \
    --experimental-enable-custom-templates \
    --enable-experimental-combined-documentation \
    --output-path $WWW_ROOT

# Additional options:
#
#     --exclude-extended-types
#     --enable-experimental-external-link-support

# Command line with dependencies:
#
# swift package --allow-writing-to-directory .build generate-documentation --target Bitcoin --disable-indexing --transform-for-static-hosting --enable-experimental-external-link-support --dependency .build/plugins/Swift-DocC/outputs/BitcoinCrypto.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinBase.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinMiniscript.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinWallet.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinPSBT.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinBlockchain.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinTransport.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinRPC.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinUtility.doccarchive --dependency .build/plugins/Swift-DocC/outputs/BitcoinNode.doccarchive --hosting-base-path docs --source-service github --source-service-base-url https://github.com/swift-bitcoin/swift-bitcoin/blob/develop --checkout-path $PWD --experimental-enable-custom-templates

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
