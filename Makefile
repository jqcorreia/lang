test:
	odin run .
	gcc -o calc calc.o
	./calc
