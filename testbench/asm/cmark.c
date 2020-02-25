#include "defines.h"

#define ITERATIONS 1
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


/*
Author : Shay Gal-On, EEMBC

This file is part of  EEMBC(R) and CoreMark(TM), which are Copyright (C) 2009
All rights reserved.

EEMBC CoreMark Software is a product of EEMBC and is provided under the terms of the
CoreMark License that is distributed with the official EEMBC COREMARK Software release.
If you received this EEMBC CoreMark Software without the accompanying CoreMark License,
you must discontinue use and download the official release from www.coremark.org.

Also, if you are publicly displaying scores generated from the EEMBC CoreMark software,
make sure that you are in compliance with Run and Reporting rules specified in the accompanying readme.txt file.

EEMBC
4354 Town Center Blvd. Suite 114-200
El Dorado Hills, CA, 95762
*/

//#include "/wd/users/jrahmeh/coremark_v1.0/riscv/coremark.h"

/*
Author : Shay Gal-On, EEMBC

This file is part of  EEMBC(R) and CoreMark(TM), which are Copyright (C) 2009
All rights reserved.

EEMBC CoreMark Software is a product of EEMBC and is provided under the terms of the
CoreMark License that is distributed with the official EEMBC COREMARK Software release.
If you received this EEMBC CoreMark Software without the accompanying CoreMark License,
you must discontinue use and download the official release from www.coremark.org.

Also, if you are publicly displaying scores generated from the EEMBC CoreMark software,
make sure that you are in compliance with Run and Reporting rules specified in the accompanying readme.txt file.

EEMBC
4354 Town Center Blvd. Suite 114-200
El Dorado Hills, CA, 95762
*/
/* Topic: Description
        This file contains  declarations of the various benchmark functions.
*/

/* Configuration: TOTAL_DATA_SIZE
        Define total size for data algorithms will operate on
*/
#ifndef TOTAL_DATA_SIZE
#define TOTAL_DATA_SIZE 2*1000
#endif

#define SEED_ARG 0
#define SEED_FUNC 1
#define SEED_VOLATILE 2

#define MEM_STATIC 0
#define MEM_MALLOC 1
#define MEM_STACK 2

/* File : core_portme.h */

/*
        Author : Shay Gal-On, EEMBC
        Legal : TODO!
*/
/* Topic : Description
        This file contains configuration constants required to execute on different platforms
*/
#ifndef CORE_PORTME_H
#define CORE_PORTME_H
/************************/
/* Data types and settings */
/************************/
/* Configuration : HAS_FLOAT
        Define to 1 if the platform supports floating point.
*/
#ifndef HAS_FLOAT
#define HAS_FLOAT 0
#endif
/* Configuration : HAS_TIME_H
        Define to 1 if platform has the time.h header file,
        and implementation of functions thereof.
*/
#ifndef HAS_TIME_H
#define HAS_TIME_H 0
#endif
/* Configuration : USE_CLOCK
        Define to 1 if platform has the time.h header file,
        and implementation of functions thereof.
*/
#ifndef USE_CLOCK
#define USE_CLOCK 0
#endif
/* Configuration : HAS_STDIO
        Define to 1 if the platform has stdio.h.
*/
#ifndef HAS_STDIO
#define HAS_STDIO 0
#endif
/* Configuration : HAS_PRINTF
        Define to 1 if the platform has stdio.h and implements the printf function.
*/
#ifndef HAS_PRINTF
#define HAS_PRINTF 1
int whisperPrintf(const char* format, ...);
#define ee_printf whisperPrintf
#endif

/* Configuration : CORE_TICKS
        Define type of return from the timing functions.
 */
#include <time.h>
typedef clock_t CORE_TICKS;

/* Definitions : COMPILER_VERSION, COMPILER_FLAGS, MEM_LOCATION
        Initialize these strings per platform
*/
#ifndef COMPILER_VERSION
 #ifdef __GNUC__
 #define COMPILER_VERSION "GCC"__VERSION__
 #else
 #define COMPILER_VERSION "Please put compiler version here (e.g. gcc 4.1)"
 #endif
#endif
#ifndef COMPILER_FLAGS
 #define COMPILER_FLAGS "-O2"
#endif

#ifndef MEM_LOCATION
// #define MEM_LOCATION "STACK"
 #define MEM_LOCATION "STATIC"
#endif

/* Data Types :
        To avoid compiler issues, define the data types that need ot be used for 8b, 16b and 32b in <core_portme.h>.

        *Imprtant* :
        ee_ptr_int needs to be the data type used to hold pointers, otherwise coremark may fail!!!
*/
typedef signed short ee_s16;
typedef unsigned short ee_u16;
typedef signed int ee_s32;
typedef double ee_f32;
typedef unsigned char ee_u8;
typedef unsigned int ee_u32;
typedef ee_u32 ee_ptr_int;
typedef size_t ee_size_t;
/* align_mem :
        This macro is used to align an offset to point to a 32b value. It is used in the Matrix algorithm to initialize the input memory blocks.
*/
#define align_mem(x) (void *)(4 + (((ee_ptr_int)(x) - 1) & ~3))

/* Configuration : SEED_METHOD
        Defines method to get seed values that cannot be computed at compile time.

        Valid values :
        SEED_ARG - from command line.
        SEED_FUNC - from a system function.
        SEED_VOLATILE - from volatile variables.
*/
#ifndef SEED_METHOD
#define SEED_METHOD SEED_VOLATILE
#endif

/* Configuration : MEM_METHOD
        Defines method to get a block of memry.

        Valid values :
        MEM_MALLOC - for platforms that implement malloc and have malloc.h.
        MEM_STATIC - to use a static memory array.
        MEM_STACK - to allocate the data block on the stack (NYI).
*/
#ifndef MEM_METHOD
//#define MEM_METHOD MEM_STACK
#define MEM_METHOD MEM_STATIC
#endif

/* Configuration : MULTITHREAD
        Define for parallel execution

        Valid values :
        1 - only one context (default).
        N>1 - will execute N copies in parallel.

        Note :
        If this flag is defined to more then 1, an implementation for launching parallel contexts must be defined.

        Two sample implementations are provided. Use <USE_PTHREAD> or <USE_FORK> to enable them.

        It is valid to have a different implementation of <core_start_parallel> and <core_end_parallel> in <core_portme.c>,
        to fit a particular architecture.
*/
#ifndef MULTITHREAD
#define MULTITHREAD 1
#define USE_PTHREAD 0
#define USE_FORK 0
#define USE_SOCKET 0
#endif

/* Configuration : MAIN_HAS_NOARGC
        Needed if platform does not support getting arguments to main.

        Valid values :
        0 - argc/argv to main is supported
        1 - argc/argv to main is not supported

        Note :
        This flag only matters if MULTITHREAD has been defined to a value greater then 1.
*/
#ifndef MAIN_HAS_NOARGC
#define MAIN_HAS_NOARGC 1
#endif

/* Configuration : MAIN_HAS_NORETURN
        Needed if platform does not support returning a value from main.

        Valid values :
        0 - main returns an int, and return value will be 0.
        1 - platform does not support returning a value from main
*/
#ifndef MAIN_HAS_NORETURN
#define MAIN_HAS_NORETURN 1
#endif

/* Variable : default_num_contexts
        Not used for this simple port, must cintain the value 1.
*/
extern ee_u32 default_num_contexts;

typedef struct CORE_PORTABLE_S {
        ee_u8   portable_id;
} core_portable;

/* target specific init/fini */
void portable_init(core_portable *p, int *argc, char *argv[]);
void portable_fini(core_portable *p);

#if !defined(PROFILE_RUN) && !defined(PERFORMANCE_RUN) && !defined(VALIDATION_RUN)
#if (TOTAL_DATA_SIZE==1200)
#define PROFILE_RUN 1
#elif (TOTAL_DATA_SIZE==2000)
#define PERFORMANCE_RUN 1
#else
#define VALIDATION_RUN 1
#endif
#endif

#endif /* CORE_PORTME_H */


#if HAS_STDIO
#include <stdio.h>
#endif
#if HAS_PRINTF
#ifndef ee_printf
#define ee_printf printf
#endif
#endif

/* Actual benchmark execution in iterate */
void *iterate(void *pres);

/* Typedef: secs_ret
        For machines that have floating point support, get number of seconds as a double.
        Otherwise an unsigned int.
*/
#if HAS_FLOAT
typedef double secs_ret;
#else
typedef ee_u32 secs_ret;
#endif

#if MAIN_HAS_NORETURN
#define MAIN_RETURN_VAL
#define MAIN_RETURN_TYPE void
#else
#define MAIN_RETURN_VAL 0
#define MAIN_RETURN_TYPE int
#endif

void start_time(void);
void stop_time(void);
CORE_TICKS get_time(void);
secs_ret time_in_secs(CORE_TICKS ticks);

/* Misc useful functions */
ee_u16 crcu8(ee_u8 data, ee_u16 crc);
ee_u16 crc16(ee_s16 newval, ee_u16 crc);
ee_u16 crcu16(ee_u16 newval, ee_u16 crc);
ee_u16 crcu32(ee_u32 newval, ee_u16 crc);
ee_u8 check_data_types();
void *portable_malloc(ee_size_t size);
void portable_free(void *p);
ee_s32 parseval(char *valstring);

/* Algorithm IDS */
#define ID_LIST         (1<<0)
#define ID_MATRIX       (1<<1)
#define ID_STATE        (1<<2)
#define ALL_ALGORITHMS_MASK (ID_LIST|ID_MATRIX|ID_STATE)
#define NUM_ALGORITHMS 3

/* list data structures */
typedef struct list_data_s {
        ee_s16 data16;
        ee_s16 idx;
} list_data;

