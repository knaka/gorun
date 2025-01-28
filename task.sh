#!/bin/sh
test "${guard_6ee3caf+set}" = set && return 0; guard_6ee3caf=-
set -o nounset -o errexit

# Update the script by replacing itself with the latest version.
if test "${1+SET}" = SET && test "$1" = "update-me"
then
  temp_dir_path_5de91af="$(mktemp -d)"
  # shellcheck disable=SC2317
  cleanup_7f0c4de() { rm -fr "$temp_dir_path_5de91af"; }
  trap cleanup_7f0c4de EXIT
  curl --fail --location --output "$temp_dir_path_5de91af"/task_sh https://raw.githubusercontent.com/knaka/src/main/task.sh
  cat "$temp_dir_path_5de91af"/task_sh > "$0"
  exit 0
fi

# --------------------------------------------------------------------------
# Constants.
# --------------------------------------------------------------------------

# shellcheck disable=SC2034
rc_delegate_task_not_found=10

# shellcheck disable=SC2034
rc_test_skipped=11

# --------------------------------------------------------------------------
# IFS-separated value functions.
# --------------------------------------------------------------------------

# Head of IFSV.
ifsv_head() {
  test $# -eq 0 && return 1
  # shellcheck disable=SC2086
  set -- $1
  printf "%s" "$1"
}

# Tail of IFSV.
ifsv_tail() {
  test $# -eq 0 && return 1
  # shellcheck disable=SC2086
  set -- $1
  shift
  local item
  for item in "$@"
  do
    printf "%s%s" "$item" "$IFS"
  done
}

ifsv_length() {
  # shellcheck disable=SC2086
  set -- $1
  echo "$#"
}

ifsv_empty() {
  test -z "$1"
}

# Join IFS-separated values with a delimiter.
ifsv_join() {
  local out_delim="$2"
  # shellcheck disable=SC2086
  set -- $1
  local delim=
  local arg=
  for arg in "$@"
  do
    printf "%s%s" "$delim" "$arg"
    delim="$out_delim"
  done
}

# Get an item at a specified index.
ifsv_at() {
  local i=0
  local item
  for item in $1
  do
    if test "$i" = "$2"
    then
      if test "${3+set}" = set
      then
        printf "%s%s" "$3" "$IFS"
      else
        printf "%s" "$item"
        return
      fi
    else
      if test "${3+set}" = set
      then
        printf "%s%s" "$item" "$IFS"
      fi
    fi
    i=$((i + 1))
  done
}

# Map IFS-separated values with a command. If the command contains "_", then it is replaced with the item.
ifsv_map() {
  local arr="$1"
  shift
  local should_replace=false
  local arg
  for arg in "$@"
  do
    if test "$arg" = "_" || test "$arg" = "it"
    then
      should_replace=true
    fi
  done
  local i=0
  local item
  for item in $arr
  do
    if $should_replace
    then
      (
        for arg in "$@"
        do
          if test "$arg" = "_"
          then
            arg="$item"
          fi
          set -- "$@" "$arg"
          shift
        done
        printf "%s%s" "$("$@")" "$IFS"
      )
    else
      printf "%s%s" "$("$@" "$item")" "$IFS"
    fi
    i=$((i + 1))
  done
}

# Filter IFS-separated values with a command. If the command contains "_", then it is replaced with the item.
ifsv_filter() {
  local arr="$1"
  shift
  local should_replace=false
  local arg
  for arg in "$@"
  do
    if test "$arg" = "_"
    then
      should_replace=true
    fi
  done
  local item
  for item in $arr
  do
    if $should_replace
    then
      if ! (
        for arg in "$@"
        do
          if test "$arg" = "_"
          then
            arg="$item"
          fi
          set -- "$@" "$arg"
          shift
        done
        "$@"
      )
      then
        continue
      fi
    elif ! "$@" "$item"
    then
      continue
    fi
    printf "%s%s" "$item" "$IFS"
  done
}

# Reduce IFS-separated values with a function. If the function contains "_", then it is replaced with the accumulator and the item.
ifsv_reduce() {
  local arr="$1"
  shift
  local acc="$1"
  shift
  local has_place_holder=false
  local arg
  for arg in "$@"
  do
    if test "$arg" = "_"
    then
      has_place_holder=true
    fi
  done
  local item
  for item in $arr
  do
    if $has_place_holder
    then
      acc="$(
        first_place_holder=true
        for arg2 in "$@"
        do
          if test "$arg2" = "_"
          then
            if $first_place_holder
            then
              arg2="$acc"
              first_place_holder=false
            else
              arg2="$item"
            fi
          fi
          set -- "$@" "$arg2"
          shift
        done
        "$@"
      )"
    else
      acc="$("$@" "$acc" "$item")"
    fi
  done
  printf "%s" "$acc"
}

