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
	int *Pixel_Data;
} image;

// coefficient matrix for DCT
int IDCT_Coeffs[8][8];

// global variables (with limited scope) related to debug
// (for generating hardware validation data)
static int debug_level;
static int *debug_data;
static char debug_filename[100];
static FILE *debug_file;

// function prototypes
void Lossless_Dequant_IDCT(char *, image *);
unsigned int Read_Coded_Block(FILE *, int [][8], int);
int  Read_Bits(FILE *, int);
int  Quant_Val(int, int);
//static void Fetch_Block(int *, int [][8], int, int, int, int, int);
void Init_IDCT_Coeffs();
void Block_IDCT(int [][8]);
static void Write_Block(int [][8], int *, int, int, int, int, int);
void Interpolate_Colourspace(image *, image *);
void Write_PPM_Image(image *, char *);

void Decoder(char *Source_Filename, char *Destination_Filename, int debug_info) {   
	image Source_Image, Upsampled_Image;

	// setup for debug
	debug_level = debug_info;
	sprintf(debug_filename, "%s.d%dd", Destination_Filename, debug_level);
	strcat(Source_Filename, ".mic");
	strcat(Destination_Filename, "_sw.ppm");
	printf("Decoding file %s to image %s\n", Source_Filename, Destination_Filename);

	// Decompress the image
	Lossless_Dequant_IDCT(Source_Filename, &Source_Image);
	Interpolate_Colourspace(&Source_Image, &Upsampled_Image);
	Write_PPM_Image(&Upsampled_Image, Destination_Filename);

	free(Upsampled_Image.Pixel_Data);
	free(Source_Image.Pixel_Data);
}

void Lossless_Dequant_IDCT(char *Filename, image *Source_Image) {
	// Performs lossless decoding, dequantization and IDCT on all the blocks
	int i, j, colour, Compression_Format;
	int Block_Rows, Block_Columns, Source_Rows, Source_Columns;
	int *Source_Data, Block_Data[8][8];
	unsigned char file_data;
	FILE *Source_File;

	// Open the file
	if ((Source_File = fopen(Filename, "rb")) == NULL) {
		printf("Problem opening source compressed stream %s\n", Filename); exit(1); }

	// Extract compressed file header information
	fgetc(Source_File); fgetc(Source_File); fgetc(Source_File); // strip 0xECE744
	file_data = fgetc(Source_File);
	Compression_Format = file_data & 0x3;

	file_data = fgetc(Source_File);
	Source_Rows = file_data << 8;
	file_data = fgetc(Source_File);
	Source_Rows |= file_data;

	file_data = fgetc(Source_File);
	Source_Columns = file_data << 8;
	file_data = fgetc(Source_File);
	Source_Columns |= file_data;

	unsigned int encoded_byte_offset[3], encoded_bit_offset[3];
	for (colour = 0; colour < 3; colour++) {
		file_data = fgetc(Source_File);
		encoded_byte_offset[colour] = file_data << 16;
		file_data = fgetc(Source_File);
		encoded_byte_offset[colour] |= file_data << 8;
		file_data = fgetc(Source_File);
		encoded_byte_offset[colour] |= file_data;
		file_data = fgetc(Source_File);
		encoded_bit_offset[colour] = file_data;
	}

	Block_Rows = Source_Rows/8;
	Block_Columns = Source_Columns/8;

	// allocate memory
	Source_Data = (int *)malloc(Source_Rows*Source_Columns*2*sizeof(int));
	if (debug_level == 2) debug_data = (int *)malloc(Source_Rows*Source_Columns*3*sizeof(int));

	// fill the IDCT coefficient matrix
	Init_IDCT_Coeffs();

	unsigned int decoded_byte_offset[3], decoded_bit_offset[3];
	decoded_byte_offset[0] = (unsigned int)ftell(Source_File);
	decoded_bit_offset[0] = 0;
		
	unsigned int block_bits = 0;
	// process blocks in sequence from the bitstream
	for (colour = 0; colour < 3; colour++) {
		if (colour == 0) {
			decoded_byte_offset[0] = (unsigned int)ftell(Source_File);
			decoded_bit_offset[0] = 0;
		} else {
			decoded_byte_offset[colour] = decoded_byte_offset[0] + (block_bits / 8);
			decoded_bit_offset[colour] = (block_bits % 8);
		}
		for (i = 0; i < Block_Rows; i++)
			for (j = 0; j < Block_Columns; j++) {
				block_bits += Read_Coded_Block(Source_File, Block_Data, Compression_Format);
				if (debug_level == 2)
					Write_Block(Block_Data, debug_data, i, j, Source_Rows, Source_Columns, colour);
				Block_IDCT(Block_Data);
				Write_Block(Block_Data, Source_Data, i, j, Source_Rows, Source_Columns, colour);
			}
		if (colour == Y) Block_Columns /= 2;   // since U and V have half the width of Y
	}

	for (colour = 0; colour < 3; colour++) {
		if (encoded_byte_offset[colour] != decoded_byte_offset[colour]) {
			fprintf(stdout, "Colour = %c\tEncoded byte offset = %d\t!= Decoded byte offset = %d\n", \
				(colour == 0) ? 'Y' : (colour == 1) ? 'U' : 'V', \
				encoded_byte_offset[colour], decoded_byte_offset[colour]);
		}
		if (encoded_bit_offset[colour] != decoded_bit_offset[colour]) {
			fprintf(stdout, "Colour = %c\tEncoded bit offset = %d\t!= Decoded bit offset = %d\n", \
				(colour == 0) ? 'Y' : (colour == 1) ? 'U' : 'V', \
				encoded_bit_offset[colour], decoded_bit_offset[colour]);
		}
	}

	if (debug_level == 2) {
		printf("Writing debug information for level %d to file %s\n", debug_level, debug_filename);
		Block_Rows = Source_Rows;
		Block_Columns = Source_Columns;
		if ((debug_file = fopen(debug_filename, "wb")) == NULL) {
			printf("Problem opening debug file %s\n", debug_filename); exit(1); }
		for (colour = 0; colour < 3; colour++) {
			for (i = 0; i < Block_Rows; i++)
				for (j = 0; j < Block_Columns; j++)
					fprintf(debug_file, "%c%c",
							(debug_data[YUV_index(Source_Rows, Source_Columns, i, j, colour)] >> 8) & 0xFF,
							(debug_data[YUV_index(Source_Rows, Source_Columns, i, j, colour)]) & 0xFF);
			if (colour == Y) Block_Columns /= 2;
		}
		fclose(debug_file);
		free(debug_data);
	}

	Source_Image->Rows = Source_Rows;
	Source_Image->Columns = Source_Columns;
	Source_Image->Pixel_Data = Source_Data;

	fclose(Source_File);
}

