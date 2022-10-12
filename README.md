# runasm

Build and run a single-file aarch64 assembly program.

## Usage

Run `runasm.sh` with `-h` or `--help` for usage.
Examples are below.

## Obtaining

You can clone the repository or just download the script itself.
I suggest you place this in a directory on your PATH so you can access it everywhere.

Remember to make the script executable: `chmod +x /path/to/runasm.sh`

## Examples

For these examples, suppose there is a project in the current directory and a project in another directory, which we will call `/home/example/demo_project`.
A project directory should contain exactly one `.s` file. If it contains more than one, the build will fail.

Run the project in the current directory:

- `runasm.sh`
- `runasm.sh .`

Run the project in a specific directory:

- `runasm.sh /home/example/demo_project`

Run the project in the current directory with gdb:

- `runasm.sh -g`
- `runasm.sh . -g`

Run the project in a specific directory with gdb:

- `runasm.sh /home/example/demo_project -g`

Run a project, linking libc (support for printf):

- `runasm.sh -lc`

## Bug reporting

Before reporting a bug, make sure you're running the latest version.
If the bug persists, you can open an issue. Please include what version you're running in the issue.

## Known issues

- When debugging a dynamically linked executable, gdb will say "unable to find dynamic linker breakpoint function".
  - Workaround: type `list` to see your program, then debug as usual. When debugging a call to a linked function (such as `printf` or `fflush`), step over the call.
