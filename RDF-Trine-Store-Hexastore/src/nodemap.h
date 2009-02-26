#ifndef _NODEMAP_H
#define _NODEMAP_H

#include <stdio.h>
#include <string.h>
#include "hexastore_types.h"
#include "avl.h"
#include "node.h"
#include "storage.h"

typedef struct avl_table avl;
typedef struct {
	hx_node_id next_id;
	avl* id2node;
	avl* node2id;
} hx_nodemap;

typedef struct {
	hx_node_id id;
	hx_node* node;
} hx_nodemap_item;

hx_nodemap* hx_new_nodemap( void );
int hx_free_nodemap ( hx_nodemap* m );

hx_node_id hx_nodemap_add_node ( hx_nodemap* m, hx_node* n );
int hx_nodemap_remove_node_id ( hx_nodemap* m, hx_node_id id );
int hx_nodemap_remove_node ( hx_nodemap* m, hx_node* n );
hx_node_id hx_nodemap_get_node_id ( hx_nodemap* m, hx_node* n );
hx_node* hx_nodemap_get_node ( hx_nodemap* m, hx_node_id id );
hx_nodemap* hx_nodemap_sparql_order_nodes ( hx_nodemap* map );

int hx_nodemap_write( hx_nodemap* t, FILE* f );
hx_nodemap* hx_nodemap_read( hx_storage_manager* s, FILE* f, int buffer );

#endif
