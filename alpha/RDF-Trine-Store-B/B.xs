#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <b.h>
#include <string.h>
#include <stdlib.h>

MODULE = RDF::Trine::Store::B        PACKAGE = RDF::Trine::Store::B
PROTOTYPES: DISABLE

b_t*
new (class, filename_prefix)
	char* class
	char* filename_prefix
	PREINIT:
		b_t *b;
		b_error_t err;
	CODE:
		if ((err = b_new (&b, (unsigned char*) filename_prefix)) != B_OK) {
			croak("b_new: %s", b_strerror(err));
		}
		RETVAL	= b;
	OUTPUT:
		RETVAL

MODULE = RDF::Trine::Store::B		PACKAGE = b_tPtr		PREFIX = b_

b_iterator_triple_t*
b_iterate (b)
	b_t* b
	PREINIT:
		b_error_t err;
		b_iterator_triple_t *iterator;
	CODE:
		if ((err = b_iterator_triple_new (b, &iterator, NULL)) != B_OK)
			{
				croak("b_iterator_new: %s\n", b_strerror (err));
			}
		RETVAL	= iterator;
	OUTPUT:
		RETVAL

b_iterator_triple_t*
b_find_statements (b, s, p, o)
	b_t* b
	SV* s
	SV* p
	SV* o
	PREINIT:
		b_triple_t* t;
		b_error_t err;
		b_iterator_triple_t *iterator;
		char *subject_uri, *predicate_uri, *object_uri;
		b_uint64 subject_uri_len, predicate_uri_len, object_uri_len;
		char *subject_bnode, *object_bnode;
		b_uint64 subject_bnode_len, object_bnode_len;
		char *object_literal;
		b_uint64 object_literal_len;
		char *lang;
		b_uint64 lang_len;
		char *datatype;
		b_uint64 datatype_len;
		SV* ssv;
		SV* psv;
		SV* osv;
	CODE:
		ssv					= NULL;
		psv					= NULL;
		osv					= NULL;
		subject_uri			= NULL;
		subject_uri_len		= 0;
		subject_bnode		= NULL;
		subject_bnode_len	= 0;
		predicate_uri		= NULL;
		predicate_uri_len	= 0;
		object_uri			= NULL;
		object_uri_len		= 0;
		object_bnode		= NULL;
		object_bnode_len	= 0;
		object_literal		= NULL;
		object_literal_len	= 0;
		datatype			= NULL;
		datatype_len		= 0;
		lang				= NULL;
		lang_len			= 0;
		
		if (SvOK(s)) {
			STRLEN len;
			dSP;
			int count;
			ENTER;
			SAVETMPS;
			PUSHMARK(SP);
			XPUSHs(s);
			PUTBACK;
			count	= call_method("uri_value", G_SCALAR);
			fprintf( stderr, "call_method returned %d results\n", count );
			SPAGAIN;
			if (count != 1)
				croak("Big trouble");
			ssv	= POPs;
			SvREFCNT_inc(ssv);
			PUTBACK;
			FREETMPS;
			LEAVE;
			subject_uri		= SvPV( ssv, len );
			subject_uri_len	= len;
			fprintf( stderr, "*** subject: %s (%d)\n", subject_uri, subject_uri_len );
		}
		
		if (SvOK(p)) {
			STRLEN len;
			dSP;
			int count;
			ENTER;
			SAVETMPS;
			PUSHMARK(SP);
			XPUSHs(p);
			PUTBACK;
			count	= call_method("uri_value", G_SCALAR);
			fprintf( stderr, "call_method returned %d results\n", count );
			SPAGAIN;
			if (count != 1)
				croak("Big trouble");
			psv	= POPs;
			SvREFCNT_inc(psv);
			PUTBACK;
			FREETMPS;
			LEAVE;
			predicate_uri		= SvPV( psv, len );
			predicate_uri_len	= len;
			fprintf( stderr, "*** predicate: %s (%d)\n", predicate_uri, predicate_uri_len );
		}

		if (SvOK(o)) {
			STRLEN len;
			fprintf( stderr, "o: %p\n", o );
			fprintf( stderr, "undef: %p\n", &PL_sv_undef );
			dSP;
			int count;
			ENTER;
			SAVETMPS;
			PUSHMARK(SP);
			XPUSHs(o);
			PUTBACK;
			count	= call_method("uri_value", G_SCALAR);
			fprintf( stderr, "call_method returned %d results\n", count );
			SPAGAIN;
			if (count != 1)
				croak("Big trouble");
			osv	= POPs;
			SvREFCNT_inc(osv);
			PUTBACK;
			FREETMPS;
			LEAVE;
			object_uri		= SvPV( osv, len );
			object_uri_len	= len;
			fprintf( stderr, "*** object: %s (%d)\n", object_uri, object_uri_len );
		}
		
		if ((err = b_triple_new_incomplete(
					&t,
					(unsigned char*) subject_uri, subject_uri_len,
					(unsigned char*) subject_bnode, subject_bnode_len,
					(unsigned char*) predicate_uri, predicate_uri_len,
					(unsigned char*) object_uri, object_uri_len,
					(unsigned char*) object_bnode, object_bnode_len,
					(unsigned char*) object_literal, object_literal_len,
					NULL, 0,
					(unsigned char*) datatype, datatype_len,
					(unsigned char*) lang, lang_len
				) != B_OK) || !t) {
			croak("b_triple_new_incomplete: %s\n", b_strerror(err));
		}
		
		fprintf( stderr, "incomplete triple: %p ", t );
