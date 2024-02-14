Contribute to Swift Bitcoin

# Generate DocC

Use the following command:

```sh
swift package --allow-writing-to-directory .build generate-documentation --target Bitcoin --disable-indexing --transform-for-static-hosting --hosting-base-path docc

swift package --allow-writing-to-directory .build generate-documentation --target bcnode --disable-indexing --transform-for-static-hosting --hosting-base-path docc/bcnode

swift package --allow-writing-to-directory .build generate-documentation --target bcutil --disable-indexing --transform-for-static-hosting --hosting-base-path docc/bcutil

WWW_ROOT=~/Developer/CraigWrong/swift-bitcoin.github.io/static

rm -rf WWW_ROOT/docc

cp -rp .build/plugins/Swift-DocC/outputs/Bitcoin.doccarchive/. $WWW_ROOT/docc
cp -rp .build/plugins/Swift-DocC/outputs/bcnode.doccarchive/. $WWW_ROOT/docc/bcnode
cp -rp .build/plugins/Swift-DocC/outputs/bcutil.doccarchive/. $WWW_ROOT/docc/bcutil
```

On your website make sure to link to `/docc/documentation/bitcoin/`.
