#include <b.h>
#include <raptor.h>
#include <string.h>
#include <stdlib.h>

#define TEST4_MAX 4096

#ifdef WIN32
#define snprintf sprintf_s
#define TEST4_FILE ".\\TEST4"
#else
#define TEST4_FILE "/tmp/test4"
#endif

void GTW_load_data( const char *filename, b_t* b );
void GTW_handle_triple(void* user_data, const raptor_statement* triple);
void GTW_extract_fields( void *node, raptor_identifier_type type, char* lang, raptor_uri* dt, char **object_uri, b_uint64 *object_uri_len, char **object_bnode, b_uint64 *object_bnode_len, char **object_literal, b_uint64 *object_literal_len, char **object_lang, b_uint64 *object_lang_len, char **object_datatype, b_uint64 *object_datatype_len );

void GTW_handle_triple(void* user_data, const raptor_statement* triple)	{
	b_t *b	= (b_t*) user_data;
	b_triple_t *btriple;
	
	char *subject_uri, *predicate_uri, *object_uri;
	b_uint64 subject_uri_len, predicate_uri_len, object_uri_len;
	char *subject_bnode, *object_bnode;
	b_uint64 subject_bnode_len, object_bnode_len;
	char *object_literal;
	b_uint64 object_literal_len;
	char *object_lang;
	b_uint64 object_lang_len;
	char *object_datatype;
	b_uint64 object_datatype_len;
	b_error_t err;
	
	GTW_extract_fields( (void*) triple->subject, triple->subject_type, NULL, NULL, &subject_uri, &subject_uri_len, &subject_bnode, &subject_bnode_len, NULL, NULL, NULL, NULL, NULL, NULL );
	GTW_extract_fields( (void*) triple->predicate, triple->predicate_type, NULL, NULL, &predicate_uri, &predicate_uri_len, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL );
	GTW_extract_fields( (void*) triple->object, triple->object_type, (char*) triple->object_literal_language, triple->object_literal_datatype, &object_uri, &object_uri_len, &object_bnode, &object_bnode_len, &object_literal, &object_literal_len, &object_lang, &object_lang_len, &object_datatype, &object_datatype_len );
	if ((err = b_triple_new (&btriple,
				(unsigned char*) subject_uri,
				subject_uri_len,
				(unsigned char*) subject_bnode,
				subject_bnode_len,
				(unsigned char*) predicate_uri,
				predicate_uri_len,
				(unsigned char*) object_uri,
				object_uri_len,
				(unsigned char*) object_bnode,
				object_bnode_len,
				(unsigned char*) object_literal,
				object_literal_len,
				NULL,
				0,
				(unsigned char*) object_datatype,
				object_datatype_len,
				(unsigned char*) object_lang,
				object_lang_len
			)) != B_OK) {
		fprintf (stderr, "b_triple_new: %s\n", b_strerror (err));
		return;
	}
	
	if (strcmp(predicate_uri, "http://www.w3.org/2002/07/owl#imports") == 0) {
		b_uint64 count;
		fprintf(stderr, "*** ");
		b_triple_print (stderr, btriple);
		b_count_triple( b, &count );
		fprintf(stderr, "\t- %d\n", (int) count);
	}
	
	if ((err = b_add_triple (b, btriple)) != B_OK) {
		fprintf (stderr, "b_add: %s\n", b_strerror (err));
		return;
	}

	b_triple_destroy (btriple);
}

