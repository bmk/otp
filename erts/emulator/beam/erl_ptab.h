/*
 * %CopyrightBegin%
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Copyright Ericsson AB 2012-2025. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * %CopyrightEnd%
 */

/*
 * Description:	Process/Port table implementation.
 *
 * Author: 	Rickard Green
 */

#ifndef ERL_PTAB_H__
#define ERL_PTAB_H__

#include "sys.h"
#include "erl_term.h"
#include "erl_time.h"
#include "erl_utils.h"
#define ERL_THR_PROGRESS_TSD_TYPE_ONLY
#include "erl_thr_progress.h"
#undef ERL_THR_PROGRESS_TSD_TYPE_ONLY
#include "erl_alloc.h"
#include "erl_monitor_link.h"

typedef struct ErtsTracerRef {
    struct ErtsTracerRef *next;
    struct ErtsTraceSession *session;
    ErtsTracer tracer;
    Uint32 flags;
} ErtsTracerRef;

typedef struct ErtsTracee_ {
    Uint32 all_trace_flags;
    ErtsTracerRef *first_ref;
} ErtsTracee;

#define ERTS_TRACER_MODULE(T) 	(is_internal_pid(T) ? am_erl_tracer : CAR(list_val(T)))
#define ERTS_TRACER_STATE(T) 	(is_internal_pid(T) ? T : CDR(list_val(T)))

#define ERTS_P_LINKS(P)		((P)->common.u.alive.links)
#define ERTS_P_MONITORS(P)	((P)->common.u.alive.monitors)
#define ERTS_P_LT_MONITORS(P)	((P)->common.u.alive.lt_monitors)

#define IS_SESSION_TRACED_FL(ref,tf) \
    ((ref)->tracer != NIL && (ref->flags & (tf)) == (tf))

#define IS_SESSION_TRACED_ANY_FL(ref,tf) \
    ((ref)->tracer != NIL && (ref->flags & (tf)))

#define ERTS_IS_P_TRACED(p) \
    ((p)->common.tracee.all_trace_flags & ~F_SENSITIVE)

#define ERTS_IS_P_TRACED_FL(p, tf) \
    ((p)->common.tracee.all_trace_flags & (tf))

#define ERTS_P_ALL_TRACE_FLAGS(p) ((p)->common.tracee.all_trace_flags)

#define ERTS_IS_PROC_SENSITIVE(p) \
    ((p)->common.tracee.all_trace_flags & F_SENSITIVE)


typedef struct {
    Eterm id;
    union {
	erts_atomic_t atmc;
	Sint sint;
    } refc;
    erts_atomic_t timer;
    union {
	/* --- While being alive --- */
	struct {
	    Uint64 started_interval;
	    struct reg_proc *reg;
	    ErtsLink *links;
             /* Local target monitors, double linked list
                contains the remote part of local monitors  */
            ErtsMonitor *lt_monitors;
             /* other monitors, rb tree */
	    ErtsMonitor *monitors;
	} alive;

	/* --- While being released --- */
	ErtsThrPrgrLaterOp release;
    } u;
    ErtsTracee tracee;
} ErtsPTabElementCommon;

typedef struct ErtsPTabDeletedElement_ ErtsPTabDeletedElement;

typedef struct {
    erts_rwmtx_t rwmtx;
    erts_interval_t interval;
    struct {
	ErtsPTabDeletedElement *start;
	ErtsPTabDeletedElement *end;
    } deleted;
    int chunks;
} ErtsPTabListData;

typedef struct {
    erts_atomic64_t last_data;
    erts_atomic32_t count;
    erts_atomic32_t aid_ix;
    erts_atomic32_t fid_ix;
} ErtsPTabVolatileData;

typedef struct {
    erts_atomic_t *tab;
    erts_atomic_t *free_id_data;
    Uint32 max;
    Uint pix_mask;
    Uint pix_cl_mask;
    Uint pix_cli_mask;
    Uint32 pix_cl_shift;
    Uint32 pix_cli_shift;
    Uint dix_cl_mask;
    Uint dix_cli_mask;
    Uint32 dix_cl_shift;
    Uint32 dix_cli_shift;
    ErtsPTabElementCommon *invalid_element;
    Eterm invalid_data;
    void (*release_element)(void *);
    UWord element_size;
    int atomic_refc;
} ErtsPTabReadOnlyData;

