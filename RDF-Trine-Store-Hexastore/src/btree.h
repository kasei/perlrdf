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

// XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
// XXX remove this as soon as branching_size is a param of the tree...
#define BRANCHING_SIZE	252

typedef struct {
	uint32_t type;
	uint32_t flags;
	uint64_t parent;
	uint64_t prev;
	uint64_t next;
	uint32_t used;
	hx_node_id keys[ BRANCHING_SIZE ];
	uint64_t children[ BRANCHING_SIZE ];
// 	uint32_t __padding2;
// 	uint64_t __padding1[3];
} hx_btree_node;

typedef struct {
	uint32_t branching_size;
	hx_btree_node* root;
} hx_btree;

typedef struct {
	int started;
	int finished;
	hx_storage_manager* storage;
	hx_btree_node* root;
	hx_btree_node* page;
	uint32_t index;
} hx_btree_iter;

typedef void hx_btree_node_visitor ( hx_storage_manager* s, hx_btree_node* node, int level, void* param );

hx_btree* hx_new_btree ( hx_storage_manager* s, uint32_t branching_size );
int hx_free_btree ( hx_storage_manager* s, hx_btree* tree );

uint64_t hx_btree_search ( hx_storage_manager* s, hx_btree* tree, hx_node_id key );
int hx_btree_insert ( hx_storage_manager* s, hx_btree* tree, hx_node_id key, uint64_t value );
int hx_btree_remove ( hx_storage_manager* s, hx_btree* tree, hx_node_id key );
void hx_btree_traverse ( hx_storage_manager* s, hx_btree* tree, hx_btree_node_visitor* before, hx_btree_node_visitor* after, int level, void* param );

hx_btree_iter* hx_btree_new_iter ( hx_storage_manager* s, hx_btree* tree );
int hx_free_btree_iter ( hx_btree_iter* iter );
int hx_btree_iter_finished ( hx_btree_iter* iter );
int hx_btree_iter_current ( hx_btree_iter* iter, hx_node_id* n, uint64_t* v );
int hx_btree_iter_next ( hx_btree_iter* iter );
int hx_btree_iter_seek( hx_btree_iter* iter, hx_node_id n );

// XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
// XXX remove this as soon as branching_size is a param of the tree...
#include "btree_internal.h"

#endif