# Check if an IFS-separated value contains a specified item.
ifsv_contains() {
  local arr="$1"
  local target="$2"
  local item
  for item in $arr
  do
    if test "$item" = "$target"
    then
      return
    fi
  done
  return 1
}

# Sort IFS-separated values.
ifsv_sort() {
  local arr="$1"
  if test -z "$arr"
  then
    return
  fi
  shift
  local vers
  # shellcheck disable=SC2086
  vers="$(
    printf "%s\n" $arr \
    | if test "$#" -eq 0
    then
      sort
    else
      "$@"
    fi
  )"
  push_ifs
  ifs_newline
  # shellcheck disable=SC2086
  set -- $vers
  pop_ifs
  local item
  for item in "$@"
  do
    printf "%s%s" "$item" "$IFS"
  done
}

if ! type shuf > /dev/null 2>&1
then
  alias shuf='sort -R'
fi

# --------------------------------------------------------------------------
# Associative array functions. It is represented as propty list.
# --------------------------------------------------------------------------

# Get a value from an associative array implemented as a property list.
ifsv_get() {
  local plist="$1"
  local target_key="$2"
  local key=
  local i=0
  for item in $plist
  do
    if test $((i % 2)) -eq 0
    then
      key="$item"
    else
      if test "$key" = "$target_key"
      then
        printf "%s" "$item"
        return
      fi
    fi
    i=$((i + 1))
  done
  return 1
}

# Keys of an associative array implemented as a property list.
ifsv_keys() {
  local plist="$1"
  local i=0
  local item
  for item in $plist
  do
    if test $((i % 2)) -eq 0
    then
      printf "%s%s" "$item" "$IFS"
    fi
    i=$((i + 1))
  done
}

# Values of an associative array implemented as a property list.
ifsv_values() {
  local plist="$1"
  local i=0
  local item
  for item in $plist
  do
    if test $((i % 2)) -eq 1
    then
      printf "%s%s" "$item" "$IFS"
    fi
    i=$((i + 1))
  done
}

# Put a value in an associative array implemented as a property list.
ifsv_put() {
  local plist="$1"
  local target_key="$2"
  local value="$3"
  local found=false
  local key=
  local i=0
  local item
  for item in $plist
  do
    if test $((i % 2)) -eq 0
    then
      key="$item"
    else
      if test "$key" = "$target_key"
      then
        found=true
        printf "%s%s%s%s" "$target_key" "$IFS" "$value" "$IFS"
      else
        printf "%s%s%s%s" "$key" "$IFS" "$item" "$IFS"
      fi
    fi
    i=$((i + 1))
  done
  if ! "$found"
  then
    printf "%s%s%s%s" "$target_key" "$IFS" "$value" "$IFS"
  fi
}

# --------------------------------------------------------------------------
# IFS manipulation.
# --------------------------------------------------------------------------

# shellcheck disable=SC2034
readonly unit_sep=""

# shellcheck disable=SC2034
readonly us=""

# shellcheck disable=SC2034
readonly is1=""

# shellcheck disable=SC2034
readonly is2=""

# shellcheck disable=SC2034
readonly is3=""

# shellcheck disable=SC2034
readonly is4=""

ifs_newline() {
  IFS="$(printf '\n\r')"
}

newline() {
  printf '\n\r'
}

# To split path.
ifs_slashes() {
  printf "/\\"
}

ifs_default() {
  printf ' \t\n\r'
}

ifs_blank() {
  printf ' \t'
}

csv_ifss_6b672ac=

# Push IFS to the stack.
push_ifs() {
  if test "${IFS+set}" = set
  then
    csv_ifss_6b672ac="$(printf "%s" "$IFS" | base64),$csv_ifss_6b672ac"
  else
    csv_ifss_6b672ac=",$csv_ifss_6b672ac"
  fi
}

