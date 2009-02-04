#ifndef _NODEMAP_H
#define _NODEMAP_H

#include <stdio.h>
#include <string.h>
#include "hexastore_types.h"
#include "avl.h"

typedef struct avl_table avl;
typedef struct {
	rdf_node_id next_id;
	avl* id2node;
	avl* node2id;
} hx_nodemap;

typedef struct {
	rdf_node_id id;
	char* string;
} hx_nodemap_item;

hx_nodemap* hx_new_nodemap( void );
int hx_free_nodemap ( hx_nodemap* m );

rdf_node_id hx_nodemap_add_node ( hx_nodemap* m, char* nodestr );
int hx_nodemap_remove_node_id ( hx_nodemap* m, rdf_node_id id );
int hx_nodemap_remove_node_string ( hx_nodemap* m, char* nodestr );

rdf_node_id hx_nodemap_get_node_id ( hx_nodemap* m, char* nodestr );
char* hx_nodemap_get_node_string ( hx_nodemap* m, rdf_node_id id );

#endif