typedef struct list_head_s {
        struct list_head_s *next;
        struct list_data_s *info;
} list_head;


/*matrix benchmark related stuff */
#define MATDAT_INT 1
#if MATDAT_INT
typedef ee_s16 MATDAT;
typedef ee_s32 MATRES;
#else
typedef ee_f16 MATDAT;
typedef ee_f32 MATRES;
#endif

typedef struct MAT_PARAMS_S {
        int N;
        MATDAT *A;
        MATDAT *B;
        MATRES *C;
} mat_params;

/* state machine related stuff */
/* List of all the possible states for the FSM */
typedef enum CORE_STATE {
        CORE_START=0,
        CORE_INVALID,
        CORE_S1,
        CORE_S2,
        CORE_INT,
        CORE_FLOAT,
        CORE_EXPONENT,
        CORE_SCIENTIFIC,
        NUM_CORE_STATES
} core_state_e ;


/* Helper structure to hold results */
typedef struct RESULTS_S {
        /* inputs */
        ee_s16  seed1;          /* Initializing seed */
        ee_s16  seed2;          /* Initializing seed */
        ee_s16  seed3;          /* Initializing seed */
        void    *memblock[4];   /* Pointer to safe memory location */
        ee_u32  size;           /* Size of the data */
        ee_u32 iterations;              /* Number of iterations to execute */
        ee_u32  execs;          /* Bitmask of operations to execute */
        struct list_head_s *list;
        mat_params mat;
        /* outputs */
        ee_u16  crc;
        ee_u16  crclist;
        ee_u16  crcmatrix;
        ee_u16  crcstate;
        ee_s16  err;
        /* ultithread specific */
        core_portable port;
} core_results;

/* Multicore execution handling */
#if (MULTITHREAD>1)
ee_u8 core_start_parallel(core_results *res);
ee_u8 core_stop_parallel(core_results *res);
#endif

/* list benchmark functions */
list_head *core_list_init(ee_u32 blksize, list_head *memblock, ee_s16 seed);
ee_u16 core_bench_list(core_results *res, ee_s16 finder_idx);

/* state benchmark functions */
void core_init_state(ee_u32 size, ee_s16 seed, ee_u8 *p);
ee_u16 core_bench_state(ee_u32 blksize, ee_u8 *memblock,
                ee_s16 seed1, ee_s16 seed2, ee_s16 step, ee_u16 crc);

/* matrix benchmark functions */
ee_u32 core_init_matrix(ee_u32 blksize, void *memblk, ee_s32 seed, mat_params *p);
ee_u16 core_bench_matrix(mat_params *p, ee_s16 seed, ee_u16 crc);





/*
Topic: Description
        Benchmark using a linked list.

        Linked list is a common data structure used in many applications.

        For our purposes, this will excercise the memory units of the processor.
        In particular, usage of the list pointers to find and alter data.

        We are not using Malloc since some platforms do not support this library.

        Instead, the memory block being passed in is used to create a list,
        and the benchmark takes care not to add more items then can be
        accomodated by the memory block. The porting layer will make sure
        that we have a valid memory block.

        All operations are done in place, without using any extra memory.

        The list itself contains list pointers and pointers to data items.
        Data items contain the following:

        idx - An index that captures the initial order of the list.
        data - Variable data initialized based on the input parameters. The 16b are divided as follows:
        o Upper 8b are backup of original data.
        o Bit 7 indicates if the lower 7 bits are to be used as is or calculated.
        o Bits 0-2 indicate type of operation to perform to get a 7b value.
        o Bits 3-6 provide input for the operation.

*/

/* local functions */

list_head *core_list_find(list_head *list,list_data *info);
list_head *core_list_reverse(list_head *list);
list_head *core_list_remove(list_head *item);
list_head *core_list_undo_remove(list_head *item_removed, list_head *item_modified);
list_head *core_list_insert_new(list_head *insert_point
        , list_data *info, list_head **memblock, list_data **datablock
        , list_head *memblock_end, list_data *datablock_end);
typedef ee_s32(*list_cmp)(list_data *a, list_data *b, core_results *res);
list_head *core_list_mergesort(list_head *list, list_cmp cmp, core_results *res);

ee_s16 calc_func(ee_s16 *pdata, core_results *res) {
        ee_s16 data=*pdata;
        ee_s16 retval;
        ee_u8 optype=(data>>7) & 1; /* bit 7 indicates if the function result has been cached */
        if (optype) /* if cached, use cache */
                return (data & 0x007f);
        else { /* otherwise calculate and cache the result */
                ee_s16 flag=data & 0x7; /* bits 0-2 is type of function to perform */
                ee_s16 dtype=((data>>3) & 0xf); /* bits 3-6 is specific data for the operation */
                dtype |= dtype << 4; /* replicate the lower 4 bits to get an 8b value */
                switch (flag) {
                        case 0:
                                if (dtype<0x22) /* set min period for bit corruption */
                                        dtype=0x22;
                                retval=core_bench_state(res->size,res->memblock[3],res->seed1,res->seed2,dtype,res->crc);
                                if (res->crcstate==0)
                                        res->crcstate=retval;
                                break;
                        case 1:
                                retval=core_bench_matrix(&(res->mat),dtype,res->crc);
                                if (res->crcmatrix==0)
                                        res->crcmatrix=retval;
                                break;
                        default:
                                retval=data;
                                break;
                }
                res->crc=crcu16(retval,res->crc);
                retval &= 0x007f;
                *pdata = (data & 0xff00) | 0x0080 | retval; /* cache the result */
                return retval;
        }
}
/* Function: cmp_complex
        Compare the data item in a list cell.

        Can be used by mergesort.
*/
ee_s32 cmp_complex(list_data *a, list_data *b, core_results *res) {
        ee_s16 val1=calc_func(&(a->data16),res);
        ee_s16 val2=calc_func(&(b->data16),res);
        return val1 - val2;
}

/* Function: cmp_idx
        Compare the idx item in a list cell, and regen the data.

        Can be used by mergesort.
*/
ee_s32 cmp_idx(list_data *a, list_data *b, core_results *res) {
        if (res==NULL) {
                a->data16 = (a->data16 & 0xff00) | (0x00ff & (a->data16>>8));
                b->data16 = (b->data16 & 0xff00) | (0x00ff & (b->data16>>8));
        }
        return a->idx - b->idx;
}

void copy_info(list_data *to,list_data *from) {
        to->data16=from->data16;
        to->idx=from->idx;
}

/* Benchmark for linked list:
        - Try to find multiple data items.
        - List sort
        - Operate on data from list (crc)
        - Single remove/reinsert
        * At the end of this function, the list is back to original state
*/
ee_u16 core_bench_list(core_results *res, ee_s16 finder_idx) {
        ee_u16 retval=0;
        ee_u16 found=0,missed=0;
        list_head *list=res->list;
        ee_s16 find_num=res->seed3;
        list_head *this_find;
        list_head *finder, *remover;
        list_data info;
        ee_s16 i;

        info.idx=finder_idx;
        /* find <find_num> values in the list, and change the list each time (reverse and cache if value found) */
        for (i=0; i<find_num; i++) {
                info.data16= (i & 0xff) ;
                this_find=core_list_find(list,&info);
                list=core_list_reverse(list);
                if (this_find==NULL) {
                        missed++;
                        retval+=(list->next->info->data16 >> 8) & 1;
                }
                else {
                        found++;
                        if (this_find->info->data16 & 0x1) /* use found value */
                                retval+=(this_find->info->data16 >> 9) & 1;
                        /* and cache next item at the head of the list (if any) */
                        if (this_find->next != NULL) {
                                finder = this_find->next;
                                this_find->next = finder->next;
                                finder->next=list->next;
                                list->next=finder;
                        }
                }
                if (info.idx>=0)
                        info.idx++;
#if CORE_DEBUG
        ee_printf("List find %d: [%d,%d,%d]\n",i,retval,missed,found);
#endif
        }
        retval+=found*4-missed;
        /* sort the list by data content and remove one item*/
        if (finder_idx>0)
                list=core_list_mergesort(list,cmp_complex,res);
        remover=core_list_remove(list->next);
        /* CRC data content of list from location of index N forward, and then undo remove */
        finder=core_list_find(list,&info);
        if (!finder)
                finder=list->next;
        while (finder) {
                retval=crc16(list->info->data16,retval);
                finder=finder->next;
        }
#if CORE_DEBUG
        ee_printf("List sort 1: %04x\n",retval);
#endif
        remover=core_list_undo_remove(remover,list->next);
        /* sort the list by index, in effect returning the list to original state */
        list=core_list_mergesort(list,cmp_idx,NULL);
        /* CRC data content of list */
        finder=list->next;
        while (finder) {
                retval=crc16(list->info->data16,retval);
                finder=finder->next;
        }
#if CORE_DEBUG
        ee_printf("List sort 2: %04x\n",retval);
#endif
        return retval;
}
/* Function: core_list_init
        Initialize list with data.

        Parameters:
        blksize - Size of memory to be initialized.
        memblock - Pointer to memory block.
        seed -  Actual values chosen depend on the seed parameter.
                The seed parameter MUST be supplied from a source that cannot be determined at compile time

        Returns:
        Pointer to the head of the list.

*/
list_head *core_list_init(ee_u32 blksize, list_head *memblock, ee_s16 seed) {
        /* calculated pointers for the list */
        ee_u32 per_item=16+sizeof(struct list_data_s);
        ee_u32 size=(blksize/per_item)-2; /* to accomodate systems with 64b pointers, and make sure same code is executed, set max list elements */
        list_head *memblock_end=memblock+size;
        list_data *datablock=(list_data *)(memblock_end);
        list_data *datablock_end=datablock+size;
        /* some useful variables */
        ee_u32 i;
        list_head *finder,*list=memblock;
        list_data info;

        /* create a fake items for the list head and tail */
        list->next=NULL;
        list->info=datablock;
        list->info->idx=0x0000;
        list->info->data16=(ee_s16)0x8080;
        memblock++;
        datablock++;
        info.idx=0x7fff;
        info.data16=(ee_s16)0xffff;
        core_list_insert_new(list,&info,&memblock,&datablock,memblock_end,datablock_end);

        /* then insert size items */
        for (i=0; i<size; i++) {
                ee_u16 datpat=((ee_u16)(seed^i) & 0xf);
                ee_u16 dat=(datpat<<3) | (i&0x7); /* alternate between algorithms */
                info.data16=(dat<<8) | dat;             /* fill the data with actual data and upper bits with rebuild value */
                core_list_insert_new(list,&info,&memblock,&datablock,memblock_end,datablock_end);
        }
        /* and now index the list so we know initial seed order of the list */
        finder=list->next;
        i=1;
        while (finder->next!=NULL) {
                if (i<size/5) /* first 20% of the list in order */
                        finder->info->idx=i++;
                else {
                        ee_u16 pat=(ee_u16)(i++ ^ seed); /* get a pseudo random number */
                        finder->info->idx=0x3fff & (((i & 0x07) << 8) | pat); /* make sure the mixed items end up after the ones in sequence */
                }
                finder=finder->next;
        }
        list = core_list_mergesort(list,cmp_idx,NULL);
#if CORE_DEBUG
        ee_printf("Initialized list:\n");
        finder=list;
        while (finder) {
                ee_printf("[%04x,%04x]",finder->info->idx,(ee_u16)finder->info->data16);
                finder=finder->next;
        }
        ee_printf("\n");
#endif
        return list;
}

