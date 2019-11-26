# SweRV RISC-V core from Western Digital

## Configuration

### Contents
Name                    | Description
----------------------  | ------------------------------
swerv.config            | Configuration script for SweRV


This script will generate a consistent st of `defines/#defines needed for the design and testbench.
A perl hash (*perl_configs.pl*) and a JSON format for SweRV-iss are also generated.

While the defines fines may be modified by hand, it is recommended that this script be used to generate a consistent set.
