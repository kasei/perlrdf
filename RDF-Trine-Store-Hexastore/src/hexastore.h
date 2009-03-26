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
#include "variablebindings.h"
#include "nodemap.h"
#include "index.h"
#include "terminal.h"
#include "vector.h"
#include "head.h"
#include "storage.h"

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
	hx_storage_manager* storage;
	hx_nodemap* map;
	hx_index* spo;
	hx_index* sop;
	hx_index* pso;
	hx_index* pos;
	hx_index* osp;
	hx_index* ops;
	int next_var;
} hx_hexastore;

typedef struct {
	hx_node* subject;
	hx_node* predicate;
	hx_node* object;
} hx_triple;

typedef struct {
	hx_node_id subject;
	hx_node_id predicate;
	hx_node_id object;
} hx_triple_id;

typedef struct {
	hx_hexastore* hx;
	hx_index* index;
	hx_index* secondary;
	hx_triple_id* triples;
	int count;
} hx_thread_info;

typedef struct {
	hx_index_iter* iter;
	int size;
	char** names;
	int* triple_pos_to_index;
	int* index_to_triple_pos;
	char *subject, *predicate, *object;
} _hx_iter_vb_info;

hx_hexastore* hx_new_hexastore ( hx_storage_manager* w );
hx_hexastore* hx_new_hexastore_with_nodemap ( hx_storage_manager* w, hx_nodemap* map );
int hx_free_hexastore ( hx_hexastore* hx );

int hx_add_triple( hx_hexastore* hx, hx_node* s, hx_node* p, hx_node* o );
int hx_add_triples( hx_hexastore* hx, hx_triple* triples, int count );

int hx_remove_triple( hx_hexastore* hx, hx_node* s, hx_node* p, hx_node* o );
int hx_get_ordered_index( hx_hexastore* hx, hx_node* s, hx_node* p, hx_node* o, int order_position, hx_index** index, hx_node** nodes );
hx_index_iter* hx_get_statements( hx_hexastore* hx, hx_node* s, hx_node* p, hx_node* o, int order_position );

uint64_t hx_triples_count( hx_hexastore* hx );
uint64_t hx_count_statements( hx_hexastore* hx, hx_node* s, hx_node* p, hx_node* o );

hx_node* hx_new_variable ( hx_hexastore* hx );
hx_node_id hx_get_node_id ( hx_hexastore* hx, hx_node* node );
hx_nodemap* hx_get_nodemap ( hx_hexastore* hx );

hx_variablebindings_iter* hx_new_iter_variablebindings ( hx_index_iter* i, char* subj_name, char* pred_name, char* obj_name );

int hx_write( hx_hexastore* h, FILE* f );
hx_hexastore* hx_read( hx_storage_manager* w, FILE* f, int buffer );

#endif
