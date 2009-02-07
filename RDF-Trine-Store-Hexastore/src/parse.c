#include <time.h>
#include <stdio.h>
#include <raptor.h>
#include "hexastore.h"
#include "nodemap.h"
#include "node.h"

#define TRIPLES_BATCH_SIZE	25000
typedef struct {
	hx_hexastore* h;
	hx_nodemap* m;
	hx_triple triples[ TRIPLES_BATCH_SIZE ];
	int count;
} triplestore;

void help (int argc, char** argv);
int main (int argc, char** argv);
int GTW_get_triple_identifiers( triplestore* index, const raptor_statement* triple, hx_node_id* s, hx_node_id* p, hx_node_id* o );
hx_node_id GTW_identifier_for_node( triplestore* index, void* node, raptor_identifier_type type, char* lang, raptor_uri* dt );
void GTW_handle_triple(void* user_data, const raptor_statement* triple);
int add_triples_batch ( triplestore* index );

static int count	= 0;

void help (int argc, char** argv) {
	fprintf( stderr, "Usage: %s data.rdf hexastore.out [mime-type]\n\n", argv[0] );
}
int main (int argc, char** argv) {
	const char* rdf_filename	= NULL;
	const char* output_filename	= NULL;
	const char* type			= "ntriples";
	triplestore index;
	char* pred					= NULL;
	raptor_parser* rdf_parser;
	unsigned char *uri_string;
	raptor_uri *uri, *base_uri;
	
	if (argc < 3) {
		help(argc, argv);
		exit(1);
	}
	
	rdf_filename	= argv[1];
	output_filename	= argv[2];
	if (argc > 3)
		type		= argv[3];
	if (argc > 4)
		pred		= argv[4];
	
	index.count		= 0;
	index.h	= hx_new_hexastore();
	index.m	= hx_new_nodemap();
	printf( "hx_index: %p\n", (void*) &index );
	
	FILE* f	= fopen( output_filename, "w" );
	if (f == NULL) {
		perror( "Failed to open hexastore file for writing: " );
		return 1;
	}
	
	rdf_parser	= NULL;
	raptor_init();
	rdf_parser	= raptor_new_parser( type );
	raptor_set_statement_handler(rdf_parser, &index, GTW_handle_triple);
	uri_string	= raptor_uri_filename_to_uri_string( rdf_filename );
	uri			= raptor_new_uri(uri_string);
	base_uri	= raptor_uri_copy(uri);
	raptor_parse_file(rdf_parser, uri, base_uri);
	if (index.count > 0) {
		add_triples_batch( &index );
	}

	fprintf( stderr, "\n" );
	
	if (hx_write( index.h, f ) != 0) {
		fprintf( stderr, "*** Couldn't write hexastore to disk.\n" );
		return 1;
	}
	
	if (hx_nodemap_write( index.m, f ) != 0) {
		fprintf( stderr, "*** Couldn't write nodemap to disk.\n" );
		return 1;
	}
	
	hx_free_hexastore( index.h );
	hx_free_nodemap( index.m );
	return 0;
}


int GTW_get_triple_identifiers( triplestore* index, const raptor_statement* triple, hx_node_id* s, hx_node_id* p, hx_node_id* o ) {
	*s	= GTW_identifier_for_node( index, (void*) triple->subject, triple->subject_type, NULL, NULL );
	*p	= GTW_identifier_for_node( index, (void*) triple->predicate, triple->predicate_type, NULL, NULL );
	*o	= GTW_identifier_for_node( index, (void*) triple->object, triple->object_type, (char*) triple->object_literal_language, triple->object_literal_datatype );
	return 0;
}
hx_node_id GTW_identifier_for_node( triplestore* index, void* node, raptor_identifier_type type, char* lang, raptor_uri* dt ) {
	hx_node_id id	= 0;
	char node_type;
	char* value;
	int needs_free	= 0;
	char* language	= NULL;
	char* datatype	= NULL;
	hx_node* newnode;
	
	switch (type) {
		case RAPTOR_IDENTIFIER_TYPE_RESOURCE:
		case RAPTOR_IDENTIFIER_TYPE_PREDICATE:
			value		= (char*) raptor_uri_as_string((raptor_uri*)node);
			newnode		= hx_new_node_resource( value );
			node_type	= 'R';
			break;
		case RAPTOR_IDENTIFIER_TYPE_ANONYMOUS:
			value		= (char*) node;
			newnode		= hx_new_node_blank( value );
			node_type	= 'B';
			break;
		case RAPTOR_IDENTIFIER_TYPE_LITERAL:
			value		= (char*)node;
			node_type	= 'L';
			if(lang && type == RAPTOR_IDENTIFIER_TYPE_LITERAL) {
				language	= (char*) lang;
				newnode		= (hx_node*) hx_new_node_lang_literal( value, language );
			} else if (dt) {
				datatype	= (char*) raptor_uri_as_string((raptor_uri*) dt);
				newnode		= (hx_node*) hx_new_node_dt_literal( value, datatype );
			} else {
				newnode		= hx_new_node_literal( value );
			}
			break;
		case RAPTOR_IDENTIFIER_TYPE_XML_LITERAL:
			value		= (char*) node;
			datatype	= "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral";
			node_type	= 'L';
			newnode		= (hx_node*) hx_new_node_dt_literal( value, datatype );
			break;
		case RAPTOR_IDENTIFIER_TYPE_ORDINAL:
			needs_free	= 1;
			value		= (char*) malloc( 64 );
			sprintf( value, "http://www.w3.org/1999/02/22-rdf-syntax-ns#_%d", *((int*) node) );
			newnode		= hx_new_node_resource( value );
			node_type	= 'R';
			break;
		case RAPTOR_IDENTIFIER_TYPE_UNKNOWN:
		default:
			fprintf(stderr, "*** unknown node type %d\n", type);
			return 0;
	}
	
	
// 	char* nodestr	= malloc( strlen( value ) + 2 );
// 	sprintf( nodestr, "%c%s", node_type, value );
	id	= hx_nodemap_add_node( index->m, newnode );
// 	free( nodestr );
	
	if (needs_free) {
		free( value );
		needs_free	= 0;
	}
	return id;
}
void GTW_handle_triple(void* user_data, const raptor_statement* triple)	{
	triplestore* index	= (triplestore*) user_data;
	hx_node_id s, p, o;
	
	GTW_get_triple_identifiers( index, triple, &s, &p, &o );
	if (index->count >= TRIPLES_BATCH_SIZE) {
		add_triples_batch( index );
	}
	
	int i	= index->count++;
	index->triples[ i ].subject		= s;
	index->triples[ i ].predicate	= p;
	index->triples[ i ].object		= o;
//	hx_add_triple( index->h, s, p, o );
	if ((++count % 25000) == 0)
		fprintf( stderr, "\rparsed %d triples", count );
}

int add_triples_batch ( triplestore* index ) {
	if (index->count > 0) {
		hx_add_triples( index->h, index->triples, index->count );
		index->count	= 0;
	}
	return 0;
}
