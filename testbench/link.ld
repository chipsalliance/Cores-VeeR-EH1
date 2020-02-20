
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
    . = 0;
  .text   : { *(.text*) }
 _end = .;
  . = 0x10000;
  .data  :  ALIGN(0x800) { *(.*data) *(.rodata*) STACK = ALIGN(16) + 0x8000; }
}
