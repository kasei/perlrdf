#include <stdio.h>
#include <stdlib.h>
#include "hexastore.h"
#include "nodemap.h"

void print_triple ( hx_nodemap* map, hx_node_id s, hx_node_id p, hx_node_id o, int count );
char* node_string ( const char* nodestr );
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
	hx_nodemap* map		= hx_nodemap_read( f, 0 );
	
	if (pred == NULL) {
		int count	= 1;
		hx_index_iter* iter	= hx_index_new_iter( hx->spo );
		while (!hx_index_iter_finished( iter )) {
			hx_node_id s, p, o;
			hx_index_iter_current( iter, &s, &p, &o );
			print_triple( map, s, p, o, count++ );
			hx_index_iter_next( iter );
		}
		hx_free_index_iter( iter );
	} else {
		char* predstr	= (char*) malloc( strlen( pred ) + 2 );
		sprintf( predstr, "R%s", pred );
		hx_node_id id	= hx_nodemap_get_node_id( map, predstr );
		free(predstr);
		
		if (id > 0) {
			fprintf( stderr, "iter (*,%d,*) ordered by subject...\n", (int) id );
			hx_index_iter* iter	= hx_get_statements( hx, (hx_node_id) 0, id, (hx_node_id) 0, HX_SUBJECT );
			int count	= 1;
			while (!hx_index_iter_finished( iter )) {
				hx_node_id s, p, o;
				hx_index_iter_current( iter, &s, &p, &o );
				print_triple( map, s, p, o, count++ );
				hx_index_iter_next( iter );
			}
			hx_free_index_iter( iter );
		} else {
			fprintf( stderr, "No such predicate found: '%s'.\n", pred );
		}
	}
	
	hx_free_hexastore( hx );
	hx_free_nodemap( map );
	return 0;
}

char* node_string ( const char* nodestr ) {
	int len			= strlen( nodestr ) + 1 + 2;
	char* string	= (char*) malloc( len );
	const char* value		= &(nodestr[1]);
	switch (*nodestr) {
		case 'R':
			sprintf( string, "<%s>", value );
			len	+= 2;
			break;
		case 'L':
			sprintf( string, "\"%s\"", value );
			len	+= 2;
			break;
		case 'B':
			sprintf( string, "_:%s", value );
			len	+= 2;
			break;
	};
	return string;
}

void print_triple ( hx_nodemap* map, hx_node_id s, hx_node_id p, hx_node_id o, int count ) {
// 	fprintf( stderr, "[%d] %d, %d, %d\n", count++, (int) s, (int) p, (int) o );
	char* ss	= node_string( hx_nodemap_get_node_string( map, s ) );
	char* sp	= node_string( hx_nodemap_get_node_string( map, p ) );
	char* so	= node_string( hx_nodemap_get_node_string( map, o ) );
	if (count > 0) {
		fprintf( stdout, "[%d] ", count );
	}
	fprintf( stdout, "%s, %s, %s\n", ss, sp, so );
	free( ss );
	free( sp );
	free( so );
}
