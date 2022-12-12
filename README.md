# VeeR EH1 RISC-V Core

This repository contains the VeeR EH1 design RTL.

## License

By contributing to this project, you agree that your contribution is governed by [Apache-2.0](LICENSE).  
Files under the [tools](tools/) directory may be available under a different license. Please review individual files for details.

## Directory Structure

    ├── configs                 # Configurations Dir
    │   └── snapshots           # Where generated configuration files are created
    ├── design                  # Design root dir
    │   ├── dbg                 # Debugger
    │   ├── dec                 # Decode, Registers and Exceptions
    │   ├── dmi                 # DMI block
    │   ├── exu                 # EXU (ALU/MUL/DIV)
    │   ├── ifu                 # Fetch & Branch Predictor
    │   ├── include             
    │   ├── lib
    │   └── lsu                 # Load/Store
    ├── docs
    ├── tools                   # Scripts/Makefiles
    └── testbench               # (Very) simple testbench
        ├── asm                 # Example test files
        └── hex                 # Canned demo hex files
 
## Dependencies

- Verilator **(4.102 or later)** must be installed on the system if running with verilator
- If adding/removing instructions, `espresso` must be installed (used by `tools/coredecode`)
- A RISC-V tool chain (based on gcc version 7.3 or higher) must be
installed so that it can be used to prepare RISC-V binaries to run.

## Quickstart guide

1. Clone the repository
1. Setup `RV_ROOT` to point to the path in your local filesystem
1. Determine your configuration {optional}
1. Run `make` with `tools/Makefile`

## Release Notes for this version

Please see [release notes](release-notes.md) for changes and bug fixes in this version of VeeR.

### Configurations

VeeR can be configured by running the `$RV_ROOT/configs/veer.config` script:

`% $RV_ROOT/configs/veer.config -h` for detailed help options

For example to build with a DCCM of size 64 Kb:  

`% $RV_ROOT/configs/veer.config -dccm_size=64`  

This will update the **default** snapshot in `$PWD/snapshots/default/` with parameters for a 64K DCCM.
To **unset** a parameter, add `-unset=PARAM` option to `veer.config`.

Add `-snapshot=dccm64`, for example, if you wish to name your build snapshot `dccm64` and refer to it during the build.  

There are four predefined target configurations: `default`, `default_ahb`, `default_pd`, `high_perf`  that can be selected via 
the `-target=name` option in `veer.config`.

This script derives the following consistent set of include files:

    snapshots/default
    ├── common_defines.vh                       # `defines for testbench or design
    ├── defines.h                               # #defines for C/assembly headers
    ├── pd_defines.vh                           # `defines for physical design
    ├── perl_configs.pl                         # Perl %configs hash for scripting
    ├── pic_map_auto.h                          # PIC memory map based on configure size
    └── whisper.json                            # JSON file for veer-iss

### Building a model

While in a work directory:

1. Set the `RV_ROOT` environment variable to the root of the VeeR directory structure.

   Example for bash shell: `export RV_ROOT=/path/to/veer`  
   Example for csh or its derivatives: `setenv RV_ROOT /path/to/veer`
    
1. Create your specific configuration

   (Skip if default is sufficient)  
   (Name your snapshot to distinguish it from the default. Without an explicit name, it will update/override the __default__ snapshot)

   For example if `mybuild` is the name for the snapshot: `$RV_ROOT/configs/veer.config [configuration options..] -snapshot=mybuild`  
    
   Snapshots are placed in the `./snapshots` directory

**Building an FPGA speed optimized model:**  
Use ``-fpga_optimize=1`` option in ``veer.config`` to build a model that removes clock gating logic from flop model so that the FPGA builds can run at higher speeds.
**This is now the default option for targets other than ``default_pd``.**

**Building a Power optimized model (ASIC flows):**  
Use ``-fpga_optimize=0`` option in ``veer.config`` to build a model that **enables** clock gating logic into the flop model so that the ASIC flows get a better power footprint.
**This is now the default option for target``default_pd``.**

### Running RTL simulations

To run a simple Hello World program in Verilator, use:

```shell
make -f $RV_ROOT/tools/Makefile
```

