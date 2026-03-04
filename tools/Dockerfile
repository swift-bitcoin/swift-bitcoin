# syntax=docker/dockerfile:1

# Get the latest Static Linux `swift sdk install` command from https://www.swift.org/install/linux/#swift-sdk-bundles

FROM --platform=$BUILDPLATFORM swift:6.2.4 AS builder
ARG TARGETARCH
COPY . /opt/swift-bitcoin
WORKDIR /opt/swift-bitcoin
RUN \
    swift sdk install https://download.swift.org/swift-6.2.4-release/static-sdk/swift-6.2.4-RELEASE/swift-6.2.4-RELEASE_static-linux-0.1.0.artifactbundle.tar.gz --checksum 24bdf84495dd31a6de2eb679647c1982b747bfbfe1a2060c779d84dcecd902a4 && \
    if [  $TARGETARCH = arm64 ]; then export ARCH=aarch64; elif [ $TARGETARCH = amd64 ]; then export ARCH=x86_64; else export ARCH=$TARGETARCH; fi && \
    swift build -c release --swift-sdk $ARCH-swift-linux-musl && \
    mv /opt/swift-bitcoin/.build/$ARCH-swift-linux-musl /opt/swift-bitcoin/.build/swift-linux-musl
    # && \ swift test

FROM scratch AS bcutil
COPY --from=builder /opt/swift-bitcoin/.build/swift-linux-musl/release/bcutil /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/bcutil"]

FROM scratch AS bcnode
COPY --from=builder /opt/swift-bitcoin/.build/swift-linux-musl/release/bcnode /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/bcnode"]
