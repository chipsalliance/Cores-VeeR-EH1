# SweRV RISC-V Core<sup>TM</sup> 1.3 from Western Digital
## Release Notes
1. Make the FPGA optimization code work with the latest version of Verilator.[Pull request #13](https://github.com/chipsalliance/Cores-SweRV/pull/12)
1. Move JTAG TAP to swerv_wrapper module. [Pull request #10](https://github.com/chipsalliance/Cores-SweRV/pull/10)

# SweRV RISC-V Core<sup>TM</sup> 1.2 from Western Digital
## Release Notes
1. SWERV core RISCV compatibility improvements
    * The ebreak and ecall instructions are no longer counted in the MINSRET
	  control and status register.
    * Write to SBDATA0 does not start SB write access when both
	  sbreadonaddr/sbreadondata are zero. This fixes issue number
	  5 on github.

1. FPGA support: Add fpga_optimize option to swerv.config which
   eliminates over 90% of clock-gating enabling faster FPGA
   simulation.
   
1. Usability: Untabified all the verilog files.  This fixes issue number 3 on github.

# SweRV RISC-V Core<sup>TM</sup> 1.1 from Western Digital
## Release Notes
1. SWERV core RISCV compatibility improvements

    * Illegal instructions no longer increment minstret
    * Debug single-step command no longer executes multiple instructions
    * For instructions, MTVAL register holds the address that actually
      triggered an access fault
    * DICAD1 debug CSR ECC read size enhancements

1. SWERV core performance enhancements

    * Improved instruction fetch unit external memory access performance
    * Instruction fetcher no longer stalls due to DMA ICCM requests
    * Improved performance of streaming stores
    * Improved performance of divide instruction
    * Improved I/O Timing 
    * Non-idempotent Ld/St changed to non-posted in MFDC
    * DMA QoS Configurable in MFDC

1. SWERV core miscellaneous changes

    * Non-word access to PIC memory generates access-error
    * Improved streaming performance with unified read/write buffer
    * Non-idempotent load enhancements
    * Debug, single-step, and trigger enhancements
    * DMA, IFU, and LSU interaction enhancements
    * Bus error handling improvements
    * DMA h-ready addition
    * DMA slave error response enhancements

1. Added memory protection windows
    
	* Now able to define up to eight instruction fetch windows and up to eight
	  data load/store windows. See the programmer reference manual for more
	  details.
