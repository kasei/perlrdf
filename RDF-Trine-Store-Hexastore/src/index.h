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

typedef struct {
	hx_index* index;
	int flags;
	rdf_node node_mask_a, node_mask_b, node_mask_c;
	hx_head_iter* head_iter;
	hx_vector_iter* vector_iter;
	hx_terminal_iter* terminal_iter;
	int started;
	int finished;
} hx_index_iter;

static int HX_INDEX_ORDER_SPO[3]	= { HX_SUBJECT, HX_PREDICATE, HX_OBJECT };
static int HX_INDEX_ORDER_SOP[3]	= { HX_SUBJECT, HX_OBJECT, HX_PREDICATE };
static int HX_INDEX_ORDER_PSO[3]	= { HX_PREDICATE, HX_SUBJECT, HX_OBJECT };
static int HX_INDEX_ORDER_POS[3]	= { HX_PREDICATE, HX_OBJECT, HX_SUBJECT };
static int HX_INDEX_ORDER_OSP[3]	= { HX_OBJECT, HX_SUBJECT, HX_PREDICATE };
static int HX_INDEX_ORDER_OPS[3]	= { HX_OBJECT, HX_PREDICATE, HX_SUBJECT };

// hx_index* hx_new_index ( int a, int b, int c );
hx_index* hx_new_index ( int* index_order );
int hx_free_index ( hx_index* index );
int hx_index_debug ( hx_index* index );
int hx_index_add_triple ( hx_index* i, rdf_node s, rdf_node p, rdf_node o );
int hx_index_remove_triple ( hx_index* i, rdf_node s, rdf_node p, rdf_node o );
uint64_t hx_index_triples_count ( hx_index* index );
size_t hx_index_memory_size ( hx_index* i );

int hx_index_write( hx_index* t, FILE* f );
hx_index* hx_index_read( FILE* f, int buffer );

hx_index_iter* hx_index_new_iter ( hx_index* index );
hx_index_iter* hx_index_new_iter1 ( hx_index* index, rdf_node a, rdf_node b, rdf_node c );
int hx_free_index_iter ( hx_index_iter* iter );

int hx_index_iter_finished ( hx_index_iter* iter );
int hx_index_iter_current ( hx_index_iter* iter, rdf_node* s, rdf_node* p, rdf_node* o );
int hx_index_iter_next ( hx_index_iter* iter );


#endif