unsigned int Read_Coded_Block(FILE *Source_File, int Block_Data[][8], int Compression_Format) {
	// reads a block of coefficients from the bitstream and dequantizes it
	int i, k, code;
	unsigned int block_bits = 0;
	
	// Decode one block
	k = 0;
	while (k < 64) {
		code = Read_Bits(Source_File, 2); block_bits += 2;
		switch(code) {
			case ZERO_RUN : // a run of zeros
				code = Read_Bits(Source_File, 3); block_bits += 3;

				code += (code) ? k : k + 8;
				while (k < code) {
					i = Scan_Pattern[k];
					Block_Data[i/8][i%8] = 0;
					k++;
				}
				break;
			case CODE_9 : // a 9-bit coefficient
				code = Read_Bits(Source_File, 9); block_bits += 9;
				i = Scan_Pattern[k];
				code = (code >= 256) ? code - 512 : code;
				code *= Quant_Val(i, Compression_Format);
				Block_Data[i/8][i%8] = code;
				k++;
				break;
			case CODE_3 : // a 3-bit coefficient
				code = Read_Bits(Source_File, 3); block_bits += 3;
				i = Scan_Pattern[k];
				code = (code >= 4) ? code - 8 : code;
				code *= Quant_Val(i, Compression_Format);
				Block_Data[i/8][i%8] = code;
				k++;
				break;
			case BLOCK_END : // the end of the block
				code = 64;
				while (k < code) {
					i = Scan_Pattern[k];
					Block_Data[i/8][i%8] = 0;
					k++;
				}
				break;
			default : printf("Unrecognized code in bistream - terminating!\n"); exit(1);
		}
	} 
	return block_bits;
}

int Read_Bits(FILE *Source_File, int length) {
	// reads length bits from the bitstream (the serializer)
	static unsigned int buffer = 0, pointer = 32;
	unsigned int bits;
	unsigned char read_val_H, read_val_L;
	unsigned int read_val;

	while (pointer >= 16) {
		read_val_H = (feof(Source_File)) ? 0x00 : fgetc(Source_File);
		read_val_L = (feof(Source_File)) ? 0x00 : fgetc(Source_File);
		read_val = ((read_val_H << 8) | read_val_L) & 0xFFFF;
		buffer |= (read_val << (pointer - 16));
		pointer -= 16;
	}

	bits = (buffer >> (32 - length));
	buffer <<= length;
	pointer += length;

	return (int)bits;
}

