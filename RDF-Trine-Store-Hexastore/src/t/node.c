#include <unistd.h>
#include "node.h"
#include "tap.h"

void test_variables ( void );
void test_literals ( void );
void test_resources ( void );
void test_bnodes ( void );
void test_cmp ( void );
void test_store ( void );

int main ( void ) {
	plan_tests(119);
	
	test_variables();
	test_literals();
	test_resources();
	test_bnodes();
	test_cmp();
	test_store();
	
	return exit_status();
}

void test_variables ( void ) {
	diag("variables test");
	{
		hx_node* v1	= hx_new_node_variable( -1 );
		ok1( v1 != NULL );
		
		ok1( hx_node_is_variable(v1) );
		ok1( !hx_node_is_literal(v1) );
		ok1( !hx_node_is_lang_literal(v1) );
		ok1( !hx_node_is_dt_literal(v1) );
		ok1( !hx_node_is_blank(v1) );
		ok1( !hx_node_is_resource(v1) );
		
		ok1( hx_node_iv(v1) == -1 );
		ok1( hx_node_value(v1) == NULL );
		
		hx_free_node(v1);
	}
	{
		hx_node* v2	= hx_new_node_variable( -2 );
		ok1( v2 != NULL );
		
		ok1( hx_node_is_variable(v2) );
		ok1( !hx_node_is_literal(v2) );
		ok1( !hx_node_is_lang_literal(v2) );
		ok1( !hx_node_is_dt_literal(v2) );
		ok1( !hx_node_is_blank(v2) );
		ok1( !hx_node_is_resource(v2) );
		
		ok1( hx_node_iv(v2) == -2 );
		ok1( hx_node_value(v2) == NULL );
		
		hx_free_node(v2);
	}
}

void test_literals ( void ) {
	diag("literals test");
	{
		hx_node* l1	= hx_new_node_literal("foo");
		ok1( l1 != NULL );
		
		ok1( !hx_node_is_variable(l1) );
		ok1( hx_node_is_literal(l1) );
		ok1( !hx_node_is_lang_literal(l1) );
		ok1( !hx_node_is_dt_literal(l1) );
		ok1( !hx_node_is_blank(l1) );
		ok1( !hx_node_is_resource(l1) );
		
		ok1( hx_node_iv(l1) == 0 );
		ok1( hx_node_value(l1) != NULL );
		ok1( strcmp(hx_node_value(l1), "foo") == 0 );
		
		hx_free_node(l1);
	}
	{
		hx_node* l2	= (hx_node*) hx_new_node_lang_literal("bar", "en-us");
		ok1( l2 != NULL );
		
		ok1( !hx_node_is_variable(l2) );
		ok1( hx_node_is_literal(l2) );
		ok1( hx_node_is_lang_literal(l2) );
		ok1( !hx_node_is_dt_literal(l2) );
		ok1( !hx_node_is_blank(l2) );
		ok1( !hx_node_is_resource(l2) );
		
		ok1( hx_node_iv(l2) == 0 );
		ok1( hx_node_value(l2) != NULL );
		ok1( strcmp(hx_node_value(l2), "bar") == 0 );
		ok1( strcmp(hx_node_lang((hx_node_lang_literal*) l2), "en-us") == 0 );
		
		hx_free_node(l2);
	}
	{
		hx_node* l3	= (hx_node*) hx_new_node_dt_literal("7", "http://www.w3.org/2001/XMLSchema#integer");
		ok1( l3 != NULL );
		
		ok1( !hx_node_is_variable(l3) );
		ok1( hx_node_is_literal(l3) );
		ok1( !hx_node_is_lang_literal(l3) );
		ok1( hx_node_is_dt_literal(l3) );
		ok1( !hx_node_is_blank(l3) );
		ok1( !hx_node_is_resource(l3) );
		
		ok1( hx_node_ivok(l3) == 1 );
		ok1( hx_node_nvok(l3) == 0 );
		
		ok1( hx_node_iv(l3) == 7 );
		ok1( hx_node_value(l3) != NULL );
		ok1( strcmp(hx_node_value(l3), "7") == 0 );
		ok1( strcmp(hx_node_dt((hx_node_dt_literal*) l3), "http://www.w3.org/2001/XMLSchema#integer") == 0 );
		
		hx_node* copy	= hx_node_copy( l3 );
		ok1( copy != NULL );
		ok1( copy != l3 );
		ok1( hx_node_value(l3) != hx_node_value(copy) );
		ok1( strcmp(hx_node_value(l3), hx_node_value(copy)) == 0 );
		
		hx_free_node(l3);
	}
	{
		hx_node* l4	= (hx_node*) hx_new_node_dt_literal("1.2340", "http://www.w3.org/2001/XMLSchema#float");
		ok1( l4 != NULL );
		
		ok1( !hx_node_is_variable(l4) );
		ok1( hx_node_is_literal(l4) );
		ok1( !hx_node_is_lang_literal(l4) );
		ok1( hx_node_is_dt_literal(l4) );
		ok1( !hx_node_is_blank(l4) );
		ok1( !hx_node_is_resource(l4) );
		
		ok1( hx_node_ivok(l4) == 0 );
		ok1( hx_node_nvok(l4) == 1 );
		
		ok1( hx_node_nv(l4) == 1.234 );
		ok1( hx_node_value(l4) != NULL );
		ok1( strcmp(hx_node_value(l4), "1.2340") == 0 );
		ok1( strcmp(hx_node_dt((hx_node_dt_literal*) l4), "http://www.w3.org/2001/XMLSchema#float") == 0 );
		
		hx_node* copy	= hx_node_copy( l4 );
		ok1( copy != NULL );
		ok1( copy != l4 );
		ok1( hx_node_value(l4) != hx_node_value(copy) );
		ok1( strcmp(hx_node_value(l4), hx_node_value(copy)) == 0 );
		
		hx_free_node(l4);
	}
}

