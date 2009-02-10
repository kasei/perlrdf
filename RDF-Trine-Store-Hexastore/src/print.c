#include <stdio.h>
#include <stdlib.h>
#include "hexastore.h"
#include "nodemap.h"

hx_node_id node_id_for_string ( char* string, hx_nodemap* map );
void print_triple ( hx_nodemap* map, hx_node_id s, hx_node_id p, hx_node_id o, int count );

void help (int argc, char** argv) {
	fprintf( stderr, "Usage:\n" );
	fprintf( stderr, "\t%s hexastore.dat -c\n", argv[0] );
	fprintf( stderr, "\t%s hexastore.dat -c subj pred obj\n", argv[0] );
	fprintf( stderr, "\t%s hexastore.dat -p pred\n", argv[0] );
	fprintf( stderr, "\t%s hexastore.dat subj pred obj\n", argv[0] );
	fprintf( stderr, "\n\n" );
}

int main (int argc, char** argv) {
	const char* filename	= NULL;
	char* arg				= NULL;
	
	if (argc < 2) {
		help(argc, argv);
		exit(1);
	}

	filename	= argv[1];
	if (argc > 2)
		arg		= argv[2];
	
	FILE* f	= fopen( filename, "r" );
	if (f == NULL) {
		perror( "Failed to open hexastore file for reading: " );
		return 1;
	}
	
	hx_hexastore* hx	= hx_read( f, 0 );
	hx_nodemap* map		= hx_nodemap_read( f, 0 );
	
	if (arg == NULL) {
		int count	= 1;
		hx_index_iter* iter	= hx_index_new_iter( hx->spo );
		while (!hx_index_iter_finished( iter )) {
			hx_node_id s, p, o;
			hx_index_iter_current( iter, &s, &p, &o );
			print_triple( map, s, p, o, count++ );
			hx_index_iter_next( iter );
		}
		hx_free_index_iter( iter );
	} else if (strcmp( arg, "-c" ) == 0) {
		if (argc == 4) {
			char* str	= argv[3];
			
			hx_node_id id	= node_id_for_string( str, map );
			for (int i = 0; i < 3; i++) {
				hx_index* index;
				hx_node_id index_ordered[3];
				hx_node_id triple[3]	= { 0, 0, 0 };
				triple[i]	= id;
				hx_get_ordered_index( hx, triple[0], triple[1], triple[2], HX_SUBJECT, &index, index_ordered );
				hx_head* head	= index->head;
				hx_vector* vector	= hx_head_get_vector( head, index_ordered[0] );
				
				fprintf( stdout, "{" );
				for (int z = 0; z < 3; z++) {
					if (triple[z] > (hx_node_id) 0) {
						char* string;
						hx_node* node	= hx_nodemap_get_node( map, triple[z] );
						if (node == NULL) {
							fprintf( stderr, "*** No such node %d\n", (int) triple[z] );
						} else {
							hx_node_string( node, &string );
							fprintf( stdout, " %s", string );
						}
					} else {
						fprintf( stdout, "_" );
					}
					if (z < 2) {
						fprintf( stdout, ", " );
					}
				}
				fprintf( stdout, " } -> " );
				if (vector != NULL) {
					fprintf( stdout, "%d triples\n", (int) hx_vector_triples_count( vector ) );
				} else {
					fprintf( stdout, "0 triples\n" );
				}
			}
		} else {
			fprintf( stdout, "Triples: %llu\n", (unsigned long long) hx_triples_count( hx ) );
		}
	} else if (strcmp( arg, "-p" ) == 0) {
		if (argc != 4) {
			help(argc, argv);
			exit(1);
		}
		char* pred	= argv[3];
		hx_node_id id	= node_id_for_string( pred, map );
		if (id > 0) {
//			fprintf( stderr, "iter (*,%d,*) ordered by subject...\n", (int) id );
			hx_index_iter* iter	= hx_get_statements( hx, (hx_node_id) -1, id, (hx_node_id) -2, HX_SUBJECT );
			int count	= 1;
			while (!hx_index_iter_finished( iter )) {
				hx_node_id s, p, o;
				hx_index_iter_current( iter, &s, &p, &o );
				print_triple( map, s, p, o, count++ );
				hx_index_iter_next( iter );
			}
			hx_free_index_iter( iter );
		}
	} else {
		if (argc != 5) {
			help(argc, argv);
			exit(1);
		}
		char* subj	= arg;
		char* pred	= argv[3];
		char* obj	= argv[4];
		
		hx_node_id sid	= node_id_for_string( subj, map );
		hx_node_id pid	= node_id_for_string( pred, map );
		hx_node_id oid	= node_id_for_string( obj, map );
//		fprintf( stderr, "iter (%d,%d,%d) ordered by subject...\n", (int) sid, (int) pid, (int) oid );
		hx_index_iter* iter	= hx_get_statements( hx, sid, pid, oid, HX_SUBJECT );
		int count	= 1;
		while (!hx_index_iter_finished( iter )) {
			hx_node_id s, p, o;
			hx_index_iter_current( iter, &s, &p, &o );
			print_triple( map, s, p, o, count++ );
			hx_index_iter_next( iter );
		}
		hx_free_index_iter( iter );
	}
	
	hx_free_hexastore( hx );
	hx_free_nodemap( map );
	return 0;
}

void print_triple ( hx_nodemap* map, hx_node_id s, hx_node_id p, hx_node_id o, int count ) {
// 	fprintf( stderr, "[%d] %d, %d, %d\n", count++, (int) s, (int) p, (int) o );
	hx_node* sn	= hx_nodemap_get_node( map, s );
	hx_node* pn	= hx_nodemap_get_node( map, p );
	hx_node* on	= hx_nodemap_get_node( map, o );
	char *ss, *sp, *so;
	hx_node_string( sn, &ss );
	hx_node_string( pn, &sp );
	hx_node_string( on, &so );
	if (count > 0) {
		fprintf( stdout, "[%d] ", count );
	}
	fprintf( stdout, "%s, %s, %s\n", ss, sp, so );
	free( ss );
	free( sp );
	free( so );
}

hx_node_id node_id_for_string ( char* string, hx_nodemap* map ) {
	static int var_id	= -100;
	hx_node_id id;
	hx_node* node;
	if (strcmp( string, "-" ) == 0) {
		id	= (hx_node_id) var_id--;
	} else if (strcmp( string, "0" ) == 0) {
		id	= (hx_node_id) 0;
	} else if (*string == '-') {
		id	= 0 - atoi( string+1 );
	} else {
		node	= hx_new_node_resource( string );
		id		= hx_nodemap_get_node_id( map, node );
		hx_free_node( node );
		if (id <= 0) {
			fprintf( stderr, "No such subject found: '%s'.\n", string );
		}
	}
	return id;
}