typedef struct {
    /*
     * Data mainly modified when someone is listing
     * the content of the table.
     */
    union {
	ErtsPTabListData data;
	char algn[ERTS_ALC_CACHE_LINE_ALIGN_SIZE(sizeof(ErtsPTabListData))];
    } list;

    /*
     * Frequently modified data.
     */
    union {
	ErtsPTabVolatileData tile;
	char algn[ERTS_ALC_CACHE_LINE_ALIGN_SIZE(sizeof(ErtsPTabVolatileData))];
    } vola;

    /*
     * Read only data.
     */
    union {
	ErtsPTabReadOnlyData o;
	char algn[ERTS_ALC_CACHE_LINE_ALIGN_SIZE(sizeof(ErtsPTabReadOnlyData))];
    } r;
} ErtsPTab;

#define ERTS_PTAB_ID_DATA_SIZE	(ERTS_SIZEOF_TERM*8 - _TAG_IMMED1_SIZE)
#define ERTS_PTAB_ID_DATA_SHIFT	(_TAG_IMMED1_SIZE)
/* ERTS_PTAB_MAX_SIZE must be a power of 2 */
#define ERTS_PTAB_MAX_SIZE (UWORD_CONSTANT(1) << 27)
#if (ERTS_PTAB_MAX_SIZE-1) > MAX_SMALL
# error "The maximum number of processes/ports must fit in a SMALL."
#endif


/*
 * Currently pids and ports are allowed.
 */
#if _PID_DATA_SIZE != ERTS_PTAB_ID_DATA_SIZE
# error "Unexpected pid data size"
#endif
#if _PID_DATA_SHIFT != ERTS_PTAB_ID_DATA_SHIFT
# error "Unexpected pid tag size"
#endif
#if _PORT_DATA_SIZE != ERTS_PTAB_ID_DATA_SIZE
# error "Unexpected port data size"
#endif
#if _PORT_DATA_SHIFT != ERTS_PTAB_ID_DATA_SHIFT
# error "Unexpected port tag size"
#endif

#define ERTS_PTAB_INVALID_ID(TAG)					\
    ((Eterm)								\
     ((((UWORD_CONSTANT(1) << ERTS_PTAB_ID_DATA_SIZE) - 1)              \
       << ERTS_PTAB_ID_DATA_SHIFT)                                      \
      | (TAG)))

#define erts_ptab_is_valid_id(ID)					\
    (is_internal_pid((ID)) || is_internal_port((ID)))

void erts_ptab_init(void);
void erts_ptab_init_table(ErtsPTab *ptab,
			  ErtsAlcType_t atype,
			  void (*release_element)(void *),
			  ErtsPTabElementCommon *invalid_element,
			  int size,
			  UWord element_size,
			  char *name,
			  int legacy,
			  int atomic_refc);
int erts_ptab_new_element(ErtsPTab *ptab,
			  ErtsPTabElementCommon *ptab_el,
			  void *init_arg,
			  void (*init_ptab_el)(void *, Eterm));
void erts_ptab_delete_element(ErtsPTab *ptab,
			      ErtsPTabElementCommon *ptab_el);
int erts_ptab_initialized(ErtsPTab *ptab);
UWord erts_ptab_mem_size(ErtsPTab *ptab);

