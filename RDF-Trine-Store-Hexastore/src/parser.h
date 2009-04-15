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
#include <sys/time.h>
#include <string.h>
#include <unistd.h>
#include <raptor.h>

#include "hexastore_types.h"
#include "hexastore.h"
#include "node.h"

static int TRIPLES_BATCH_SIZE	= 5000;
typedef void (*hx_parser_logger)( uint64_t count );

typedef struct {
	uint64_t next_bnode;
	struct timeval tv;
	int count;
	uint64_t total;
	hx_hexastore* hx;
	hx_storage_manager* s;
	hx_triple* triples;
	hx_parser_logger logger;
} hx_parser;

hx_parser* hx_new_parser ( void );
int hx_parser_set_logger( hx_parser* p, hx_parser_logger l );

uint64_t hx_parser_parse_file_into_hexastore ( hx_parser* p, hx_hexastore* hx, hx_storage_manager* s, const char* filename );
int hx_parser_parse_string_into_hexastore ( hx_parser* p, hx_hexastore* hx, const char* string, const char* base, char* parser_name );
int hx_free_parser ( hx_parser* p );

#endif