# Pop IFS from the stack.
pop_ifs() {
  if test -z "$csv_ifss_6b672ac"
  then
    return 1
  fi
  local v
  v="$(IFS=, ifsv_head "$csv_ifss_6b672ac")"
  csv_ifss_6b672ac="$(IFS=, ifsv_tail "$csv_ifss_6b672ac")"
  if test -n "$v"
  then
    IFS="$(printf "%s" "$v" | base64 -d)"
  else
    unset IFS
  fi
}

# --------------------------------------------------------------------------
# Utility functions.
# --------------------------------------------------------------------------s

unset shell_flags_c225b8f

# Backup the current shell flags.
backup_shell_flags() {
  if test "${shell_flags_c225b8f+set}" = set
  then
    # Fails to save the state if it was already saved. Does not nest.
    return 1
  fi
  shell_flags_c225b8f="$(set +o)"
}

# Restore the shell flags saved by `backup_shell_flags`.
restore_shell_flags() {
  if ! test "${shell_flags_c225b8f+set}" = set
  then
    # Fails to restore the state if it was not saved.
    return 1
  fi
  eval "$shell_flags_c225b8f"
  unset shell_flags_c225b8f
}

is_linux() {
  if test "$(uname -s)" = "Linux"
  then
    return 0
  fi
  return 1
}

# Executable file extension.
exe_ext() {
  if is_windows
  then
    echo ".exe"
  fi
}

is_bsd() {
  if stat -f "%z" . > /dev/null 2>&1
  then
    return 0
  fi
  return 1
}

is_darwin() {
  if test "$(uname -s)" = "Darwin"
  then
    return 0
  fi
  return 1
}

is_mac() {
  is_darwin
}

is_windows() {
  case "$(uname -s)" in
    (Windows_NT|CYGWIN*|MINGW*|MSYS*) return 0 ;;
    (*) return 1 ;;
  esac
}

# Busybox Ash shell on Windows sets $SHELL to provide the virtual executable path `/bin/sh`.
is_windows_busybox_shell() {
  if is_windows && test "${SHELL+SET}" = SET && test "$SHELL" = "/bin/sh" && "$SHELL" --help 2>&1 | grep -q "BusyBox"
  then
    return 0
  fi
  return 1
}

# Set the extra attributes of the file/directory.
set_path_attr() {
  local path="$1"
  local attribute="$2"
  local value="$3"
  if which xattr > /dev/null 2>&1
  then
    xattr -w "$attribute" "$value" "$path"
  elif which PowerShell > /dev/null 2>&1
  then
    # Run in the background because it takes much time to run.
    PowerShell -Command "Set-Content -Path '$path' -Stream '$attribute' -Value '$value'" &
  elif which attr > /dev/null 2>&1
  then
    attr -s "$attribute" -V "$value" "$path" >/dev/null 2>&1
  else
    echo "No command to set attribute: $attribute" >&2
    # exit 1
  fi
}

readonly psv_file_sharing_ignorance_attributes="com.dropbox.ignored|com.apple.fileprovider.ignore#P|"

# Set the file/directory to be ignored by file sharing such as Dropbox.
set_sync_ignored() {
  local path
  for path in "$@"
  do
    if ! test -e "$path"
    then
      continue
    fi
    push_ifs
    IFS='|'
    for file_sharing_ignorance_attribute in $psv_file_sharing_ignorance_attributes
    do
      set_path_attr "$path" "$file_sharing_ignorance_attribute" 1
    done
    pop_ifs
  done
}

# Create a directory and set it to be ignored by file sharing such as Dropbox.
mkdir_sync_ignored() {
  local path
  for path in "$@"
  do
    if test -d "$path"
    then
      continue
    fi
    mkdir -p "$path"
    push_ifs
    IFS='|'
    for attribute in $psv_file_sharing_ignorance_attributes
    do
      set_path_attr "$path" "$attribute" 1
    done
    pop_ifs
  done
}

# Set the file/directory to be ignored by file sharing such as Dropbox.
force_sync_ignored() {
  local path
  for path in "$@"
  do
    push_ifs
    IFS='|'
    for attribute in $psv_file_sharing_ignorance_attributes
    do
      set_path_attr "$path" "$attribute" 1
    done
    pop_ifs
  done
}

