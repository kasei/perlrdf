#ifndef _HEXASTORE_H
#define _HEXASTORE_H

#ifdef __cplusplus
extern "C" {
#endif

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
#include "triple.h"

enum {
	RDF_ITER_FLAGS_BOUND_A	= 1,
	RDF_ITER_FLAGS_BOUND_B	= 2,
	RDF_ITER_FLAGS_BOUND_C	= 4
};

#define THREADED_BATCH_SIZE	5000

static const int RDF_ITER_TYPE_MASK	= 0x07;
static const int RDF_ITER_TYPE_FFF	= 0;
static const int RDF_ITER_TYPE_BFF	= RDF_ITER_FLAGS_BOUND_A;
static const int RDF_ITER_TYPE_BBF	= RDF_ITER_FLAGS_BOUND_A | RDF_ITER_FLAGS_BOUND_B;

typedef struct {
	hx_nodemap* map;
	hx_storage_id_t spo;
	hx_storage_id_t sop;
	hx_storage_id_t pso;
	hx_storage_id_t pos;
	hx_storage_id_t osp;
	hx_storage_id_t ops;
	int next_var;
} hx_hexastore;

typedef struct {
	hx_storage_manager* s;
	hx_hexastore* hx;
	hx_index* index;
	hx_index* secondary;
	hx_triple_id* triples;
	int count;
} hx_thread_info;

typedef struct {
	hx_storage_manager* s;
	hx_index_iter* iter;
	int size;
	int free_names;
	char** names;
	int* triple_pos_to_index;
	int* index_to_triple_pos;
	char *subject, *predicate, *object;
	hx_variablebindings* current;
} _hx_iter_vb_info;

hx_hexastore* hx_open_hexastore ( hx_storage_manager* s, hx_nodemap* map );
hx_hexastore* hx_new_hexastore ( hx_storage_manager* s );
hx_hexastore* hx_new_hexastore_with_nodemap ( hx_storage_manager* w, hx_nodemap* map );
int hx_free_hexastore ( hx_hexastore* hx, hx_storage_manager* s );

int hx_add_triple( hx_hexastore* hx, hx_storage_manager* st, hx_node* s, hx_node* p, hx_node* o );
int hx_add_triples( hx_hexastore* hx, hx_storage_manager* s, hx_triple* triples, int count );

int hx_remove_triple( hx_hexastore* hx, hx_storage_manager* st, hx_node* s, hx_node* p, hx_node* o );
int hx_get_ordered_index( hx_hexastore* hx, hx_storage_manager* st, hx_node* s, hx_node* p, hx_node* o, int order_position, hx_index** index, hx_node** nodes, int* var_count );
hx_index_iter* hx_get_statements( hx_hexastore* hx, hx_storage_manager* st, hx_node* s, hx_node* p, hx_node* o, int order_position );

hx_storage_id_t hx_triples_count( hx_hexastore* hx, hx_storage_manager* s );
hx_storage_id_t hx_count_statements( hx_hexastore* hx, hx_storage_manager* st, hx_node* s, hx_node* p, hx_node* o );

hx_node* hx_new_variable ( hx_hexastore* hx );
hx_node* hx_new_named_variable ( hx_hexastore* hx, char* name );
hx_node_id hx_get_node_id ( hx_hexastore* hx, hx_node* node );
hx_nodemap* hx_get_nodemap ( hx_hexastore* hx );

hx_variablebindings_iter* hx_new_iter_variablebindings ( hx_index_iter* i, hx_storage_manager* s, char* subj_name, char* pred_name, char* obj_name, int free_names );

int hx_write( hx_hexastore* h, hx_storage_manager* s, FILE* f );
hx_hexastore* hx_read( hx_storage_manager* w, FILE* f, int buffer );

#ifdef __cplusplus
}
#endif

#endif
