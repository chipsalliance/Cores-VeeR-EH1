OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS {
  .text  :  { *(.text*) }
  . = 0x10000;
  .data  :  { *(.*data) *(.rodata*)}
  . = ALIGN(4);
  printf_start = .;
  . = 0xee000000;
  .data_load : AT(printf_start) {*(.data_text)}
  printf_end = printf_start + SIZEOF(.data_load);
}