//		b_triple_print( stderr, t );
		if ((err = b_iterator_triple_new (b, &iterator, t)) != B_OK) {
			b_triple_destroy( t );
			croak("b_iterator_new: %s\n", b_strerror (err));
		}
		
		if (ssv)
			SvREFCNT_dec(ssv);
		if (psv)
			SvREFCNT_dec(psv);
		if (osv)
			SvREFCNT_dec(osv);
		
		RETVAL	= iterator;
	OUTPUT:
		RETVAL

void
b_DESTROY(b)
	b_t* b
	PREINIT:
		b_error_t err;
	CODE:
//		fprintf(stderr, "destroying b_t\n");
		if ((err = b_destroy(b)) != B_OK) {
			croak("b_destroy: %s\n", b_strerror(err));
		}
		
MODULE = RDF::Trine::Store::B		PACKAGE = b_iterator_triple_tPtr	PREFIX = iter_

b_triple_t*
iter_next (iter)
	b_iterator_triple_t *iter
	PREINIT:
		b_triple_t *triple;
		b_error_t err;
	CODE:
		if ((err = b_iterator_triple_step(iter, &triple)) == B_OK && triple) {
			RETVAL	= triple;
		} else {
			if (err != B_OK) {
				croak("b_iterator_step: %s\n", b_strerror (err));
			}
			RETVAL	= NULL;
		}
	OUTPUT:
		RETVAL
		
void
iter_DESTROY(iter)
	b_iterator_triple_t *iter
	PREINIT:
		b_error_t err;
	CODE:
//		fprintf(stderr, "destroying iterator\n");
		if ((err = b_iterator_triple_destroy(iter)) != B_OK) {
			croak("b_iterator_destroy: %s\n", b_strerror (err));
		}

MODULE = RDF::Trine::Store::B		PACKAGE = b_triple_tPtr	PREFIX = triple_

SV*
triple_subject(t)
	b_triple_t *t
	PREINIT:
		b_error_t err;
		SV* sv;
	CODE:
		if (t->subject_uri) {
			dSP;
			int count;
			ENTER;
			SAVETMPS;
			PUSHMARK(SP);
			XPUSHs(sv_2mortal(newSVpv( "RDF::Trine::Node::Resource", (STRLEN) 0 )));
			XPUSHs(sv_2mortal(newSVpv( (const char*) t->subject_uri, (STRLEN) 0 )));
			PUTBACK;
			count	= call_method("new", G_SCALAR);
			SPAGAIN;
			if (count != 1)
				croak("Big trouble");
			sv	= POPs;
			SvREFCNT_inc( sv );
			PUTBACK;
			FREETMPS;
			LEAVE;
			RETVAL	= sv;
		} else if (t->subject_bnode) {
			dSP;
			int count;
			ENTER;
			SAVETMPS;
			PUSHMARK(SP);
			XPUSHs(sv_2mortal(newSVpv( "RDF::Trine::Node::Blank", (STRLEN) 0 )));
			XPUSHs(sv_2mortal(newSVpv( (const char*) t->subject_bnode, (STRLEN) 0 )));
			PUTBACK;
			count	= call_method("new", G_SCALAR);
			SPAGAIN;
			if (count != 1)
				croak("Big trouble");
			sv	= POPs;
			SvREFCNT_inc( sv );
			PUTBACK;
			FREETMPS;
			LEAVE;
			RETVAL	= sv;
		}
	OUTPUT:
		RETVAL

