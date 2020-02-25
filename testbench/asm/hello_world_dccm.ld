
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS {
  .text   : { *(.text*) }
 _end = .;
  . = 0xfff8;
  .data.ctl : { LONG(0xf0040000); LONG(STACK) }
  . = 0xf0040000;
  .data  : AT(0x10000)  { *(.*data) *(.rodata*) STACK = ALIGN(16) + 0x8000;}
}