# Check if the file(s)/directory(s) is/are newer than the destination.
newer() {
  local found_than=false
  local dest=
  local arg
  for arg in "$@"
  do
    shift
    if test "$arg" = "--than"
    then
      found_than=true
    elif $found_than
    then
      dest="$arg"
    else
      set -- "$@" "$arg"
    fi
  done
  if test -z "$dest"
  then
    echo "No --than option" >&2
    exit 1
  fi
  if test "$#" -eq 0
  then
    echo "No source files" >&2
    exit 1
  fi
  # If the destination does not exist, it is considered newer than the destination.
  if ! test -e "$dest"
  then
    echo "Destination does not exist: $dest" >&2
    return 0
  fi
  # If the destination is a directory, the newest file in the directory is used.
  if test -d "$dest"
  then
    if is_bsd
    then
      dest="$(find "$dest" -type f -exec stat -l -t "%F %T" {} \+ | cut -d' ' -f6- | sort -n | tail -1 | cut -d' ' -f3)"
    else
      dest="$(find "$dest" -type f -exec stat -Lc '%Y %n' {} \+ | sort -n | tail -1 | cut -d' ' -f2)"
    fi
  fi
  if test -z "$dest"
  then
    echo "No destination file" >&2
    return 0
  fi
  test -n "$(find "$@" -newer "$dest" 2> /dev/null)"
}

# Busybox sh seems to fail to detect proper executable if a file without executable extension exists in the same directory.
cross_exec() {
  cleanup
  if ! is_windows
  then
    exec "$@"
  fi
  if ! test "${1+set}" = set
  then
    exit 1
  fi
  local cmd_path="$1"
  shift
  if type "$cmd_path.exe" >/dev/null 2>&1
  then
    exec "$cmd_path.exe" "$@"
  fi
  if type "$cmd_path.cmd" >/dev/null 2>&1
  then
    exec "$cmd_path.cmd" "$@"
  fi
  if type "$cmd_path.bat" >/dev/null 2>&1
  then
    exec "$cmd_path.bat" "$@"
  fi
  exec "$cmd_path" "$@"
}

# Run a command preferring the Windows version if available.
cross_run() {
  if ! is_windows
  then
    "$@"
    return $?
  fi
  local cmd="$1"
  shift
  local ext
  for ext in .exe .cmd .bat
  do
    if type "$cmd$ext" > /dev/null 2>&1
    then
      "$cmd$ext" "$@"
      return $?
    fi
  done
  "$cmd" "$@"
}

# Ensure an argument for an option.
ensure_opt_arg() {
  if test -z "$2"
  then
    echo "No argument for option --$1." >&2
    usage
    exit 1
  fi
  echo "$2"
}

