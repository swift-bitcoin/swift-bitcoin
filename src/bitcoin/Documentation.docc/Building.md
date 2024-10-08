# Building

To build Swift Bitcoin you'll either need Docker or a working copy of the Swift Toolchain installed on your system.

## Docker instructions

To build using the Swift docker image:

```sh
docker run --rm -it -v $PWD:/root/src swift
```

At the container's prompt:

```sh
cd ~/src
swift build --build-tests
swift test
swift run bcutil --help
```

## Linux

Use [swiftly](https://github.com/swiftlang/swiftly) to get the Toolchain installed on your system:

```sh
curl -L https://swiftlang.github.io/swiftly/swiftly-install.sh | bash
swiftly install latest
```

Once you have the latest toolchain, change to the Swift Bitcoin project directory and make sure all tests are passing:

```sh
cd swift-bitcoin
swift build --build-tests
swift test
```

After that you can run one of the available executable targets:

```sh
swift run bcutil --help
```

## Mac

The simplest way to build and run Swift Bitcoin on a Mac is to have Xcode installed. After that you can use the IDE or run `swift` from the command line.