/* Function: core_list_insert
        Insert an item to the list

        Parameters:
        insert_point - where to insert the item.
        info - data for the cell.
        memblock - pointer for the list header
        datablock - pointer for the list data
        memblock_end - end of region for list headers
        datablock_end - end of region for list data

        Returns:
        Pointer to new item.
*/
list_head *core_list_insert_new(list_head *insert_point, list_data *info, list_head **memblock, list_data **datablock
        , list_head *memblock_end, list_data *datablock_end) {
        list_head *newitem;

        if ((*memblock+1) >= memblock_end)
                return NULL;
        if ((*datablock+1) >= datablock_end)
                return NULL;

        newitem=*memblock;
        (*memblock)++;
        newitem->next=insert_point->next;
        insert_point->next=newitem;

        newitem->info=*datablock;
        (*datablock)++;
        copy_info(newitem->info,info);

        return newitem;
}

/* Function: core_list_remove
        Remove an item from the list.

        Operation:
        For a singly linked list, remove by copying the data from the next item
        over to the current cell, and unlinking the next item.

        Note:
        since there is always a fake item at the end of the list, no need to check for NULL.

        Returns:
        Removed item.
*/
list_head *core_list_remove(list_head *item) {
        list_data *tmp;
        list_head *ret=item->next;
        /* swap data pointers */
        tmp=item->info;
        item->info=ret->info;
        ret->info=tmp;
        /* and eliminate item */
        item->next=item->next->next;
        ret->next=NULL;
        return ret;
}

/* Function: core_list_undo_remove
        Undo a remove operation.

        Operation:
        Since we want each iteration of the benchmark to be exactly the same,
        we need to be able to undo a remove.
        Link the removed item back into the list, and switch the info items.

        Parameters:
        item_removed - Return value from the <core_list_remove>
        item_modified - List item that was modified during <core_list_remove>

        Returns:
        The item that was linked back to the list.

*/
list_head *core_list_undo_remove(list_head *item_removed, list_head *item_modified) {
        list_data *tmp;
        /* swap data pointers */
        tmp=item_removed->info;
        item_removed->info=item_modified->info;
        item_modified->info=tmp;
        /* and insert item */
        item_removed->next=item_modified->next;
        item_modified->next=item_removed;
        return item_removed;
}

/* Function: core_list_find
        Find an item in the list

        Operation:
        Find an item by idx (if not 0) or specific data value

        Parameters:
        list - list head
        info - idx or data to find

        Returns:
        Found item, or NULL if not found.
*/
list_head *core_list_find(list_head *list,list_data *info) {
        if (info->idx>=0) {
                while (list && (list->info->idx != info->idx))
                        list=list->next;
                return list;
        } else {
                while (list && ((list->info->data16 & 0xff) != info->data16))
                        list=list->next;
                return list;
        }
}
/* Function: core_list_reverse
        Reverse a list

        Operation:
        Rearrange the pointers so the list is reversed.

        Parameters:
        list - list head
        info - idx or data to find

        Returns:
        Found item, or NULL if not found.
*/

list_head *core_list_reverse(list_head *list) {
        list_head *next=NULL, *tmp;
        while (list) {
                tmp=list->next;
                list->next=next;
                next=list;
                list=tmp;
        }
        return next;
}
/* Function: core_list_mergesort
        Sort the list in place without recursion.

        Description:
        Use mergesort, as for linked list this is a realistic solution.
        Also, since this is aimed at embedded, care was taken to use iterative rather then recursive algorithm.
        The sort can either return the list to original order (by idx) ,
        or use the data item to invoke other other algorithms and change the order of the list.

        Parameters:
        list - list to be sorted.
        cmp - cmp function to use

        Returns:
        New head of the list.

        Note:
        We have a special header for the list that will always be first,
        but the algorithm could theoretically modify where the list starts.

 */
list_head *core_list_mergesort(list_head *list, list_cmp cmp, core_results *res) {
    list_head *p, *q, *e, *tail;
    ee_s32 insize, nmerges, psize, qsize, i;

    insize = 1;

    while (1) {
        p = list;
        list = NULL;
        tail = NULL;

        nmerges = 0;  /* count number of merges we do in this pass */

        while (p) {
            nmerges++;  /* there exists a merge to be done */
            /* step `insize' places along from p */
            q = p;
            psize = 0;
            for (i = 0; i < insize; i++) {
                psize++;
                            q = q->next;
                if (!q) break;
            }

            /* if q hasn't fallen off end, we have two lists to merge */
            qsize = insize;

            /* now we have two lists; merge them */
            while (psize > 0 || (qsize > 0 && q)) {

                                /* decide whether next element of merge comes from p or q */
                                if (psize == 0) {
                                    /* p is empty; e must come from q. */
                                    e = q; q = q->next; qsize--;
                                } else if (qsize == 0 || !q) {
                                    /* q is empty; e must come from p. */
                                    e = p; p = p->next; psize--;
                                } else if (cmp(p->info,q->info,res) <= 0) {
                                    /* First element of p is lower (or same); e must come from p. */
                                    e = p; p = p->next; psize--;
                                } else {
                                    /* First element of q is lower; e must come from q. */
                                    e = q; q = q->next; qsize--;
                                }

                        /* add the next element to the merged list */
                                if (tail) {
                                    tail->next = e;
                                } else {
                                    list = e;
                                }
                                tail = e;
                }

                        /* now p has stepped `insize' places along, and q has too */
                        p = q;
        }

            tail->next = NULL;

        /* If we have done only one merge, we're finished. */
        if (nmerges <= 1)   /* allow for nmerges==0, the empty list case */
            return list;

        /* Otherwise repeat, merging lists twice the size */
        insize *= 2;
    }
#if COMPILER_REQUIRES_SORT_RETURN
        return list;
#endif
}
/*
Author : Shay Gal-On, EEMBC

This file is part of  EEMBC(R) and CoreMark(TM), which are Copyright (C) 2009
All rights reserved.

EEMBC CoreMark Software is a product of EEMBC and is provided under the terms of the
CoreMark License that is distributed with the official EEMBC COREMARK Software release.
If you received this EEMBC CoreMark Software without the accompanying CoreMark License,
you must discontinue use and download the official release from www.coremark.org.

Also, if you are publicly displaying scores generated from the EEMBC CoreMark software,
make sure that you are in compliance with Run and Reporting rules specified in the accompanying readme.txt file.

EEMBC
4354 Town Center Blvd. Suite 114-200
El Dorado Hills, CA, 95762
*/
/* File: core_main.c
        This file contains the framework to acquire a block of memory, seed initial parameters, tun t he benchmark and report the results.
*/
//#include "coremark.h"

/* Function: iterate
        Run the benchmark for a specified number of iterations.

        Operation:
        For each type of benchmarked algorithm:
                a - Initialize the data block for the algorithm.
                b - Execute the algorithm N times.

        Returns:
        NULL.
*/
static ee_u16 list_known_crc[]   =      {(ee_u16)0xd4b0,(ee_u16)0x3340,(ee_u16)0x6a79,(ee_u16)0xe714,(ee_u16)0xe3c1};
static ee_u16 matrix_known_crc[] =      {(ee_u16)0xbe52,(ee_u16)0x1199,(ee_u16)0x5608,(ee_u16)0x1fd7,(ee_u16)0x0747};
static ee_u16 state_known_crc[]  =      {(ee_u16)0x5e47,(ee_u16)0x39bf,(ee_u16)0xe5a4,(ee_u16)0x8e3a,(ee_u16)0x8d84};
void *iterate(void *pres) {
        ee_u32 i;
        ee_u16 crc;
        core_results *res=(core_results *)pres;
        ee_u32 iterations=res->iterations;
        res->crc=0;
        res->crclist=0;
        res->crcmatrix=0;
        res->crcstate=0;

        for (i=0; i<iterations; i++) {
                crc=core_bench_list(res,1);
                res->crc=crcu16(crc,res->crc);
                crc=core_bench_list(res,-1);
                res->crc=crcu16(crc,res->crc);
                if (i==0) res->crclist=res->crc;
        }
        return NULL;
}

