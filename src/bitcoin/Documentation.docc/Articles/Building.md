# Building

Build the Swift Bitcoin library and executables using the Swift Toolchain or Docker.

## Overview

To build Swift Bitcoin you'll either need Docker or a working copy of the Swift Toolchain installed on your system. On Mac you can also build and run directly from Xcode.

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

## Executable image

Build both executable images `bcnode` and `bcutil` from Swift Bitcoin's project root:

```sh
docker build --target bcnode -t bcnode -f tools/Dockerfile .
docker build --target bcutil -t bcutil -f tools/Dockerfile .
```

To execute these images:

```sh
docker network create bitcoin-regtest
docker run --rm -it --network bitcoin-regtest --name alice bcnode -n regtest
docker run --rm --network bitcoin-regtest bcutil -n regtest -h alice status
```

For more information on running and controlling a network of nodes check out <doc:Running>.

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

## Tooling

The examples below assume Swift Bitcoin is built with `swift build -c release`.

### Logs

For logging we use [Swift Log](https://github.com/apple/swift-log) with the default standard output backend.

To override the default _info_ log level:

    ./.build/release/bcnode --log-level=debug

Possible values are: `critical, `error`, `warning`, `info`, `notice`, `debug` and `trace`. It is also possible to specify the log level via configuration file `~/.swift-bitcoin/config.swift`:

```swift
let config = NodeConfig(…
    logLevel: .info, …)
```

### Metrics

Swift Bitcoin uses [Swift Metrics](https://github.com/apple/swift-metrics) with the corresponding OpenTelemetry back-end provided by [Swift OTel](https://github.com/swift-otel/swift-otel). Hardware diagnostics are provided by the [System Metrics](https://github.com/apple/swift-system-metrics) package.

To configure use:

```swift
let config = NodeConfig( …
    metrics: .init(), …
)
```

Which will use the default gRPC endpoint `http://localhost:4317`. Alternatively you can specify a custom endpoint using the `NodeConfig.OTelMetrics` initializer.

To visualize metrics you can start the [Grafana](https://grafana.com/oss/grafana/) container from included the Docker Compose definition:

```bash
cd tools/grafana
docker compose up
```

The configuration already includes a dashboard dedicated to Bitcoin protocol metrics as well as a separate dashboard for system metrics.

Point your browser to http://localhost:3000 to explore metrics in real time.

### Profiler

The Bitcoin Node (bcnode) daemon has a [profiler](https://github.com/apple/swift-profile-recorder) built in.

To configure use:

```swift
let config = NodeConfig( …
    enableProfiling: true, …
)
```

 The Profile Recorder Server will run in the background if enabled if environment variable `PROFILE_RECORDER_SERVER_URL_PATTERN` is set:

    PROFILE_RECORDER_SERVER_URL_PATTERN=unix:///tmp/bcnode-samples-{PID}.sock ./.build/release/bcnode

In the logs you should see a message similar to the one below:

    ServerInfo(startResult: ProfileRecorderServer.ProfileRecorderServer.ServerInfo.ServerStartResult.successful([UDS]/tmp/bcnode-samples-94846.sock)) [ProfileRecorderServer] profile recorder server up and running

That message contains the process ID, `94846` in this case. With that you can record using `curl`:

    curl --unix-socket /tmp/bcnode-samples-94846.sock -sd '{"numberOfSamples":10,"timeInterval":"100 ms"}' http://localhost/sample | swift demangle --compact > /tmp/samples.perf

To visualize you can upload to a service like [Speedscope](https://www.speedscope.app) or some other flamegraph visualizer.
