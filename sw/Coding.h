/*
   Copyright by Adam Kinsman and Nicola Nicolici
   Department of Electrical and Computer Engineering
   McMaster University
   Ontario, Canada
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#ifndef PI
#ifdef M_PI
#define PI M_PI
#else
#define PI 3.14159265358979323846
#endif
#endif

// codes for lossless coding
#define ZERO_RUN  0
#define CODE_9    1
#define CODE_3    2
#define BLOCK_END 3

// RGB component indices
#define R 0
#define G 1
#define B 2

// YUV component indices
#define Y 0
#define U 1
#define V 2

// indices for accessing a desired sample from memory
#define YUV_offset(colour,num_rows,num_cols) ((colour) ? ((colour)/2) ? (3*(num_rows)*(num_cols)/2) : ((num_rows)*(num_cols)) : 0)
#define YUV_row_step(colour,num_cols) ((colour) ? (num_cols)/2 : (num_cols))

#define RGB_index(num_rows,num_cols,row,col,colour) (3*((row)*(num_cols)+(col))+(colour))
#define YUV_index(num_rows,num_cols,row,col,colour)   \
	YUV_offset(colour,num_rows,num_cols) +             \
	(row)*YUV_row_step(colour,num_cols) + (col)

// lossless coding scan pattern
static int Scan_Pattern[64] = {
	0,  1,  8, 16,  9,  2,  3, 10, 17, 24, 32, 25, 18, 11,  4,  5,
	12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13,  6,  7, 14, 21, 28,
	35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
	58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63 };

