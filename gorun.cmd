@echo off
setlocal enabledelayedexpansion

if "%~1" == "update-me" (
  curl.exe --fail --location --output %TEMP%\cmd-%~nx0 https://raw.githubusercontent.com/knaka/gorun/gorun.cmd
  move /y %TEMP%\cmd-%~nx0 %~f0
  exit /b 0
)

@REM All releases - The Go Programming Language https://go.dev/dl/
set required_min_major_ver=1
set required_min_minor_ver=23
set ver=!required_min_major_ver!.!required_min_minor_ver!.1

set exit_code=1

:unique_temp_loop
set "temp_dir_path=%TEMP%\%~n0-%RANDOM%"
if exist "!temp_dir_path!" goto unique_temp_loop
mkdir "!temp_dir_path!" || goto :exit
call :to_short_path "!temp_dir_path!"
set temp_dir_spath=!short_path!

set go_cmd_spath=!goroot_dir_spath!\bin\go.exe
set GOROOT=

if not defined GOPATH (
  set GOPATH=!user_profile_spath!\go
)

if not exist !GOPATH!\bin (
  mkdir !GOPATH!\bin
)

set "name=embedded-%~f0"
set "name=!name: =_!"
set "name=!name:\=_!"
set "name=!name::=_!"
set "name=!name:/=_!"
if exist !GOPATH!\bin\!name!.exe (
  xcopy /l /d /y !GOPATH!\bin\!name!.exe "%~f0" | findstr /b /c:"1 " >nul 2>&1
  if !ERRORLEVEL! == 0 (
    goto :execute
  )
)

set goroot_dir_spath=

call :to_short_path "C:\Program Files"
set program_files_spath=!short_path!
call :to_short_path "%USERPROFILE%"
set user_profile_spath=!short_path!

@REM Command in %PATH%
where go >nul 2>&1 
if !ERRORLEVEL! == 0 (
  for /F "usebackq tokens=*" %%p in (`where go`) do (
    call :to_short_path "%%p"
    set cmd_spath=!short_path!
    call :set_proper_goroot_dir_spath !cmd_spath!
    if !goroot_dir_spath! neq "" (
      goto :found_goroot
    )
  )
)

@REM Trivial installation paths
@REM for /D %%d in (!program_files_spath!\go !user_profile_spath!\sdk\go*) do (
for /D %%d in (!user_profile_spath!\sdk\go*) do (
  set cmd_spath=%%d\bin\go.exe
  if exist !cmd_spath! (
    call :set_proper_goroot_dir_spath !cmd_spath!
    if !goroot_dir_spath! neq "" (
      goto :found_goroot
    )
  )
)

@REM Download if not found
set goos=windows
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
  set goarch=amd64
) else if "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
  set goarch=amd64
) else (
  goto :exit
)
set sdk_dir_spath=!user_profile_spath!\sdk
if not exist !sdk_dir_spath! (
  mkdir !sdk_dir_spath! || goto :exit
)
set zip_spath=!temp_dir_spath!\go.zip
echo Downloading Go SDK: !ver! >&2
curl.exe --fail --location -o !zip_spath! "https://go.dev/dl/go!ver!.%goos%-%goarch%.zip" || goto :exit
cd !sdk_dir_spath! || goto :exit
unzip -q !zip_spath! || goto :exit
move /y !sdk_dir_spath!\go !sdk_dir_spath!\go!ver! || goto :exit
set goroot_dir_spath=!sdk_dir_spath!\go!ver!

:found_goroot
echo Using Go compiler: !go_cmd_spath! >&2
for /f "usebackq tokens=1 delims=:" %%i in (`findstr /n /b :embed_53c8fd5 "%~f0"`) do set n=%%i
set tempfile=!temp_dir_spath!\!name!.go
more +%n% "%~f0" > !tempfile!

set GOTOOLCHAIN=
!go_cmd_spath! build -o !GOPATH!\bin\!name!.exe !tempfile! || goto :exit
del /q !temp_dir_spath!

:execute
!GOPATH!\bin\!name!.exe %* || goto :exit
set exit_code=0

:exit
if exist !temp_dir_spath! (
  del /q !temp_dir_spath!
)
exit /b !exit_code!

:to_short_path
set "input_path=%~1"
for %%i in ("%input_path%") do set "short_path=%%~si"
exit /b
goto :eof

:set_proper_goroot_dir_spath
set GOTOOLCHAIN=local
for /F "usebackq tokens=*" %%v in (`%1 env GOVERSION`) do (
  set version=%%v
  set major=!version:~2,1!
  set minor=!version:~4,2!
  if !major! geq !required_min_major_ver! (
    if !minor! geq !required_min_minor_ver! (
      for /F "useback tokens=*" %%p in (`%1 env GOROOT`) do (
        call :to_short_path "%%p"
        set goroot_dir_spath=!short_path!
      )
    )
  )
)
exit /b
goto :eof

endlocal

:embed_53c8fd5
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
