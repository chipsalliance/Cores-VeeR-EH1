# SweRV RISC-V Core<sup>TM</sup> 1.3 from Western Digital

This repository contains the SweRV Core<sup>TM</sup> 1.3 design RTL. The previous version can be found in [branch 1.2.](https://github.com/chipsalliance/Cores-SweRV/tree/branch1.2)
The SweRV 1 series provides a 32-bit, machine-mode only, implementation of the RISC-V ISA including options I (base integer), M (multiply/divide) and C (compressed instructions from I and M).

## License

By contributing to this project, you agree that your contribution is governed by [Apache-2.0](LICENSE).  
Files under the [tools](tools/) directory may be available under a different license. Please review individual file for details.

## Directory Structure

    ├── configs                 # Configurations Dir
    │   └── snapshots           # Where generated configuration files are created
    ├── design                  # Design root dir
    │   ├── dbg                 #   Debugger
    │   ├── dec                 #   Decode, Registers and Exceptions
    │   ├── dmi                 #   DMI block
    │   ├── exu                 #   EXU (ALU/MUL/DIV)
    │   ├── ifu                 #   Fetch & Branch Prediction
    │   ├── include             
    │   ├── lib
    │   └── lsu                 #   Load/Store
    ├── docs
    ├── tools                   # Scripts/Makefiles
    └── testbench               # (Very) simple testbench
        ├── asm                 #   Example assembly files
        └── hex                 #   Canned demo hex files
 
## Dependencies

- Verilator **(3.926 or later)** must be installed on the system
- If adding/removing instructions, espresso must be installed. Espresso is a logic minimization tool used in *tools/coredecode*.

## Quickstart guide
1. Clone the repository
1. Setup RV_ROOT to point to the path in your local filesystem
1. Determine your configuration {optional}
1. Run make with tools/Makefile

## Release Notes for this version
Please see [release notes](release-notes.md) for changes and bug fixes in this version of SweRV

### Configurations

SweRV can be configured by running the `$RV_ROOT/configs/swerv.config` script:

`% $RV_ROOT/configs/swerv.config -h` for detailed help options

For example to build with a DCCM of size 64 :  

`% $RV_ROOT/configs/swerv.config -dccm_size=64`  

This will update the **default** snapshot in $RV_ROOT/configs/snapshots/default/ with parameters for a 64K DCCM.  

Add `-snapshot=dccm64`, for example, if you wish to name your build snapshot *dccm64* and refer to it during the build.  

This script derives the following consistent set of include files :  

    $RV_ROOT/configs/snapshots/default
    ├── common_defines.vh                       # `defines for testbench or design
    ├── defines.h                               # #defines for C/assembly headers
    ├── pd_defines.vh                           # `defines for physical design
    ├── perl_configs.pl                         # Perl %configs hash for scripting
    ├── pic_ctrl_verilator_unroll.sv            # Unrolled verilog based on PIC size
    ├── pic_map_auto.h                          # PIC memory map based on configure size
    └── whisper.json                            # JSON file for swerv-iss



### Building a model
1. Set the RV_ROOT environment variable to the root of the SweRV directory structure  

    `RV_ROOT = /path/to/swerv`  
    `export RV_ROOT`

1. Create your configuration  

    *(Skip if default is sufficient)*  
    *(Name your snapshot to distinguish it from the default. Without an explicit name, it will update/override the **default** snapshot)*  
    `$RV_ROOT/configs/swerv.config [configuration options..] -snapshot=mybuild`  

    Snapshots are placed in `$RV_ROOT/configs/snapshots/<snapshot name>/` directory

1. Build with **verilator**:  

    `make -f $RV_ROOT/tools/Makefile verilator [snapshot=name]`  

This will create and populate the verilator *obj_dir/* in the current work dir.  

**Other targets supported**:  

    vcs  (Synopsys)  
    irun (Cadence)  

### Running a simple Hello World program (verilator)

    RV_ROOT = /path/to/swerv
    export RV_ROOT

    make -f $RV_ROOT/tools/Makefile verilator-run

This will build a verilator model of SweRV with AHB-lite bus, and execute a short sequence of instructions that writes out "HELLO
WORLD" to the bus.

You can re-execute using

    ./obj_dir/Vtb_top

    Start of sim

    ------------------------------
    Hello World from SweRV @WDC !!
    ------------------------------

    Finished : minstret = 389, mcycle = 1658

    End of sim

A vcd file `sim.vcd` is created which can be browsed by gtkwave or similar waveform viewers. `trace_port.csv` contains a log of
the trace port. `exec.log` contains a basic execution trace showing PC, opcode and GPR writes.

The Makefile allows you to specify different assembly files from command line
     
    make -f $RV_ROOT/tools/Makefile verilator-run ASM_TEST=my_hellow_world.s ASM_TEST_DIR=/path/to/dir

If you change only the assembly files, you do not need to rebuild verilator, just specify the target as `program.hex` :

    make -f $RV_ROOT/tools/Makefile program.hex ASM_TEST=my_hello_world.s ASM_TEST_DIR=/path/to/dir
    ./obj_dir/Vtb_top

----
Western Digital, the Western Digital logo, G-Technology, SanDisk, Tegile, Upthere, WD, SweRV Core, SweRV ISS, and OmniXtend are registered trademarks or trademarks of Western Digital Corporation or its affiliates in the US and/or other countries. All other marks are the property of their respective owners.
