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

void Compare(char *Source_Filename_1, char *Source_Filename_2)
{
	unsigned char temp_char_1, temp_char_2;
	char temp_string[50];
	int pixel_counter, total_error, difference;
	int temp_int;
	double RMSE, PSNR;
	FILE *Source_File_1, *Source_File_2; 

	strcat(Source_Filename_1, ".ppm");
	strcat(Source_Filename_2, ".ppm");
	printf("Comparing file %s to %s\n", Source_Filename_1, Source_Filename_2);

	// open files
	if ((Source_File_1 = fopen(Source_Filename_1, "rb")) == NULL) { printf("Problem with file %s\n", Source_Filename_1); exit(0); }
	if ((Source_File_2 = fopen(Source_Filename_2, "rb")) == NULL) { printf("Problem with file %s\n", Source_Filename_2); exit(0); }

	// strip headers
	fscanf(Source_File_1, "%s", temp_string); fscanf(Source_File_2, "%s", temp_string); // image type - usually P6
	fscanf(Source_File_1, "%d", &temp_int);   fscanf(Source_File_2, "%d", &temp_int);   // Pixel Columns
	fscanf(Source_File_1, "%d", &temp_int);   fscanf(Source_File_2, "%d", &temp_int);   // Pixel Rows
	fscanf(Source_File_1, "%s", temp_string); fscanf(Source_File_2, "%s", temp_string); // max colours - usually 255
	fgetc(Source_File_1);                     fgetc(Source_File_2);                     // newline character

	// compare image data
	pixel_counter = total_error = 0;
	while (!(feof(Source_File_1) || feof(Source_File_2))) {
		temp_char_1 = fgetc(Source_File_1);
		temp_char_2 = fgetc(Source_File_2);
		if (!(feof(Source_File_1) || feof(Source_File_2))) {
			pixel_counter++;
			difference = (int)temp_char_1 - (int)temp_char_2;
			total_error += difference * difference;
		}
	}

	// close files
	fclose(Source_File_1);
	fclose(Source_File_2);

	// compute SNR
	RMSE = (double)total_error / (double)pixel_counter;
	RMSE = sqrt(RMSE);
	// printf("Total error: %10.4lf RMSE: %10.4lf\n", (double)total_error, RMSE);
	PSNR = 20.0*log10(255.0 / RMSE);

	printf("Compared %d pixels, PSNR: %10.4lf\n", pixel_counter/3, PSNR);
}
