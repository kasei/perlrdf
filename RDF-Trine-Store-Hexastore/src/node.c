#include "node.h"

hx_node* _hx_new_node ( char type, char* value, int padding ) {
	hx_node* n	= (hx_node*) calloc( 1, sizeof( hx_node ) + padding );
	n->id		= (hx_node_id) 0;
	n->type		= type;
	n->value	= malloc( strlen( value ) + 1 );
	if (n->value == NULL) {
		free( n );
		return NULL;
	}
	strcpy( n->value, value );
	return n;
}

hx_node* hx_new_node_resource ( char* value ) {
	hx_node* n	= _hx_new_node( 'R', value, 0 );
	return n;
}

hx_node* hx_new_node_blank ( char* value ) {
	hx_node* n	= _hx_new_node( 'B', value, 0 );
	return n;
}

hx_node* hx_new_node_literal ( char* value ) {
	hx_node* n	= _hx_new_node( 'L', value, 0 );
	return n;
}

hx_node_lang_literal* hx_new_node_lang_literal ( char* value, char* lang ) {
	int padding	= sizeof( hx_node_lang_literal ) - sizeof( hx_node );
	hx_node_lang_literal* n	= (hx_node_lang_literal*) _hx_new_node( 'G', value, padding );
	n->lang		= malloc( strlen( lang ) + 1 );
	if (n->lang == NULL) {
		free( n->value );
		free( n );
		return NULL;
	}
	strcpy( n->lang, lang );
	return n;
}

hx_node_dt_literal* hx_new_node_dt_literal ( char* value, char* dt ) {
	int padding	= sizeof( hx_node_dt_literal ) - sizeof( hx_node );
	hx_node_dt_literal* n	= (hx_node_dt_literal*) _hx_new_node( 'D', value, padding );
	n->dt		= malloc( strlen( dt ) + 1 );
	if (n->dt == NULL) {
		free( n->value );
		free( n );
		return NULL;
	}
	strcpy( n->dt, dt );
	return n;
}

int hx_free_node( hx_node* n ) {
	if (n->type == 'G') {
		hx_node_lang_literal* l	= (hx_node_lang_literal*) n;
		free( l->lang );
	} else if (n->type == 'D') {
		hx_node_dt_literal* d	= (hx_node_dt_literal*) n;
		free( d->dt );
	}
	free( n->value );
	free( n );
	return 0;
}
