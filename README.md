# gorun

`gorun` is a tool that speeds up the execution of `go run ...` commands by caching the resulting binaries. By leveraging this cache, subsequent runs of the same package with identical build tags and arguments are significantly faster.

## Features

- **Caching:** Automatically caches the binary output. 
- **Go Version Management:** Automatically downloads and manages a specified Go version (`1.23.1` by default) if not already installed.
- **Custom Build Tags:** Supports custom build tags to tailor builds to your needs.

## Installation and usage

For Unixy systems (Linux, macOS, WSL), you can install `gorun` shell script by running:

```bash
curl --fail --remote-name --location https://raw.githubusercontent.com/knaka/gorun/refs/heads/main/gorun
chmod +x gorun
````

Then run the following command to see the usage:

```console
$ ./gorun --verbose --tags=foo,bar golang.org/x/tools/cmd/stringer@v0.11 --help
```

For Windows, you can download the `gorun.cmd` script.

```cmd
curl.exe --fail --remote-name --location https://raw.githubusercontent.com/knaka/gorun/refs/heads/main/gorun.cmd
```

Then run the following command to see the usage:

```console
C:\> gorun.cmd --verbose --tags=foo,bar golang.org/x/tools/cmd/stringer@v0.11 --help
```

This tool is designed also to be used as a `go:generate` directive. For example, you can add the following line to your Go source code:

```go
//go:generate -command stringer go run gorun.go golang.org/x/tools/cmd/stringer@v0.11
//go:generate stringer -type Fruit .
```

### Options

* `--verbose`: Enables verbose logging for debugging.
* `--tags`: Specifies build tags (comma-separated) for the Go build process.
* `--help`: Displays usage information.


How It Works
------------

1. **Caching Strategy:**  
   `gorun` computes a unique identifier for the combination of the package path, version, and build tags. If a cached binary exists for this combination, it is reused. Otherwise, the binary is built and cached.

2. **Go Version Management:**  
   The tool automatically ensures the required Go version is installed in `~/sdk`. If the required version is not present, it downloads and installs it from the official Go website.

3. **Binary Location:**  
   Cached binaries are stored in `~/.gorun`, with filenames that include the package name, version, and a hash of the build tags.


Requirements
------------

* Nothing! `gorun` is a self-contained script that works out of the box.

Contributing
------------

Contributions are welcome! If you encounter a bug or have a feature request, please open an issue or submit a pull request.

License
-------

This project is licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for details.

* * *

Enjoy faster development with `gorun`!
