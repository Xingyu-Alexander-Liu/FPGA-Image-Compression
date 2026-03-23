/*
Copyright by Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps

`include "../rtl/define_state.h"

`define FEOF 32'hFFFFFFFF
`define MAX_MISMATCHES 100

// the defines/parameters below should change based on the IMAGE
parameter IMAGE_WIDTH = 640;	// these two values should be extracted from the
parameter IMAGE_HEIGHT = 480;	// UART stream when processing the PPM header
								// it is ok to have them as parameters as well
`define INPUT_FILE_NAME "../data/fractal1-0.d1e"
// milestone 1 (pre-DCT) - you can name the debug as you wish
// it is only a suggestion for a suffix -0 when quantization matrix 0 is used
// `define VALIDATION_FILE_NAME "../data/fractal1-0.d1e"
// milestone 2 (post-DCT)
`define VALIDATION_FILE_NAME "../data/fractal1-0.d2e"
// encoded file
// `define VALIDATION_FILE_NAME "../data/motorcycle-0.mic"

// the define below should change based on MILESTONE
// it is used to set up base addresses for SRAM fill/comparison
`define MILESTONE 2

// the top module of the testbench
module TB;

	logic clock_50;				// 50 MHz clock

	logic [3:0] push_button_n;		// pushbuttons
	logic [17:0] switch;			// switches

	logic [6:0] seven_seg_n [7:0];		// 8 seven segment displays
	logic [8:0] led_green;			// 9 green LEDs

	logic uart_rx, uart_tx;			// UART receive/transmit

	wire [15:0] SRAM_data_io;		// SRAM interface
	logic [15:0] SRAM_write_data, SRAM_read_data;
	logic [19:0] SRAM_address;
	logic SRAM_UB_N, SRAM_LB_N, SRAM_WE_N, SRAM_CE_N, SRAM_OE_N;
	logic SRAM_resetn;			// used to initialize the
	logic RAM_filled;			// SRAM emulator in the TB

	// some bookkeeping variables
	integer validation_fd;
	int number_of_mismatches;

	// UUT instantiation (we pass cols/rows as parameters)
	project1 #(
		.no_cols(IMAGE_WIDTH),
		.no_rows(IMAGE_HEIGHT))
		UUT (
		.CLOCK_50_I(clock_50),

		.SWITCH_I(switch),
		.PUSH_BUTTON_N_I(push_button_n),

		.SEVEN_SEGMENT_N_O(seven_seg_n),
		.LED_GREEN_O(led_green),

		.SRAM_DATA_IO(SRAM_data_io),
		.SRAM_ADDRESS_O(SRAM_address),
		.SRAM_UB_N_O(SRAM_UB_N),
		.SRAM_LB_N_O(SRAM_LB_N),
		.SRAM_WE_N_O(SRAM_WE_N),
		.SRAM_CE_N_O(SRAM_CE_N),
		.SRAM_OE_N_O(SRAM_OE_N),

		.UART_RX_I(uart_rx),
		.UART_TX_O(uart_tx)
	);

	// the emulator for the external SRAM during simulation
	tb_SRAM_Emulator SRAM_component (
		.Clock_50(clock_50),
		.Resetn(SRAM_resetn),

		.SRAM_data_io(SRAM_data_io),
		.SRAM_address(SRAM_address),
		.SRAM_UB_N(SRAM_UB_N),
		.SRAM_LB_N(SRAM_LB_N),
		.SRAM_WE_N(SRAM_WE_N),
		.SRAM_CE_N(SRAM_CE_N),
		.SRAM_OE_N(SRAM_OE_N)
	);

	// 50 MHz clock generation
	always begin
		#10;
		clock_50 = ~clock_50;
	end

	initial begin
		$timeformat(-6, 2, "us", 10);
		clock_50 = 1'b0;
		switch[17:0] = 18'd0;
		push_button_n[3:0] = 4'hF;
		uart_rx = 1'b1;
		SRAM_resetn = 1'b1;
		RAM_filled = 1'b0;
		number_of_mismatches = 0;
		repeat (2) @(negedge clock_50);
		$display("\n*** Asserting the asynchronous reset ***");
		switch[17] = 1'b1;
		repeat (3) @(negedge clock_50);
		switch[17] = 1'b0;
		$display("*** Deasserting the asynchronous reset ***\n");
		@(negedge clock_50);
		// clear SRAM model
		SRAM_resetn = 1'b0;
		@(negedge clock_50);
		SRAM_resetn = 1'b1;
	end

	initial begin
		wait (SRAM_resetn === 1'b0);
		wait (SRAM_resetn === 1'b1);
		repeat (3) @ (posedge clock_50);

		fill_SRAM;
		$write("SRAM is now filled at %t\n\n", $realtime);

		// we can also start the encoder by pressing push button 0
		push_button_n[0] = 1'b0;
		// we assume the top_state is S_IDLE
		wait (UUT.top_state != S_IDLE);
		$write("Starting Encoder at   %t\n\n", $realtime);
		push_button_n[0] = 1'b1;

		// wait until we reach the second UART state
		// we do this in order to force the UART timer
		// in order to bypass the UART states
		wait (UUT.top_state == S_WAIT_UART_RX);

		// advance the UART timer closer to timeout
		// we use this to "bypass" the UART states
		@(negedge clock_50);
		UUT.UART_timer = 26'd49999990;

		wait (UUT.top_state == S_IDLE);
		$write("Encoding finished at  %t\n\n", $realtime);

		repeat (3) @ (posedge clock_50);

		compare_result;

		$stop;
	end

	// Task for filling the SRAM directly to shorten simulation time
	task fill_SRAM;
		integer input_fd, file_data, i, new_line_count, input_sram_offset;
		logic [15:0] buffer;
	begin
		if (`MILESTONE == 1) begin
			input_sram_offset = 'd0;
		end else if (`MILESTONE == 2) begin
			input_sram_offset = 'd614400;
		end else if (`MILESTONE == 3) begin
			input_sram_offset = 'd0;
		end else begin
			$write("--Unrecognized MILESTONE %d\n", `MILESTONE);
		end

		$write("Opening file \"%s\" for initializing SRAM\n", `INPUT_FILE_NAME);
		input_fd = $fopen(`INPUT_FILE_NAME, "rb");

		if (`MILESTONE == 1) begin
			$display("For milestone 1 we remove the header of PPM file");
			file_data = $fgetc(input_fd);
			new_line_count = 0;
			// This is for filtering out the header of the
			// PPM file, which consists of 3 lines of text
			// So check for line feed (8'h0A in ASCII) here
			while (file_data != `FEOF && new_line_count < 3) begin
				// Filter out the header
				if ((file_data & 8'hFF) == 8'h0A) new_line_count++;
				if (new_line_count < 3) file_data = $fgetc(input_fd);
			end
		end

		file_data = $fgetc(input_fd);
		i = 0;
		while (file_data != `FEOF) begin
			buffer[15:8] = file_data & 8'hFF;
			file_data = $fgetc(input_fd);
			buffer[7:0] = file_data & 8'hFF;
			SRAM_component.SRAM_data[i+input_sram_offset] = buffer;
			i++;

			file_data = $fgetc(input_fd);
		end

		$fclose(input_fd);
		$write("Finish initializing SRAM\n\n");
	end
	endtask

	// Task for comparing the SRAM with the software-generated result
	task compare_result;
		integer compare_file, file_data, i, compare_sram_offset, compare_size;
		logic [15:0] buffer, sram_data;
	begin
		$write("Comparing TB and SW results\n");
		if (`MILESTONE == 1) begin
			compare_sram_offset = 'd614400;
			// three (3) bytes per pixel
			// downsampling compression of (4+4+4)/(4+2+2)
			// two (2) Y/U/V samples stored per location
			// width * height * 3 * (8/12) * (1/2) = width * height
			compare_size = IMAGE_WIDTH * IMAGE_HEIGHT;
		end else if (`MILESTONE == 2) begin
			compare_sram_offset = 'd0;
			// now we have one sample per location
			// hence twice as many locations as milestone 1
			compare_size = IMAGE_WIDTH * IMAGE_HEIGHT * 2;
		end else if (`MILESTONE == 3) begin
			compare_sram_offset = 'd614400;
			// ************************************
			// compare size MUST be set up manually
			// ************************************
			compare_size = 1000;
		end else begin
			$write("--Unrecognized MILESTONE %d\n", `MILESTONE);
		end

		$write("Opening file \"%s\" for Comparison\n", `VALIDATION_FILE_NAME);
		compare_file = $fopen(`VALIDATION_FILE_NAME, "rb");

		file_data = $fgetc(compare_file);
		i = 0;
		while ((file_data != `FEOF) && (i < compare_size)) begin
			buffer[15:8] = file_data & 8'hFF;
			file_data = $fgetc(compare_file);
			buffer[7:0] = file_data & 8'hFF;
			sram_data = SRAM_component.SRAM_data[i+compare_sram_offset];

			if (sram_data != buffer) begin
				number_of_mismatches = number_of_mismatches + 1;
				$write("Mismatch #%3d at SRAM location %6d: %4h vs %4h\n",
					number_of_mismatches, i+compare_sram_offset, sram_data, buffer);
				if (number_of_mismatches >= `MAX_MISMATCHES) begin
					$write("Exceeded maximum mismatches - stopping\n");
					$stop;
				end
			end

			i++;
			file_data = $fgetc(compare_file);
		end

		$fclose(compare_file);
	end
	endtask

endmodule