ERTS_GLB_INLINE erts_interval_t *erts_ptab_interval(ErtsPTab *ptab);
ERTS_GLB_INLINE int erts_ptab_max(ErtsPTab *ptab);
ERTS_GLB_INLINE int erts_ptab_count(ErtsPTab *ptab);
ERTS_GLB_INLINE Uint erts_ptab_pixdata2data(ErtsPTab *ptab, Eterm pixdata);
ERTS_GLB_INLINE Uint erts_ptab_pixdata2pix(ErtsPTab *ptab, Eterm pixdata);
ERTS_GLB_INLINE Uint erts_ptab_data2pix(ErtsPTab *ptab, Eterm data);
ERTS_GLB_INLINE Uint erts_ptab_data2pixdata(ErtsPTab *ptab, Eterm data);
ERTS_GLB_INLINE Eterm erts_ptab_make_id(ErtsPTab *ptab, Eterm data, Eterm tag);
ERTS_GLB_INLINE int erts_ptab_id2pix(ErtsPTab *ptab, Eterm id);
ERTS_GLB_INLINE Uint erts_ptab_id2data(ErtsPTab *ptab, Eterm id);
ERTS_GLB_INLINE erts_aint_t erts_ptab_pix2intptr_nob(ErtsPTab *ptab, int ix);
ERTS_GLB_INLINE erts_aint_t erts_ptab_pix2intptr_ddrb(ErtsPTab *ptab, int ix);
ERTS_GLB_INLINE erts_aint_t erts_ptab_pix2intptr_rb(ErtsPTab *ptab, int ix);
ERTS_GLB_INLINE erts_aint_t erts_ptab_pix2intptr_acqb(ErtsPTab *ptab, int ix);
ERTS_GLB_INLINE void erts_ptab_inc_refc(ErtsPTabElementCommon *ptab_el);
ERTS_GLB_INLINE Sint erts_ptab_dec_test_refc(ErtsPTabElementCommon *ptab_el);
ERTS_GLB_INLINE Sint erts_ptab_add_test_refc(ErtsPTabElementCommon *ptab_el,
					     Sint add_refc);
ERTS_GLB_INLINE Sint erts_ptab_read_refc(ErtsPTabElementCommon *ptab_el);
ERTS_GLB_INLINE void erts_ptab_atmc_inc_refc(ErtsPTabElementCommon *ptab_el);
ERTS_GLB_INLINE Sint erts_ptab_atmc_dec_test_refc(ErtsPTabElementCommon *ptab_el);
ERTS_GLB_INLINE Sint erts_ptab_atmc_add_test_refc(ErtsPTabElementCommon *ptab_el,
						  Sint add_refc);
ERTS_GLB_INLINE Sint erts_ptab_atmc_read_refc(ErtsPTabElementCommon *ptab_el);
ERTS_GLB_INLINE void erts_ptab_rlock(ErtsPTab *ptab);
ERTS_GLB_INLINE int erts_ptab_tryrlock(ErtsPTab *ptab);
ERTS_GLB_INLINE void erts_ptab_runlock(ErtsPTab *ptab);
ERTS_GLB_INLINE void erts_ptab_rwlock(ErtsPTab *ptab);
ERTS_GLB_INLINE int erts_ptab_tryrwlock(ErtsPTab *ptab);
ERTS_GLB_INLINE void erts_ptab_rwunlock(ErtsPTab *ptab);
ERTS_GLB_INLINE int erts_lc_ptab_is_rlocked(ErtsPTab *ptab);
ERTS_GLB_INLINE int erts_lc_ptab_is_rwlocked(ErtsPTab *ptab);

#if ERTS_GLB_INLINE_INCL_FUNC_DEF

ERTS_GLB_INLINE erts_interval_t *
erts_ptab_interval(ErtsPTab *ptab)
{
    return &ptab->list.data.interval;
}

ERTS_GLB_INLINE int
erts_ptab_max(ErtsPTab *ptab)
{
    int max = ptab->r.o.max;
    return max == ERTS_PTAB_MAX_SIZE ? max - 1 : max;
}

ERTS_GLB_INLINE int
erts_ptab_count(ErtsPTab *ptab)
{
    int max = ptab->r.o.max;
    erts_aint32_t res = erts_atomic32_read_nob(&ptab->vola.tile.count);
    if (max == ERTS_PTAB_MAX_SIZE) {
	max--;
	res--;
    }
    if (res > max)
	return max;
    ASSERT(res >= 0);
    return (int) res;

}

ERTS_GLB_INLINE Uint erts_ptab_pixdata2data(ErtsPTab *ptab, Eterm pixdata)
{
    Uint data = ((Uint) pixdata) & ~ptab->r.o.pix_mask;
    data |= (pixdata >> ptab->r.o.pix_cl_shift) & ptab->r.o.pix_cl_mask;
    data |= (pixdata & ptab->r.o.pix_cli_mask) << ptab->r.o.pix_cli_shift;
    return data;
}

