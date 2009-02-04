#include <stdio.h>
#include <stdlib.h>
#include "hexastore.h"
#include "nodemap.h"

void help (int argc, char** argv) {
	fprintf( stderr, "Usage: %s hexastore.dat [pred]\n\n", argv[0] );
}

int main (int argc, char** argv) {
	const char* filename	= NULL;
	char* pred					= NULL;
	
	if (argc < 2) {
		help(argc, argv);
		exit(1);
	}

	filename	= argv[1];
	if (argc > 2)
		pred		= argv[2];
	
	FILE* f	= fopen( filename, "r" );
	if (f == NULL) {
		perror( "Failed to open hexastore file for reading: " );
		return 1;
	}
	
	hx_hexastore* hx	= hx_read( f, 0 );
	if (pred == NULL) {
		int count	= 1;
		hx_index_iter* iter	= hx_index_new_iter( hx->spo );
		while (!hx_index_iter_finished( iter )) {
			rdf_node_id s, p, o;
			hx_index_iter_current( iter, &s, &p, &o );
			fprintf( stderr, "[%d] %d, %d, %d\n", count++, (int) s, (int) p, (int) o );
			hx_index_iter_next( iter );
		}
		hx_free_index_iter( iter );
		hx_free_hexastore( hx );
	} else {
		rdf_node_id id	= (rdf_node_id) atoll( pred );
		fprintf( stderr, "iter (*,%d,*) ordered by subject...\n", (int) id );
		hx_index_iter* iter	= hx_get_statements( hx, (rdf_node_id) 0, id, (rdf_node_id) 0, HX_SUBJECT );
		int count	= 1;
		while (!hx_index_iter_finished( iter )) {
			rdf_node_id s, p, o;
			hx_index_iter_current( iter, &s, &p, &o );
			fprintf( stderr, "[%d] %d, %d, %d\n", count++, (int) s, (int) p, (int) o );
			
// 			char* ss	= node_string( hx_nodemap_get_node_string( index.m, s ) );
// 			char* sp	= node_string( hx_nodemap_get_node_string( index.m, p ) );
// 			char* so	= node_string( hx_nodemap_get_node_string( index.m, o ) );
// 			fprintf( stderr, "[%d] %s, %s, %s\n", count++, ss, sp, so );
// 			free( ss );
// 			free( sp );
// 			free( so );
			
			hx_index_iter_next( iter );
		}
		hx_free_index_iter( iter );
	}
	return 0;
}