This command will build a Verilator model of VeeR EH1 with an AXI bus, and
execute a short sequence of instructions that writes out "HELLO WORLD"
to the bus.

    
The simulation produces output on the screen like:  

```
VerilatorTB: Start of sim

-------------------------
Hello World from VeeR EH1
-------------------------

Finished : minstret = 443, mcycle = 1372
See "exec.log" for execution trace with register updates..

TEST_PASSED
```

The simulation generates following files:

* `console.log` contains what the cpu writes to the console address of `0xd0580000`.
* `exec.log` shows instruction trace with GPR updates.
* `trace_port.csv` contains a log of the trace port. 

When `debug=1` is provided, a vcd file `sim.vcd` is created and can be browsed by 
gtkwave or similar waveform viewers.
  
You can re-execute the simulation using: `./obj_dir/Vtb_top` or `make -f $RV_ROOT/tools/Makefile verilator`.

The simulation run/build command has the following generic form:

```shell
make -f $RV_ROOT/tools/Makefile [<simulator>] [debug=1] [snapshot=<snapshot>] [target=<target>] [TEST=<test>] [TEST_DIR=<path_to_test_dir>] [CONF_PARAMS=<veer.config option>]
```

where:

* `<simulator>` - can be `verilator` (by default) `irun` - Cadence xrun, `vcs` - Synopsys VCS, `vlog` - Mentor Questa, `riviera` - Aldec Riviera-PRO; if not provided, `make` cleans the work directory, builds a Verilator executable and runs a test.
* `debug=1` - allows VCD generation for verilator, VCS and Riviera-PRO and SHM waves for irun option.
* `<target>` - predefined CPU configurations `default` (by default), `default_ahb`, `default_pd`, `high_perf`
* `TEST` - allows to run a C (<test>.c) or assembly (<test>.s) test, hello_world is run by default 
* `TEST_DIR` - alternative to test source directory `testbench/asm`
* `<snapshot>` - run and build executable model of custom CPU configuration, remember to provide `snapshot` argument for runs on custom configurations.
* `CONF_PARAMS` - configuration parameter for veer.config, ex: `CONF_PARAMS=-unset=dccm_enable` to build with no DCCM

Example:
     
```shell
make -f $RV_ROOT/tools/Makefile verilator TEST=cmark
```

will simulate the `testbench/asm/cmark.c` program with Verilator on the default target.

If you want to compile a test only, you can run:

```shell
make -f $RV_ROOT/tools/Makefile program.hex TEST=<test> [TEST_DIR=/path/to/dir]
```

The Makefile uses `$RV_ROOT/testbench/link.ld` file by default to build test executable.  
User can provide test specific linker file in form `<test_name>.ld` to build the test executable,
 in the same directory with the test source.

User also can create a test specific makefile in form `<test_name>.makefile`, contaning building instructions
how to create a `program.hex` file used by the simulation. The private Makefile should be in the same directory
as the test source.  
*(the `program.hex` file is loaded to instruction and data bus memory slaves and
optionally to DCCM/ICCM at the beginning of simulation)*.

Note: You may need to delete `program.hex` file from work directory, when running a new test.

The  `$RV_ROOT/testbench/asm` directory contains thefollowing tests ready to simulate:

* `hello_world` - default test to run, prints Hello World message to screen and `console.log`
* `hello_world_dccm` - same as above, but takes the string from preloaded DCCM.
* `hello_world_iccm` - same as above, but CPU copies the code from external memory to ICCM via AXI LSU to DMA bridge and then jumps there. The test runs only on CPU configurations with ICCM and AXI bus.
* `cmark` - coremark benchmark running with code and data in external memories
* `cmark_dccm` - same as above, running data and stack from DCCM (faster)
* `cmark_iccm` - same as above, but with code preloaded to iccm - runs only on CPU with ICCM; use the `CONF_PARAMS=-set=iccm_enable` argument to `make` to build CPU with ICCM
* `dhry` - dhrystone benchmark - example of multi source files program

The `$RV_ROOT/testbench/hex` directory contains precompiled hex files of the tests, ready for simulation in case RISC-V SW tools are not installed.