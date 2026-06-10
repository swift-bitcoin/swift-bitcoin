# syntax=docker/dockerfile:1

# Get the latest Static Linux `swift sdk install` command from https://www.swift.org/install/linux/#swift-sdk-bundles

FROM --platform=$BUILDPLATFORM swift:6.3.2 AS builder
ARG TARGETARCH
COPY . /opt/swift-bitcoin
WORKDIR /opt/swift-bitcoin
RUN \
    swift sdk install https://download.swift.org/swift-6.3.2-release/static-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_static-linux-0.1.0.artifactbundle.tar.gz --checksum 3fd798bef6f4408f1ea5a6f94ce4d4052830c4326ab85ebc04f983f01b3da407 && \
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
