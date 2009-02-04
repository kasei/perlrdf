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

hx_hexastore* hx_new_hexastore ( void );
int hx_free_hexastore ( hx_hexastore* hx );
int hx_add_triple( hx_hexastore* hx, rdf_node_id s, rdf_node_id p, rdf_node_id o );
int hx_remove_triple( hx_hexastore* hx, rdf_node_id s, rdf_node_id p, rdf_node_id o );
hx_index_iter* hx_get_statements( hx_hexastore* hx, rdf_node_id s, rdf_node_id p, rdf_node_id o, int order_position );

int hx_write( hx_hexastore* h, FILE* f );
hx_hexastore* hx_read( FILE* f, int buffer );

#endif
