CFLAGS	=	-std=c99 -pedantic # -Werror -Wall
CC		=	gcc $(CFLAGS)
LIBS	=	-lraptor -lcrypto
# INC		=	-L/Users/samofool/Library/__G5_local/lib

all: main

main: main.c hexastore.o index.o terminal.o vector.o head.o
	$(CC) $(INC) main.c hexastore.o index.o terminal.o vector.o head.o

hexastore.o: hexastore.c hexastore.h index.h head.h vector.h terminal.h
	$(CC) $(INC) -c hexastore.c

index.o: index.c index.h terminal.h vector.h head.h
	$(CC) $(INC) -c index.c

terminal.o: terminal.c terminal.h
	$(CC) $(INC) -c terminal.c

vector.o: vector.c vector.h terminal.h
	$(CC) $(INC) -c vector.c

head.o: head.c head.h vector.h terminal.h
	$(CC) $(INC) -c head.c

clean:
	rm *.o
	rm a.out
