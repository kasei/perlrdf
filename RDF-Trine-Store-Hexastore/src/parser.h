#ifndef _PARSER_H
#define _PARSER_H

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
#include <raptor.h>

#include "hexastore_types.h"
#include "hexastore.h"
#include "node.h"

static int TRIPLES_BATCH_SIZE	= 25000;

typedef struct {
	int count;
	hx_hexastore* hx;
	hx_triple* triples;
} hx_parser_t;

int hx_parser_parse_file_into_hexastore ( hx_hexastore* hx, const char* filename );


#endif