# Open a URL in a browser.
open_browser() {
  case "$(uname -s)" in
    (Linux)
      xdg-open "$1" ;;
    (Darwin)
      open "$1" ;;
    (Windows_NT)
      PowerShell -Command "Start-Process '$1'" ;;
    (*)
      echo "Unsupported OS: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

# Ensure a package is installed and return the command and arguments separated by tabs.
install_pkg_cmd_tabsep_args() {
  local cmd_name=
  local winget_id=
  local win_cmd_path=
  local scoop_id=
  local brew_id=
  local brew_cmd_path=
  unset OPTIND; while getopts nc:p:b:P:w:s:-: OPT
  do
    if test "$OPT" = "-"
    then
      OPT="${OPTARG%%=*}"
      # shellcheck disable=SC2030
      OPTARG="${OPTARG#"$OPT"}"
      OPTARG="${OPTARG#=}"
    fi
    case "$OPT" in
      (b|brew-id) brew_id="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (B|brew-cmd-path) brew_cmd_path="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (c|cmd) cmd_name="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (w|winget-id) winget_id="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (p|winget-cmd-path) win_cmd_path="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (s|scoop-id) scoop_id="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (\?) exit 1;;
      (*) echo "Unexpected option: $OPT" >&2; exit 1;;
    esac
  done
  shift $((OPTIND-1))

  local cmd_path="$cmd_name"
  if is_windows
  then
    if test -n "$scoop_id"
    then
      if ! type scoop > /dev/null 2>&1
      then
        powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser; Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression" 1>&2
      fi
      cmd_path="$HOME"/scoop/shims/ghcup
      if ! type "$cmd_path" > /dev/null 2>&1
      then
        scoop install "$scoop_id" 1>&2
      fi
    elif test -n "$winget_id"
    then
      cmd_path="$win_cmd_path"
      if ! type "$cmd_path" > /dev/null 2>&1
      then
        winget install --accept-package-agreements --accept-source-agreements --exact --id "$winget_id" 2>&1
      fi
    else
      echo "No package ID for Windows specified." >&2
      exit 1
    fi
  elif is_darwin
  then
    if test -n "$brew_id"
    then
      if test -n "$brew_cmd_path"
      then
        cmd_path="$brew_cmd_path"
      fi
      if ! type "$cmd_path" > /dev/null 2>&1
      then
        brew install "$brew_id" 1>&2
      fi
    else
      echo "No package ID for macOS specified." >&2
      exit 1
    fi
  fi
  if which "$cmd_path" > /dev/null 2>&1
  then
    printf "%s\t" "$(which "$cmd_path")"
  else
    echo "Command not installed: $cmd_path" >&2
    exit 1
  fi
  local arg
  for arg in "$@"
  do
    printf "%s\t" "$arg"
  done
}

install_pkg_cmd() {
  push_ifs
  IFS="$(printf "\t")"
  # shellcheck disable=SC2046
  set -- $(install_pkg_cmd_tabsep_args "$@")
  pop_ifs
  echo "$1"
}

run_pkg_cmd() { # Run a command after ensuring it is installed.
  push_ifs
  IFS="$(printf "\t")"
  # shellcheck disable=SC2046
  set -- $(install_pkg_cmd_tabsep_args "$@")
  pop_ifs
  # echo 01d637b "$@" >&2
  cross_run "$@"
}

load() {
  if ! test -r "$1"
  then
    return 0
  fi
  IFS=
  while read -r line_0e9c96b
  do
    key_07bde23="$(echo "$line_0e9c96b" | sed -E -n -e 's/^([a-zA-Z_][[:alnum:]_]*)=.*$/\1/p')"
    if test -z "$key_07bde23"
    then
      continue
    fi
    val_5d77cea="$(eval "echo \"\${$key_07bde23:=}\"")"
    # echo bcff3d2 "$val" >&2
    if test -n "$val_5d77cea"
    then
      continue
    fi
    eval "$line_0e9c96b"
  done < "$1"
  unset IFS
}

load_env() { # Load environment variables.
  if test "${APP_ENV+set}" = set
  then
    load "$SCRIPT_DIR"/.env."$APP_ENV".dynamic
    load "$SCRIPT_DIR"/.env."$APP_ENV".local
  fi
  if test "${APP_SENV+set}" != set || test "${APP_SENV}" != "test"
  then
    load "$SCRIPT_DIR"/.env.dynamic
    load "$SCRIPT_DIR"/.env.local
  fi
  if test "${APP_ENV+set}" = set
  then
    load "$SCRIPT_DIR"/.env."$APP_ENV"
  fi
  # shellcheck disable=SC1091
  load "$SCRIPT_DIR"/.env
}

# Get a key from the user without echoing.
get_key() {
  # Dash does not support `-s` option.
  if is_linux
  then
    stty -icanon -echo
    dd bs=1 count=1 2>/dev/null
    stty icanon echo
    return
  fi
  local key
  # Bash POSIX and BusyBox ash provides `-s` (silent mode) option.
  # shellcheck disable=SC3045
  read -rsn1 key
  echo "$key"
}

memoize() {
  local cache_file_name="$1"
  shift
  if ! test -r "$(temp_dir_path)/$cache_file_name"
  then
    "$@" > "$(temp_dir_path)/$cache_file_name"
  fi
  cat "$(temp_dir_path)/$cache_file_name"
}

memoize_silent() (
  local cache_file_name="$1"
  shift
  if ! test -r "$(temp_dir_path)/$cache_file_name"
  then
    "$@" > "$(temp_dir_path)/$cache_file_name" 2> /dev/null
  fi
  cat "$(temp_dir_path)/$cache_file_name"
)

first_call() {
  if eval "test \"\${guard_$1+set}\" = set"
  then
    return 1
  fi
  eval "guard_$1=x"
}

underline() {
  printf '\033[4m%s\033[0m' "$1"
}

bold() {
  printf '\033[1m%s\033[0m' "$1"
}

enclose_with_brackets() {
  printf '[%s]' "$1"
}

# Emphasize text.
emph() {
  if test -z "$1"
  then
    return
  fi
  if is_windows
  then
    enclose_with_brackets "$(bold "$(underline "$1")")"
  else
    bold "$(underline "$1")"
  fi
}

