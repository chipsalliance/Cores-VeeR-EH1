# VeeR RISC-V core from Western Digital

## Configuration

### Contents
Name                    | Description
----------------------  | ------------------------------
veer.config            | Configuration script for VeeR  


This script will generate a consistent set of `defines/#defines needed for the design and testbench.  
A perl hash (*perl_configs.pl*) and a JSON format for VeeR-iss are also generated.  

`$RV_ROOT/configs/veer.config -h` will provide options for the script.

While the defines files may be modified by hand, it is recommended that this script be used to generate a consistent set.
