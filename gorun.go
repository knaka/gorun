package main

import (
	"crypto/sha1"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
)

func v0(err error) {
	if err != nil {
		panic(err)
	}
}

func v[T any](t T, err error) T {
	if err != nil {
		panic(err)
	}
	return t
}

func v2[T any, U any](t T, u U, err error) (T, U) {
	if err != nil {
		panic(err)
	}
	return t, u
}

var exeExt = sync.OnceValue(func() (exeExt string) {
	switch runtime.GOOS {
	case "windows":
		exeExt = ".exe"
	}
	return
})

var Goroot = sync.OnceValues(func() (gobinPath string, err error) {
	// 1.22.7 seems not working on Windows?
	ver := "1.23.1"
	homeDir := v(os.UserHomeDir())
	sdkDirPath := filepath.Join(homeDir, "sdk")
	gorootPath := filepath.Join(sdkDirPath, "go"+ver)
	goCmdPath := filepath.Join(gorootPath, "bin", "go"+exeExt())
	if _, err := os.Stat(goCmdPath); err == nil {
		return gorootPath, nil
	}
	tempDir := v(os.MkdirTemp("", ""))
	defer (func() { v0(os.RemoveAll(tempDir)) })()
	arcPath := filepath.Join(tempDir, "temp.tgz")
	url := fmt.Sprintf("https://go.dev/dl/go%s.%s-%s.tar.gz", ver, runtime.GOOS, runtime.GOARCH)
	//goland:noinspection GoBoolExpressions
	if runtime.GOOS == "windows" {
		arcPath = filepath.Join(tempDir, "temp.zip")
		url = fmt.Sprintf("https://go.dev/dl/go%s.%s-%s.zip", ver, runtime.GOOS, runtime.GOARCH)
	}
	cmd := exec.Command("curl"+exeExt(), "--location", "-o", arcPath, url)
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	v0(cmd.Run())
	cmd = exec.Command("tar"+exeExt(), "-C", sdkDirPath, "-xzf", arcPath)
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	v0(cmd.Run())
	v0(os.Rename(filepath.Join(sdkDirPath, "go"), gorootPath))
	return gorootPath, nil
})

var goCmdPath = sync.OnceValue(func() string {
	binDirPath := filepath.Join(v(Goroot()), "bin")
	v0(os.Setenv("PATH", fmt.Sprintf("%s%c%s", binDirPath, filepath.ListSeparator, os.Getenv("PATH"))))
	cmdPath := filepath.Join(binDirPath, "go"+exeExt())
	return cmdPath
})

// EnsureInstalled ensures that the program package is installed.
func EnsureInstalled(
	gobinPath string,
	pkgPath string,
	ver string,
	tags string,
	verbose bool,
) (
	cmdPath string,
	err error,
) {
	pkgBase := path.Base(pkgPath)
	pkgBaseVer := pkgBase + "@" + ver
	if tags != "" {
		hash := sha1.New()
		hash.Write([]byte(tags))
		sevenDigits := fmt.Sprintf("%x", hash.Sum(nil))[:7]
		pkgBaseVer += "-" + sevenDigits
	}
	cmdPath = filepath.Join(gobinPath, pkgBaseVer+exeExt())
	if _, err_ := os.Stat(cmdPath); err_ != nil {
		if verbose {
			log.Printf("Installing %s@%s\n", pkgPath, ver)
		}
		args := []string{"install"}
		if tags != "" {
			log.Printf("Installing with tags %s\n", tags)
			args = append(args, "-tags", tags)
		}
		args = append(args, fmt.Sprintf("%s@%s", pkgPath, ver))
		if verbose {
			log.Printf("Installing %s@%s\n", pkgPath, ver)
			log.Printf("Arguments: %v\n", args)
		}
		cmd := exec.Command(goCmdPath(), args...)
		cmd.Env = append(os.Environ(), fmt.Sprintf("GOBIN=%s", gobinPath))
		cmd.Stdout = os.Stderr
		cmd.Stderr = os.Stderr
		_ = os.Remove(cmdPath)
		v0(cmd.Run())
		_ = os.Remove(cmdPath)
		v0(os.Rename(filepath.Join(gobinPath, pkgBase), cmdPath))
	}
	return
}

func main() {
	verbose := flag.Bool("verbose", false, "Verbose output.")
	shouldHelp := flag.Bool("help", false, "Show help.")
	tags := flag.String("tags", "", "Build tags.")
	flag.Usage = func() {
		_, _ = fmt.Fprintln(os.Stderr, `Usage: gorun [options] <package> [<args>...]

Options:`)
		flag.PrintDefaults()
		_, _ = fmt.Fprintln(os.Stderr, `Examples:

  gorun --tags netgo,sqlite3 golang.org/x/tools/cmd/stringer@@v0.11 -type=MyType
`)
	}
	flag.Parse()
	if *shouldHelp {
		flag.Usage()
		os.Exit(0)
	}
	if *verbose {
		_, _ = fmt.Fprintln(os.Stderr, "Verbose output")
		_, _ = fmt.Fprintf(os.Stderr, "Build tags: %s\n", *tags)
	}
	if flag.NArg() == 0 {
		_, _ = fmt.Fprintln(os.Stderr, "No package specified.")
		os.Exit(1)
	}
	packagePathVer := flag.Arg(0)
	args := flag.Args()[1:]
	if *verbose {
		_, _ = fmt.Fprintf(os.Stderr, "Package: %s\n", packagePathVer)
		_, _ = fmt.Fprintf(os.Stderr, "Arguments: %v\n", args)
	}
	gorootPath, err := Goroot()
	if err != nil {
		log.Fatalf("Error: %+v", err)
	}
	if *verbose {
		_, _ = fmt.Fprintf(os.Stderr, "GOROOT: %s\n", gorootPath)
	}
	homeDir := v(os.UserHomeDir())
	divs := strings.SplitN(packagePathVer, "@", 2)
	packagePath := divs[0]
	packageVer := divs[1]
	cmdPath, err := EnsureInstalled(
		filepath.Join(homeDir, ".gorun"),
		packagePath,
		packageVer,
		*tags,
		*verbose,
	)
	if err != nil {
		log.Fatalf("Error: %+v", err)
	}
	cmd := exec.Command(cmdPath, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	var execErr *exec.ExitError
	err = cmd.Run()
	errors.As(err, &execErr)
	if execErr != nil {
		os.Exit(execErr.ExitCode())
	}
}