# Sort version strings.
# Version strings which are composed of three parts are sorted considering the third part as a patch version.
# Long option `--version-sort` is specific to BSD sort(1).
# shellcheck disable=SC2120
sort_version() {
  sed -E -e '/-/! { s/^([^.]+(\.[^.]+){2})$/\1_/; }' -e 's/-patch/_patch/' | sort -V "$@" | sed -e 's/_$//' -e 's/_patch/-patch/'
}

# Check if the version is greater than the specified version.
version_gt() {
  test "$(printf '%s\n' "$@" | sort_version | head -n 1)" != "$1"
}

version_ge() {
  test "$(printf '%s\n' "$@" | sort_version -r | head -n 1)" = "$1"
}

# Left/Right-Word-Boundary regex incompatible with BSD sed // re_format(7) https://man.freebsd.org/cgi/man.cgi?query=re_format&sektion=7
lwb='\<'
rwb='\>'
# shellcheck disable=SC2034
if is_bsd
then
  lwb='[[:<:]]'
  rwb='[[:>:]]'
fi

# Print a menu item with emphasis if a character is prefixed with "&".
menu_item() {
  echo "$1" | sed -E \
    -e 's/&&/@ampersand_ff37f3a@/g' \
    -e "s/^([^&]*)(&([^& ]))?(.*)$/\1${is1}\3${is1}\4/" \
  | (
    IFS="$is1" read -r pre char_to_emph post
    if test -n "$char_to_emph"
    then
      printf "%s%s%s" "$pre" "$(emph "$char_to_emph")" "$post"
    else
      printf "%s" "$pre"
    fi
  ) | sed -E -e 's/@ampersand_ff37f3a@/\&/g'
  echo
}

# Print a menu
menu() {
  echo
  local arg
  for arg in "$@"
  do
    menu_item "$arg"
  done
}

# Sort in random order.
sort_random() {
  if type shuf > /dev/null 2>&1
  then
    shuf
  else
    sort -R
  fi
}

# Get the space-separated n-th (1-based) field.
field() (
  unset IFS
  # shellcheck disable=SC2046
  printf "%s\n" $(cat) | head -n "$1" | tail -n 1
)

# Mac does not have tac(1).
if ! type tac > /dev/null 2>&1
then
  tac() {
    tail -r
  }
fi

# --------------------------------------------------------------------------
# Main.
# --------------------------------------------------------------------------

# Original directory when the script is invoked.

ORIGINAL_DIR="$PWD"
export ORIGINAL_DIR

chdir_original() {
  cd "$ORIGINAL_DIR" || exit 1
}

# Directory in which the main script is located.

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
export SCRIPT_DIR

chdir_script() {
  cd "$SCRIPT_DIR" || exit 1
}

# Directory specified by the user with the `-d` option.

user_specified_directory=

chdir_user() {
  if test -n "$user_specified_directory"
  then
    cd "$user_specified_directory" || exit 1
  else
    chdir_original
  fi
}

# Check if the working directory is in the script directory.
in_script_dir() {
  echo "$PWD" | grep -q "^$SCRIPT_DIR"
}

# Create a temporary directory if required. BusyBox sh not supports -t.

_temp_dir_path_d4a4197="$(mktemp -d --dry-run)"

temp_dir_path() {
  if ! test -d "$_temp_dir_path_d4a4197"
  then
    mkdir -p "$_temp_dir_path_d4a4197"
  fi
  echo "$_temp_dir_path_d4a4197"
}

kill_children() {
  for i_519fa93 in $(seq 10)
  do
    kill "%$i_519fa93" > /dev/null 2>&1 || :
    wait "%$i_519fa93" > /dev/null 2>&1 || :
  done
}

csv_cleanup_handlers=

# Main cleanup handler.
cleanup_79d5d1d() {
  # Save the return code.
  rc=$?
  # On some systems, `kill` cannot detect the process if `jobs` is not called before it.
  if is_windows 
  then
    kill_children
  else 
    for i_519fa93 in $(jobs | tac | sed -E -e 's/^\[([0-9]+).*/\1/')
    do
      kill "%$i_519fa93"
      wait "%$i_519fa93" || :
    done
  fi
  # echo "Killed children." >&2

  rm -fr "$_temp_dir_path_d4a4197"
  # echo "Cleaned up temporary files." >&2

  if test "$rc" -ne 0
  then
    echo "Exiting with status $rc" >&2
    if type on_error > /dev/null 2>&1
    then
      on_error
    fi
  fi

  push_ifs
  IFS=,
  for cleanup_handler in $csv_cleanup_handlers
  do
    "$cleanup_handler"
  done
  pop_ifs

  exit "$rc"
}

