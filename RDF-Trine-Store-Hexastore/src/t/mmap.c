#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include "hexastore.h"
#include "nodemap.h"
#include "node.h"
#include "storage.h"
#include "parser.h"
#include "tap.h"

void cleanup_files (void);
void _add_data ( hx_hexastore* hx, hx_storage_manager* s );
void _debug_node ( char* h, hx_node* node );
hx_variablebindings_iter* _get_triples ( hx_hexastore* hx, int sort );

void test_close_open ( void );
void test_mmap_grow ( void );

static char* temp_file	= "/tmp/test.hx";
static char* temp_map	= "/tmp/test.map";

int main ( void ) {
	plan_tests(20);
	
	test_close_open();
	test_mmap_grow();
	
	return exit_status();
}

void test_close_open (void) {
	{
		int fd	= open( temp_file, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR );
		for (int i = 0; i < 4*65536; i++)
			write( fd, "", 1 );
		lseek( fd, 0, SEEK_SET );
		
		hx_storage_manager* s	= hx_new_mmap_storage_manager( fd );
		if (s == NULL) {
			fail( "hx_new_mmap_storage_manager returns mmap storage manager", "" );
			cleanup_files();
			return;
		}
		
		hx_hexastore* hx	= hx_new_hexastore( s );
		_add_data( hx, s );
		
		FILE* fp		= fopen(temp_map, "w");
		if (fp == NULL) {
			perror( "fopen failed" );
			fail( "fopen failed", "" );
			cleanup_files();
			return;
		}
		
		hx_nodemap* map	= hx_get_nodemap( hx );
		if (hx_nodemap_write( map, fp ) != 0) {
			fail( "hx_nodemap_write", "" );
			cleanup_files();
			return;
		}
		fclose( fp );
		hx_free_hexastore( hx, s );
		hx_free_storage_manager( s );
	}
	
	{
		int fd	= open( temp_file, O_RDONLY );
		hx_storage_manager* s	= hx_open_mmap_storage_manager( fd, PROT_READ );
		
		FILE* fp		= fopen(temp_map, "r");
		hx_nodemap* map	= hx_nodemap_read( s, fp, 0 );
		hx_hexastore* hx	= hx_open_hexastore( s, map );
		fclose( fp );
		
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
			hx_storage_id_t total	= hx_triples_count( hx, s );
			ok1( total == 31 );
		}
		
		{	// fff
			hx_storage_id_t total	= hx_count_statements( hx, s, x, y, z );
			ok1( total == 31 );
		}
		
		{	// fbf
			hx_storage_id_t total	= hx_count_statements( hx, s, x, binding, z );
			ok1( total == 8 );
		}
		
		{	// bff
			hx_storage_id_t total	= hx_count_statements( hx, s, rs, x, y );
			ok1( total == 7 );
		}
		
		{	// ffb
			hx_storage_id_t total	= hx_count_statements( hx, s, x, y, sl );
			ok1( total == 3 );
		}
		
		{	// fbb
			hx_storage_id_t total	= hx_count_statements( hx, s, x, variable, sl );
			ok1( total == 2 );
		}
		
		{	// bfb
			hx_storage_id_t total	= hx_count_statements( hx, s, rs, x, rstype );
			ok1( total == 1 );
		}
	
		{	// bbf
			hx_storage_id_t total	= hx_count_statements( hx, s, rs, resvar, y );
			ok1( total == 4 );
		}
		
		{	// bbb
			hx_storage_id_t total	= hx_count_statements( hx, s, rs, resvar, sl );
			ok1( total == 1 );
		}
		
		{	// bbb
			hx_storage_id_t total	= hx_count_statements( hx, s, rs, resvar, rstype );
			ok1( total == 0 );
		}
		
		hx_variablebindings* b;
		
		hx_free_hexastore( hx, s );
		hx_free_storage_manager( s );
		cleanup_files();
	}
}

void test_mmap_grow ( void ) {
	int fd	= open( temp_file, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR );
	for (int i = 0; i < 4096; i++)
		write( fd, "", 1 );
	lseek( fd, 0, SEEK_SET );
	fsync(fd);
	hx_storage_manager* s	= hx_new_mmap_storage_manager( fd );
	if (s == NULL) {
		fail( "hx_new_mmap_storage_manager returns mmap storage manager", "" );
		cleanup_files();
		return;
	}
	
	hx_hexastore* hx	= hx_new_hexastore( s );
	_add_data( hx, s );
	
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
		hx_storage_id_t total	= hx_triples_count( hx, s );
		ok1( total == 31 );
	}
	
	{	// fff
		hx_storage_id_t total	= hx_count_statements( hx, s, x, y, z );
		ok1( total == 31 );
	}
	
	{	// fbf
		hx_storage_id_t total	= hx_count_statements( hx, s, x, binding, z );
		ok1( total == 8 );
	}
	
	{	// bff
		hx_storage_id_t total	= hx_count_statements( hx, s, rs, x, y );
		ok1( total == 7 );
	}
	
	{	// ffb
		hx_storage_id_t total	= hx_count_statements( hx, s, x, y, sl );
		ok1( total == 3 );
	}
	
	{	// fbb
		hx_storage_id_t total	= hx_count_statements( hx, s, x, variable, sl );
		ok1( total == 2 );
	}
	
	{	// bfb
		hx_storage_id_t total	= hx_count_statements( hx, s, rs, x, rstype );
		ok1( total == 1 );
	}

	{	// bbf
		hx_storage_id_t total	= hx_count_statements( hx, s, rs, resvar, y );
		ok1( total == 4 );
	}
	
	{	// bbb
		hx_storage_id_t total	= hx_count_statements( hx, s, rs, resvar, sl );
		ok1( total == 1 );
	}
	
	{	// bbb
		hx_storage_id_t total	= hx_count_statements( hx, s, rs, resvar, rstype );
		ok1( total == 0 );
	}
	
	
	hx_free_hexastore( hx, s );
	hx_free_storage_manager( s );
	cleanup_files();
}

void _add_data ( hx_hexastore* hx, hx_storage_manager* s ) {
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
	hx_parser_parse_string_into_hexastore( parser, hx, s, rdf, "http://example.org/", "turtle" );
	hx_free_parser(parser);
}

void _debug_node ( char* h, hx_node* node ) {
	char* string;
	hx_node_string( node, &string );
	fprintf( stderr, "%s %s\n", h, string );
}

void cleanup_files (void) {
	unlink( temp_file );
	unlink( temp_map );
}
