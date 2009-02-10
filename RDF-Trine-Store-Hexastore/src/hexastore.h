#ifndef _HEXASTORE_H
#define _HEXASTORE_H

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
#include <pthread.h>

#include "hexastore_types.h"
#include "index.h"
#include "terminal.h"
#include "vector.h"
#include "head.h"

enum {
	RDF_ITER_FLAGS_BOUND_A	= 1,
	RDF_ITER_FLAGS_BOUND_B	= 2,
	RDF_ITER_FLAGS_BOUND_C	= 4,
};

#define THREADED_BATCH_SIZE	200

static const int RDF_ITER_TYPE_MASK	= 0x07;
static const int RDF_ITER_TYPE_FFF	= 0;
static const int RDF_ITER_TYPE_BFF	= RDF_ITER_FLAGS_BOUND_A;
static const int RDF_ITER_TYPE_BBF	= RDF_ITER_FLAGS_BOUND_A | RDF_ITER_FLAGS_BOUND_B;

typedef struct {
	hx_index* spo;
	hx_index* sop;
	hx_index* pso;
	hx_index* pos;
	hx_index* osp;
	hx_index* ops;
} hx_hexastore;

typedef struct {
	hx_index* index;
	hx_index* secondary;
	hx_triple* triples;
	int count;
} hx_thread_info;

hx_hexastore* hx_new_hexastore ( void );
int hx_free_hexastore ( hx_hexastore* hx );
int hx_add_triple( hx_hexastore* hx, hx_node_id s, hx_node_id p, hx_node_id o );
int hx_add_triples( hx_hexastore* hx, hx_triple* triples, int count );
int hx_remove_triple( hx_hexastore* hx, hx_node_id s, hx_node_id p, hx_node_id o );
int hx_get_ordered_index( hx_hexastore* hx, hx_node_id s, hx_node_id p, hx_node_id o, int order_position, hx_index** index, hx_node_id* nodes );
hx_index_iter* hx_get_statements( hx_hexastore* hx, hx_node_id s, hx_node_id p, hx_node_id o, int order_position );
uint64_t hx_triples_count( hx_hexastore* hx );

int hx_write( hx_hexastore* h, FILE* f );
hx_hexastore* hx_read( FILE* f, int buffer );

#endif