# Add a cleanup handler, not replacing the existing ones.
add_cleanup_handler() {
  csv_cleanup_handlers="$csv_cleanup_handlers$1,"
}

# Verbose flag.

verbose_f26120b=false 

verbose() {
  "$verbose_f26120b"
}

psv_task_file_paths=

task_subcmds() ( # List subcommands.
  lines="$(
    (
      IFS="|"
      # shellcheck disable=SC2086
      sed -E -n -e 's/^subcmd_([[:alnum:]_]+)\(\) *[{(] *(# *(.*))?/\1 \3/p' $psv_task_file_paths
    ) | while read -r name desc
    do
      echo "$(echo "$name" | sed -E -e 's/__/:/g')" "$desc"
    done
    if type delegate_tasks >/dev/null 2>&1 && delegate_tasks subcmds >/dev/null 2>&1
    then
      delegate_tasks subcmds
    fi
  )"
  max_name_len="$(
    echo "$lines" \
    | while read -r name _
    do
      echo "${#name}"
    done \
    | sort -nr \
    | head -1
  )"
  echo "$lines" | while read -r name desc
  do
    printf "%-${max_name_len}s  %s\n" "$name" "$desc"
  done | sort
)

task_tasks() ( # List tasks.
  lines="$(
    (
      IFS="|"
      # shellcheck disable=SC2086
      sed -E -n -e 's/^task_([[:alnum:]_]+)\(\) *[{(] *(# *(.*))?/\1 \3/p' $psv_task_file_paths
    ) | while read -r name desc
    do
      echo "$(echo "$name" | sed -E -e 's/__/:/g')" "$desc"
    done
    if type delegate_tasks >/dev/null 2>&1 && delegate_tasks tasks >/dev/null 2>&1
    then
      delegate_tasks tasks
    fi
  )"
  max_name_len="$(
    echo "$lines" \
    | while read -r name _
    do
      echo "${#name}"
    done \
    | sort -nr \
    | head -1
  )"
  echo "$lines" | while read -r name desc
  do
    printf "%-${max_name_len}s  %s\n" "$name" "$desc"
  done | sort
)

usage() ( # Show help message.
  cat <<EOF
Usage:
  $ARG0BASE [options] <subcommand> [args...]
  $ARG0BASE [options] <task[arg1,arg2,...]> [tasks...]

Options:
  -d, --directory=<dir>  Change directory before running tasks.
  -h, --help             Display this help and exit.
  -v, --verbose          Verbose mode.

Subcommands:
$(task_subcmds | while IFS= read -r line; do echo "  $line"; done)

Tasks:
$(task_tasks | while IFS= read -r line; do echo "  $line"; done)
EOF
)

subcmd_exec() { # Execute a command in task.sh context.
  backup_shell_flags
  set +o errexit
  "$@"
  echo "Exit status: $?" >&2
  restore_shell_flags
}

run_pre_task() {
  if type pre_"$1" > /dev/null 2>&1
  then
    echo "Running pre-task for $1" >&2
    pre_"$1"
  fi
}

run_post_task() {
  if type post_"$1" > /dev/null 2>&1
  then
    echo "Running post-task for $1" >&2
    post_"$1"
  fi
}

