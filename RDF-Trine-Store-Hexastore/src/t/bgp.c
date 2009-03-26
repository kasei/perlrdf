#include "hexastore.h"
#include "bgp.h"
#include "tap.h"

void _fill_triple ( hx_triple* t, hx_node* s, hx_node* p, hx_node* o );

void bgp1_test ( void );
void bgp2_test ( void );
void bgp3_test ( void );

hx_node *p1, *p2, *r1, *r2, *l1, *l2, *l3;
int main ( void ) {
	plan_tests(3);
	
	p1	= hx_new_node_resource( "p1" );
	p2	= hx_new_node_resource( "p2" );
	r1	= hx_new_node_resource( "r1" );
	r2	= hx_new_node_resource( "r2" );
	l1	= hx_new_node_literal( "l1" );
	l2	= hx_new_node_literal( "l2" );
	l3	= hx_new_node_literal( "l3" );
	
	bgp1_test();
	bgp2_test();
	bgp3_test();
	
	hx_free_node( p1 );
	hx_free_node( p2 );
	hx_free_node( r1 );
	hx_free_node( r2 );
	hx_free_node( l1 );
	hx_free_node( l2 );
	
	return exit_status();
}


void bgp1_test ( void ) {
	char* string;
	hx_triple t1;
	_fill_triple( &t1, r1, p1, l1 );
	hx_bgp* b	= hx_new_bgp1( &t1 );
	hx_bgp_string( b, &string );
	ok1( strcmp(string, "{\n\t<r1> <p1> \"l1\" .\n}\n") == 0 );
	free( string );
	hx_free_bgp( b );
}

void bgp2_test ( void ) {
	char* string;
	hx_triple t1, t2;
	
	{
		_fill_triple( &t1, r1, p1, l1 );
		_fill_triple( &t2, r2, p1, l2 );
		hx_bgp* b	= hx_new_bgp2( &t1, &t2 );
		hx_bgp_string( b, &string );
		ok1( strcmp(string, "{\n\t<r1> <p1> \"l1\" .\n\t<r2> <p1> \"l2\" .\n}\n") == 0 );
		free( string );
		hx_free_bgp( b );
	}
}

void bgp3_test ( void ) {
	char* string;
	hx_triple t1, t2, t3, t4;
	{
		_fill_triple( &t1, r1, p1, l1 );
		_fill_triple( &t2, r2, p1, l2 );
		_fill_triple( &t3, r2, p1, l3 );
		_fill_triple( &t3, r2, p2, l1 );
		hx_triple* triples[3]	= { &t1, &t2, &t3 };
		hx_bgp* b		= hx_new_bgp( 3, triples );
		hx_bgp_string( b, &string );
		ok1( strcmp(string, "{\n\t<r1> <p1> \"l1\" .\n\t<r2> <p1> \"l2\" ;\n\t\t<p2> \"l1\" .\n}\n") == 0 );
		free( string );
		hx_free_bgp( b );
	}
}

void _fill_triple ( hx_triple* t, hx_node* s, hx_node* p, hx_node* o ) {
	t->subject		= s;
	t->predicate	= p;
	t->object		= o;
}
