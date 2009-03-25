#include "parser.h"

void _hx_parser_handle_triple(void* user_data, const raptor_statement* triple);
int  _hx_parser_add_triples_batch ( hx_parser_t* index );
int _hx_parser_get_triple_nodes( hx_parser_t* index, const raptor_statement* triple, hx_node** s, hx_node** p, hx_node** o );
hx_node* _hx_parser_node( hx_parser_t* index, void* node, raptor_identifier_type type, char* lang, raptor_uri* dt );

int hx_parser_parse_file_into_hexastore ( hx_hexastore* hx, const char* filename ) {
	raptor_init();
	raptor_parser* rdf_parser	= raptor_new_parser( "guess" );
	unsigned char* uri_string	= raptor_uri_filename_to_uri_string( filename );
	raptor_uri* uri				= raptor_new_uri(uri_string);
	const char* parser_name		= raptor_guess_parser_name(NULL, NULL, NULL, 0, uri_string);
	raptor_uri *base_uri		= raptor_uri_copy(uri);
	
	hx_parser_t index;
	index.triples	= (hx_triple*) calloc( TRIPLES_BATCH_SIZE, sizeof( hx_triple ) );
	index.hx		= hx;
	
	raptor_set_statement_handler(rdf_parser, &index, _hx_parser_handle_triple);
	raptor_parse_file(rdf_parser, uri, base_uri);
	if (index.count > 0) {
		_hx_parser_add_triples_batch( &index );
	}
	
	free( index.triples );
	return 0;
}

void _hx_parser_handle_triple (void* user_data, const raptor_statement* triple)	{
	hx_parser_t* index	= (hx_parser_t*) user_data;
	hx_node *s, *p, *o;
	
	_hx_parser_get_triple_nodes( index, triple, &s, &p, &o );
	if (index->count >= TRIPLES_BATCH_SIZE) {
		_hx_parser_add_triples_batch( index );
	}
	
	int i	= index->count++;
	index->triples[ i ].subject		= s;
	index->triples[ i ].predicate	= p;
	index->triples[ i ].object		= o;
}

int  _hx_parser_add_triples_batch ( hx_parser_t* index ) {
	if (index->count > 0) {
		hx_add_triples( index->hx, index->triples, index->count );
		index->count	= 0;
	}
	return 0;
}

int _hx_parser_get_triple_nodes( hx_parser_t* index, const raptor_statement* triple, hx_node** s, hx_node** p, hx_node** o ) {
	*s	= _hx_parser_node( index, (void*) triple->subject, triple->subject_type, NULL, NULL );
	*p	= _hx_parser_node( index, (void*) triple->predicate, triple->predicate_type, NULL, NULL );
	*o	= _hx_parser_node( index, (void*) triple->object, triple->object_type, (char*) triple->object_literal_language, triple->object_literal_datatype );
	return 0;
}

hx_node* _hx_parser_node( hx_parser_t* index, void* node, raptor_identifier_type type, char* lang, raptor_uri* dt ) {
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
	
	id	= hx_nodemap_add_node( hx_get_nodemap( index->hx ), newnode );
	if (0) {
		char* string;
		hx_node_string( newnode, &string );
		fprintf( stderr, "*** '%s' => %d\n", string, (int) id );
		free(string);
	}
	
	if (needs_free) {
		free( value );
		needs_free	= 0;
	}
	return newnode;
}
