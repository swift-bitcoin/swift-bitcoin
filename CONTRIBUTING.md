Contribute to Swift Bitcoin

# Generate DocC

Use the following command:

```sh
swift package --allow-writing-to-directory .build generate-documentation --target Bitcoin --disable-indexing --transform-for-static-hosting --hosting-base-path docc

cp -rp .build/plugins/Swift-DocC/outputs/Bitcoin.doccarchive/. $STATIC_WEBSITE_ROOT/docc 
```

On your website make sure to link to `/docc/documentation/bitcoin/`.
