CFLAGS	=	-std=c99 -pedantic # -Werror -Wall
CC		=	gcc $(CFLAGS)
LIBS	=	-lraptor -lcrypto
# INC		=	-L/Users/samofool/Library/__G5_local/lib

all: main

main: main.c hexastore.o
	$(CC) $(INC) main.c hexastore.o

hexastore.o: hexastore.c hexastore.h
	$(CC) $(INC) -c hexastore.c

clean:
	rm *.o
	rm a.out