void GTW_extract_fields( void *node, raptor_identifier_type type, char* lang, raptor_uri* dt, char **object_uri, b_uint64 *object_uri_len, char **object_bnode, b_uint64 *object_bnode_len, char **object_literal, b_uint64 *object_literal_len, char **object_lang, b_uint64 *object_lang_len, char **object_datatype, b_uint64 *object_datatype_len ) {
	*object_uri				= NULL;
	*object_uri_len			= 0;
	
	if (object_bnode) {
		*object_bnode			= NULL;
		*object_bnode_len		= 0;
	}
	
	if (object_literal) {
		*object_literal			= NULL;
		*object_literal_len		= 0;
		*object_lang			= NULL;
		*object_lang_len		= 0;
		*object_datatype		= NULL;
		*object_datatype_len	= 0;
	}
	
	switch (type) {
		case RAPTOR_IDENTIFIER_TYPE_LITERAL:
			*object_literal		= (char*)node;
			*object_literal_len	= strlen( *object_literal );
			if(lang && type == RAPTOR_IDENTIFIER_TYPE_LITERAL) {
				*object_lang			= (char*) lang;
				*object_lang_len		= strlen(*object_lang);
			} else if (dt) {
				*object_datatype		= (char*) raptor_uri_as_string((raptor_uri*) dt);
				*object_datatype_len	= strlen(*object_datatype);
			}
			break;
		case RAPTOR_IDENTIFIER_TYPE_XML_LITERAL:
			*object_literal			= (char*)node;
			*object_literal_len		= strlen( *object_literal );
			*object_datatype		= "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral";
			*object_datatype_len	= strlen( *object_datatype );
			break;
		case RAPTOR_IDENTIFIER_TYPE_ANONYMOUS:
			*object_bnode		= (char*) node;
			*object_bnode_len	= strlen( *object_bnode );
			break;
		case RAPTOR_IDENTIFIER_TYPE_ORDINAL:
			*object_uri		= malloc( 64 );
			*object_uri_len	= strlen( *object_uri );
			sprintf( *object_uri, "http://www.w3.org/1999/02/22-rdf-syntax-ns#_%d", *((int*) node) );
			break;
		case RAPTOR_IDENTIFIER_TYPE_RESOURCE:
		case RAPTOR_IDENTIFIER_TYPE_PREDICATE:
			*object_uri	= (char*) raptor_uri_as_string((raptor_uri*)node);
			*object_uri_len	= strlen( *object_uri );
			break;
		case RAPTOR_IDENTIFIER_TYPE_UNKNOWN:
		default:
			fprintf(stderr, "*** unknown node type %d\n", type);
	}
}

void GTW_load_data( const char *rdf_filename, b_t* b ) {
	raptor_parser* rdf_parser=NULL;
	unsigned char *uri_string;
	raptor_uri *uri, *base_uri;
	raptor_init();
	rdf_parser	= raptor_new_parser("rdfxml");
	raptor_set_statement_handler(rdf_parser, b, GTW_handle_triple);
	uri_string	= raptor_uri_filename_to_uri_string( rdf_filename );
	uri			= raptor_new_uri(uri_string);
	base_uri	= raptor_uri_copy(uri);
	raptor_parse_file(rdf_parser, uri, base_uri);
}

int main (int argc, char **argv) {
	b_t *b;
	b_triple_t *triple;
	b_error_t err;
	char* data_prefix;
	char* rdf_filename;
	b_iterator_triple_t *iterator;
	b_uint64 count;
	
	if (!(argc == 2 || argc == 3)) {
		fprintf(stderr, "USAGE: %s data_file_prefix [ data.rdf ]\n\n", argv[0]);
		return 1;
	}
	
	data_prefix	= argv[1];
	fprintf (stderr, "Creating new b struct... ");
	if ((err = b_new (&b, (unsigned char*) data_prefix)) != B_OK) {
		fprintf (stderr, "b_new: %s\n", b_strerror (err));
		return 1;
	}
	fprintf (stderr, "done.\n");
	
	if (argc == 3) {
		fprintf (stderr, "Loading RDF data... ");
		rdf_filename	= argv[2];
		GTW_load_data( rdf_filename, b );
		fprintf (stderr, "done.\n");
	}

	fprintf (stderr, "Creating iterator... ");
	if ((err = b_iterator_triple_new (b, &iterator, NULL)) != B_OK)
		{
			fprintf (stderr, "b_iterator_new: %s\n", b_strerror (err));
			return 1;
		}

	fprintf (stderr, "done.\n");

	count	= 0;
	while ((err = b_iterator_triple_step (iterator, &triple)) == B_OK && triple)
		{
			count++;
			fprintf (stdout, "[%05d] Next data: ", (int) count);
			b_triple_print (stdout, triple);
			b_triple_destroy (triple);
		}

	if (err != B_OK)
		{
			fprintf (stderr, "b_iterator_step: %s\n", b_strerror (err));
			return 1;
		}

	fprintf (stderr, "Destroying iterator... ");
	if ((err = b_iterator_triple_destroy (iterator)) != B_OK)
		{
			fprintf (stderr, "b_iterator_destroy: %s\n", b_strerror (err));
			return 1;
		}

	fprintf (stderr, "done.\nDestroing the b struct... ");

	if ((err = b_destroy (b)) != B_OK)
		{
			fprintf (stderr, "b_destroy: %s\n", b_strerror (err));
			return 1;
		}

	fprintf (stderr, "done.\n");
	return 0;
}
