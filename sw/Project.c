/*
   Copyright by Adam Kinsman and Nicola Nicolici
   Department of Electrical and Computer Engineering
   McMaster University
   Ontario, Canada
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void Parse_bmp(char *, char *);
void Encoder(char *, int, char *, int);
void Decoder(char *, char *, int);
void Compare(char *, char *);

int main(int argc, char *argv[]) {
	int compression_format, debug_level;
	char filename_1[100], filename_2[100];

	// Extract command line parameters
	if (argc > 1) {
		if (!strcmp(argv[1], "-parse")) {
			if (argc != 4) {
				printf("\nFormat for parsing: Project -parse input_file output_file\n");
				printf("   input_file is a .bmp file\n");
				printf("   output_file is a .ppm file\n");
				printf("i.e. \"Project -parse file1 file2\" will parse file1.bmp and produce file2.ppm\n\n");
			} else {
				sscanf(argv[2], "%s", filename_1);
				sscanf(argv[3], "%s", filename_2);
				Parse_bmp(filename_1, filename_2);
			}
		} else if (!strcmp(argv[1], "-encode")) {
			if (argc == 5) {
				sscanf(argv[2], "%s", filename_1);
				sscanf(argv[3], "%d", &compression_format);
				sscanf(argv[4], "%s", filename_2);
				Encoder(filename_1, compression_format, filename_2, 0);
			} else if ((argc == 7) && !strcmp(argv[5], "-debug")) {
				sscanf(argv[2], "%s", filename_1);
				sscanf(argv[3], "%d", &compression_format);
				sscanf(argv[4], "%s", filename_2);
				sscanf(argv[6], "%d", &debug_level);
				Encoder(filename_1, compression_format, filename_2, debug_level);
			} else {
				printf("\nFormat for straight encoding: Project -encode input_file format output_file\n");
				printf("   input_file is a .ppm file\n");
				printf("   format is 0, 1 or 2\n");
				printf("   output_file is a .mic file\n");
				printf("i.e. \"Project -encode file1 0 file2\" will compress file1.ppm to file2.mic\n");
				printf("   using quantization matrix 0\n");
				printf("\nFormat for debug encoding: Project -encode input_file format output_file -debug debug_level\n");
				printf("   input_file is a .ppm file\n");
				printf("   format is 0, 1 or 2 (which quantization matrix to use)\n");
				printf("   output_file is a .mic file\n");
				printf("   debug_level is:\n");
				printf("      0 for no information (same as straight encoding)\n");
				printf("      1 for colourspace converted and downsampled (i.e. pre-DCT) data\n");
				printf("      2 for before quantization and lossless coding (i.e. post-DCT data)\n");
				printf("      3 to print out the integer DCT coefficients\n");
				printf("      4 to peform encoding using double precision instead of fixed-point\n");
				printf("e.g. \"Project -encode file1 0 file2 -debug 1\" will compress file1.ppm to file2.mic\n");
				printf("   using quantization matrix 0 and produces the file file2.d1e which \n");
				printf("   contains encoding debug data at level 1\n\n");
			}
		} else if (!strcmp(argv[1], "-decode")) {
			if (argc == 4) {
				sscanf(argv[2], "%s", filename_1);
				sscanf(argv[3], "%s", filename_2);
				Decoder(filename_1, filename_2, 0);
			} else if ((argc == 6) && !strcmp(argv[4], "-debug")) {
				sscanf(argv[2], "%s", filename_1);
				sscanf(argv[3], "%s", filename_2);
				sscanf(argv[5], "%d", &debug_level);
				Decoder(filename_1, filename_2, debug_level);
			} else {
				printf("\nFormat for straight decoding: Project -decode input_file output_file\n");
				printf("   input_file is a .mic file\n");
				printf("   output_file is a .ppm file\n");
				printf("i.e. \"Project -decode file1 file2\" will decompress file1.mic to file2_sw.ppm\n\n");
				printf("Format for debug decoding: Project -decode input_file output_file -debug debug_level\n");
				printf("   input_file is a .mic file\n");
				printf("   output_file is a .ppm file\n");
				printf("   debug_level is:\n");
				printf("      0 for no information (same as straight decoding)\n");
				printf("      1 for milestone 1 transmission file (downsampled data)\n");
				printf("      2 for milestone 2 transmission file (pre-IDCT data)\n");
				printf("      3 to print out the integer IDCT coefficients\n");
				printf("i.e. \"Project -decode file1 file2 -debug 1\" decompresses file1.mic to file2.ppm\n");
				printf("   and produces the file file2.d1d which contains decoding debug data at level 1\n\n");
			}
		} else if (!strcmp(argv[1], "-compare")) {
			if (argc != 4) {
				printf("\nFormat for comparison: Project -compare input_file output_file\n");
				printf("   input_file is a .ppm file\n");
				printf("   output_file is a .ppm file\n");
				printf("i.e. \"Project -parse file1 file2\" will compare file1.ppm and file2.ppm\n");
				printf("   and computes the signal-to-noise ratio (SNR)\n\n");
			} else {
				sscanf(argv[2], "%s", filename_1);
				sscanf(argv[3], "%s", filename_2);
				Compare(filename_1, filename_2);
			}
		} else printf("Unrecognized input, run with no parameters for info\n");
	} else {
		printf("\nThis program contains the software model for the hardware implementation of\n");
		printf("the McMaster Image Compression (.mic) specification, as well as the supporting\n");
		printf("infrastructure. It includes a parser for obtaining .ppm images from .bmp images,\n");
		printf("the encoding half of the spec (to produce compressed files), the decoding half\n");
		printf("of the spec (to produce a .ppm images), a debug mode for producing validation data,\n");
		printf("and a signal-to-noise ratio (SNR) calculator for comparing the decompressed image\n");
		printf("to the original. Usage is as follows:\n\n");

		printf("Format for parsing: Project -parse input_file output_file\n");
		printf("Format for straight encoding: Project -encode input_file format output_file\n");
		printf("Format for debug encoding: Project -encode input_file format output_file -debug debug_level\n");
		printf("Format for straight decoding: Project -decode input_file output_file\n");
		printf("Format for debug decoding: Project -decode input_file output_file -debug debug_level\n");
		printf("Format for comparison: Project -compare input_file output_file (computes SNR)\n\n");

		printf("Re-run with mode parameter only for specific details for that mode (e.g. \"Project -decode\")\n\n");
	}

	return 0;
}