SV*
triple_predicate(t)
	b_triple_t *t
	PREINIT:
		b_error_t err;
		SV* sv;
	CODE:
		if (t->property) {
			dSP;
			int count;
			ENTER;
			SAVETMPS;
			PUSHMARK(SP);
			XPUSHs(sv_2mortal(newSVpv( "RDF::Trine::Node::Resource", 0 )));
			XPUSHs(sv_2mortal(newSVpv( (const char*) t->property, 0 )));
			PUTBACK;
			count	= call_method("new", G_SCALAR);
			SPAGAIN;
			if (count != 1)
				croak("Big trouble");
			sv	= POPs;
			SvREFCNT_inc( sv );
			PUTBACK;
			FREETMPS;
			LEAVE;
			RETVAL	= sv;
		}
	OUTPUT:
		RETVAL

SV*
triple_object(t)
	b_triple_t *t
	PREINIT:
		b_error_t err;
		SV* sv;
	CODE:
		if (t->object_uri) {
			dSP;
			int count;
			ENTER;
			SAVETMPS;
			PUSHMARK(SP);
			XPUSHs(sv_2mortal(newSVpv( "RDF::Trine::Node::Resource", 0 )));
			XPUSHs(sv_2mortal(newSVpv( (const char*) t->object_uri, 0 )));
			PUTBACK;
			count	= call_method("new", G_SCALAR);
			SPAGAIN;
			if (count != 1)
				croak("Big trouble");
			sv	= POPs;
			SvREFCNT_inc( sv );
			PUTBACK;
			FREETMPS;
			LEAVE;
			RETVAL	= sv;
		} else if (t->object_bnode) {
			dSP;
			int count;
			ENTER;
			SAVETMPS;
			PUSHMARK(SP);
			XPUSHs(sv_2mortal(newSVpv( "RDF::Trine::Node::Blank", 0 )));
			XPUSHs(sv_2mortal(newSVpv( (const char*) t->object_bnode, 0 )));
			PUTBACK;
			count	= call_method("new", G_SCALAR);
			SPAGAIN;
			if (count != 1)
				croak("Big trouble");
			sv	= POPs;
			SvREFCNT_inc( sv );
			PUTBACK;
			FREETMPS;
			LEAVE;
			RETVAL	= sv;
		} else if (t->object_literal) {
			dSP;
			int count;
			ENTER;
			SAVETMPS;
			PUSHMARK(SP);
			XPUSHs(sv_2mortal(newSVpv( "RDF::Trine::Node::Literal", 0 )));
			XPUSHs(sv_2mortal(newSVpv( (const char*) t->object_literal, 0 )));
			if (t->lang) {
				XPUSHs(sv_2mortal(newSVpv( (const char*) t->lang, 0 )));
			} else if (t->datatype) {
				XPUSHs(&PL_sv_undef);
				XPUSHs(sv_2mortal(newSVpv( (const char*) t->datatype, 0 )));
			}
			
			PUTBACK;
			count	= call_method("new", G_SCALAR);
			SPAGAIN;
			if (count != 1)
				croak("Big trouble");
			sv	= POPs;
			SvREFCNT_inc( sv );
			PUTBACK;
			FREETMPS;
			LEAVE;
			RETVAL	= sv;
		}
	OUTPUT:
		RETVAL

void triple_DESTROY(t)
	b_triple_t *t
	PREINIT:
		b_error_t err;
	CODE:
//		fprintf( stderr, "destroying triple %p\n", t );
		b_triple_destroy(t);
