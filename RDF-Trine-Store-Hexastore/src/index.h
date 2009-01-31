#ifndef _INDEX_H
#define _INDEX_H

#include <errno.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <string.h>
#include <unistd.h>

#include "hexastore_types.h"
#include "head.h"

typedef struct {
	int order[3];
	hx_head* head;
} hx_index;

static int HX_INDEX_ORDER_SPO[3]	= { 0,1,2 };
static int HX_INDEX_ORDER_SOP[3]	= { 0,2,1 };
static int HX_INDEX_ORDER_PSO[3]	= { 1,0,2 };
static int HX_INDEX_ORDER_POS[3]	= { 1,2,0 };
static int HX_INDEX_ORDER_OSP[3]	= { 2,0,1 };
static int HX_INDEX_ORDER_OPS[3]	= { 2,1,0 };

// hx_index* hx_new_index ( int a, int b, int c );
hx_index* hx_new_index ( int* index_order );
int hx_free_index ( hx_index* index );
int hx_index_debug ( hx_index* index );
int hx_index_add_triple ( hx_index* i, rdf_node s, rdf_node p, rdf_node o );
int hx_index_remove_triple ( hx_index* i, rdf_node s, rdf_node p, rdf_node o );
uint64_t hx_index_triples_count ( hx_index* index );

#endif
