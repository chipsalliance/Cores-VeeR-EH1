extern int STACK;
void main();


#define STDOUT 0xd0580000

__asm (".section .text");
__asm (".global _start");
__asm ("_start:");

// Enable Caches in MRAC
__asm ("li t0, 0x5f555555");
__asm ("csrw 0x7c0, t0");

// Set stack pointer.
__asm ("la sp, STACK");

__asm ("jal main");

// Write 0xff to STDOUT for TB to termiate test.
__asm (".global _finish");
__asm ("_finish:");
__asm ("li t0, 0xd0580000");
__asm ("addi t1, zero, 0xff");
__asm ("sb t1, 0(t0)");
__asm ("beq x0, x0, _finish");
__asm (".rept 10");
__asm ("nop");
__asm (".endr");
