#include <stdio.h>
#include <stdlib.h>
#include "hexastore.h"
#include "nodemap.h"
#include "storage.h"

hx_node_id map_old_to_new_id ( hx_nodemap* old, hx_nodemap* new, hx_node_id id );
void help (int argc, char** argv) {
	fprintf( stderr, "Usage: %s in.hx out.hxo\n\n", argv[0] );
}

int main (int argc, char** argv) {
	const char* in_filename		= NULL;
	const char* out_filename	= NULL;
	
	if (argc != 3) {
		help(argc, argv);
		exit(1);
	}

	in_filename		= argv[1];
	out_filename	= argv[2];
	
	FILE* inf	= fopen( in_filename, "r" );
	if (inf == NULL) {
		perror( "Failed to open hexastore file for reading: " );
		return 1;
	}
	
	FILE* outf	= fopen( out_filename, "w" );
	if (outf == NULL) {
		perror( "Failed to open hexastore file for writing: " );
		return 1;
	}
	
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	
	fprintf( stderr, "reading hexastore from file...\n" );
	hx_hexastore* hx	= hx_read( st, inf, 0 );
	fprintf( stderr, "reading nodemap from file...\n" );
	hx_nodemap* map		= hx_get_nodemap( hx );
	
	fprintf( stderr, "re-sorting nodemap...\n" );
	hx_nodemap* smap	= hx_nodemap_sparql_order_nodes( map );
	
	int count	= 0;
	fprintf( stderr, "creating new hexastore...\n" );
	hx_hexastore* shx	= hx_new_hexastore_with_nodemap( st, smap );
	hx_index_iter* iter	= hx_index_new_iter( hx->spo, st );
	while (!hx_index_iter_finished( iter )) {
		hx_node_id s, p, o;
		hx_index_iter_current( iter, &s, &p, &o );
		hx_node* sn	= hx_nodemap_get_node( hx->map, s );
		hx_node* pn	= hx_nodemap_get_node( hx->map, p );
		hx_node* on	= hx_nodemap_get_node( hx->map, o );
		
		hx_add_triple( shx, st, sn, pn, on );
		hx_index_iter_next( iter );
		if ((++count % 25000) == 0)
			fprintf( stderr, "\rfinished %d triples", count );
	}
	hx_free_index_iter( iter );
	
	if (hx_write( shx, st, outf ) != 0) {
		fprintf( stderr, "*** Couldn't write hexastore to disk.\n" );
		return 1;
	}
	
	if (hx_nodemap_write( smap, outf ) != 0) {
		fprintf( stderr, "*** Couldn't write nodemap to disk.\n" );
		return 1;
	}
	
	hx_free_hexastore( hx, st );
	hx_free_nodemap( smap );
	hx_free_storage_manager( st );
	fclose( inf );
	fclose( outf );
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

hx_node_id map_old_to_new_id ( hx_nodemap* old, hx_nodemap* new, hx_node_id id ) {
	hx_node* node		= hx_nodemap_get_node( old, id );
	hx_node_id newid	= hx_nodemap_get_node_id( new, node );
	return newid;
}



