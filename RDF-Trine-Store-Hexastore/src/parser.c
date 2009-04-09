#include "parser.h"

void _hx_parser_handle_triple(void* user_data, const raptor_statement* triple);
int  _hx_parser_add_triples_batch ( hx_parser* index );
int _hx_parser_get_triple_nodes( hx_parser* index, const raptor_statement* triple, hx_node** s, hx_node** p, hx_node** o );
hx_node* _hx_parser_node( hx_parser* index, void* node, raptor_identifier_type type, char* lang, raptor_uri* dt );
unsigned char* _hx_parser_generate_id (void *user_data, raptor_genid_type type, unsigned char* user_bnodeid);

hx_parser* hx_new_parser ( void ) {
	hx_parser* p	= (hx_parser*) calloc( 1, sizeof( hx_parser ) );
	p->next_bnode	= 0;
	gettimeofday( &( p->tv ), NULL );
	p->logger		= NULL;
	return p;
}

int hx_free_parser ( hx_parser* p ) {
	free( p );
	return 0;
}

int hx_parser_set_logger( hx_parser* p, hx_parser_logger l ) {
	p->logger	= l;
	return 0;
}

int hx_parser_parse_file_into_hexastore ( hx_parser* parser, hx_hexastore* hx, const char* filename ) {
	raptor_init();
	unsigned char* uri_string	= raptor_uri_filename_to_uri_string( filename );
	raptor_uri* uri				= raptor_new_uri(uri_string);
	const char* parser_name		= raptor_guess_parser_name(NULL, NULL, NULL, 0, uri_string);
	raptor_parser* rdf_parser	= raptor_new_parser( parser_name );
	raptor_uri *base_uri		= raptor_uri_copy(uri);
	
	parser->hx		= hx;
	parser->count	= 0;
	parser->triples	= (hx_triple*) calloc( TRIPLES_BATCH_SIZE, sizeof( hx_triple ) );
	
	raptor_set_statement_handler(rdf_parser, parser, _hx_parser_handle_triple);
	raptor_set_generate_id_handler(rdf_parser, parser, _hx_parser_generate_id);
	
	raptor_parse_file(rdf_parser, uri, base_uri);
	if (parser->count > 0) {
		_hx_parser_add_triples_batch( parser );
	}
	
	raptor_free_parser(rdf_parser);
	free( parser->triples );
	free( uri_string );
	free( base_uri );
	free( uri );
	return 0;
}

int hx_parser_parse_string_into_hexastore ( hx_parser* parser, hx_hexastore* hx, const char* string, const char* base, char* parser_name ) {
	raptor_init();
	raptor_parser* rdf_parser	= raptor_new_parser( parser_name );
	raptor_uri* base_uri		= raptor_new_uri((const unsigned char*) base);
	raptor_start_parse( rdf_parser, base_uri );
	
	parser->hx		= hx;
	parser->count	= 0;
	parser->triples	= (hx_triple*) calloc( TRIPLES_BATCH_SIZE, sizeof( hx_triple ) );
	
	raptor_set_statement_handler(rdf_parser, parser, _hx_parser_handle_triple);
	raptor_set_generate_id_handler(rdf_parser, parser, _hx_parser_generate_id);
	
	raptor_parse_chunk(rdf_parser, (const unsigned char*)string, strlen(string), 1);
	if (parser->count > 0) {
		_hx_parser_add_triples_batch( parser );
	}
	
	raptor_free_parser(rdf_parser);
	free( parser->triples );
	return 0;
}

void _hx_parser_handle_triple (void* user_data, const raptor_statement* triple)	{
	hx_parser* index	= (hx_parser*) user_data;
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

int  _hx_parser_add_triples_batch ( hx_parser* parser ) {
	if (parser->count > 0) {
		hx_add_triples( parser->hx, parser->triples, parser->count );
		parser->total	+= parser->count;
		if (parser->logger != NULL) {
			parser->logger( parser->total );
		}
		for (int i = 0; i < parser->count; i++) {
			hx_free_node( parser->triples[i].subject );
			hx_free_node( parser->triples[i].predicate );
			hx_free_node( parser->triples[i].object );
		}
		parser->count	= 0;
	}
	return 0;
}

int _hx_parser_get_triple_nodes( hx_parser* index, const raptor_statement* triple, hx_node** s, hx_node** p, hx_node** o ) {
	*s	= _hx_parser_node( index, (void*) triple->subject, triple->subject_type, NULL, NULL );
	*p	= _hx_parser_node( index, (void*) triple->predicate, triple->predicate_type, NULL, NULL );
	*o	= _hx_parser_node( index, (void*) triple->object, triple->object_type, (char*) triple->object_literal_language, triple->object_literal_datatype );
	return 0;
}

hx_node* _hx_parser_node( hx_parser* index, void* node, raptor_identifier_type type, char* lang, raptor_uri* dt ) {
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

unsigned char* _hx_parser_generate_id (void *user_data, raptor_genid_type type, unsigned char* user_bnodeid) {
	hx_parser* parser	= (hx_parser*) user_data;
//	fprintf( stderr, "time: %llx seconds, %llx µs\n", (unsigned long long) parser->tv.tv_sec, (unsigned long long) parser->tv.tv_usec );
	
	unsigned long long seconds	= (parser->tv.tv_sec - 1234567890);
	unsigned long long copy		= seconds;
	static char encodingTable [64] = {
		'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
		'Q','R','S','T','U','V','W',    'Y','Z','a','b','c','d','e','f',
		'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
		'w','x','y','z','0','1','2','3','4','5','6','7','8','9','_','.','-'
	};
	
	unsigned char* id	= (unsigned char*) calloc( 48, sizeof( char ) );
	unsigned char* p	= id;
	*(p++)	= 'X';
	while (copy != 0) {
		int i	= (int) (copy & 0x3f);
		*(p++)	= encodingTable[ i ];
		copy >>= 4;
	}
	*(p++)	= 'X';
	copy	= parser->tv.tv_usec;
	while (copy != 0) {
		int i	= (int) (copy & 0x3f);
		*(p++)	= encodingTable[ i ];
		copy >>= 4;
	}
	*(p++)	= 'X';
	copy	= parser->next_bnode++;
	while (copy != 0) {
		int i	= (int) (copy & 0x3f);
		*(p++)	= encodingTable[ i ];
		copy >>= 4;
	}
	*(p++)	= (char) 0;
	if (user_bnodeid != NULL) {
		free( user_bnodeid );
	}
	return id;
}