#if (SEED_METHOD==SEED_ARG)
ee_s32 get_seed_args(int i, int argc, char *argv[]);
#define get_seed(x) (ee_s16)get_seed_args(x,argc,argv)
#define get_seed_32(x) get_seed_args(x,argc,argv)
#else /* via function or volatile */
ee_s32 get_seed_32(int i);
#define get_seed(x) (ee_s16)get_seed_32(x)
#endif

#if (MEM_METHOD==MEM_STATIC)
ee_u8 static_memblk[TOTAL_DATA_SIZE];
#endif
char *mem_name[3] = {"Static","Heap","Stack"};
/* Function: main
        Main entry routine for the benchmark.
        This function is responsible for the following steps:

        1 - Initialize input seeds from a source that cannot be determined at compile time.
        2 - Initialize memory block for use.
        3 - Run and time the benchmark.
        4 - Report results, testing the validity of the output if the seeds are known.

        Arguments:
        1 - first seed  : Any value
        2 - second seed : Must be identical to first for iterations to be identical
        3 - third seed  : Any value, should be at least an order of magnitude less then the input size, but bigger then 32.
        4 - Iterations  : Special, if set to 0, iterations will be automatically determined such that the benchmark will run between 10 to 100 secs

*/

#if MAIN_HAS_NOARGC
MAIN_RETURN_TYPE main(void) {
        int argc=0;
        char *argv[1];
#else
MAIN_RETURN_TYPE main(int argc, char *argv[]) {
#endif
        ee_u16 i,j=0,num_algorithms=0;
        ee_s16 known_id=-1,total_errors=0;
        ee_u16 seedcrc=0;
        CORE_TICKS total_time;
        core_results results[MULTITHREAD];
#if (MEM_METHOD==MEM_STACK)
        ee_u8 stack_memblock[TOTAL_DATA_SIZE*MULTITHREAD];
#endif
        /* first call any initializations needed */
        portable_init(&(results[0].port), &argc, argv);
        /* First some checks to make sure benchmark will run ok */
        if (sizeof(struct list_head_s)>128) {
                ee_printf("list_head structure too big for comparable data!\n");
                return MAIN_RETURN_VAL;
        }
        results[0].seed1=get_seed(1);
        results[0].seed2=get_seed(2);
        results[0].seed3=get_seed(3);
        results[0].iterations=get_seed_32(4);
#if CORE_DEBUG
        results[0].iterations=1;
#endif
        results[0].execs=get_seed_32(5);
        if (results[0].execs==0) { /* if not supplied, execute all algorithms */
                results[0].execs=ALL_ALGORITHMS_MASK;
        }
                /* put in some default values based on one seed only for easy testing */
        if ((results[0].seed1==0) && (results[0].seed2==0) && (results[0].seed3==0)) { /* validation run */
                results[0].seed1=0;
                results[0].seed2=0;
                results[0].seed3=0x66;
        }
        if ((results[0].seed1==1) && (results[0].seed2==0) && (results[0].seed3==0)) { /* perfromance run */
                results[0].seed1=0x3415;
                results[0].seed2=0x3415;
                results[0].seed3=0x66;
        }
#if (MEM_METHOD==MEM_STATIC)
        results[0].memblock[0]=(void *)static_memblk;
        results[0].size=TOTAL_DATA_SIZE;
        results[0].err=0;
        #if (MULTITHREAD>1)
        #error "Cannot use a static data area with multiple contexts!"
        #endif
#elif (MEM_METHOD==MEM_MALLOC)
        for (i=0 ; i<MULTITHREAD; i++) {
                ee_s32 malloc_override=get_seed(7);
                if (malloc_override != 0)
                        results[i].size=malloc_override;
                else
                        results[i].size=TOTAL_DATA_SIZE;
                results[i].memblock[0]=portable_malloc(results[i].size);
                results[i].seed1=results[0].seed1;
                results[i].seed2=results[0].seed2;
                results[i].seed3=results[0].seed3;
                results[i].err=0;
                results[i].execs=results[0].execs;
        }
#elif (MEM_METHOD==MEM_STACK)
        for (i=0 ; i<MULTITHREAD; i++) {
                results[i].memblock[0]=stack_memblock+i*TOTAL_DATA_SIZE;
                results[i].size=TOTAL_DATA_SIZE;
                results[i].seed1=results[0].seed1;
                results[i].seed2=results[0].seed2;
                results[i].seed3=results[0].seed3;
                results[i].err=0;
                results[i].execs=results[0].execs;
        }
#else
#error "Please define a way to initialize a memory block."
#endif
        /* Data init */
        /* Find out how space much we have based on number of algorithms */
        for (i=0; i<NUM_ALGORITHMS; i++) {
                if ((1<<(ee_u32)i) & results[0].execs)
                        num_algorithms++;
        }
        for (i=0 ; i<MULTITHREAD; i++)
                results[i].size=results[i].size/num_algorithms;
        /* Assign pointers */
        for (i=0; i<NUM_ALGORITHMS; i++) {
                ee_u32 ctx;
                if ((1<<(ee_u32)i) & results[0].execs) {
                        for (ctx=0 ; ctx<MULTITHREAD; ctx++)
                                results[ctx].memblock[i+1]=(char *)(results[ctx].memblock[0])+results[0].size*j;
                        j++;
                }
        }
        /* call inits */
        for (i=0 ; i<MULTITHREAD; i++) {
                if (results[i].execs & ID_LIST) {
                        results[i].list=core_list_init(results[0].size,results[i].memblock[1],results[i].seed1);
                }
                if (results[i].execs & ID_MATRIX) {
                        core_init_matrix(results[0].size, results[i].memblock[2], (ee_s32)results[i].seed1 | (((ee_s32)results[i].seed2) << 16), &(results[i].mat) );
                }
                if (results[i].execs & ID_STATE) {
                        core_init_state(results[0].size,results[i].seed1,results[i].memblock[3]);
                }
        }

        /* automatically determine number of iterations if not set */
        if (results[0].iterations==0) {
                secs_ret secs_passed=0;
                ee_u32 divisor;
                results[0].iterations=1;
                while (secs_passed < (secs_ret)1) {
                        results[0].iterations*=10;
                        start_time();
                        iterate(&results[0]);
                        stop_time();
                        secs_passed=time_in_secs(get_time());
                }
                /* now we know it executes for at least 1 sec, set actual run time at about 10 secs */
                divisor=(ee_u32)secs_passed;
                if (divisor==0) /* some machines cast float to int as 0 since this conversion is not defined by ANSI, but we know at least one second passed */
                        divisor=1;
                results[0].iterations*=1+10/divisor;
        }
        /* perform actual benchmark */
        start_time();

        __asm("__perf_start:");

#if (MULTITHREAD>1)
        if (default_num_contexts>MULTITHREAD) {
                default_num_contexts=MULTITHREAD;
        }
        for (i=0 ; i<default_num_contexts; i++) {
                results[i].iterations=results[0].iterations;
                results[i].execs=results[0].execs;
                core_start_parallel(&results[i]);
        }
        for (i=0 ; i<default_num_contexts; i++) {
                core_stop_parallel(&results[i]);
        }
#else
        iterate(&results[0]);
#endif

        __asm("__perf_end:");

        stop_time();
        total_time=get_time();
        /* get a function of the input to report */
        seedcrc=crc16(results[0].seed1,seedcrc);
        seedcrc=crc16(results[0].seed2,seedcrc);
        seedcrc=crc16(results[0].seed3,seedcrc);
        seedcrc=crc16(results[0].size,seedcrc);

        switch (seedcrc) { /* test known output for common seeds */
                case 0x8a02: /* seed1=0, seed2=0, seed3=0x66, size 2000 per algorithm */
                        known_id=0;
                        ee_printf("6k performance run parameters for coremark.\n");
                        break;
                case 0x7b05: /*  seed1=0x3415, seed2=0x3415, seed3=0x66, size 2000 per algorithm */
                        known_id=1;
                        ee_printf("6k validation run parameters for coremark.\n");
                        break;
                case 0x4eaf: /* seed1=0x8, seed2=0x8, seed3=0x8, size 400 per algorithm */
                        known_id=2;
                        ee_printf("Profile generation run parameters for coremark.\n");
                        break;
                case 0xe9f5: /* seed1=0, seed2=0, seed3=0x66, size 666 per algorithm */
                        known_id=3;
                        ee_printf("2K performance run parameters for coremark.\n");
                        break;
                case 0x18f2: /*  seed1=0x3415, seed2=0x3415, seed3=0x66, size 666 per algorithm */
                        known_id=4;
                        ee_printf("2K validation run parameters for coremark.\n");
                        break;
                default:
                        total_errors=-1;
                        break;
        }
        if (known_id>=0) {
                for (i=0 ; i<default_num_contexts; i++) {
                        results[i].err=0;
                        if ((results[i].execs & ID_LIST) &&
                                (results[i].crclist!=list_known_crc[known_id])) {
                                ee_printf("[%u]ERROR! list crc 0x%04x - should be 0x%04x\n",i,results[i].crclist,list_known_crc[known_id]);
                                results[i].err++;
                        }
                        if ((results[i].execs & ID_MATRIX) &&
                                (results[i].crcmatrix!=matrix_known_crc[known_id])) {
                                ee_printf("[%u]ERROR! matrix crc 0x%04x - should be 0x%04x\n",i,results[i].crcmatrix,matrix_known_crc[known_id]);
                                results[i].err++;
                        }
                        if ((results[i].execs & ID_STATE) &&
                                (results[i].crcstate!=state_known_crc[known_id])) {
                                ee_printf("[%u]ERROR! state crc 0x%04x - should be 0x%04x\n",i,results[i].crcstate,state_known_crc[known_id]);
                                results[i].err++;
                        }
                        total_errors+=results[i].err;
                }
        }
        total_errors+=check_data_types();
        /* and report results */
        ee_printf("CoreMark Size    : %u\n",(ee_u32)results[0].size);
        ee_printf("Total ticks      : %u\n",(ee_u32)total_time);
#if HAS_FLOAT
        ee_printf("Total time (secs): %f\n",time_in_secs(total_time));
        if (time_in_secs(total_time) > 0)
                ee_printf("Iterations/Sec   : %f\n",default_num_contexts*results[0].iterations/time_in_secs(total_time));
#else
        ee_printf("Total time (secs): %d\n",time_in_secs(total_time));
        if (time_in_secs(total_time) > 0)
//              ee_printf("Iterations/Sec   : %d\n",default_num_contexts*results[0].iterations/time_in_secs(total_time));
                ee_printf("Iterat/Sec/MHz   : %d.%d\n",1000*default_num_contexts*results[0].iterations/time_in_secs(total_time),
                             100000*default_num_contexts*results[0].iterations/time_in_secs(total_time) % 100);
#endif
        if (time_in_secs(total_time) < 10) {
                ee_printf("ERROR! Must execute for at least 10 secs for a valid result!\n");
                total_errors++;
        }

        ee_printf("Iterations       : %u\n",(ee_u32)default_num_contexts*results[0].iterations);
        ee_printf("Compiler version : %s\n",COMPILER_VERSION);
        ee_printf("Compiler flags   : %s\n",COMPILER_FLAGS);
#if (MULTITHREAD>1)
        ee_printf("Parallel %s : %d\n",PARALLEL_METHOD,default_num_contexts);
#endif
        ee_printf("Memory location  : %s\n",MEM_LOCATION);
        /* output for verification */
        ee_printf("seedcrc          : 0x%04x\n",seedcrc);
        if (results[0].execs & ID_LIST)
                for (i=0 ; i<default_num_contexts; i++)
                        ee_printf("[%d]crclist       : 0x%04x\n",i,results[i].crclist);
        if (results[0].execs & ID_MATRIX)
                for (i=0 ; i<default_num_contexts; i++)
                        ee_printf("[%d]crcmatrix     : 0x%04x\n",i,results[i].crcmatrix);
        if (results[0].execs & ID_STATE)
                for (i=0 ; i<default_num_contexts; i++)
                        ee_printf("[%d]crcstate      : 0x%04x\n",i,results[i].crcstate);
        for (i=0 ; i<default_num_contexts; i++)
                ee_printf("[%d]crcfinal      : 0x%04x\n",i,results[i].crc);
        if (total_errors==0) {
                ee_printf("Correct operation validated. See readme.txt for run and reporting rules.\n");
#if HAS_FLOAT
                if (known_id==3) {
                        ee_printf("CoreMark 1.0 : %f / %s %s",default_num_contexts*results[0].iterations/time_in_secs(total_time),COMPILER_VERSION,COMPILER_FLAGS);
#if defined(MEM_LOCATION) && !defined(MEM_LOCATION_UNSPEC)
                        ee_printf(" / %s",MEM_LOCATION);
#else
                        ee_printf(" / %s",mem_name[MEM_METHOD]);
#endif

#if (MULTITHREAD>1)
                        ee_printf(" / %d:%s",default_num_contexts,PARALLEL_METHOD);
#endif
                        ee_printf("\n");
                }
#endif
        }
        if (total_errors>0)
                ee_printf("Errors detected\n");
        if (total_errors<0)
                ee_printf("Cannot validate operation for these seed values, please compare with results on a known platform.\n");

#if (MEM_METHOD==MEM_MALLOC)
        for (i=0 ; i<MULTITHREAD; i++)
                portable_free(results[i].memblock[0]);
#endif
        /* And last call any target specific code for finalizing */
        portable_fini(&(results[0].port));

        return MAIN_RETURN_VAL;
}


/*
Author : Shay Gal-On, EEMBC

This file is part of  EEMBC(R) and CoreMark(TM), which are Copyright (C) 2009
All rights reserved.

EEMBC CoreMark Software is a product of EEMBC and is provided under the terms of the
CoreMark License that is distributed with the official EEMBC COREMARK Software release.
If you received this EEMBC CoreMark Software without the accompanying CoreMark License,
you must discontinue use and download the official release from www.coremark.org.

Also, if you are publicly displaying scores generated from the EEMBC CoreMark software,
make sure that you are in compliance with Run and Reporting rules specified in the accompanying readme.txt file.

EEMBC
4354 Town Center Blvd. Suite 114-200
El Dorado Hills, CA, 95762
*/
//#include "coremark.h"
/*
Topic: Description
        Matrix manipulation benchmark

        This very simple algorithm forms the basis of many more complex algorithms.

        The tight inner loop is the focus of many optimizations (compiler as well as hardware based)
        and is thus relevant for embedded processing.

        The total available data space will be divided to 3 parts:
        NxN Matrix A - initialized with small values (upper 3/4 of the bits all zero).
        NxN Matrix B - initialized with medium values (upper half of the bits all zero).
        NxN Matrix C - used for the result.

        The actual values for A and B must be derived based on input that is not available at compile time.
*/
ee_s16 matrix_test(ee_u32 N, MATRES *C, MATDAT *A, MATDAT *B, MATDAT val);
ee_s16 matrix_sum(ee_u32 N, MATRES *C, MATDAT clipval);
void matrix_mul_const(ee_u32 N, MATRES *C, MATDAT *A, MATDAT val);
void matrix_mul_vect(ee_u32 N, MATRES *C, MATDAT *A, MATDAT *B);
void matrix_mul_matrix(ee_u32 N, MATRES *C, MATDAT *A, MATDAT *B);
void matrix_mul_matrix_bitextract(ee_u32 N, MATRES *C, MATDAT *A, MATDAT *B);
void matrix_add_const(ee_u32 N, MATDAT *A, MATDAT val);

#define matrix_test_next(x) (x+1)
#define matrix_clip(x,y) ((y) ? (x) & 0x0ff : (x) & 0x0ffff)
#define matrix_big(x) (0xf000 | (x))
#define bit_extract(x,from,to) (((x)>>(from)) & (~(0xffffffff << (to))))

#if CORE_DEBUG
void printmat(MATDAT *A, ee_u32 N, char *name) {
        ee_u32 i,j;
        ee_printf("Matrix %s [%dx%d]:\n",name,N,N);
        for (i=0; i<N; i++) {
                for (j=0; j<N; j++) {
                        if (j!=0)
                                ee_printf(",");
                        ee_printf("%d",A[i*N+j]);
                }
                ee_printf("\n");
        }
}
void printmatC(MATRES *C, ee_u32 N, char *name) {
        ee_u32 i,j;
        ee_printf("Matrix %s [%dx%d]:\n",name,N,N);
        for (i=0; i<N; i++) {
                for (j=0; j<N; j++) {
                        if (j!=0)
                                ee_printf(",");
                        ee_printf("%d",C[i*N+j]);
                }
                ee_printf("\n");
        }
}
#endif
/* Function: core_bench_matrix
        Benchmark function

        Iterate <matrix_test> N times,
        changing the matrix values slightly by a constant amount each time.
*/
ee_u16 core_bench_matrix(mat_params *p, ee_s16 seed, ee_u16 crc) {
        ee_u32 N=p->N;
        MATRES *C=p->C;
        MATDAT *A=p->A;
        MATDAT *B=p->B;
        MATDAT val=(MATDAT)seed;

        crc=crc16(matrix_test(N,C,A,B,val),crc);

        return crc;
}

/* Function: matrix_test
        Perform matrix manipulation.

        Parameters:
        N - Dimensions of the matrix.
        C - memory for result matrix.
        A - input matrix
        B - operator matrix (not changed during operations)

        Returns:
        A CRC value that captures all results calculated in the function.
        In particular, crc of the value calculated on the result matrix
        after each step by <matrix_sum>.

        Operation:

        1 - Add a constant value to all elements of a matrix.
        2 - Multiply a matrix by a constant.
        3 - Multiply a matrix by a vector.
        4 - Multiply a matrix by a matrix.
        5 - Add a constant value to all elements of a matrix.

        After the last step, matrix A is back to original contents.
*/
ee_s16 matrix_test(ee_u32 N, MATRES *C, MATDAT *A, MATDAT *B, MATDAT val) {
        ee_u16 crc=0;
        MATDAT clipval=matrix_big(val);

        matrix_add_const(N,A,val); /* make sure data changes  */
#if CORE_DEBUG
        printmat(A,N,"matrix_add_const");
#endif
        matrix_mul_const(N,C,A,val);
        crc=crc16(matrix_sum(N,C,clipval),crc);
#if CORE_DEBUG
        printmatC(C,N,"matrix_mul_const");
#endif
        matrix_mul_vect(N,C,A,B);
        crc=crc16(matrix_sum(N,C,clipval),crc);
#if CORE_DEBUG
        printmatC(C,N,"matrix_mul_vect");
#endif
        matrix_mul_matrix(N,C,A,B);
        crc=crc16(matrix_sum(N,C,clipval),crc);
#if CORE_DEBUG
        printmatC(C,N,"matrix_mul_matrix");
#endif
        matrix_mul_matrix_bitextract(N,C,A,B);
        crc=crc16(matrix_sum(N,C,clipval),crc);
#if CORE_DEBUG
        printmatC(C,N,"matrix_mul_matrix_bitextract");
#endif

        matrix_add_const(N,A,-val); /* return matrix to initial value */
        return crc;
}

/* Function : matrix_init
        Initialize the memory block for matrix benchmarking.

        Parameters:
        blksize - Size of memory to be initialized.
        memblk - Pointer to memory block.
        seed - Actual values chosen depend on the seed parameter.
        p - pointers to <mat_params> containing initialized matrixes.

        Returns:
        Matrix dimensions.

        Note:
        The seed parameter MUST be supplied from a source that cannot be determined at compile time
*/
ee_u32 core_init_matrix(ee_u32 blksize, void *memblk, ee_s32 seed, mat_params *p) {
        ee_u32 N=0;
        MATDAT *A;
        MATDAT *B;
        ee_s32 order=1;
        MATDAT val;
        ee_u32 i=0,j=0;
        if (seed==0)
                seed=1;
        while (j<blksize) {
                i++;
                j=i*i*2*4;
        }
        N=i-1;
        A=(MATDAT *)align_mem(memblk);
        B=A+N*N;

        for (i=0; i<N; i++) {
                for (j=0; j<N; j++) {
                        seed = ( ( order * seed ) % 65536 );
                        val = (seed + order);
                        val=matrix_clip(val,0);
                        B[i*N+j] = val;
                        val =  (val + order);
                        val=matrix_clip(val,1);
                        A[i*N+j] = val;
                        order++;
                }
        }

        p->A=A;
        p->B=B;
        p->C=(MATRES *)align_mem(B+N*N);
        p->N=N;
#if CORE_DEBUG
        printmat(A,N,"A");
        printmat(B,N,"B");
#endif
        return N;
}

/* Function: matrix_sum
        Calculate a function that depends on the values of elements in the matrix.

        For each element, accumulate into a temporary variable.

        As long as this value is under the parameter clipval,
        add 1 to the result if the element is bigger then the previous.

        Otherwise, reset the accumulator and add 10 to the result.
*/
ee_s16 matrix_sum(ee_u32 N, MATRES *C, MATDAT clipval) {
        MATRES tmp=0,prev=0,cur=0;
        ee_s16 ret=0;
        ee_u32 i,j;
        for (i=0; i<N; i++) {
                for (j=0; j<N; j++) {
                        cur=C[i*N+j];
                        tmp+=cur;
                        if (tmp>clipval) {
                                ret+=10;
                                tmp=0;
                        } else {
                                ret += (cur>prev) ? 1 : 0;
                        }
                        prev=cur;
                }
        }
        return ret;
}

/* Function: matrix_mul_const
        Multiply a matrix by a constant.
        This could be used as a scaler for instance.
*/
void matrix_mul_const(ee_u32 N, MATRES *C, MATDAT *A, MATDAT val) {
        ee_u32 i,j;
        for (i=0; i<N; i++) {
                for (j=0; j<N; j++) {
                        C[i*N+j]=(MATRES)A[i*N+j] * (MATRES)val;
                }
        }
}

/* Function: matrix_add_const
        Add a constant value to all elements of a matrix.
*/
void matrix_add_const(ee_u32 N, MATDAT *A, MATDAT val) {
        ee_u32 i,j;
        for (i=0; i<N; i++) {
                for (j=0; j<N; j++) {
                        A[i*N+j] += val;
                }
        }
}

/* Function: matrix_mul_vect
        Multiply a matrix by a vector.
        This is common in many simple filters (e.g. fir where a vector of coefficients is applied to the matrix.)
*/
void matrix_mul_vect(ee_u32 N, MATRES *C, MATDAT *A, MATDAT *B) {
        ee_u32 i,j;
        for (i=0; i<N; i++) {
                C[i]=0;
                for (j=0; j<N; j++) {
                        C[i]+=(MATRES)A[i*N+j] * (MATRES)B[j];
                }
        }
}

/* Function: matrix_mul_matrix
        Multiply a matrix by a matrix.
        Basic code is used in many algorithms, mostly with minor changes such as scaling.
*/
void matrix_mul_matrix(ee_u32 N, MATRES *C, MATDAT *A, MATDAT *B) {
        ee_u32 i,j,k;
        for (i=0; i<N; i++) {
                for (j=0; j<N; j++) {
                        C[i*N+j]=0;
                        for(k=0;k<N;k++)
                        {
                                C[i*N+j]+=(MATRES)A[i*N+k] * (MATRES)B[k*N+j];
                        }
                }
        }
}

/* Function: matrix_mul_matrix_bitextract
        Multiply a matrix by a matrix, and extract some bits from the result.
        Basic code is used in many algorithms, mostly with minor changes such as scaling.
*/
void matrix_mul_matrix_bitextract(ee_u32 N, MATRES *C, MATDAT *A, MATDAT *B) {
        ee_u32 i,j,k;
        for (i=0; i<N; i++) {
                for (j=0; j<N; j++) {
                        C[i*N+j]=0;
                        for(k=0;k<N;k++)
                        {
                                MATRES tmp=(MATRES)A[i*N+k] * (MATRES)B[k*N+j];
                                C[i*N+j]+=bit_extract(tmp,2,4)*bit_extract(tmp,5,7);
                        }
                }
        }
}
/*
Author : Shay Gal-On, EEMBC

This file is part of  EEMBC(R) and CoreMark(TM), which are Copyright (C) 2009
All rights reserved.

EEMBC CoreMark Software is a product of EEMBC and is provided under the terms of the
CoreMark License that is distributed with the official EEMBC COREMARK Software release.
If you received this EEMBC CoreMark Software without the accompanying CoreMark License,
you must discontinue use and download the official release from www.coremark.org.

Also, if you are publicly displaying scores generated from the EEMBC CoreMark software,
make sure that you are in compliance with Run and Reporting rules specified in the accompanying readme.txt file.

EEMBC
4354 Town Center Blvd. Suite 114-200
El Dorado Hills, CA, 95762
*/
//#include "coremark.h"
/* local functions */
enum CORE_STATE core_state_transition( ee_u8 **instr , ee_u32 *transition_count);

/*
Topic: Description
        Simple state machines like this one are used in many embedded products.

        For more complex state machines, sometimes a state transition table implementation is used instead,
        trading speed of direct coding for ease of maintenance.

        Since the main goal of using a state machine in CoreMark is to excercise the switch/if behaviour,
        we are using a small moore machine.

        In particular, this machine tests type of string input,
        trying to determine whether the input is a number or something else.
        (see core_state.png).
*/

/* Function: core_bench_state
        Benchmark function

        Go over the input twice, once direct, and once after introducing some corruption.
*/
ee_u16 core_bench_state(ee_u32 blksize, ee_u8 *memblock,
                ee_s16 seed1, ee_s16 seed2, ee_s16 step, ee_u16 crc)
{
        ee_u32 final_counts[NUM_CORE_STATES];
        ee_u32 track_counts[NUM_CORE_STATES];
        ee_u8 *p=memblock;
        ee_u32 i;


#if CORE_DEBUG
        ee_printf("State Bench: %d,%d,%d,%04x\n",seed1,seed2,step,crc);
#endif
        for (i=0; i<NUM_CORE_STATES; i++) {
                final_counts[i]=track_counts[i]=0;
        }
        /* run the state machine over the input */
        while (*p!=0) {
                enum CORE_STATE fstate=core_state_transition(&p,track_counts);
                final_counts[fstate]++;
#if CORE_DEBUG
        ee_printf("%d,",fstate);
        }
        ee_printf("\n");
#else
        }
#endif
        p=memblock;
        while (p < (memblock+blksize)) { /* insert some corruption */
                if (*p!=',')
                        *p^=(ee_u8)seed1;
                p+=step;
        }
        p=memblock;
        /* run the state machine over the input again */
        while (*p!=0) {
                enum CORE_STATE fstate=core_state_transition(&p,track_counts);
                final_counts[fstate]++;
#if CORE_DEBUG
        ee_printf("%d,",fstate);
        }
        ee_printf("\n");
#else
        }
