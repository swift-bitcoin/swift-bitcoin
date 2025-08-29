# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM swift:6.1.2 AS builder
ARG TARGETARCH
COPY . /opt/swift-bitcoin
WORKDIR /opt/swift-bitcoin
RUN \
    swift sdk install https://download.swift.org/swift-6.1.2-release/static-sdk/swift-6.1.2-RELEASE/swift-6.1.2-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz --checksum df0b40b9b582598e7e3d70c82ab503fd6fbfdff71fd17e7f1ab37115a0665b3b && \
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
