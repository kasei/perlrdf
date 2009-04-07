#ifndef _TRIPLE_H
#define _TRIPLE_H

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
#include "node.h"

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

hx_triple* hx_new_triple( hx_node* s, hx_node* p, hx_node* o );
int hx_free_triple ( hx_triple* t );

#endif
