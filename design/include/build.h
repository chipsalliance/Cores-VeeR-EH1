// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// BUILD_ICACHE_SIZE = { 32, 64, 128, 256 }
//`define BUILD_ICACHE_SIZE 256

// BUILD_ICACHE_LINE_SIZE = { 16 }
//`define BUILD_ICACHE_LINE_SIZE 64

//// BUILD_BTB_SIZE = {256, 512}
//`define BUILD_BTB_SIZE 512
////`define BUILD_ICCM_SIZE 128
//
////----------------------------------------------------------------------
//// For configurable BTB size
//`define BTB_INDEX1_HI  ((`BUILD_BTB_SIZE==256) ? 9 : 10)
//`define BTB_INDEX1_LO  4
//`define BTB_INDEX2_HI  ((`BUILD_BTB_SIZE==256) ? 15 : 17)
//`define BTB_INDEX2_LO  ((`BUILD_BTB_SIZE==256) ? 10 : 11)
//`define BTB_INDEX3_HI  ((`BUILD_BTB_SIZE==256) ? 21 : 24)
//`define BTB_INDEX3_LO  ((`BUILD_BTB_SIZE==256) ? 16 : 18)
//`define BTB_ADDR_HI    ((`BUILD_BTB_SIZE==256) ? 9 : 10)
//`define BTB_ADDR_LO 4
//// ----------------------------------------------------------------------


// BUILD_DTCM_SADDR
//`define BUILD_DTCM_SADR 32'hf0000000
// BUILD_DTCM_EADDR = {256, 512}
//`define BUILD_DTCM_EADR 32'hf0020000

// BUILD_ITCM_SADDR
//`define BUILD_ITCM_SADR 32'hee000000
// BUILD_ITCM_EADDR = {256, 512}
//`define BUILD_ITCM_EADR 32'hee020000

//----------------------------------------------------------------------
//`define TOTAL_INT              256
//`define INTPEND_BASE_ADDR      32'hcc000400
//`define INTENABLE_BASE_ADDR    32'hcc000800
//`define INTPRIORITY_BASE_ADDR  32'hcc000c00
//`define CLAIMID_ADDR           32'hcc001000
//`define PRITHRESH_ADDR         32'hcc001010

//----------------------------------------------------------------------




// Enable assertions
//`define ASSERT_ON


