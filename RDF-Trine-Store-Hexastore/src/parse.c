#include <time.h>
#include <stdio.h>
#include <raptor.h>
#include "hexastore.h"
#include "nodemap.h"

typedef struct {
	hx_hexastore* h;
	hx_nodemap* m;
} triplestore;


char* node_string ( const char* nodestr );
void help (int argc, char** argv);
int main (int argc, char** argv);
int GTW_get_triple_identifiers( triplestore* index, const raptor_statement* triple, rdf_node_id* s, rdf_node_id* p, rdf_node_id* o );
rdf_node_id GTW_identifier_for_node( triplestore* index, void* node, raptor_identifier_type type, char* lang, raptor_uri* dt );
void GTW_handle_triple(void* user_data, const raptor_statement* triple);
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
	fprintf( stderr, "\n" );
	
	if (hx_write( index.h, f ) != 0) {
		fprintf( stderr, "*** Couldn't write hexastore to disk.\n" );
		return 1;
	}
	
// 	size_t bytes		= hx_index_memory_size( index.h->spo );
// 	size_t megs			= bytes / (1024 * 1024);
// 	uint64_t triples	= hx_index_triples_count( index.h->spo );
// 	int mtriples		= (int) (triples / 1000000);
// 	fprintf( stdout, "total triples: %d (%dM)\n", (int) triples, (int) mtriples );
// 	fprintf( stdout, "total memory size: %d bytes (%d megs)\n", (int) bytes, (int) megs );
	
	hx_free_hexastore( index.h );
	hx_free_nodemap( index.m );
	return 0;
}


int GTW_get_triple_identifiers( triplestore* index, const raptor_statement* triple, rdf_node_id* s, rdf_node_id* p, rdf_node_id* o ) {
	*s	= GTW_identifier_for_node( index, (void*) triple->subject, triple->subject_type, NULL, NULL );
	*p	= GTW_identifier_for_node( index, (void*) triple->predicate, triple->predicate_type, NULL, NULL );
	*o	= GTW_identifier_for_node( index, (void*) triple->object, triple->object_type, (char*) triple->object_literal_language, triple->object_literal_datatype );
	return 0;
}

rdf_node_id GTW_identifier_for_node( triplestore* index, void* node, raptor_identifier_type type, char* lang, raptor_uri* dt ) {
	rdf_node_id id	= 0;
	char node_type;
	char* value;
	int needs_free	= 0;
	char* language	= NULL;
	char* datatype	= NULL;
	
	switch (type) {
		case RAPTOR_IDENTIFIER_TYPE_RESOURCE:
		case RAPTOR_IDENTIFIER_TYPE_PREDICATE:
			value		= (char*) raptor_uri_as_string((raptor_uri*)node);
			node_type	= 'R';
			break;
		case RAPTOR_IDENTIFIER_TYPE_ANONYMOUS:
			value		= (char*) node;
			node_type	= 'B';
			break;
		case RAPTOR_IDENTIFIER_TYPE_LITERAL:
			value		= (char*)node;
			node_type	= 'L';
			if(lang && type == RAPTOR_IDENTIFIER_TYPE_LITERAL) {
				language	= (char*) lang;
			} else if (dt) {
				datatype	= (char*) raptor_uri_as_string((raptor_uri*) dt);
			}
			break;
		case RAPTOR_IDENTIFIER_TYPE_XML_LITERAL:
			value		= (char*) node;
			datatype	= "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral";
			node_type	= 'L';
			break;
		case RAPTOR_IDENTIFIER_TYPE_ORDINAL:
			needs_free	= 1;
			value		= (char*) malloc( 64 );
			sprintf( value, "http://www.w3.org/1999/02/22-rdf-syntax-ns#_%d", *((int*) node) );
			node_type	= 'R';
			break;
		case RAPTOR_IDENTIFIER_TYPE_UNKNOWN:
		default:
			fprintf(stderr, "*** unknown node type %d\n", type);
			return 0;
	}
	
	
	char* nodestr	= malloc( strlen( value ) + 2 );
	sprintf( nodestr, "%c%s", node_type, value );
	id	= hx_nodemap_add_node( index->m, nodestr );
	free( nodestr );
	
	if (needs_free) {
		free( value );
		needs_free	= 0;
	}
	return id;
}

void GTW_handle_triple(void* user_data, const raptor_statement* triple)	{
	triplestore* index	= (triplestore*) user_data;
	rdf_node_id s, p, o;
	
	GTW_get_triple_identifiers( index, triple, &s, &p, &o );
	hx_add_triple( index->h, s, p, o );
	if ((++count % 25000) == 0)
		fprintf( stderr, "\rparsed %d triples", count );
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