#endif
        p=memblock;
        while (p < (memblock+blksize)) { /* undo corruption is seed1 and seed2 are equal */
                if (*p!=',')
                        *p^=(ee_u8)seed2;
                p+=step;
        }
        /* end timing */
        for (i=0; i<NUM_CORE_STATES; i++) {
                crc=crcu32(final_counts[i],crc);
                crc=crcu32(track_counts[i],crc);
        }
        return crc;
}

/* Default initialization patterns */
static ee_u8 *intpat[4]  ={(ee_u8 *)"5012",(ee_u8 *)"1234",(ee_u8 *)"-874",(ee_u8 *)"+122"};
static ee_u8 *floatpat[4]={(ee_u8 *)"35.54400",(ee_u8 *)".1234500",(ee_u8 *)"-110.700",(ee_u8 *)"+0.64400"};
static ee_u8 *scipat[4]  ={(ee_u8 *)"5.500e+3",(ee_u8 *)"-.123e-2",(ee_u8 *)"-87e+832",(ee_u8 *)"+0.6e-12"};
static ee_u8 *errpat[4]  ={(ee_u8 *)"T0.3e-1F",(ee_u8 *)"-T.T++Tq",(ee_u8 *)"1T3.4e4z",(ee_u8 *)"34.0e-T^"};

