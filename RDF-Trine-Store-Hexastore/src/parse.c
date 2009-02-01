#include <time.h>
#include <stdio.h>
#include <raptor.h>
#include <openssl/sha.h>
#include "hexastore.h"

void help (int argc, char** argv);
int main (int argc, char** argv);
int GTW_get_triple_identifiers( hx_index* index, const raptor_statement* triple, rdf_node* s, rdf_node* p, rdf_node* o );
rdf_node GTW_identifier_for_node( hx_index* index, void* node, raptor_identifier_type type, char* lang, raptor_uri* dt );
void GTW_handle_triple(void* user_data, const raptor_statement* triple);
static int count	= 0;

void help (int argc, char** argv) {
	fprintf( stderr, "Usage: %s data.rdf [mime-type]\n\n", argv[0] );
}

int main (int argc, char** argv) {
	const char* rdf_filename	= NULL;
	const char* type			= "rdfxml";
	hx_index* index;
	raptor_parser* rdf_parser;
	unsigned char *uri_string;
	raptor_uri *uri, *base_uri;
	
	if (argc < 3) {
		help(argc, argv);
		exit(1);
	}
	
	rdf_filename	= argv[1];
	if (argc > 2)
		type		= argv[2];
	
	index	= hx_new_index( HX_INDEX_ORDER_SPO );
	printf( "hx_index: %p\n", (void*) index );
	
	rdf_parser	= NULL;
	raptor_init();
	rdf_parser	= raptor_new_parser( type );
	raptor_set_statement_handler(rdf_parser, index, GTW_handle_triple);
	uri_string	= raptor_uri_filename_to_uri_string( rdf_filename );
	uri			= raptor_new_uri(uri_string);
	base_uri	= raptor_uri_copy(uri);
	raptor_parse_file(rdf_parser, uri, base_uri);
	
	size_t bytes		= hx_index_memory_size( index );
	size_t megs			= bytes / (1024 * 1024);
	uint64_t triples	= hx_index_triples_count( index );
	int mtriples		= (int) (triples / 1000000);
	fprintf( stdout, "total triples: %d (%dM)\n", (int) triples, mtriples );
	fprintf( stdout, "total memory size: %d bytes (%d megs)\n", bytes, megs );
	hx_free_index( index );
	return 0;
}


int GTW_get_triple_identifiers( hx_index* index, const raptor_statement* triple, rdf_node* s, rdf_node* p, rdf_node* o ) {
	*s	= GTW_identifier_for_node( index, (void*) triple->subject, triple->subject_type, NULL, NULL );
	*p	= GTW_identifier_for_node( index, (void*) triple->predicate, triple->predicate_type, NULL, NULL );
	*o	= GTW_identifier_for_node( index, (void*) triple->object, triple->object_type, (char*) triple->object_literal_language, triple->object_literal_datatype );
	return 0;
}

rdf_node GTW_identifier_for_node( hx_index* index, void* node, raptor_identifier_type type, char* lang, raptor_uri* dt ) {
	rdf_node id	= 0;
	char node_type;
	char* value;
	int needs_free	= 0;
	char* language	= NULL;
	char* datatype	= NULL;
	unsigned char hash[21];
	SHA_CTX c;
	
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
	
	SHA1_Init(&c);
	SHA1_Update(&c, &node_type, 1);
	SHA1_Update(&c, value, strlen( value ));
	if (language)
		SHA1_Update(&c, language, strlen( language ));
	if (datatype)
		SHA1_Update(&c, datatype, strlen( datatype ));
	hash[20]	= (char) 0;
	SHA1_Final(hash, &c);
	id			= *( (rdf_node*) hash );
	
	if (needs_free) {
		free( value );
		needs_free	= 0;
	}
	return id;
}

void GTW_handle_triple(void* user_data, const raptor_statement* triple)	{
	hx_index* index	= (hx_index*) user_data;
	rdf_node s, p, o;
	
	GTW_get_triple_identifiers( index, triple, &s, &p, &o );
	hx_index_add_triple( index, s, p, o );
	if ((++count % 25000) == 0)
		fprintf( stderr, "%d\n", count );
}
