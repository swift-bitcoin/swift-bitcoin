# syntax=docker/dockerfile:1

# Get the latest Static Linux `swift sdk install` command from https://www.swift.org/install/linux/#swift-sdk-bundles

FROM --platform=$BUILDPLATFORM swift:6.4 AS builder
ARG TARGETARCH
COPY . /opt/swift-bitcoin
WORKDIR /opt/swift-bitcoin
RUN \
    swift sdk install https://download.swift.org/swift-6.4.0-release/static-sdk/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE_static-linux-0.1.0.artifactbundle.tar.gz --checksum 47d2fd89eebfdf9eb4d536b6710414297f755c17926cdebc4742c08982b40a9e && \
    if [  $TARGETARCH = arm64 ]; then export ARCH=aarch64; elif [ $TARGETARCH = amd64 ]; then export ARCH=x86_64; else export ARCH=$TARGETARCH; fi && \
    swift build -c release --swift-sdk $ARCH-swift-linux-musl -Xswiftc -Osize -Xlinker --strip-all -Xlinker --gc-sections && \
    mkdir /out && \
    mv  .build/$ARCH-swift-linux-musl/release/bcnode .build/$ARCH-swift-linux-musl/release/bcutil /out/
    # && \ swift test

FROM scratch AS artifacts
COPY --from=builder /out /out

FROM scratch AS bcutil
COPY --from=artifacts /out/bcutil /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/bcutil"]

FROM scratch AS bcnode
COPY --from=artifacts /out/bcnode /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/bcnode"]

# Fully optimized build command:
# swift build -c release --swift-sdk aarch64-swift-linux-musl -Xswiftc -Osize -Xswiftc -cross-module-optimization -Xswiftc -lto=llvm-thin -Xlinker --strip-all -Xlinker --gc-sections
#  -Xswiftc -cross-module-optimization fails for aarch64 (building from Linux)
# -Xswiftc -lto=llvm-thin fails for x86_64 (building from Linux)

