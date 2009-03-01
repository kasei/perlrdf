#ifndef _BTREE_H
#define _BTREE_H

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
#include "storage.h"

// #define BRANCHING_SIZE	124
#define BRANCHING_SIZE	252
// #define BRANCHING_SIZE	510
// #define BRANCHING_SIZE	1022
// #define BRANCHING_SIZE	14
// #define BRANCHING_SIZE	4

static uint32_t HX_BTREE_NODE_ROOT	= 1;
static uint32_t HX_BTREE_NODE_LEAF	= 2;

typedef struct {
	uint32_t type;
	uint32_t flags;
	uint64_t parent;
	uint32_t used;
	uint64_t prev;
	uint64_t next;
	hx_node_id keys[ BRANCHING_SIZE ];
	uint64_t children[ BRANCHING_SIZE ];
	uint64_t padding1[3];
	uint32_t padding2;
} hx_btree_node;

typedef struct {
	int started;
	int finished;
	hx_storage_manager* storage;
	hx_btree_node* root;
	hx_btree_node* page;
	uint32_t index;
} hx_btree_iter;

typedef void hx_btree_node_visitor ( hx_storage_manager* s, hx_btree_node* node, int level, void* param );

hx_btree_node* hx_new_btree_root ( hx_storage_manager* s );
hx_btree_node* hx_new_btree_node ( hx_storage_manager* s );
int hx_free_btree_node ( hx_storage_manager* s, hx_btree_node* node );

list_size_t hx_btree_size ( hx_storage_manager* s, hx_btree_node* node );

int hx_btree_node_debug ( char* string, hx_storage_manager* s, hx_btree_node* node );
int hx_btree_tree_debug ( char* string, hx_storage_manager* s, hx_btree_node* node );
int hx_btree_node_add_child ( hx_storage_manager* s, hx_btree_node* node, hx_node_id n, uint64_t child );
uint64_t hx_btree_node_get_child ( hx_storage_manager* s, hx_btree_node* node, hx_node_id n );
int hx_btree_node_remove_child ( hx_storage_manager* s, hx_btree_node* node, hx_node_id n );

hx_btree_node* hx_btree_node_next_neighbor ( hx_storage_manager* s, hx_btree_node* node );
hx_btree_node* hx_btree_node_prev_neighbor ( hx_storage_manager* s, hx_btree_node* node );
int hx_btree_node_set_parent ( hx_storage_manager* s, hx_btree_node* node, hx_btree_node* parent );
int hx_btree_node_set_next_neighbor ( hx_storage_manager* s, hx_btree_node* node, hx_btree_node* next );
int hx_btree_node_set_prev_neighbor ( hx_storage_manager* s, hx_btree_node* node, hx_btree_node* prev );

int hx_btree_node_has_flag ( hx_storage_manager* s, hx_btree_node* node, uint32_t type );
int hx_btree_node_set_flag ( hx_storage_manager* s, hx_btree_node* node, uint32_t type );
int hx_btree_node_unset_flag ( hx_storage_manager* s, hx_btree_node* node, uint32_t type );

uint64_t hx_btree_search ( hx_storage_manager* s, hx_btree_node* root, hx_node_id key );
int hx_btree_insert ( hx_storage_manager* s, hx_btree_node** _root, hx_node_id key, uint64_t value );
int hx_btree_remove ( hx_storage_manager* s, hx_btree_node** _root, hx_node_id key );
void hx_btree_traverse ( hx_storage_manager* s, hx_btree_node* node, hx_btree_node_visitor* before, hx_btree_node_visitor* after, int level, void* param );

hx_btree_iter* hx_btree_new_iter ( hx_storage_manager* s, hx_btree_node* root );
int hx_free_btree_iter ( hx_btree_iter* iter );
int hx_btree_iter_finished ( hx_btree_iter* iter );
int hx_btree_iter_current ( hx_btree_iter* iter, hx_node_id* n, uint64_t* v );
int hx_btree_iter_next ( hx_btree_iter* iter );
int hx_btree_iter_seek( hx_btree_iter* iter, hx_node_id n );


#endif
