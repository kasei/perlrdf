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

#define BRANCHING_SIZE	254
#define BRANCHING_MIN	127

#define BRANCHING_SIZE	510
#define BRANCHING_MIN	255

// #define BRANCHING_SIZE	1022
// #define BRANCHING_MIN	511

// #define BRANCHING_SIZE	14
// #define BRANCHING_MIN	7

// #define BRANCHING_SIZE	4
// #define BRANCHING_MIN	2

enum {
	HX_BTREE_MEMORY	= 2,
	HX_BTREE_FILE	= 4
};

static uint32_t HX_BTREE_NODE_ROOT	= 1;
static uint32_t HX_BTREE_NODE_LEAF	= 2;

typedef struct {
	int flags;
	int fd;
	char* filename;
} hx_btree_world;

typedef struct {
	uint32_t type;
	uint32_t flags;
	uint64_t parent;
	uint64_t padding1;
	uint32_t padding2;
	uint32_t used;
	hx_node_id keys[ BRANCHING_SIZE ];
	uint64_t children[ BRANCHING_SIZE ];
} hx_btree_node;

typedef void hx_btree_node_visitor ( hx_btree_world* w, hx_btree_node* node, int level );

hx_btree_node* hx_new_btree_node ( hx_btree_world* w );
int hx_free_btree_node ( hx_btree_world* w, hx_btree_node* node );

int hx_btree_node_debug ( hx_btree_world* w, hx_btree_node* node );
int hx_btree_node_add_child ( hx_btree_world* w, hx_btree_node* node, hx_node_id n, uint64_t child );
uint64_t hx_btree_node_get_child ( hx_btree_world* w, hx_btree_node* node, hx_node_id n );
int hx_btree_node_remove_child ( hx_btree_world* w, hx_btree_node* node, hx_node_id n );

int hx_btree_node_has_flag ( hx_btree_world* w, hx_btree_node* node, uint32_t type );
int hx_btree_node_set_flag ( hx_btree_world* w, hx_btree_node* node, uint32_t type );
int hx_btree_node_unset_flag ( hx_btree_world* w, hx_btree_node* node, uint32_t type );

uint64_t hx_btree_search ( hx_btree_world* w, hx_btree_node* root, hx_node_id key );
int hx_btree_insert ( hx_btree_world* w, hx_btree_node** _root, hx_node_id key, uint64_t value );

void hx_btree_traverse ( hx_btree_world* w, hx_btree_node* node, hx_btree_node_visitor* before, hx_btree_node_visitor* after, int level );

#endif
