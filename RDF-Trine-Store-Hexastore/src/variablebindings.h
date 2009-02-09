#ifndef _VARIABLEBINDINGS_H
#define _VARIABLEBINDINGS_H

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
#include "nodemap.h"
#include "node.h"
#include "index.h"

typedef struct {
	int size;
	char** names;
	hx_node_id* nodes;
} hx_variablebindings;

// type characters:
//	'I' a variable bindings wrapper around a hx_index_iter
//	'J' a variable bindings iterator for joining two children bindings iterators
typedef struct {
	char type;
	void* ptr;
	int size;
	char** names;
	int* indexes;
} hx_variablebindings_iter;

hx_variablebindings* hx_new_variablebindings ( int size, char** names, hx_node_id* nodes );
int hx_free_variablebindings ( hx_variablebindings* b, int free_names );

void hx_variablebindings_debug ( hx_variablebindings* b, hx_nodemap* m );
char* hx_variablebindings_name_for_binding ( hx_variablebindings* b, int column );
hx_node_id hx_variablebindings_node_for_binding ( hx_variablebindings* b, int column );

hx_variablebindings_iter* hx_variablebindings_new_iterator_triples ( hx_index_iter* i, char* subj_name, char* pred_name, char* obj_name );
int hx_free_variablebindings_iter ( hx_variablebindings_iter* iter );

int hx_variablebindings_iter_finished ( hx_variablebindings_iter* iter );
int hx_variablebindings_iter_current ( hx_variablebindings_iter* iter, hx_variablebindings** b );
int hx_variablebindings_iter_next ( hx_variablebindings_iter* iter );

#endif
