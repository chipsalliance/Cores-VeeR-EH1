

.global _start
_start:
 csrrw  x2, 0xb02, x3


 lui x5, 974848
 ori  x5, x5, 0
 csrrw  x2, 0x305, x5


 lui x6, 382293
 ori  x6, x6, 1365
 csrrw  x1, 0x7c0, x6




 lui x5, 0
 ori  x5, x5, 0
 csrrw  x2, 0x7f8, x5




 lui x5, 0
 ori  x5, x5, 0
 csrrw  x2, 0x7f9, x5


 addi  x0, x0, 0
 lui x11, 853376
 ori  x9, x0, 'H'
 sw x9, 0 (x11)
 ori  x9, x0, 'E'
 sw x9, 0 (x11)
 ori  x9, x0, 'L'
 sw x9, 0 (x11)
 sw x9, 0 (x11)
 ori  x9, x0, 'O'
 sw x9, 0 (x11)
 ori  x9, x0, ' '
 sw x9, 0 (x11)
 addi  x9, x0, 'W'
 sw x9, 0 (x11)
 ori  x9, x0, 'O'
 sw x9, 0 (x11)
 ori  x9, x0, 'R'
 sw x9, 0 (x11)
 ori  x9, x0, 'L'
 sw x9, 0 (x11)
 ori  x9, x0, 'D'
 sw x9, 0 (x11)
 ori  x9, x0, '!'
 sw x9, 0 (x11)
 ori  x9, x0, 255
 sw x9, 0 (x11)
 addi x1,x0,0

finish:
 addi x1,x1,1
 jal x0, finish;
 addi x0,x0,0
 addi x0,x0,0
 addi x0,x0,0
 addi x0,x0,0
