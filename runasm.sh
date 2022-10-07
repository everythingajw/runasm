#!/bin/bash

# ***************************************************************************************** #
# Description: compile, link, and run a single-file assembly program 
# Author:      Anthony (AJ) Webster
# Date:        October 4, 2022
# Version:     1.0.0
# License:     MIT License
# 
# Copyright (c) 2022 Anthony Webster
# 
# Permission is hereby granted, free of charge, to any person obtaining a 
# copy of this software and associated documentation files (the "Software"), 
# to deal in the Software without restriction, including without limitation 
# the rights to use, copy, modify, merge, publish, distribute, sublicense, 
# and/or sell copies of the Software, and to permit persons to whom the 
# Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included 
# in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR 
# IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# ***************************************************************************************** #

# Colors
declare -rg COLOR_OFF='\033[0m'
declare -rg BLACK='\033[0;30m'
declare -rg RED='\033[0;31m'
declare -rg GREEN='\033[0;32m'
declare -rg YELLOW='\033[0;33m'
declare -rg BLUE='\033[0;34m'
declare -rg PURPLE='\033[0;35m'
declare -rg CYAN='\033[0;36m'
declare -rg WHITE='\033[0;37m'

# MAKEFILE_NAME='build_asm.mak'
MAKEFILE_NAME="$(mktemp)"
declare -rg MAKEFILE_NAME
declare -rg QEMU_PORT=27182

on_exit () {
    info "Cleaning up..."

    # Only run the cleanup recipe if the makefile exists.
    # run_make will crash and burn if the makefile does not exist.
    if [ -f "$MAKEFILE_NAME" ]; then 
        run_make clean
    else 
        warning "Makefile does not exist; cannot run make clean"
    fi

    for pid in $(jobs -p | tail -n +1); do
        echo "Killing background job $pid"

        # It's entirely possible that, between the time of getting all the background jobs
        # and actually killing those jobs, the process has already terminated. Thus, we kill
        # nothing and kill returns an error. We'll just ignore this since we already have
        # what we wanted (the process has died).
        kill -9 "$pid" 2> /dev/null || true
    done

    if [ -f "$MAKEFILE_NAME" ]; then
        rm -fv "$MAKEFILE_NAME"
    else
        warning "Makefile does not exist; not removing."
    fi

    info "Leaving project directory"
    if ! cd - > /dev/null 2>&1; then
        warning "Failed to leave project directory"
    fi
}

info () {
    printf "${GREEN}INFO: %s${COLOR_OFF}\n" "$*"
}

warn () {
    printf "${YELLOW}WARNING: %s${COLOR_OFF}\n" "$*" >&2
}

error () {
    printf "${RED}ERROR: %s${COLOR_OFF}\n" "$*" >&2
}

die () {
    local code="$1"
    shift
    # Only show a message if we have one
    [ $# -gt 0 ] && error "$@"
    exit "$code"
}

extract_makefile () {
    sed '0,/^##section:MAKEFILE##$/d' "$0" > "$MAKEFILE_NAME" || die 1 "Failed to extract makefile"
    info "Makefile extracted to $MAKEFILE_NAME"
}

run_make () {
    [ ! -f "$MAKEFILE_NAME" ] && die 2 "Makefile '$MAKEFILE_NAME' not found (was it extracted?)"
    local target="$1"
    shift
    local makeargs=( -f "$MAKEFILE_NAME" "$target" )

    # Make *loves* to complain about blank arguments instead of just ignoring them. Only pass the non-zero length ones.
    for arg in "$@"; do
        [ -n "$arg" ] && local makeargs+=( "$arg" )
    done

    make "${makeargs[@]}"
}

get_exe_name () {
    # Assume that, since we've probably already run make, we'll only have one .s file
    local asm_file
    asm_file="$(ls ./*.s)"
    echo "${asm_file%.*}"
}

start_qemu () {
    local elf_path=/usr/aarch64-linux-gnu/
    if [ -z "$run_gdb" ]; then
        info "Running"
        qemu-aarch64 -L "$elf_path" "./$project_exe_name"
        info "Program exited with code $?"
    else 
        info "Starting qemu-aarch64 on port $QEMU_PORT"
        qemu-aarch64 -L "$elf_path" -g "${QEMU_PORT}" "$project_exe_name" &
        sleep 1
    fi
}

start_gdb () {
# gdb-multiarch --nh -q ./lab5 \
#     -ex 'set disassemble-next-line on'\
#     -ex 'target remote :27182'\
#     -ex 'set solib-search-path
# /usr/aarch64-linux-gnu-lib/'\
#     -ex 'layout regs'

    if [ -z "$gdb_new_window" ] || [ -z "$terminal_emulator" ]; then
        gdb-multiarch -nh -q \
            "$project_exe_name" \
            -ex 'layout regs' \
            -ex 'list' \
            -ex 'set disassemble-next-line on' \
            -ex "target remote localhost:$QEMU_PORT" \
            -ex 'set solib-search-path /usr/aarch64-linux-gnu-lib/'
        # gdb-multiarch --nh -q -ex 'set disassemble-next-line on' -ex "target remote localhost:$QEMU_PORT" -ex 'set solib-search-path /usr/aarch64-linux-gnu-lib/' -ex 'layout regs' -ex "file $program_exe_name"
        # gdb-multiarch --nh -q "$project_exe_name" -ex 'set disassemble-next-line on' -ex "target remote localhost:$QEMU_PORT" -ex 'set solib-search-path /usr/aarch64-linux-gnu-lib/' -ex 'layout regs'

    else
        # This is kind of gross. But I can do this or fight with escaping quotes. I'll choose this.
        local gdb_args="-nh -q"
        local gdb_args="${gdb_args} './$project_exe_name'"
        local gdb_args="${gdb_args} -ex 'layout regs'"
        local gdb_args="${gdb_args} -ex 'list'"
        local gdb_args="${gdb_args} -ex 'set disassemble-next-line on'"
        local gdb_args="${gdb_args} -ex 'target remote localhost:$QEMU_PORT'"
        local gdb_args="${gdb_args} -ex 'set solib-search-path /usr/aarch64-linux-gnu-lib/'"

        local gdb_cmd="gdb-multiarch $gdb_args"

        case "$terminal_emulator" in
            konsole)
                konsole -e bash -c "exec $gdb_cmd" ;;
            gnome-terminal)
                die 4 "Internal error! gnome-terminal is not supported for launching gdb in a new window; this should've been handled earlier."
                gnome-terminal -e -- bash -c "exec $gdb_cmd" ;;
            xterm) 
                xterm -e -- bash -c "exec $gdb_cmd" ;;
            *) die 10 "Terminal emulator '$terminal_emulator' not supported" ;;
        esac
    fi
}

