#!/bin/sh
test "${guard_54039c5+set}" = set && return 0; guard_54039c5=-

. ./task.sh

subcmd_go__embedded__sh__gen() { # Generate a shell script with embedded Go code.
  first_call 902b3c5 || return 0

  local main_go=
  local template_sh=
  local out_sh=
  local url=

  unset OPTIND; while getopts u:-: OPT
  do
    if test "$OPT" = "-"
    then
      OPT="${OPTARG%%=*}"
      # shellcheck disable=SC2030
      OPTARG="${OPTARG#"$OPT"}"
      OPTARG="${OPTARG#=}"
    fi
    case "$OPT" in
      (main-go) main_go="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (template-sh) template_sh="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (out-sh) out_sh="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (u|url) url="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (\?) exit 1;;
      (*) echo "Unexpected option: $OPT" >&2; exit 1;;
    esac
  done
  shift $((OPTIND-1))

  if test -z "$main_go" || test -z "$template_sh" || test -z "$out_sh"
  then
    echo "Missing required options" >&2
    return 1
  fi

  if ! newer "$main_go" "$template_sh" --than "$out_sh"
  then
    echo "No need to update $out_sh" >&2
    return 0
  fi

  # shellcheck disable=SC2046
  line_num_start_marker="$(IFS=:; printf "%s\n" $(grep -E -n "^.+EMBED_FAA58B3" "$template_sh") | head -n 1)"
  # shellcheck disable=SC2046
  line_num_end_marker="$(IFS=:; printf "%s\n" $(grep -E -n "^EMBED_FAA58B3" "$template_sh") | head -n 1)"

  head -n "$line_num_start_marker" < "$template_sh" | (
    if test -n "$url"
    then
      sed -E -e "s@https://raw.githubusercontent.com/.*@${url}@"
    else
      cat
    fi
  ) >"$out_sh"
  cat "$main_go" >>"$out_sh"
  tail -n +"$line_num_end_marker" < "$template_sh" >>"$out_sh"

  chmod 0755 "$out_sh"
}

subcmd_go__embedded__cmd__gen() {
  first_call 645592d || return 0

  local main_go=
  local template_cmd=
  local out_cmd=
  local url=

  unset OPTIND; while getopts u:-: OPT
  do
    if test "$OPT" = "-"
    then
      OPT="${OPTARG%%=*}"
      # shellcheck disable=SC2030
      OPTARG="${OPTARG#"$OPT"}"
      OPTARG="${OPTARG#=}"
    fi
    case "$OPT" in
      (main-go) main_go="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (template-cmd) template_cmd="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (out-cmd) out_cmd="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (u|url) url="$(ensure_opt_arg "$OPT" "$OPTARG")";;
      (\?) exit 1;;
      (*) echo "Unexpected option: $OPT" >&2; exit 1;;
    esac
  done
  shift $((OPTIND-1))

  if test -z "$main_go" || test -z "$template_cmd" || test -z "$out_cmd"
  then
    echo "Missing required options" >&2
    return 1
  fi

  if ! newer "$main_go" "$template_cmd" --than "$out_cmd"
  then
    echo "No need to update $out_cmd" >&2
    return 0
  fi

  # shellcheck disable=SC2046
  line_num_marker_label="$(IFS=:; printf "%s\n" $(grep -E -n "^:embed_53c8fd5" "$template_cmd") | head -n 1)"
  head -n "$line_num_marker_label" <"$template_cmd" | (
    if test -n "$url"
    then
      sed -E -e "s@https://raw.githubusercontent.com/.*@${url}@"
    else
      cat
    fi
  ) >"$out_cmd"
  cat "$main_go" >>"$out_cmd"
}
