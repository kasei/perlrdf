#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include "hexastore.h"
#include "nodemap.h"
#include "node.h"
#include "storage.h"
#include "parser.h"
#include "tap.h"

void _add_data ( hx_hexastore* hx );
void _debug_node ( char* h, hx_node* node );
hx_variablebindings_iter* _get_triples ( hx_hexastore* hx, int sort );

void test_small_iter ( void );

static char* temp_file	= "/tmp/test.hx";

int main ( void ) {
	plan_tests(10);
	
	int fd	= open( temp_file, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR );
	for (int i = 0; i < 4*65536; i++)
		write( fd, "", 1 );
	lseek( fd, 0, SEEK_SET );
	
	hx_storage_manager* s	= hx_new_mmap_storage_manager( fd );
	if (s == NULL) {
		fail( "hx_new_mmap_storage_manager returns mmap storage manager", "" );
		return exit_status();
	}
	
	hx_hexastore* hx	= hx_new_hexastore( s );
	hx_nodemap* map		= hx_get_nodemap( hx );
	_add_data( hx );
	
	hx_node* x			= hx_new_variable( hx );
	hx_node* y			= hx_new_variable( hx );
	hx_node* z			= hx_new_variable( hx );
	hx_node* binding	= hx_new_node_resource( "http://www.w3.org/2001/sw/DataAccess/tests/result-set#binding" );
	hx_node* variable	= hx_new_node_resource( "http://www.w3.org/2001/sw/DataAccess/tests/result-set#variable" );
	hx_node* resvar		= hx_new_node_resource( "http://www.w3.org/2001/sw/DataAccess/tests/result-set#resultVariable" );
	hx_node* rs			= hx_new_node_resource( "http://resultset/" );
	hx_node* rstype		= hx_new_node_resource( "http://www.w3.org/2001/sw/DataAccess/tests/result-set#ResultSet" );
	hx_node* sl			= hx_new_node_literal( "s" );

	{	// ALL TRIPLES
		hx_storage_id_t total	= hx_triples_count( hx );
		ok1( total == 31 );
	}
	
	{	// fff
		hx_storage_id_t total	= hx_count_statements( hx, x, y, z );
		ok1( total == 31 );
	}
	
	{	// fbf
		hx_storage_id_t total	= hx_count_statements( hx, x, binding, z );
		ok1( total == 8 );
	}
	
	{	// bff
		hx_storage_id_t total	= hx_count_statements( hx, rs, x, y );
		ok1( total == 7 );
	}
	
	{	// ffb
		hx_storage_id_t total	= hx_count_statements( hx, x, y, sl );
		ok1( total == 3 );
	}
	
	{	// fbb
		hx_storage_id_t total	= hx_count_statements( hx, x, variable, sl );
		ok1( total == 2 );
	}
	
	{	// bfb
		hx_storage_id_t total	= hx_count_statements( hx, rs, x, rstype );
		ok1( total == 1 );
	}

	{	// bbf
		hx_storage_id_t total	= hx_count_statements( hx, rs, resvar, y );
		ok1( total == 4 );
	}
	
	{	// bbb
		hx_storage_id_t total	= hx_count_statements( hx, rs, resvar, sl );
		ok1( total == 1 );
	}
	
	{	// bbb
		hx_storage_id_t total	= hx_count_statements( hx, rs, resvar, rstype );
		ok1( total == 0 );
	}
	
	hx_variablebindings* b;
	
	hx_free_hexastore( hx );
	hx_free_storage_manager( s );
	
	return exit_status();
}

void _add_data ( hx_hexastore* hx ) {
	const char* rdf	= "@prefix :        <http://example/> . \
@prefix rs:      <http://www.w3.org/2001/sw/DataAccess/tests/result-set#> . \
@prefix rdf:     <http://www.w3.org/1999/02/22-rdf-syntax-ns#> . \
@prefix xsd:        <http://www.w3.org/2001/XMLSchema#> . \
 \
<http://resultset/>    rdf:type      rs:ResultSet ; \
      rs:resultVariable  \"p\" ; \
      rs:resultVariable  \"g\" ; \
      rs:resultVariable  \"s\" ; \
      rs:resultVariable  \"o\" ; \
      rs:solution   [ rs:binding    [ rs:value      :x ; \
                                      rs:variable   \"s\" \
                                    ] ; \
                      rs:binding    [ rs:value      :p ; \
                                      rs:variable   \"p\" \
                                    ] ; \
                      rs:binding    [ rs:value      <data-g1.ttl> ; \
                                      rs:variable   \"g\" \
                                    ] ; \
                      rs:binding    [ rs:value      \"1\"^^xsd:integer ; \
                                      rs:variable   \"o\" \
                                    ] \
                    ] ; \
      rs:solution   [ rs:binding    [ rs:value      :a ; \
                                      rs:variable   \"s\" \
                                    ] ; \
                      rs:binding    [ rs:value      :p ; \
                                      rs:variable   \"p\" \
                                    ] ; \
                      rs:binding    [ rs:value      \"9\"^^xsd:integer ; \
                                      rs:variable   \"o\" \
                                    ] ; \
                      rs:binding    [ rs:value      <data-g1.ttl> ; \
                                      rs:variable   \"g\" \
                                    ] \
                    ] . \
";
	hx_parser* parser	= hx_new_parser();
	hx_parser_parse_string_into_hexastore( parser, hx, rdf, "http://example.org/", "turtle" );
	hx_free_parser(parser);
}

void _debug_node ( char* h, hx_node* node ) {
	char* string;
	hx_node_string( node, &string );
	fprintf( stderr, "%s %s\n", h, string );
}