int Quant_Val(int location, int Compression_Format) {
	// returns the quantization value for the current location and format
	if (Compression_Format == 0) {
		if ((location/8 + location%8) >= 8) return 64;
		else if ((location/8 + location%8) >= 6) return 32;
		else if ((location/8 + location%8) >= 4) return 16;
		else if ((location/8 + location%8) >= 2) return 8;
		else if ((location/8 + location%8) >= 1) return 4;
		else return 8;
	} else if (Compression_Format == 1) {
		if ((location/8 + location%8) >= 8) return 32;
		else if ((location/8 + location%8) >= 6) return 16;
		else if ((location/8 + location%8) >= 4) return 8;
		else if ((location/8 + location%8) >= 2) return 4;
		else if ((location/8 + location%8) >= 1) return 4;
		else return 8;
	} else {
		if ((location/8 + location%8) >= 8) return 16;
		else if ((location/8 + location%8) >= 6) return 8;
		else if ((location/8 + location%8) >= 4) return 4;
		else if ((location/8 + location%8) >= 2) return 2;
		else if ((location/8 + location%8) >= 1) return 2;
		else return 8;
	}
}

void Init_IDCT_Coeffs() {
	// initializes the IDCT coefficient matrix for the block IDCT function
	int i, j; double s;

	for (i = 0; i < 8; i++) {
		s = (i == 0) ? sqrt(1.0 / 8.0) : sqrt(2.0 / 8.0);
		for (j = 0; j < 8; j++)
			IDCT_Coeffs[i][j] = (int)(s*cos((PI/8.0)*i*(j + 0.5))*4096.0); // fixed point at bit 12
	}

	// debug information
	if (debug_level == 3) {
		printf("Writing debug information for level %d to file %s\n", debug_level, debug_filename);
		if ((debug_file = fopen(debug_filename, "wb")) == NULL) {
			printf("Problem opening debug file %s\n", debug_filename); exit(1); }
		for (i = 0; i < 8; i++) {
			for (j = 0; j < 8; j++)
				fprintf(debug_file, "%5d ", IDCT_Coeffs[i][j]);
			fprintf(debug_file, "\n");
		}
		fclose(debug_file);
	}
}

void Block_IDCT(int Block_Data[][8])
{
	int i, j, k, s, temp[8][8];

	// post-multiplication with the coefficient matrix
	for (i = 0; i < 8; i++)
		for (j = 0; j < 8; j++) {
			s = 0;
			for (k = 0; k < 8; k++)
				s += Block_Data[i][k] * IDCT_Coeffs[k][j];
			temp[i][j] = s >> 8;
		}

	// pre-multiplication with the transponsed coefficient matrix
	for (j = 0; j < 8; j++)
		for (i = 0; i < 8; i++) {
			s = 0;
			for (k = 0; k < 8; k++)
				s += IDCT_Coeffs[k][i] * temp[k][j];
			s >>= 16;
			s = (s > 255) ? 255 : (s < 0) ? 0 : s; // clipping to ensure values on 8 bits (0 .. 255)
			Block_Data[i][j] = s;
		}
}

static void Write_Block(int Block_Data[][8], int *IDCT_Data,
		int Block_Row, int Block_Column, int Rows, int Columns, int colour
		) {
	// opposite of fetch block, writes a block back into the image/plane data array
	int i, j;

	for (i = 0; i < 8; i++)
		for (j = 0; j < 8; j++)
			IDCT_Data[YUV_index(Rows, Columns, 8*Block_Row+i, 8*Block_Column+j, colour)] =
				Block_Data[i][j];
}

