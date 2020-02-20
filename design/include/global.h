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

localparam TOTAL_INT        = `RV_PIC_TOTAL_INT_PLUS1;

localparam DCCM_BITS        = `RV_DCCM_BITS;
localparam DCCM_BANK_BITS   = `RV_DCCM_BANK_BITS;
localparam DCCM_NUM_BANKS   = `RV_DCCM_NUM_BANKS;
localparam DCCM_DATA_WIDTH  = `RV_DCCM_DATA_WIDTH;
localparam DCCM_FDATA_WIDTH = `RV_DCCM_FDATA_WIDTH;
localparam DCCM_BYTE_WIDTH  = `RV_DCCM_BYTE_WIDTH;
localparam DCCM_ECC_WIDTH   = `RV_DCCM_ECC_WIDTH;

localparam LSU_RDBUF_DEPTH  = `RV_LSU_NUM_NBLOAD;
localparam DMA_BUF_DEPTH    = `RV_DMA_BUF_DEPTH;
localparam LSU_STBUF_DEPTH  = `RV_LSU_STBUF_DEPTH;
localparam LSU_SB_BITS      = `RV_LSU_SB_BITS;

localparam DEC_INSTBUF_DEPTH = `RV_DEC_INSTBUF_DEPTH;

localparam ICCM_SIZE         = `RV_ICCM_SIZE;
localparam ICCM_BITS         = `RV_ICCM_BITS;
localparam ICCM_NUM_BANKS    = `RV_ICCM_NUM_BANKS;
localparam ICCM_BANK_BITS    = `RV_ICCM_BANK_BITS;
localparam ICCM_INDEX_BITS   = `RV_ICCM_INDEX_BITS;
localparam ICCM_BANK_HI      = 4 + (`RV_ICCM_BANK_BITS/4);

localparam ICACHE_TAG_HIGH  = `RV_ICACHE_TAG_HIGH;
localparam ICACHE_TAG_LOW   = `RV_ICACHE_TAG_LOW;
localparam ICACHE_IC_DEPTH  = `RV_ICACHE_IC_DEPTH;
localparam ICACHE_TAG_DEPTH = `RV_ICACHE_TAG_DEPTH;

localparam LSU_BUS_TAG     = `RV_LSU_BUS_TAG;
localparam DMA_BUS_TAG     = `RV_DMA_BUS_TAG;
localparam SB_BUS_TAG      = `RV_SB_BUS_TAG;

localparam IFU_BUS_TAG     = `RV_IFU_BUS_TAG;


