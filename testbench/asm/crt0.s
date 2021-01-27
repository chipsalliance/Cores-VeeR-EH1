# SPDX-License-Identifier: Apache-2.0
# Copyright 2020 Western Digital Corporation or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
// startup code to support HLL programs

#include "defines.h"

.section .text.init
.global _start
_start:

// enable caching, except region 0xd
        li t0, 0x59555555
        csrw 0x7c0, t0

        la sp, STACK

        call main


.global _finish
_finish:
        la t0, tohost
        li t1, 0xff
        sb t1, 0(t0) // DemoTB test termination
        li t1, 1
        sw t1, 0(t0) // Whisper test termination
        beq x0, x0, _finish
        .rept 10
        nop
        .endr

.section .data.io
.global tohost
tohost: .word 0

