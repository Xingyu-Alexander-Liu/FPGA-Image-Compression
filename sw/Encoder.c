/*
Copyright by Adam Kinsman and Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

#include "Coding.h"

// image data type
typedef struct image_struct {
	int Rows, Columns;
	double *Pixel_Data;
} image;

// coefficient matrix for DCT
double DCT_Coeffs[8][8];

// global variables (with limited scope) related to debug
// (for generating hardware validation data)
static int debug_level;
static double *debug_data;
static char debug_filename[100];
static FILE *debug_file;

// function prototypes
void Fetch_Image(char *, image *);
void Colour_Space_422(image *, image *);
void Discrete_Cosine_Transform(image *, image *, int);
void Init_DCT_Coeffs(void);
static void Fetch_Block(double *, double [][8], int, int, int, int, int);
void Quantize_Block(double [][8], int);
void Block_DCT(double [][8]);
static void Write_Block(double [][8], double *, int, int, int, int, int);
void Lossless_Coding(image *, char *, int);
unsigned int Write_Coded_Block(double [][8], FILE *);
unsigned int Write_Bits(FILE *, int, int);

void Encoder(char *Source_Filename, int Compression_Format, char *Destination_Filename, int debug_info) {
	image Source_Image, Downsampled_Image, DCT_Image;

	// setup for debug
	debug_level = debug_info;
	sprintf(debug_filename, "%s.d%de", Destination_Filename, debug_level);

	strcat(Source_Filename, ".ppm");
	strcat(Destination_Filename, ".mic");
	printf("Encoding image %s to file %s\n", Source_Filename, Destination_Filename);

	// Compress the image
	Fetch_Image(Source_Filename, &Source_Image);
	Colour_Space_422(&Source_Image, &Downsampled_Image);
	Discrete_Cosine_Transform(&Downsampled_Image, &DCT_Image, Compression_Format);
	Lossless_Coding(&DCT_Image, Destination_Filename, Compression_Format);

	free(DCT_Image.Pixel_Data);
	free(Downsampled_Image.Pixel_Data);
	free(Source_Image.Pixel_Data);
}

void Fetch_Image(char *Filename, image *Source_Image) {
	int i, j, Rows, Columns;
	char temp_string[20];
	double *Pixel_Data;
	FILE *Source_File;

	// open the file
	if ((Source_File = fopen(Filename, "rb")) == NULL) {
		printf("Problem opening source image %s\n", Filename); exit(1); }

	// extract header information
	fscanf(Source_File, "%s", temp_string);     // image type - usually P6
	fscanf(Source_File, "%d", &Columns);        // Pixel Columns
	fscanf(Source_File, "%d", &Rows);           // Pixel Rows
	fscanf(Source_File, "%s", temp_string);     // max colours - usually 255
	fgetc(Source_File);

	// read the image data
	Pixel_Data = (double *)malloc(Rows*Columns*3*sizeof(double));
	for (i = 0; i < Rows; i++)
		for (j = 0; j < Columns; j++) {
			Pixel_Data[RGB_index(Rows,Columns,i,j,R)] = (double)((int)fgetc(Source_File));
			Pixel_Data[RGB_index(Rows,Columns,i,j,G)] = (double)((int)fgetc(Source_File));
			Pixel_Data[RGB_index(Rows,Columns,i,j,B)] = (double)((int)fgetc(Source_File));
		}
	fclose(Source_File);

	Source_Image->Rows = Rows;
	Source_Image->Columns = Columns;
	Source_Image->Pixel_Data = Pixel_Data;
}

void Colour_Space_422(image *Source_Image, image *Downsampled_Image) {
	int i, j, colour;
	int Source_Rows, Source_Columns, Downsampled_Rows, Downsampled_Columns;
	int jm5, jm3, jm1, jp1, jp3, jp5;
	double *Source_Data, *Downsampled_Data;
 	double Y_val, U_val, V_val, R_val, G_val, B_val;
 	double RGB_YUV_matrix_int[9] = {
		16843.0,   33030.0,   6423.0,
		-9699.0,  -19071.0,   28770.0,
		28770.0,  -24117.0,  -4653.0 };
	double RGB_YUV_matrix_dbl[9] = {
		 0.257,   0.504,   0.098,
		-0.148,  -0.291,   0.439, 
		 0.439,  -0.368,  -0.071 };

	Source_Rows = Source_Image->Rows;
	Source_Columns = Source_Image->Columns;
	Source_Data = Source_Image->Pixel_Data;

	// Colourspace conversion
	for (i = 0; i < Source_Rows; i++)
		for (j = 0; j < Source_Columns; j++) {
			R_val = Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, R)];
			G_val = Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, G)];
			B_val = Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, B)];

			if (debug_level == 4) {
				Y_val = RGB_YUV_matrix_dbl[0]*R_val + RGB_YUV_matrix_dbl[1]*G_val + RGB_YUV_matrix_dbl[2]*B_val; 
				Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, G)] = Y_val + 16.0;

				U_val = RGB_YUV_matrix_dbl[3]*R_val + RGB_YUV_matrix_dbl[4]*G_val + RGB_YUV_matrix_dbl[5]*B_val; 
				Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, B)] = U_val + 128.0;

				V_val = RGB_YUV_matrix_dbl[6]*R_val + RGB_YUV_matrix_dbl[7]*G_val + RGB_YUV_matrix_dbl[8]*B_val; 
				Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, R)] = V_val + 128.0;				
			} else {
				Y_val = RGB_YUV_matrix_int[0]*R_val + RGB_YUV_matrix_int[1]*G_val + RGB_YUV_matrix_int[2]*B_val;
				Y_val += (double)(((16 << 1) + 1) << 15); Y_val = floor(Y_val / (double)(1 << 16));
				if (Y_val < 0.0) 
					Y_val = 0.0; 
				if (Y_val > 255.0) 
					Y_val = 255.0;
				Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, G)] = Y_val;

				U_val = RGB_YUV_matrix_int[3]*R_val + RGB_YUV_matrix_int[4]*G_val + RGB_YUV_matrix_int[5]*B_val;
				U_val += (double)(((128 << 1) + 1) << 15); U_val = floor(U_val / (double)(1 << 16));
				Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, B)] = U_val;

				V_val = RGB_YUV_matrix_int[6]*R_val + RGB_YUV_matrix_int[7]*G_val + RGB_YUV_matrix_int[8]*B_val;
				V_val += (double)(((128 << 1) + 1) << 15); V_val = floor(V_val / (double)(1 << 16));
				Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, R)] = V_val;
			}
		}

	// Downsampling
	Downsampled_Rows = Source_Rows;
	Downsampled_Columns = Source_Columns;
	Downsampled_Data = (double *)malloc(Downsampled_Rows*Downsampled_Columns*2*sizeof(double));
	if (debug_level == 1) 
		debug_data = (double *)malloc(Source_Rows*Source_Columns*3*sizeof(double));

	for (i = 0; i < Downsampled_Rows; i++)
		for (j = 0; j < Downsampled_Columns; j++) {
			Downsampled_Data[YUV_index(Downsampled_Rows, Downsampled_Columns, i, j, Y)] =
				Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, G)];
			if (debug_level == 1)
				debug_data[YUV_index(Downsampled_Rows, Downsampled_Columns, i, j, Y)] =
					Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, G)];

			if (j%2 == 0) {
				jm5 = (j < 5) ? 0 : j - 5;
				jm3 = (j < 3) ? 0 : j - 3;
				jm1 = (j < 1) ? 0 : j - 1;
				jp1 = (j < (Downsampled_Columns - 1)) ? j + 1 : Downsampled_Columns - 1;
				jp3 = (j < (Downsampled_Columns - 3)) ? j + 3 : Downsampled_Columns - 1;
				jp5 = (j < (Downsampled_Columns - 5)) ? j + 5 : Downsampled_Columns - 1;

				if (debug_level == 4) {
					Downsampled_Data[YUV_index(Downsampled_Rows, Downsampled_Columns, i, j/2, U)] = 
						0.043 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jm5, B)] -
						0.102 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jm3, B)] +
						0.311 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jm1, B)] + 
						0.500 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, B)] + 
						0.311 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jp1, B)] - 
						0.102 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jp3, B)] +
						0.043 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jp5, B)];

					Downsampled_Data[YUV_index(Downsampled_Rows, Downsampled_Columns, i, j/2, V)] = 
						0.043 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jm5, R)] -
						0.102 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jm3, R)] +
						0.311 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jm1, R)] + 
						0.500 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, R)] + 
						0.311 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jp1, R)] - 
						0.102 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jp3, R)] +
						0.043 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jp5, R)];
				} else {
					U_val = 
						 22.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jm5, B)] -
						 52.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jm3, B)] +
						159.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jm1, B)] +
						256.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, B)] +
						159.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jp1, B)] -
						 52.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jp3, B)] +
						 22.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jp5, B)];
					U_val += (double)(1 << 8); U_val = floor(U_val / (double)(1 << 9));
					if (U_val < 0.0) 
						U_val = 0.0; 
					if (U_val > 255.0) 
						U_val = 255.0;
					Downsampled_Data[YUV_index(Downsampled_Rows, Downsampled_Columns, i, j/2, U)] = U_val;
					if (debug_level == 1)
						debug_data[YUV_index(Downsampled_Rows, Downsampled_Columns, i, j/2, U)] = U_val;

					V_val = 
						 22.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jm5, R)] -
						 52.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jm3, R)] +
						159.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jm1, R)] +
						256.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, j, R)] +
						159.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jp1, R)] -
						 52.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jp3, R)] +
						 22.0 * Source_Data[RGB_index(Source_Rows, Source_Columns, i, jp5, R)];
					V_val += (double)(1 << 8); V_val = floor(V_val / (double)(1 << 9));
					if (V_val < 0.0) 
						V_val = 0.0; 
					if (V_val > 255.0) 
						V_val = 255.0;
					Downsampled_Data[YUV_index(Downsampled_Rows, Downsampled_Columns, i, j/2, V)] = V_val;
					if (debug_level == 1)
						debug_data[YUV_index(Downsampled_Rows, Downsampled_Columns, i, j/2, V)] = V_val;
				}
			}				
		}

	Downsampled_Image->Rows = Downsampled_Rows;
	Downsampled_Image->Columns = Downsampled_Columns;
	Downsampled_Image->Pixel_Data = Downsampled_Data;

	if (debug_level == 1) {
		printf("Writing debug information for level %d to file %s\n", debug_level, debug_filename);
		if ((debug_file = fopen(debug_filename, "wb")) == NULL) {
			printf("Problem opening debug file %s\n", debug_filename); exit(1); }
		for (colour = 0; colour < 3; colour++) {
			for (i = 0; i < Downsampled_Rows; i++)
				for (j = 0; j < Downsampled_Columns; j++)
					fprintf(debug_file, "%c",
						((int)(debug_data[YUV_index(Source_Rows, Source_Columns, i, j, colour)])) & 0xFF );
			if (colour == Y) Downsampled_Columns /= 2;
		}
		fclose(debug_file);
		free(debug_data);
	}
}

void Discrete_Cosine_Transform(image *Downsampled_Image, image *DCT_Image, int Compression_Format) {
	int colour, i, j, DCT_Rows, DCT_Columns, Block_Rows, Block_Columns;
	double *Downsampled_Data, *DCT_Data, Block_Data[8][8];

	DCT_Rows = Downsampled_Image->Rows;
	DCT_Columns = Downsampled_Image->Columns;

	Block_Rows = DCT_Rows/8;
	Block_Columns = DCT_Columns/8;

	Downsampled_Data = Downsampled_Image->Pixel_Data;
	DCT_Data = (double *)malloc(DCT_Rows*DCT_Columns*2*sizeof(double));
	if (debug_level == 2) 
		debug_data = (double *)malloc(DCT_Rows*DCT_Columns*2*sizeof(double));

	Init_DCT_Coeffs();

	// process the blocks in sequence, from Y to U to V
	// for a given component, process the blocks by rows
	for (colour = 0; colour < 3; colour++) {
		for (i = 0; i < Block_Rows; i++)
			for (j = 0; j < Block_Columns; j++) {
				Fetch_Block(Downsampled_Data, Block_Data, i, j, DCT_Rows, DCT_Columns, colour);
				Block_DCT(Block_Data);
				if (debug_level == 2)
					Write_Block(Block_Data, debug_data, i, j, DCT_Rows, DCT_Columns, colour);
				Write_Block(Block_Data, DCT_Data, i, j, DCT_Rows, DCT_Columns, colour);
			}
		if (colour == Y) Block_Columns /= 2;   // since U and V have half as many columns
	}

	if (debug_level == 2) {
		printf("Writing debug information for level %d to file %s\n", debug_level, debug_filename);
		Block_Rows = DCT_Rows;
		Block_Columns = DCT_Columns;
		if ((debug_file = fopen(debug_filename, "wb")) == NULL) {
			printf("Problem opening debug file %s\n", debug_filename); exit(1); }
		for (colour = 0; colour < 3; colour++) {
			for (i = 0; i < Block_Rows; i++)
				for (j = 0; j < Block_Columns; j++)
					fprintf(debug_file, "%c%c",
						((int)(debug_data[YUV_index(DCT_Rows, DCT_Columns, i, j, colour)]) >> 8) & 0xFF,
						 (int)(debug_data[YUV_index(DCT_Rows, DCT_Columns, i, j, colour)]) & 0xFF );
			if (colour == Y) Block_Columns /= 2;
		}
		fclose(debug_file);
		free(debug_data);
	}

	DCT_Image->Rows = DCT_Rows;
	DCT_Image->Columns = DCT_Columns;
	DCT_Image->Pixel_Data = DCT_Data;
}

void Init_DCT_Coeffs(void) {
	int i, j;
	double s;

	for (i = 0; i < 8; i++) {
		s = (i == 0) ? sqrt(1.0 / 8.0) : sqrt(2.0 / 8.0);
		for (j = 0; j < 8; j++) {
			if (debug_level == 4) {
				DCT_Coeffs[i][j] = s * cos((PI/8.0)*i*(j + 0.5));
			} else {
				DCT_Coeffs[i][j] = (double)((int)(s*cos((PI/8.0)*i*(j + 0.5))*4096.0)); // fixed point at bit 12
			}
		}
	}

	// debug information
	if (debug_level == 3) {
		printf("Writing debug information for level %d to file %s\n", debug_level, debug_filename);
		if ((debug_file = fopen(debug_filename, "wb")) == NULL) {
			printf("Problem opening debug file %s\n", debug_filename); exit(1); }
		for (i = 0; i < 8; i++) {
			for (j = 0; j < 8; j++)
				fprintf(debug_file, "%5d ", (int)(DCT_Coeffs[i][j]));
			fprintf(debug_file, "\n");
		}
		fclose(debug_file);
	}
}

static void Fetch_Block(double *Downsampled_Data, double Block_Data[][8],
   int Block_Row, int Block_Column, int Rows, int Columns, int colour
) {
	int i, j;

	for (i = 0; i < 8; i++)
		for (j = 0; j < 8; j++)
			Block_Data[i][j] = Downsampled_Data[YUV_index(Rows, Columns,
				8*Block_Row+i, 8*Block_Column+j, colour)];
}

void Quantize_Block(double Block_Data[][8], int Compression_Format) {
	int i, j, s;
	double t;
	
	// quantization
	for (j = 0; j < 8; j++)
		for (i = 0; i < 8; i++) {
			if (Compression_Format == 0) {          // use quantization matrix Q0
				if ((i + j) >= 8) s = 6;
				else if ((i + j) >= 6) s = 5;
				else if ((i + j) >= 4) s = 4;
				else if ((i + j) >= 2) s = 3;
				else if ((i + j) >= 1) s = 2;
				else s = 3;
			} else if (Compression_Format == 1) {   // use quantization matrix Q1
				if ((i + j) >= 8) s = 5;
				else if ((i + j) >= 6) s = 4;
				else if ((i + j) >= 4) s = 3;
				else if ((i + j) >= 2) s = 2;
				else if ((i + j) >= 1) s = 2;
				else s = 3;
			} else {                                // use quantization matrix Q2
				if ((i + j) >= 8) s = 4;
				else if ((i + j) >= 6) s = 3;
				else if ((i + j) >= 4) s = 2;
				else if ((i + j) >= 2) s = 1;
				else if ((i + j) >= 1) s = 1;
				else s = 3;
			}

			// pointwise division
			t = floor((Block_Data[i][j] + (double)(1 << (s-1))) / (double)(1 << s));

			// clipping to retain 9-bit coefficients (-256 .. 255)
			Block_Data[i][j] = (t < -256.0) ? -256.0 : (t > 255.0) ? 255.0 : t;
		}
}

void Block_DCT(double Block_Data[][8]) {
	int i, j, k;
 	double s, temp[8][8];

	// post-multiplication with the transposed coefficient matrix
	for (i = 0; i < 8; i++)
		for (j = 0; j < 8; j++) {
			s = 0.0;
			for (k = 0; k < 8; k++)
				s += Block_Data[i][k] * DCT_Coeffs[j][k];
			if (debug_level == 4) temp[i][j] = s;
			else temp[i][j] = floor((s + (double)(1 << 7)) / (double)(1 << 8));
		}

	// pre-multiplication with the coefficient matrix
	for (j = 0; j < 8; j++)
		for (i = 0; i < 8; i++) {
			s = 0.0;
			for (k = 0; k < 8; k++)
			   s += DCT_Coeffs[i][k] * temp[k][j];
			if (debug_level == 4) Block_Data[i][j] = s;
			else Block_Data[i][j] = floor((s + (double)(1 << 15)) / (double)(1 << 16));
		}
}

static void Write_Block(double Block_Data[][8], double *DCT_Data,
	int Block_Row, int Block_Column, int Rows, int Columns, int colour
) {
	int i, j;

	for (i = 0; i < 8; i++)
		for (j = 0; j < 8; j++)
			DCT_Data[YUV_index(Rows, Columns, 8*Block_Row+i, 8*Block_Column+j, colour)] =
				Block_Data[i][j];
}

void Lossless_Coding(image *DCT_Image, char *Filename, int Compression_Format) {
	int colour, i, j, DCT_Rows, DCT_Columns, Block_Rows, Block_Columns;
	double *DCT_Data, Block_Data[8][8];
	FILE *Destination_File;
	unsigned int byte_offset[3], bit_offset[3], bits_left;

	// Open the file
	if ((Destination_File = fopen(Filename, "wb")) == NULL) {
		printf("Problem opening destination compressed stream %s\n", Filename); exit(1); }

	DCT_Rows = DCT_Image->Rows;
	DCT_Columns = DCT_Image->Columns;

	Block_Rows = DCT_Rows/8;
	Block_Columns = DCT_Columns/8;

	DCT_Data = DCT_Image->Pixel_Data;

	// provide the compressed stream header
	fprintf(Destination_File, "%c%c", 0xEC, 0xE7);
	fprintf(Destination_File, "%c%c", 0x44, Compression_Format);
	fprintf(Destination_File, "%c%c", (DCT_Rows >> 8) & 0xFF, DCT_Rows & 0xFF);
	fprintf(Destination_File, "%c%c", (DCT_Columns >> 8) & 0xFF, DCT_Columns & 0xFF);
	fprintf(Destination_File, "%c%c", 0x00, 0x00);
	fprintf(Destination_File, "%c%c", 0x00, 0x00);
	fprintf(Destination_File, "%c%c", 0x00, 0x00);
	fprintf(Destination_File, "%c%c", 0x00, 0x00);
	fprintf(Destination_File, "%c%c", 0x00, 0x00);
	fprintf(Destination_File, "%c%c", 0x00, 0x00);

	// process the blocks in sequence
	bits_left = 0;
	for (colour = 0; colour < 3; colour++) {
		byte_offset[colour] = (unsigned int)ftell(Destination_File);
		bit_offset[colour] = bits_left;
		for (i = 0; i < Block_Rows; i++)
		for (j = 0; j < Block_Columns; j++) {
			Fetch_Block(DCT_Data, Block_Data, i, j, DCT_Rows, DCT_Columns, colour);
			Quantize_Block(Block_Data, Compression_Format);
			bits_left = Write_Coded_Block(Block_Data, Destination_File);
		}
		if (colour == Y) {
			Block_Columns /= 2;
		}
	}

	// pad with zeros to the end of a 16 bit word
	Write_Bits(Destination_File, 0, 16);

	// overwrite header with correct offset for Y/U/V segments in the bitstream
	for (colour = 0; colour < 3; colour++) {
		fseek(Destination_File, 8+4*colour, SEEK_SET);
		fprintf(Destination_File, "%c%c", (byte_offset[colour] >> 16) & 0xFF, (byte_offset[colour] >> 8) & 0xFF);
		fprintf(Destination_File, "%c%c", (byte_offset[colour]) & 0xFF, bit_offset[colour] & 0xFF);
	}
	
	fclose(Destination_File);
}

unsigned int Write_Coded_Block(double Block_Data[][8], FILE *Destination_File) {
	int i, j, temp, Scanned_Block[64];
	double s;
	unsigned int bit_offset;
	
	// round double precision values to integers
	for (i = 0; i < 64; i++) {
		j = Scan_Pattern[i];
		s = Block_Data[j/8][j%8];
		Scanned_Block[i] = (int)floor(((2.0 * s) + 1.0) / 2.0);
	}
	
	// losslessly code the block
	i = 0; while (i < 64) {
		j = 0; while ((i + j < 64) && (Scanned_Block[i+j] == 0)) { j++; }
		if (i + j < 64) {
			if (j > 0) {
				temp = j;
				while (temp >= 8) {
					bit_offset = Write_Bits(Destination_File, (ZERO_RUN << 3), 5);
					temp -= 8;
				}
				if (temp > 0)
					bit_offset = Write_Bits(Destination_File, ((ZERO_RUN << 3) | temp), 5);               
			}
			if ((Scanned_Block[i+j] < 4) && (Scanned_Block[i+j] >= -4)) 
				bit_offset = Write_Bits(Destination_File, ((CODE_3 << 3) | (Scanned_Block[i+j] & 0x7)), 5);
			else bit_offset = Write_Bits(Destination_File, ((CODE_9 << 9) | (Scanned_Block[i+j] & 0x1FF)), 11);
		} else bit_offset = Write_Bits(Destination_File, BLOCK_END, 2);
		i += j + 1;
	}
	return bit_offset;
}   

unsigned int Write_Bits(FILE *Destination_File, int bits, int length) {

	static unsigned int buffer = 0, pointer = 0;

	buffer = (buffer << length) | bits;
	pointer += length;

	while (pointer >= 8) {
		fprintf(Destination_File, "%c", 0xFF & (buffer >> (pointer - 8)));
		pointer -= 8;
	}
	return pointer;
}