main() {
  # Error exit if executed with unexpected shell.
  while true
  do
    # Bash
    test "${BASH+SET}" = SET && test -x "$BASH" && break
    # Busybox shell on Windows
    is_windows_busybox_shell && break
    # Check procfs for the shell.
    if test -e /proc/$$/exe
    then
      case "$(basename "$(readlink -f /proc/$$/exe)")" in
        (ash) break ;;
        (bash) break ;;
        (dash) break ;;
        (sh)
          if "$(readlink -f /proc/$$/exe)" --help 2>&1 | grep -q "BusyBox"
          then
            break
          fi
          ;;
        (*) ;;
      esac
    fi
    echo "Unexpected shell." >&2
    exit 1
  done

  # Set the cleanup handlers caller.
  trap cleanup_79d5d1d EXIT

  # Run in the script directory.
  chdir_script

  # Set the environment variables according to the script name.
  if test "${ARG0BASE+set}" = "set"
  then
    case "$ARG0BASE" in
      (task-*)
        env="${ARG0BASE#task-}"
        case "$env" in
          (dev|development)
            APP_ENV=development
            APP_SENV=dev
            ;;
          (prd|production)
            APP_ENV=production
            APP_SENV=prd
            ;;
          (*) echo "Unknown environment: $env" >&2; exit 1;;
        esac
        export APP_ENV APP_SENV
        ;;
      (*)
        ;;
    esac
  else
    # shellcheck disable=SC2034
    ARG0="$0"
    ARG0BASE="$(basename "$0")"
  fi

  # Load all the task files in the script directory.
  psv_task_file_paths="$(realpath "$0")|"
  for task_file_path in "$SCRIPT_DIR"/task_*.sh "$SCRIPT_DIR"/task-*.sh
  do
    if ! test -r "$task_file_path"
    then
      continue
    fi
    case "$(basename "$task_file_path")" in
      (task-dev.sh|task-prd.sh)
        continue
        ;;
    esac
    psv_task_file_paths="$psv_task_file_paths$task_file_path|"
    # echo Loading "$task_file_path" >&2
    # shellcheck disable=SC1090
    . "$task_file_path"
  done

  # Parse the command line arguments.
  shows_help=false
  skip_missing=false
  ignore_missing=false
  unset OPTIND; while getopts d:hvsi-: OPT
  do
    if test "$OPT" = "-"
    then
      # Extract long option name.
      # shellcheck disable=SC2031
      OPT="${OPTARG%%=*}"
      # Extract long option argument.
      # shellcheck disable=SC2031
      OPTARG="${OPTARG#"$OPT"}"
      OPTARG="${OPTARG#=}"
    fi
    case "$OPT" in
      (d|directory) user_specified_directory="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (h|help) shows_help=true;;
      (s|skip-missing) skip_missing=true;;
      (i|ignore-missing) ignore_missing=true;;
      (v|verbose) verbose_f26120b=true;;
      (\?) usage; exit 1;;
      (*) echo "Unexpected option: $OPT" >&2; exit 1;;
    esac
  done
  shift $((OPTIND-1))

  # Show help message and exit.
  if $shows_help || test "${1+set}" != "set"
  then
    usage
    exit 0
  fi

  # Execute the subcommand and exit.
  subcmd="$(echo "$1" | sed -r -e 's/:/__/g')"
  if type subcmd_"$subcmd" > /dev/null 2>&1
  then
    shift
    if alias subcmd_"$subcmd" > /dev/null 2>&1
    then
      # shellcheck disable=SC2294
      eval subcmd_"$subcmd" "$@"
      exit $?
    fi
    subcmd_"$subcmd" "$@"
    exit $?
  fi
  case "$subcmd" in
    (subcmd_*)
      if type "$subcmd" > /dev/null 2>&1
      then
        shift
        "$subcmd" "$@"
        exit $?
      fi
      ;;
  esac

  # Run tasks.
  for task_with_args in "$@"
  do
    task_name="$task_with_args"
    args=""
    case "$task_with_args" in
      (*\[*)
        task_name="${task_with_args%%\[*}"
        args="$(echo "$task_with_args" | sed -r -e 's/^.*\[//' -e 's/\]$//' -e 's/,/ /')"
        ;;
    esac
    task_name="$(echo "$task_name" | sed -r -e 's/:/__/g')"
    if type task_"$task_name" > /dev/null 2>&1
    then
      run_pre_task "task_$task_name"
      # shellcheck disable=SC2086
      task_"$task_name" $args
      run_post_task "task_$task_name"
      continue
    fi
    case "$task_name" in
      (task_*)
        run_pre_task "$task_name"
        # shellcheck disable=SC2086
        "$task_name" $args
        run_post_task "$task_name"
        continue
        ;;
    esac
    if type delegate_tasks > /dev/null 2>&1
    then
      verbose && echo "Delegating to delegate_tasks: $task_with_args" >&2
      if delegate_tasks "$@"
      then
        continue
      else
        if ! test $? -eq "$rc_delegate_task_not_found"
        then
          exit 1
        fi
      fi
    fi
    if ! $skip_missing
    then
      echo "Unknown task: $task_with_args" >&2
    fi
    if ! $skip_missing && ! $ignore_missing
    then
      exit 1
    fi
  done
}

# Run the main function if this script is executed as task runner.
if test "$(basename "$0")" = "task.sh"
then
  main "$@"
fi