void test_resources ( void ) {
	diag("resources test");
	{
		hx_node* r1	= (hx_node*) hx_new_node_resource("http://www.w3.org/2001/XMLSchema#integer");
		ok1( r1 != NULL );
		
		ok1( !hx_node_is_variable(r1) );
		ok1( !hx_node_is_literal(r1) );
		ok1( !hx_node_is_lang_literal(r1) );
		ok1( !hx_node_is_dt_literal(r1) );
		ok1( !hx_node_is_blank(r1) );
		ok1( hx_node_is_resource(r1) );
		
		ok1( hx_node_iv(r1) == 0 );
		ok1( hx_node_value(r1) != NULL );
		ok1( strcmp(hx_node_value(r1), "http://www.w3.org/2001/XMLSchema#integer") == 0 );
		
		hx_free_node(r1);
	}
}

void test_bnodes ( void ) {
	diag("bnodes test");
	{
		hx_node* b1	= (hx_node*) hx_new_node_blank("r1");
		ok1( b1 != NULL );
		
		ok1( !hx_node_is_variable(b1) );
		ok1( !hx_node_is_literal(b1) );
		ok1( !hx_node_is_lang_literal(b1) );
		ok1( !hx_node_is_dt_literal(b1) );
		ok1( hx_node_is_blank(b1) );
		ok1( !hx_node_is_resource(b1) );
		
		ok1( hx_node_iv(b1) == 0 );
		ok1( hx_node_value(b1) != NULL );
		ok1( strcmp(hx_node_value(b1), "r1") == 0 );
		
		hx_free_node(b1);
	}
}

void test_cmp ( void ) {
	hx_node* v1	= hx_new_node_variable( -1 );
	hx_node* v2	= hx_new_node_variable( -2 );
	hx_node* l1	= hx_new_node_literal("a");
	hx_node* l2	= (hx_node*) hx_new_node_lang_literal("bar", "en-us");
	hx_node* l3	= (hx_node*) hx_new_node_dt_literal("7", "http://www.w3.org/2001/XMLSchema#integer");
	hx_node* r1	= (hx_node*) hx_new_node_resource("http://www.w3.org/2001/XMLSchema#integer");
	hx_node* b1	= (hx_node*) hx_new_node_blank("r1");
	
	ok1( hx_node_cmp(b1, r1) == -1 );
	ok1( hx_node_cmp(b1, l1) == -1 );
	ok1( hx_node_cmp(b1, l2) == -1 );
	ok1( hx_node_cmp(b1, l3) == -1 );
	
	ok1( hx_node_cmp(r1, b1) == 1 );
	ok1( hx_node_cmp(r1, l1) == -1 );
	ok1( hx_node_cmp(r1, l2) == -1 );
	ok1( hx_node_cmp(r1, l3) == -1 );
	
	ok1( hx_node_cmp(l1, b1) == 1 );
	ok1( hx_node_cmp(l1, r1) == 1 );
}

void test_store ( void ) {
	diag("file store test");
	const char* filename	= "__test.node.data";
	
	{
		FILE* f	= fopen( filename, "w" );
		if (f == NULL) {
			perror( "*** Failed to open file for writing: " );
			exit(1);
		}
		hx_node* v1	= hx_new_node_variable( -1 );
		hx_node* v2	= hx_new_node_variable( -2 );
		hx_node* l1	= hx_new_node_literal("foo");
		hx_node* l2	= (hx_node*) hx_new_node_lang_literal("bar", "en-us");
		hx_node* l3	= (hx_node*) hx_new_node_dt_literal("7", "http://www.w3.org/2001/XMLSchema#integer");
		hx_node* r1	= (hx_node*) hx_new_node_resource("http://www.w3.org/2001/XMLSchema#integer");
		hx_node* b1	= (hx_node*) hx_new_node_blank("r1");
		
		ok1( hx_node_write( v1, f ) != 0 );
		ok1( hx_node_write( l1, f ) == 0 );
		ok1( hx_node_write( l2, f ) == 0 );
		ok1( hx_node_write( l3, f ) == 0 );
		ok1( hx_node_write( r1, f ) == 0 );
		ok1( hx_node_write( b1, f ) == 0 );
		fclose( f );
	}
	{
		FILE* f	= fopen( filename, "r" );
		if (f == NULL) {
			perror( "*** Failed to open file for reading: " );
			exit(1);
		}
		
		hx_node* l1	= hx_node_read( f, 0 );
		hx_node* l2	= hx_node_read( f, 0 );
		hx_node* l3	= hx_node_read( f, 0 );
		hx_node* r1	= hx_node_read( f, 0 );
		hx_node* b1	= hx_node_read( f, 0 );
		
		ok1( l1 != NULL );
		ok1( strcmp(hx_node_value(l1), "foo") == 0 );
		
		ok1( l2 != NULL );
		ok1( strcmp(hx_node_value(l2), "bar") == 0 );
		
		ok1( l3 != NULL );
		ok1( strcmp(hx_node_value(l3), "7") == 0 );
		
		ok1( r1 != NULL );
		ok1( strcmp(hx_node_value(r1), "http://www.w3.org/2001/XMLSchema#integer") == 0 );
		
		ok1( b1 != NULL );
		ok1( strcmp(hx_node_value(b1), "r1") == 0 );
	}
	unlink( filename );
}

