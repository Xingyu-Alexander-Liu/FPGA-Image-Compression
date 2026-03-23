# this makefile is intended for gcc on linux

IMG_PATH = ../data
TEST_IMAGE = $(IMG_PATH)/motorcycle
QUANT = 0
DEBUG_LEVEL = 1
CC = /usr/bin/gcc -Wall

target: compile

compile: Project.o Compare.o Decoder.o Encoder.o Parse_bmp.o
	 $(CC) -o Project Project.o Compare.o Decoder.o Encoder.o Parse_bmp.o -lm 
	
Project.o : Project.c 
Compare.o : Compare.c 
Decoder.o : Decoder.c Coding.h 
Encoder.o : Encoder.c Coding.h 
Parse_bmp.o : Parse_bmp.c 

clean: 
	rm -f Project *.o $(IMG_PATH)/*.d* $(IMG_PATH)/*.mic* $(IMG_PATH)/*.ppm

test: compile
	./Project -parse $(TEST_IMAGE) $(TEST_IMAGE) 
	./Project -encode $(TEST_IMAGE) $(QUANT) $(TEST_IMAGE)-$(QUANT) -debug $(DEBUG_LEVEL)
	./Project -decode $(TEST_IMAGE)-$(QUANT) $(TEST_IMAGE)-$(QUANT)
	./Project -compare $(TEST_IMAGE) $(TEST_IMAGE)-$(QUANT)