/* Function: core_init_state
        Initialize the input data for the state machine.

        Populate the input with several predetermined strings, interspersed.
        Actual patterns chosen depend on the seed parameter.

        Note:
        The seed parameter MUST be supplied from a source that cannot be determined at compile time
*/
void core_init_state(ee_u32 size, ee_s16 seed, ee_u8 *p) {
        ee_u32 total=0,next=0,i;
        ee_u8 *buf=0;
#if CORE_DEBUG
        ee_u8 *start=p;
        ee_printf("State: %d,%d\n",size,seed);
#endif
        size--;
        next=0;
        while ((total+next+1)<size) {
                if (next>0) {
                        for(i=0;i<next;i++)
                                *(p+total+i)=buf[i];
                        *(p+total+i)=',';
                        total+=next+1;
                }
                seed++;
                switch (seed & 0x7) {
                        case 0: /* int */
                        case 1: /* int */
                        case 2: /* int */
                                buf=intpat[(seed>>3) & 0x3];
                                next=4;
                        break;
                        case 3: /* float */
                        case 4: /* float */
                                buf=floatpat[(seed>>3) & 0x3];
                                next=8;
                        break;
                        case 5: /* scientific */
                        case 6: /* scientific */
                                buf=scipat[(seed>>3) & 0x3];
                                next=8;
                        break;
                        case 7: /* invalid */
                                buf=errpat[(seed>>3) & 0x3];
                                next=8;
                        break;
                        default: /* Never happen, just to make some compilers happy */
                        break;
                }
        }
        size++;
        while (total<size) { /* fill the rest with 0 */
                *(p+total)=0;
                total++;
        }
#if CORE_DEBUG
        ee_printf("State Input: %s\n",start);
#endif
}