void Interpolate_Colourspace(image *IDCT_Image, image *Upsampled_Image) {
	// performs upsampling(interpolation) and colourspace conversion on YUV to obtain RGB
	int i, j, colour, IDCT_Rows, IDCT_Columns, Upsampled_Rows, Upsampled_Columns;
	int *IDCT_Data, *Upsampled_Data;
	int Y_val, U_val, V_val, R_val, G_val, B_val;
	int jm2, jm1, jp1, jp2, jp3;
	int YUV_RGB_matrix[9] = {
		76284,    0  , 104595,
		76284,  25624,  53281,
		76284, 132251,    0   };

	// debug information
	if (debug_level == 1) {
		printf("Writing debug information for level %d to file %s\n", debug_level, debug_filename);
		Upsampled_Rows = IDCT_Image->Rows;
		Upsampled_Columns = IDCT_Image->Columns;
		IDCT_Rows = Upsampled_Rows;
		IDCT_Columns = Upsampled_Columns;
		debug_data = IDCT_Image->Pixel_Data;
		if ((debug_file = fopen(debug_filename, "wb")) == NULL) {
			printf("Problem opening debug file %s\n", debug_filename); exit(1); }
		for (colour = 0; colour < 3; colour++) {
			for (i = 0; i < IDCT_Rows; i++)
				for (j = 0; j < IDCT_Columns; j++)
					fprintf(debug_file, "%c", debug_data[YUV_index(
								Upsampled_Rows, Upsampled_Columns, i, j, colour)]);
			if (colour == Y) IDCT_Columns /= 2;
		}
		fclose(debug_file);
	}

	IDCT_Rows = IDCT_Image->Rows;
	IDCT_Columns = IDCT_Image->Columns;
	IDCT_Data = IDCT_Image->Pixel_Data;

	// Upsampling
	Upsampled_Rows = IDCT_Rows;
	Upsampled_Columns = IDCT_Columns;
	Upsampled_Data = (int *)malloc(Upsampled_Rows*Upsampled_Columns*3*sizeof(int));

	for (i = 0; i < Upsampled_Rows; i++)
		for (j = 0; j < Upsampled_Columns; j++) {
			Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, G)] =
				IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, j, Y)];

			jm2 = (j/2 < 2) ? 0 : j/2 - 2;
			jm1 = (j/2 < 1) ? 0 : j/2 - 1;
			jp1 = (j/2 < (Upsampled_Columns/2 - 1)) ? j/2 + 1 : Upsampled_Columns/2 - 1;
			jp2 = (j/2 < (Upsampled_Columns/2 - 2)) ? j/2 + 2 : Upsampled_Columns/2 - 1;
			jp3 = (j/2 < (Upsampled_Columns/2 - 3)) ? j/2 + 3 : Upsampled_Columns/2 - 1;

			if (j%2 == 0) {
				Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, B)] =
					IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, j/2, U)];
				Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, R)] =
					IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, j/2, V)];
			} else {

				Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, B)] = (
						21 * IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, jm2, U)] -
						52 * IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, jm1, U)] +
						159 * IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, j/2, U)] +
						159 * IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, jp1, U)] -
						52 * IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, jp2, U)] +
						21 * IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, jp3, U)] +
						128) >> 8;

				Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, R)] = (
						21 * IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, jm2, V)] -
						52 * IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, jm1, V)] +
						159 * IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, j/2, V)] +
						159 * IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, jp1, V)] -
						52 * IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, jp2, V)] +
						21 * IDCT_Data[YUV_index(IDCT_Rows, IDCT_Columns, i, jp3, V)] +
						128) >> 8;
			}
		}

	// Colourspace conversion
	for (i = 0; i < Upsampled_Rows; i++)
		for (j = 0; j < Upsampled_Columns; j++) {
			Y_val = Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, G)] - 16;
			U_val = Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, B)] - 128;
			V_val = Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, R)] - 128;

			R_val = YUV_RGB_matrix[0]*Y_val + YUV_RGB_matrix[1]*U_val + YUV_RGB_matrix[2]*V_val;
			G_val = YUV_RGB_matrix[3]*Y_val - YUV_RGB_matrix[4]*U_val - YUV_RGB_matrix[5]*V_val;
			B_val = YUV_RGB_matrix[6]*Y_val + YUV_RGB_matrix[7]*U_val + YUV_RGB_matrix[8]*V_val;

			R_val >>= 16; G_val >>= 16; B_val >>= 16;

			// clipping to keep the range on 8 bits (0 .. 255)
			R_val = (R_val < 0) ? 0 : (R_val > 255) ? 255 : R_val;
			G_val = (G_val < 0) ? 0 : (G_val > 255) ? 255 : G_val;
			B_val = (B_val < 0) ? 0 : (B_val > 255) ? 255 : B_val;

			Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, R)] = R_val;
			Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, G)] = G_val;
			Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, B)] = B_val;
		}

	Upsampled_Image->Rows = Upsampled_Rows;
	Upsampled_Image->Columns = Upsampled_Columns;
	Upsampled_Image->Pixel_Data = Upsampled_Data;
}

void Write_PPM_Image(image *Upsampled_Image, char *Filename) {
	// not used in the hardware implementation, writes the decompressed image in ppm format
	int i, j;
	int Upsampled_Rows, Upsampled_Columns;
	int *Upsampled_Data;
	FILE *outfile;

	// Open the file
	if ((outfile = fopen(Filename, "wb")) == NULL) {
		printf("Problem opening destination PPM image %s\n", Filename); exit(1); }

	Upsampled_Rows = Upsampled_Image->Rows;
	Upsampled_Columns = Upsampled_Image->Columns;
	Upsampled_Data = Upsampled_Image->Pixel_Data;

	// Write PPM header
	fprintf(outfile, "P6\n%d %d\n255\n", Upsampled_Columns, Upsampled_Rows);

	// Write PPM data
	for (i = 0; i < Upsampled_Rows; i++)
		for (j = 0; j < Upsampled_Columns; j++) {
			fprintf(outfile, "%c",
					Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, R)]);
			fprintf(outfile, "%c",
					Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, G)]);
			fprintf(outfile, "%c",
					Upsampled_Data[RGB_index(Upsampled_Rows, Upsampled_Columns, i, j, B)]);
		}

	fclose(outfile);
}
