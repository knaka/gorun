#!/bin/sh
test "${guard_305cf7f+set}" = set && return 0; guard_305cf7f=-
set -o nounset -o errexit

. ./task.sh
. ./task-go.lib.sh
. ./task-embedded-go.lib.sh

task_shims__gen() { # Generate go-embedded bootstrap scripts.
  local out_sh=gorun
  subcmd_go__embedded__sh__gen \
    --url="https://raw.githubusercontent.com/knaka/gorun/refs/heads/main/$out_sh" \
    --main-go=./gorun.go \
    --template-sh=./templates/embedded-go \
    --out-sh=./"$out_sh"
  local out_cmd=gorun.cmd
  subcmd_go__embedded__cmd__gen \
    --url="https://raw.githubusercontent.com/knaka/gorun/refs/heads/main/$out_cmd" \
    --main-go=./gorun.go \
    --template-cmd=./templates/embedded-go.cmd \
    --out-cmd=./"$out_cmd"
}

task_gen() { # Generate files.
  task_shims__gen
}