ERTS_GLB_INLINE Uint erts_ptab_pixdata2pix(ErtsPTab *ptab, Eterm pixdata)
{
    return ((Uint) pixdata) & ptab->r.o.pix_mask;
}

ERTS_GLB_INLINE Uint erts_ptab_data2pix(ErtsPTab *ptab, Eterm data)
{
    Uint n, pix;
    n = (Uint) data;
    pix = ((n & ptab->r.o.pix_cl_mask) << ptab->r.o.pix_cl_shift);
    pix += ((n >> ptab->r.o.pix_cli_shift) & ptab->r.o.pix_cli_mask);
    ASSERT(0 <= pix && pix < ptab->r.o.max);
    return pix;
}

ERTS_GLB_INLINE Uint erts_ptab_data2pixdata(ErtsPTab *ptab, Eterm data)
{
    Uint pixdata = data & ~((Uint) ptab->r.o.pix_mask);
    pixdata |= (Uint) erts_ptab_data2pix(ptab, data);
    ASSERT(data == erts_ptab_pixdata2data(ptab, pixdata));
    return pixdata;
}

ERTS_GLB_INLINE Eterm
erts_ptab_make_id(ErtsPTab *ptab, Eterm data, Eterm tag)
{
    Eterm id;
    data &= ((UWORD_CONSTANT(1) << ERTS_PTAB_ID_DATA_SIZE) - 1);
    id = (Eterm) erts_ptab_data2pixdata(ptab, data);
    return (id << ERTS_PTAB_ID_DATA_SHIFT) | tag;
}

ERTS_GLB_INLINE int
erts_ptab_id2pix(ErtsPTab *ptab, Eterm id)
{
    Uint pixdata = (Uint) id;
    pixdata >>= ERTS_PTAB_ID_DATA_SHIFT;
    return (int) erts_ptab_pixdata2pix(ptab, pixdata);
}

ERTS_GLB_INLINE Uint
erts_ptab_id2data(ErtsPTab *ptab, Eterm id)
{
    Uint pixdata = (Uint) id;
    pixdata >>= ERTS_PTAB_ID_DATA_SHIFT;
    return erts_ptab_pixdata2data(ptab, pixdata);
}

ERTS_GLB_INLINE erts_aint_t erts_ptab_pix2intptr_nob(ErtsPTab *ptab, int ix)
{
    ASSERT(0 <= ix && ix < ptab->r.o.max);
    return erts_atomic_read_nob(&ptab->r.o.tab[ix]);
}

ERTS_GLB_INLINE erts_aint_t erts_ptab_pix2intptr_ddrb(ErtsPTab *ptab, int ix)
{
    ASSERT(0 <= ix && ix < ptab->r.o.max);
    return erts_atomic_read_ddrb(&ptab->r.o.tab[ix]);
}

ERTS_GLB_INLINE erts_aint_t erts_ptab_pix2intptr_rb(ErtsPTab *ptab, int ix)
{
    ASSERT(0 <= ix && ix < ptab->r.o.max);
    return erts_atomic_read_rb(&ptab->r.o.tab[ix]);
}

ERTS_GLB_INLINE erts_aint_t erts_ptab_pix2intptr_acqb(ErtsPTab *ptab, int ix)
{
    ASSERT(0 <= ix && ix < ptab->r.o.max);
    return erts_atomic_read_acqb(&ptab->r.o.tab[ix]);
}

ERTS_GLB_INLINE void erts_ptab_atmc_inc_refc(ErtsPTabElementCommon *ptab_el)
{
#ifdef ERTS_ENABLE_LOCK_CHECK
    erts_aint_t refc = erts_atomic_inc_read_nob(&ptab_el->refc.atmc);
    ERTS_LC_ASSERT(refc > 1);
#else
    erts_atomic_inc_nob(&ptab_el->refc.atmc);
#endif
}

ERTS_GLB_INLINE Sint erts_ptab_atmc_dec_test_refc(ErtsPTabElementCommon *ptab_el)
{
    erts_aint_t refc = erts_atomic_dec_read_relb(&ptab_el->refc.atmc);
    ERTS_LC_ASSERT(refc >= 0);
    if (refc == 0)
	ETHR_MEMBAR(ETHR_LoadLoad|ETHR_LoadStore);
    return (Sint) refc;
}