static ee_u8 ee_isdigit(ee_u8 c) {
        ee_u8 retval;
        retval = ((c>='0') & (c<='9')) ? 1 : 0;
        return retval;
}

/* Function: core_state_transition
        Actual state machine.

        The state machine will continue scanning until either:
        1 - an invalid input is detcted.
        2 - a valid number has been detected.

        The input pointer is updated to point to the end of the token, and the end state is returned (either specific format determined or invalid).
*/

enum CORE_STATE core_state_transition( ee_u8 **instr , ee_u32 *transition_count) {
        ee_u8 *str=*instr;
        ee_u8 NEXT_SYMBOL;
        enum CORE_STATE state=CORE_START;
        for( ; *str && state != CORE_INVALID; str++ ) {
                NEXT_SYMBOL = *str;
                if (NEXT_SYMBOL==',') /* end of this input */ {
                        str++;
                        break;
                }
                switch(state) {
                case CORE_START:
                        if(ee_isdigit(NEXT_SYMBOL)) {
                                state = CORE_INT;
                        }
                        else if( NEXT_SYMBOL == '+' || NEXT_SYMBOL == '-' ) {
                                state = CORE_S1;
                        }
                        else if( NEXT_SYMBOL == '.' ) {
                                state = CORE_FLOAT;
                        }
                        else {
                                state = CORE_INVALID;
                                transition_count[CORE_INVALID]++;
                        }
                        transition_count[CORE_START]++;
                        break;
                case CORE_S1:
                        if(ee_isdigit(NEXT_SYMBOL)) {
                                state = CORE_INT;
                                transition_count[CORE_S1]++;
                        }
                        else if( NEXT_SYMBOL == '.' ) {
                                state = CORE_FLOAT;
                                transition_count[CORE_S1]++;
                        }
                        else {
                                state = CORE_INVALID;
                                transition_count[CORE_S1]++;
                        }
                        break;
                case CORE_INT:
                        if( NEXT_SYMBOL == '.' ) {
                                state = CORE_FLOAT;
                                transition_count[CORE_INT]++;
                        }
                        else if(!ee_isdigit(NEXT_SYMBOL)) {
                                state = CORE_INVALID;
                                transition_count[CORE_INT]++;
                        }
                        break;
                case CORE_FLOAT:
                        if( NEXT_SYMBOL == 'E' || NEXT_SYMBOL == 'e' ) {
                                state = CORE_S2;
                                transition_count[CORE_FLOAT]++;
                        }
                        else if(!ee_isdigit(NEXT_SYMBOL)) {
                                state = CORE_INVALID;
                                transition_count[CORE_FLOAT]++;
                        }
                        break;
                case CORE_S2:
                        if( NEXT_SYMBOL == '+' || NEXT_SYMBOL == '-' ) {
                                state = CORE_EXPONENT;
                                transition_count[CORE_S2]++;
                        }
                        else {
                                state = CORE_INVALID;
                                transition_count[CORE_S2]++;
                        }
                        break;
                case CORE_EXPONENT:
                        if(ee_isdigit(NEXT_SYMBOL)) {
                                state = CORE_SCIENTIFIC;
                                transition_count[CORE_EXPONENT]++;
                        }
                        else {
                                state = CORE_INVALID;
                                transition_count[CORE_EXPONENT]++;
                        }
                        break;
                case CORE_SCIENTIFIC:
                        if(!ee_isdigit(NEXT_SYMBOL)) {
                                state = CORE_INVALID;
                                transition_count[CORE_INVALID]++;
                        }
                        break;
                default:
                        break;
                }
        }
        *instr=str;
        return state;
}
/*
Author : Shay Gal-On, EEMBC

This file is part of  EEMBC(R) and CoreMark(TM), which are Copyright (C) 2009
All rights reserved.

EEMBC CoreMark Software is a product of EEMBC and is provided under the terms of the
CoreMark License that is distributed with the official EEMBC COREMARK Software release.
If you received this EEMBC CoreMark Software without the accompanying CoreMark License,
you must discontinue use and download the official release from www.coremark.org.

Also, if you are publicly displaying scores generated from the EEMBC CoreMark software,
make sure that you are in compliance with Run and Reporting rules specified in the accompanying readme.txt file.

EEMBC
4354 Town Center Blvd. Suite 114-200
El Dorado Hills, CA, 95762
*/
//#include "coremark.h"
/* Function: get_seed
        Get a values that cannot be determined at compile time.

        Since different embedded systems and compilers are used, 3 different methods are provided:
        1 - Using a volatile variable. This method is only valid if the compiler is forced to generate code that
        reads the value of a volatile variable from memory at run time.
        Please note, if using this method, you would need to modify core_portme.c to generate training profile.
        2 - Command line arguments. This is the preferred method if command line arguments are supported.
        3 - System function. If none of the first 2 methods is available on the platform,
        a system function which is not a stub can be used.

        e.g. read the value on GPIO pins connected to switches, or invoke special simulator functions.
*/
#if (SEED_METHOD==SEED_VOLATILE)
        extern volatile ee_s32 seed1_volatile;
        extern volatile ee_s32 seed2_volatile;
        extern volatile ee_s32 seed3_volatile;
        extern volatile ee_s32 seed4_volatile;
        extern volatile ee_s32 seed5_volatile;
        ee_s32 get_seed_32(int i) {
                ee_s32 retval;
                switch (i) {
                        case 1:
                                retval=seed1_volatile;
                                break;
                        case 2:
                                retval=seed2_volatile;
                                break;
                        case 3:
                                retval=seed3_volatile;
                                break;
                        case 4:
                                retval=seed4_volatile;
                                break;
                        case 5:
                                retval=seed5_volatile;
                                break;
                        default:
                                retval=0;
                                break;
                }
                return retval;
        }
#elif (SEED_METHOD==SEED_ARG)
ee_s32 parseval(char *valstring) {
        ee_s32 retval=0;
        ee_s32 neg=1;
        int hexmode=0;
        if (*valstring == '-') {
                neg=-1;
                valstring++;
        }
        if ((valstring[0] == '0') && (valstring[1] == 'x')) {
                hexmode=1;
                valstring+=2;
        }
                /* first look for digits */
        if (hexmode) {
                while (((*valstring >= '0') && (*valstring <= '9')) || ((*valstring >= 'a') && (*valstring <= 'f'))) {
                        ee_s32 digit=*valstring-'0';
                        if (digit>9)
                                digit=10+*valstring-'a';
                        retval*=16;
                        retval+=digit;
                        valstring++;
                }
        } else {
                while ((*valstring >= '0') && (*valstring <= '9')) {
                        ee_s32 digit=*valstring-'0';
                        retval*=10;
                        retval+=digit;
                        valstring++;
                }
        }
        /* now add qualifiers */
        if (*valstring=='K')
                retval*=1024;
        if (*valstring=='M')
                retval*=1024*1024;

        retval*=neg;
        return retval;
}

ee_s32 get_seed_args(int i, int argc, char *argv[]) {
        if (argc>i)
                return parseval(argv[i]);
        return 0;
}

#elif (SEED_METHOD==SEED_FUNC)
/* If using OS based function, you must define and implement the functions below in core_portme.h and core_portme.c ! */
ee_s32 get_seed_32(int i) {
        ee_s32 retval;
        switch (i) {
                case 1:
                        retval=portme_sys1();
                        break;
                case 2:
                        retval=portme_sys2();
                        break;
                case 3:
                        retval=portme_sys3();
                        break;
                case 4:
                        retval=portme_sys4();
                        break;
                case 5:
                        retval=portme_sys5();
                        break;
                default:
                        retval=0;
                        break;
        }
        return retval;
}
#endif

/* Function: crc*
        Service functions to calculate 16b CRC code.

*/
ee_u16 crcu8(ee_u8 data, ee_u16 crc )
{
        ee_u8 i=0,x16=0,carry=0;

        for (i = 0; i < 8; i++)
    {
                x16 = (ee_u8)((data & 1) ^ ((ee_u8)crc & 1));
                data >>= 1;

                if (x16 == 1)
                {
                   crc ^= 0x4002;
                   carry = 1;
                }
                else
                        carry = 0;
                crc >>= 1;
                if (carry)
                   crc |= 0x8000;
                else
                   crc &= 0x7fff;
    }
        return crc;
}
ee_u16 crcu16(ee_u16 newval, ee_u16 crc) {
        crc=crcu8( (ee_u8) (newval)                             ,crc);
        crc=crcu8( (ee_u8) ((newval)>>8)        ,crc);
        return crc;
}
ee_u16 crcu32(ee_u32 newval, ee_u16 crc) {
        crc=crc16((ee_s16) newval               ,crc);
        crc=crc16((ee_s16) (newval>>16) ,crc);
        return crc;
}
ee_u16 crc16(ee_s16 newval, ee_u16 crc) {
        return crcu16((ee_u16)newval, crc);
}

