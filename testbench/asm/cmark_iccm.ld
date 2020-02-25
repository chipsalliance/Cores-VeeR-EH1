
OUTPUT_ARCH( "riscv" )
ENTRY(_start)
MEMORY {
    EXTCODE : ORIGIN = 0,          LENGTH = 0x10000
    EXTDATA : ORIGIN = 0x10000,    LENGTH = 0x10000
    ICCM    : ORIGIN = 0xee000000, LENGTH = 0x80000
    DCCM    : ORIGIN = 0xf0040000, LENGTH = 0x10000
}
SECTIONS {
  .text_init : {*(.text_init)} > EXTCODE
  init_end = .;
  .data.ctl : AT(0xffec) { LONG(ADDR(.text)); LONG(text_end); LONG(LOADADDR(.text)); LONG(0xf0040000); LONG(STACK)}>EXTDATA
  .text : AT(init_end)  { *(.text) *(.text.startup)} > ICCM
   text_end = .;
  .data  : AT(0x10000)  { *(.*data) *(.rodata*) STACK = ALIGN(16) + 0x8000;} > DCCM
}
