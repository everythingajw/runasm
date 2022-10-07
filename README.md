# runasm

Run a single-file aarch64 assembly program.

## Usage

Run `runasm.sh` with `-h` or `--help` for usage.

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
