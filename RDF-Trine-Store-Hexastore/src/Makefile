CFLAGS	=	-I. -L. -std=c99 -pedantic -ggdb -Wall -Wno-unused-value -Wno-unused-variable -Wno-int-to-pointer-cast -Wno-pointer-to-int-cast # -Werror -DAVL_ALLOC_COUNT
CC		=	gcc $(CFLAGS)
LIBS	=	-lpthread -lraptor -L/cs/willig4/local/lib -I/cs/willig4/local/include
OBJECTS	=	hexastore.o index.o terminal.o vector.o head.o avl.o nodemap.o node.o variablebindings.o mergejoin.o materialize.o tap.o btree.o storage.o parser.o

all: parse print optimize tests

parse: parse.c $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o parse parse.c $(OBJECTS)

optimize: optimize.c $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o optimize optimize.c $(OBJECTS)

print: print.c $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o print print.c $(OBJECTS)

hexastore.o: hexastore.c hexastore.h index.h head.h vector.h terminal.h hexastore_types.h variablebindings.h nodemap.h
	$(CC) $(INC) -c hexastore.c

index.o: index.c index.h terminal.h vector.h head.h hexastore_types.h
	$(CC) $(INC) -c index.c

terminal.o: terminal.c terminal.h hexastore_types.h
	$(CC) $(INC) -c terminal.c

vector.o: vector.c vector.h terminal.h hexastore_types.h
	$(CC) $(INC) -c vector.c

head.o: head.c head.h vector.h terminal.h btree.h hexastore_types.h
	$(CC) $(INC) -c head.c

node.o: node.c node.h hexastore_types.h
	$(CC) $(INC) -c node.c
	
nodemap.o: nodemap.c nodemap.h avl.h hexastore_types.h
	$(CC) $(INC) -c nodemap.c

mergejoin.o: mergejoin.c mergejoin.h hexastore_types.h variablebindings.h
	$(CC) $(INC) -c mergejoin.c

variablebindings.o: variablebindings.c variablebindings.h hexastore_types.h node.h index.h nodemap.h
	$(CC) $(INC) -c variablebindings.c

materialize.o: materialize.c materialize.h hexastore_types.h node.h index.h nodemap.h
	$(CC) $(INC) -c materialize.c

btree.o: btree.c btree.h hexastore_types.h
	$(CC) $(INC) -c btree.c

parser.o: parser.c parser.h hexastore_types.h
	$(CC) $(INC) -c parser.c

storage.o: storage.c storage.h hexastore_types.h
	$(CC) $(INC) -c storage.c

tests: t/nodemap.t t/node.t t/index.t t/terminal.t t/vector.t t/head.t t/btree.t t/join.t t/iter.t

########
t/node.t: tap.o t/node.c node.h node.o $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o t/node.t t/node.c $(OBJECTS)

t/nodemap.t: tap.o t/nodemap.c nodemap.h nodemap.o $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o t/nodemap.t t/nodemap.c $(OBJECTS)

t/index.t: tap.o t/index.c index.h index.o $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o t/index.t t/index.c $(OBJECTS)

t/terminal.t: tap.o t/terminal.c terminal.h terminal.o $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o t/terminal.t t/terminal.c $(OBJECTS)

t/vector.t: tap.o t/vector.c vector.h vector.o $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o t/vector.t t/vector.c $(OBJECTS)

t/head.t: tap.o t/head.c head.h head.o $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o t/head.t t/head.c $(OBJECTS)

t/btree.t: tap.o t/btree.c btree.h btree.o $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o t/btree.t t/btree.c $(OBJECTS)

t/join.t: tap.o t/join.c $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o t/join.t t/join.c $(OBJECTS)

t/iter.t: tap.o t/iter.c $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o t/iter.t t/iter.c $(OBJECTS)

########

avl.o: avl.c avl.h hexastore_types.h
	$(CC) $(INC) -c avl.c

tap.o: tap.c tap.h
	$(CC) $(INC) -c tap.c

clean:
	rm -f test parse print optimize a.out
	rm -f *.o
	rm -rf *.dSYM t/*.dSYM
	rm -f t/*.t