ee_u8 check_data_types() {
        ee_u8 retval=0;
        if (sizeof(ee_u8) != 1) {
                ee_printf("ERROR: ee_u8 is not an 8b datatype!\n");
                retval++;
        }
        if (sizeof(ee_u16) != 2) {
                ee_printf("ERROR: ee_u16 is not a 16b datatype!\n");
                retval++;
        }
        if (sizeof(ee_s16) != 2) {
                ee_printf("ERROR: ee_s16 is not a 16b datatype!\n");
                retval++;
        }
        if (sizeof(ee_s32) != 4) {
                ee_printf("ERROR: ee_s32 is not a 32b datatype!\n");
                retval++;
        }
        if (sizeof(ee_u32) != 4) {
                ee_printf("ERROR: ee_u32 is not a 32b datatype!\n");
                retval++;
        }
        if (sizeof(ee_ptr_int) != sizeof(int *)) {
                ee_printf("ERROR: ee_ptr_int is not a datatype that holds an int pointer!\n");
                retval++;
        }
        if (retval>0) {
                ee_printf("ERROR: Please modify the datatypes in core_portme.h!\n");
        }
        return retval;
}
/*
        File : core_portme.c
*/
/*
        Author : Shay Gal-On, EEMBC
        Legal : TODO!
*/
#include <stdio.h>
#include <stdlib.h>
//#include "coremark.h"

#if VALIDATION_RUN
        volatile ee_s32 seed1_volatile=0x3415;
        volatile ee_s32 seed2_volatile=0x3415;
        volatile ee_s32 seed3_volatile=0x66;
#endif
#if PERFORMANCE_RUN
        volatile ee_s32 seed1_volatile=0x0;
        volatile ee_s32 seed2_volatile=0x0;
        volatile ee_s32 seed3_volatile=0x66;
#endif
#if PROFILE_RUN
        volatile ee_s32 seed1_volatile=0x8;
        volatile ee_s32 seed2_volatile=0x8;
        volatile ee_s32 seed3_volatile=0x8;
#endif
        volatile ee_s32 seed4_volatile=ITERATIONS;
        volatile ee_s32 seed5_volatile=0;
/* Porting : Timing functions
        How to capture time and convert to seconds must be ported to whatever is supported by the platform.
        e.g. Read value from on board RTC, read value from cpu clock cycles performance counter etc.
        Sample implementation for standard time.h and windows.h definitions included.
*/
/* Define : TIMER_RES_DIVIDER
        Divider to trade off timer resolution and total time that can be measured.

        Use lower values to increase resolution, but make sure that overflow does not occur.
        If there are issues with the return value overflowing, increase this value.
        */
//#define NSECS_PER_SEC CLOCKS_PER_SEC
#define NSECS_PER_SEC 1000000000
#define CORETIMETYPE clock_t
//#define GETMYTIME(_t) (*_t=clock())
#define GETMYTIME(_t) (*_t=0)
#define MYTIMEDIFF(fin,ini) ((fin)-(ini))
#define TIMER_RES_DIVIDER 1
#define SAMPLE_TIME_IMPLEMENTATION 1
//#define EE_TICKS_PER_SEC (NSECS_PER_SEC / TIMER_RES_DIVIDER)

#define EE_TICKS_PER_SEC 1000

/** Define Host specific (POSIX), or target specific global time variables. */
static CORETIMETYPE start_time_val, stop_time_val;

/* Function : start_time
        This function will be called right before starting the timed portion of the benchmark.

        Implementation may be capturing a system timer (as implemented in the example code)
        or zeroing some system parameters - e.g. setting the cpu clocks cycles to 0.
*/
void start_time(void) {
uint32_t mcyclel;
        asm volatile ("csrr %0,mcycle"  : "=r" (mcyclel) );
        start_time_val = mcyclel;
}
/* Function : stop_time
        This function will be called right after ending the timed portion of the benchmark.

        Implementation may be capturing a system timer (as implemented in the example code)
        or other system parameters - e.g. reading the current value of cpu cycles counter.
*/
void stop_time(void) {
uint32_t mcyclel;
        asm volatile ("csrr %0,mcycle"  : "=r" (mcyclel) );
        stop_time_val = mcyclel;
}
/* Function : get_time
        Return an abstract "ticks" number that signifies time on the system.

        Actual value returned may be cpu cycles, milliseconds or any other value,
        as long as it can be converted to seconds by <time_in_secs>.
        This methodology is taken to accomodate any hardware or simulated platform.
        The sample implementation returns millisecs by default,
        and the resolution is controlled by <TIMER_RES_DIVIDER>
*/
CORE_TICKS get_time(void) {
        CORE_TICKS elapsed=(CORE_TICKS)(MYTIMEDIFF(stop_time_val, start_time_val));
        return elapsed;
}
/* Function : time_in_secs
        Convert the value returned by get_time to seconds.

        The <secs_ret> type is used to accomodate systems with no support for floating point.
        Default implementation implemented by the EE_TICKS_PER_SEC macro above.
*/
secs_ret time_in_secs(CORE_TICKS ticks) {
        secs_ret retval=((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
        return retval;
}

ee_u32 default_num_contexts=1;

/* Function : portable_init
        Target specific initialization code
        Test for some common mistakes.
*/
void portable_init(core_portable *p, int *argc, char *argv[])
{
        if (sizeof(ee_ptr_int) != sizeof(ee_u8 *)) {
                ee_printf("ERROR! Please define ee_ptr_int to a type that holds a pointer!\n");
        }
        if (sizeof(ee_u32) != 4) {
                ee_printf("ERROR! Please define ee_u32 to a 32b unsigned type!\n");
        }
        p->portable_id=1;
}
/* Function : portable_fini
        Target specific final code
*/
void portable_fini(core_portable *p)
{
        p->portable_id=0;
}


#include <stdarg.h>

// Special address. Writing (store byte instruction) to this address
// causes the simulator to write to the console.
volatile char __whisper_console_io = 0;


static int
whisperPutc(char c)
{
//  __whisper_console_io = c;
//  __whisper_console_io = c;
  *(volatile char*)(STDOUT) = c;
  return c;
}


static int
whisperPuts(const char* s)
{
  while (*s)
    whisperPutc(*s++);
  return 1;
}


static int
whisperPrintDecimal(int value)
{
  char buffer[20];
  int charCount = 0;

  unsigned neg = value < 0;
  if (neg)
    {
      value = -value;
      whisperPutc('-');
    }

  do
    {
      char c = '0' + (value % 10);
      value = value / 10;
      buffer[charCount++] = c;
    }
  while (value);

  char* p = buffer + charCount - 1;
  for (unsigned i = 0; i < charCount; ++i)
    whisperPutc(*p--);

  if (neg)
    charCount++;

  return charCount;
}


static int
whisperPrintInt(int value, int base)
{
  if (base == 10)
    return whisperPrintDecimal(value);

  char buffer[20];
  int charCount = 0;

  unsigned uu = value;

  if (base == 8)
    {
      do
        {
          char c = '0' + (uu & 7);
          buffer[charCount++] = c;
          uu >>= 3;
        }
      while (uu);
    }
  else if (base == 16)
    {
      do
        {
          int digit = uu & 0xf;
          char c = digit < 10 ? '0' + digit : 'a' + digit;
          buffer[charCount++] = c;
          uu >>= 4;
        }
      while (uu);
    }
  else
    return -1;

  char* p = buffer + charCount - 1;
  for (unsigned i = 0; i < charCount; ++i)
    whisperPutc(*p--);

  return charCount;
}


int
whisperPrintfImpl(const char* format, va_list ap)
{
  int count = 0;  // Printed character count

  for (const char* fp = format; *fp; fp++)
    {
      if (*fp != '%')
        {
          whisperPutc(*fp);
          ++count;
          continue;
        }

      ++fp;  // Skip %

      if (*fp == 0)
        break;

      if (*fp == '%')
        {
          whisperPutc('%');
          continue;
        }

      if (*fp == '-')
        {
          fp++;  // Pad right not yet implemented.
        }

      while (*fp == '0')
        {
          fp++;  // Pad zero not yet implented.
        }

      if (*fp == '*')
        {
          int width = va_arg(ap, int);
          fp++;  // Width not yet implemented.
        }
      else
        {
          while (*fp >= '0' && *fp <= '9')
            ++fp;   // Width not yet implemented.
        }

      switch (*fp)
        {
        case 'd':
          count += whisperPrintDecimal(va_arg(ap, int));
          break;

        case 'u':
          count += whisperPrintDecimal((unsigned) va_arg(ap, unsigned));
          break;

        case 'x':
        case 'X':
          count += whisperPrintInt(va_arg(ap, int), 16);
          break;

        case 'o':
          count += whisperPrintInt(va_arg(ap, int), 8);
          break;

        case 'c':
          whisperPutc(va_arg(ap, int));
          ++count;
          break;

        case 's':
          count += whisperPuts(va_arg(ap, char*));
          break;
        }
    }

  return count;
}


int
whisperPrintf(const char* format, ...)
{
  va_list ap;

  va_start(ap, format);
  int code = whisperPrintfImpl(format, ap);
  va_end(ap);

  return code;
}


int
printf(const char* format, ...)
{
  va_list ap;

  va_start(ap, format);
  int code = whisperPrintfImpl(format, ap);
  va_end(ap);

  return code;
}


void* memset(void* s, int c, size_t n)
{
  asm("mv t0, a0");
  asm("add a2, a2, a0");  // end = s + n
  asm(".memset_loop: bge a0, a2, .memset_end");
  asm("sb a1, 0(a0)");
  asm("addi a0, a0, 1");
  asm("j .memset_loop");
  asm(".memset_end:");
  asm("mv a0, t0");
  asm("jr ra");
}