ERTS_GLB_INLINE Sint erts_ptab_atmc_add_test_refc(ErtsPTabElementCommon *ptab_el,
						  Sint add_refc)
{
    erts_aint_t refc = erts_atomic_add_read_mb(&ptab_el->refc.atmc,
					       (erts_aint_t) add_refc);
    ERTS_LC_ASSERT(refc >= 0);
    return (Sint) refc;
}

ERTS_GLB_INLINE Sint erts_ptab_atmc_read_refc(ErtsPTabElementCommon *ptab_el)
{
    return (Sint) erts_atomic_read_nob(&ptab_el->refc.atmc);
}

ERTS_GLB_INLINE void erts_ptab_inc_refc(ErtsPTabElementCommon *ptab_el)
{
    ptab_el->refc.sint++;
    ASSERT(ptab_el->refc.sint > 1);
}

ERTS_GLB_INLINE Sint erts_ptab_dec_test_refc(ErtsPTabElementCommon *ptab_el)
{
    Sint refc = --ptab_el->refc.sint;
    ERTS_LC_ASSERT(refc >= 0);
    return refc;
}

ERTS_GLB_INLINE Sint erts_ptab_add_test_refc(ErtsPTabElementCommon *ptab_el,
					     Sint add_refc)
{
    ptab_el->refc.sint += add_refc;
    ERTS_LC_ASSERT(ptab_el->refc.sint >= 0);
    return (Sint) ptab_el->refc.sint;
}

ERTS_GLB_INLINE Sint erts_ptab_read_refc(ErtsPTabElementCommon *ptab_el)
{
    return ptab_el->refc.sint;
}

ERTS_GLB_INLINE void erts_ptab_rlock(ErtsPTab *ptab)
{
    erts_rwmtx_rlock(&ptab->list.data.rwmtx);
}

ERTS_GLB_INLINE int erts_ptab_tryrlock(ErtsPTab *ptab)
{
    return erts_rwmtx_tryrlock(&ptab->list.data.rwmtx);
}

ERTS_GLB_INLINE void erts_ptab_runlock(ErtsPTab *ptab)
{
    erts_rwmtx_runlock(&ptab->list.data.rwmtx);
}

ERTS_GLB_INLINE void erts_ptab_rwlock(ErtsPTab *ptab)
{
    erts_rwmtx_rwlock(&ptab->list.data.rwmtx);
}

ERTS_GLB_INLINE int erts_ptab_tryrwlock(ErtsPTab *ptab)
{
    return erts_rwmtx_tryrwlock(&ptab->list.data.rwmtx);
}

ERTS_GLB_INLINE void erts_ptab_rwunlock(ErtsPTab *ptab)
{
    erts_rwmtx_rwunlock(&ptab->list.data.rwmtx);
}

ERTS_GLB_INLINE int erts_lc_ptab_is_rlocked(ErtsPTab *ptab)
{
    return erts_lc_rwmtx_is_rlocked(&ptab->list.data.rwmtx);
}

ERTS_GLB_INLINE int erts_lc_ptab_is_rwlocked(ErtsPTab *ptab)
{
    return erts_lc_rwmtx_is_rwlocked(&ptab->list.data.rwmtx);
}

#endif

#endif

#if defined(ERTS_PTAB_WANT_BIF_IMPL__) && !defined(ERTS_PTAB_LIST__)
#define ERTS_PTAB_LIST__

#include "erl_process.h"
#include "bif.h"

BIF_RETTYPE erts_ptab_list(struct process *c_p, ErtsPTab *ptab);

BIF_RETTYPE erts_ptab_processes_next(struct process *c_p, ErtsPTab *ptab,
                                     Uint first);

#endif

#if defined(ERTS_PTAB_WANT_DEBUG_FUNCS__) && !defined(ERTS_PTAB_DEBUG_FUNCS__)
#define ERTS_PTAB_DEBUG_FUNCS__
#include "erl_process.h"

/* Debug functions */
Sint erts_ptab_test_next_id(ErtsPTab *ptab, int set, Uint next);
Eterm erts_debug_ptab_list(Process *c_p, ErtsPTab *ptab);
Eterm erts_debug_ptab_list_bif_info(Process *c_p, ErtsPTab *ptab);

#endif