usage () {
    cat <<EOF
Usage: $(basename -- "$0") [project dir] [options]
Compile, link, and run a single-file assembly program.

Options:
    [project dir]       The directory containing the assembly project. If not 
                        specified, the current directory is assumed. If the 
                        directory starts with '-' (such as '-sample'), further qualify
                        the path (e.g. '-sample' becomes './-sample' or '/home/user/-sample').
    -g, --gdb           Run gdb
    -w, --window-gdb    Run gdb in a new terminal window (has no effect without -g)
                        This option is not supported if using gnome-terminal.
    -h, --help          Show this help and exit
    --examples          Show a quick how-to with examples
    --version           Show version information and exit
EOF
    exit 0
}

examples () {
    local exe
    exe="$(basename -- "$0")"
    local demo_dir='/home/example/demo_project'
    cat <<EOF
For these examples, suppose there is a project in the current directory
and a project in another directory, which we will call /home/example/demo_project.

A project directory should contain exactly one .s file. If it contains 
more than one, the build will fail.

Run the project in the current directory:
    $exe
    $exe .

Run the project in a specific directory:
    $exe $demo_dir

Run the project in the current directory with gdb:
    $exe -g
    $exe . -g

Run the project in a specific directory with gdb:
    $exe $demo_dir -g
EOF
    exit 0
}

version () {
    cat <<EOF
runasm version 1.0.0
Copyright (c) 2022 Anthony Webster
Licensed under the MIT License: https://spdx.org/licenses/MIT.html
EOF
    exit 0
}

# Please cause errors if a variable is unset. Please.
set -u

project_dir='.'

if [ $# -ge 1 ] && [[ ! "$1" =~ - ]]; then
    project_dir="$1"
    shift
fi

run_gdb=''
gdb_new_window=''
valid_opts='1'
invalid_args=()
for arg in "$@"; do
    case "$arg" in
        -g|--gdb) run_gdb='y' ;;
        -w|--window-gdb) gdb_new_window='y' ;;
        -h|--help) usage ;;
        --examples) examples ;;
        --version) version ;;
        *) invalid_args+=("$arg") ;;
    esac
done

# 0 means the options were not valid
if [ "$valid_opts" = '0' ]; then
    for arg in "${invalid_args[@]}"; do
        error "Invalid argument '$arg'"
    done
    die 1 "Invalid arguments."
fi

info "Entering project directory $project_dir"
cd "$project_dir" || die 1 "Cannot enter project directory"

# Don't set trap until after initialization phase
trap on_exit EXIT

info "Extracting makefile"
extract_makefile

info "Building project"
make_build_opts=
[ -n "$run_gdb" ] && make_build_opts=('DEBUG=y')
run_make build "${make_build_opts[@]}" || die $? "make failed with exit code $?"

project_exe_name="$(get_exe_name)"

which_quiet () {
    which "$@" > /dev/null 2>&1
}

# Find terminal emulator to use
if which_quiet konsole; then
    terminal_emulator=konsole
elif which_quiet gnome-terminal; then
    #terminal_emulator=gnome-terminal

    # gnome-terminal got rid of --disable-factory, which is a problem since we can't
    # launch it and wait for that terminal to close. So in this case, we'll launch
    # in the same window.

    warning "gnome-terminal is not currently supported for running in a separate window."
    warning "gdb will be launched in the current terminal."

    terminal_emulator=''
elif which_quiet xterm; then
    terminal_emulator=xterm
else 
    # Can't find a terminal emulator. We'll fallback to running in the current window.
    warn "No terminal emulator found. Running in current window instead."
    terminal_emulator=''
fi

start_qemu
[ -n "$run_gdb" ] && start_gdb

exit 0

##section:MAKEFILE##
target_file = $(wildcard *.s)
object_file = $(patsubst %.s,%.o,$(target_file))
exe_file    = $(patsubst %.o,%,$(object_file))
#link_opts   = -lc

debug_flags = 
ifdef DEBUG
	debug_flags = -g
endif

.PHONY: check_file_count

all: compile link

check_file_count:
ifneq "$(words $(target_file))" '1'
	$(error Expected 1 .s file, got $(words $(target_file)))
endif

compile: check_file_count
#ifdef DEBUG
#	@echo 'INFO: Debug mode on'
#endif
	aarch64-linux-gnu-as $(debug_flags) $(target_file) -o $(object_file)

link: compile
	aarch64-linux-gnu-ld $(debug_flags) $(object_file) -o $(exe_file) $(link_opts)
	@file $(exe_file)
	rm -f $(object_file)

build: compile link

clean:
	rm -f $(object_file) $(exe_file)
