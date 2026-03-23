/*
Copyright by Henry Ko and Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"

// This is the top module
// It connects the UART, SRAM and VGA together.
// It gives access to the SRAM for UART and VGA
module project1 (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// pushbuttons/switches              ////////////
		input logic[3:0] PUSH_BUTTON_N_I,         // pushbuttons
		input logic[17:0] SWITCH_I,               // toggle switches

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs

		/////// SRAM Interface                    ////////////
		inout wire[15:0] SRAM_DATA_IO,            // SRAM data bus 16 bits
		output logic[19:0] SRAM_ADDRESS_O,        // SRAM address bus 18 bits
		output logic SRAM_UB_N_O,                 // SRAM high-byte data mask
		output logic SRAM_LB_N_O,                 // SRAM low-byte data mask
		output logic SRAM_WE_N_O,                 // SRAM write enable
		output logic SRAM_CE_N_O,                 // SRAM chip enable
		output logic SRAM_OE_N_O,                 // SRAM output logic enable

		/////// UART                              ////////////
		input logic UART_RX_I,                    // UART receive signal
		output logic UART_TX_O                    // UART transmit signal
);

parameter	no_cols = 640,
		no_rows = 480;

top_state_type top_state;

//mileston1 define
logic resetn,start1,start2,done1,done2;
//m1 m2 m3 factors 
logic signed [31:0] m1_op1,m1_op2,m1_op3,m1_op4,m1_op5,m1_op6,m1_op7,m1_op8;
logic signed [31:0] m2_op1,m2_op2,m2_op3,m2_op4,m2_op5,m2_op6,m2_op7,m2_op8;
logic signed [31:0] m3_op1,m3_op2,m3_op3,m3_op4,m3_op5,m3_op6,m3_op7,m3_op8;
logic signed [31:0] multi0,multi1,multi2,multi3;//4 multipliers
logic signed [31:0] real_op1,real_op2,real_op3,real_op4,real_op5,real_op6,real_op7,real_op8; //the actual factors used by multipliers

//if current is in mileston1 (CSC & DS), use multiplier for m1.
//if current is in mileston2 , use multiplier for m2. 
//if current is in mileston3 use multiplier for m3.
assign real_op1 = (top_state == S_M1) ? m1_op1 : (top_state == S_M2) ? m2_op1 : m3_op1;
assign real_op2 = (top_state == S_M1) ? m1_op2 : (top_state == S_M2) ? m2_op2 : m3_op2;
assign real_op3 = (top_state == S_M1) ? m1_op3 : (top_state == S_M2) ? m2_op3 : m3_op3;
assign real_op4 = (top_state == S_M1) ? m1_op4 : (top_state == S_M2) ? m2_op4 : m3_op4;
assign real_op5 = (top_state == S_M1) ? m1_op5 : (top_state == S_M2) ? m2_op5 : m3_op5;
assign real_op6 = (top_state == S_M1) ? m1_op6 : (top_state == S_M2) ? m2_op6 : m3_op6;
assign real_op7 = (top_state == S_M1) ? m1_op7 : (top_state == S_M2) ? m2_op7 : m3_op7;
assign real_op8 = (top_state == S_M1) ? m1_op8 : (top_state == S_M2) ? m2_op8 : m3_op8;

assign multi0 = real_op1 * real_op2;
assign multi1 = real_op3 * real_op4;
assign multi2 = real_op5 * real_op6;
assign multi3 = real_op7 * real_op8;



// For Push button
logic [3:0] PB_pushed;

// For SRAM
logic [19:0] SRAM_address;//different 
logic [15:0] SRAM_write_data;
logic SRAM_we_n;
logic [15:0] SRAM_read_data;
logic SRAM_ready;

// For UART SRAM interface
logic UART_rx_enable;
logic UART_rx_initialize;
logic [19:0] UART_SRAM_address;//different 
logic [15:0] UART_SRAM_write_data;
logic UART_SRAM_we_n;
logic [25:0] UART_timer;

logic [6:0] value_7_segment [7:0];
// For Milestone1
logic [19:0] SRAM_M1_address;
logic [15:0] SRAM_write_M1_data;
logic SRAM_we_M1_n;

// For Milestone1
logic [19:0] SRAM_M2_address;
logic [15:0] SRAM_write_M2_data;
logic SRAM_we_M2_n;
// For error detection in UART
logic Frame_error;

// For disabling UART transmit
assign UART_TX_O = 1'b1;

assign resetn = ~SWITCH_I[17] && SRAM_ready;

// this other SRAM address will be driven
// by your logic in different top states
logic [19:0] other_SRAM_address;

// the code below is just a placeholder
// you should remove it and use specific addresses
// for different milestones
always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		other_SRAM_address <= 20'd0;
	end else begin
		other_SRAM_address <= other_SRAM_address + 20'd1;
	end
end

// Push Button unit
PB_controller PB_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	.PB_signal(PUSH_BUTTON_N_I),
	.PB_pushed(PB_pushed)
);

// UART SRAM interface
UART_SRAM_interface UART_unit(
	.Clock(CLOCK_50_I),
	.Resetn(resetn),

	.UART_RX_I(UART_RX_I),
	.Initialize(UART_rx_initialize),
	.Enable(UART_rx_enable),

	// For accessing SRAM
	.SRAM_address(UART_SRAM_address),
	.SRAM_write_data(UART_SRAM_write_data),
	.SRAM_we_n(UART_SRAM_we_n),
	.Frame_error(Frame_error)
);

// SRAM unit
SRAM_controller SRAM_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(~SWITCH_I[17]),
	.SRAM_address(SRAM_address),
	.SRAM_write_data(SRAM_write_data),
	.SRAM_we_n(SRAM_we_n),
	.SRAM_read_data(SRAM_read_data),
	.SRAM_ready(SRAM_ready),

	// To the SRAM pins
	.SRAM_DATA_IO(SRAM_DATA_IO),
	.SRAM_ADDRESS_O(SRAM_ADDRESS_O),
	.SRAM_UB_N_O(SRAM_UB_N_O),
	.SRAM_LB_N_O(SRAM_LB_N_O),
	.SRAM_WE_N_O(SRAM_WE_N_O),
	.SRAM_CE_N_O(SRAM_CE_N_O),
	.SRAM_OE_N_O(SRAM_OE_N_O)
);
Milestone_1 #(
	.no_cols(no_cols),
	.no_rows(no_rows)
) Milestone_1_unit (
	.CLOCK_50_I(CLOCK_50_I),
	.Resetn(~SWITCH_I[17]),
	.SRAM_address(SRAM_M1_address),
	.SRAM_write_data(SRAM_write_M1_data),
	.SRAM_we_n(SRAM_we_M1_n),
	.SRAM_read_data(SRAM_read_data),
	.start1(start1),
	.done1(done1),
	.m1_op1(m1_op1),
	.m1_op2(m1_op2),
	.m1_op3(m1_op3),
	.m1_op4(m1_op4),
	.m1_op5(m1_op5),
	.m1_op6(m1_op6),
	.m1_op7(m1_op7),
	.m1_op8(m1_op8),
	.multi0(multi0),
	.multi1(multi1),
	.multi2(multi2),
	.multi3(multi3)
);

Milestone_2 #(
	.no_cols(no_cols),
	.no_rows(no_rows)
) Milestone_2_unit (
	.CLOCK_50_I(CLOCK_50_I),
	.Resetn(~SWITCH_I[17]),
	.SRAM_address(SRAM_M2_address),
	.SRAM_write_data(SRAM_write_M2_data),
	.SRAM_we_n(SRAM_we_M2_n),
	.SRAM_read_data(SRAM_read_data),
	.start2(start2),
	.done2(done2),
	.m2_op1(m2_op1),
	.m2_op2(m2_op2),
	.m2_op3(m2_op3),
	.m2_op4(m2_op4),
	.m2_op5(m2_op5),
	.m2_op6(m2_op6),
	.m2_op7(m2_op7),
	.m2_op8(m2_op8),
	.multi0(multi0),
	.multi1(multi1),
	.multi2(multi2),
	.multi3(multi3)
);

always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		top_state <= S_IDLE;

		UART_rx_initialize <= 1'b0;
		UART_rx_enable <= 1'b0;
		UART_timer <= 26'd0;
		start1 <= 1'b0;//active high
		start2 <= 1'b0;//active high

	end else begin
		UART_rx_initialize <= 1'b0;
		UART_rx_enable <= 1'b0;

		// Timer for timeout on UART
		// This counter reset itself every time a new data is received on UART
		if (UART_rx_initialize | ~UART_SRAM_we_n) UART_timer <= 26'd0;
		else UART_timer <= UART_timer + 26'd1;

		case (top_state)
		S_IDLE: begin
			if (~UART_RX_I | PB_pushed[0]) begin
				// UART detected a signal, or PB0 is pressed
				UART_rx_initialize <= 1'b1;
				top_state <= S_ENABLE_UART_RX;
			end
		end
		S_ENABLE_UART_RX: begin
			// Enable the UART receiver
			UART_rx_enable <= 1'b1;
			top_state <= S_WAIT_UART_RX;
		end
		S_WAIT_UART_RX: begin
			if (UART_timer == 26'd49999999) begin
				// Timeout for 1 sec on UART for detecting if file transmission is finished
				UART_rx_initialize <= 1'b1;
				top_state <= S_M1;
			end
		end
		S_M1: begin
			// start1<=1'b1;
			// if(done1==1'b1) begin
			// 	top_state <= S_M2;
			// end
			top_state <= S_M2;
	   end
		S_M2: begin
			
			start2 <= 1'b1;
			if(done2==1'b1) begin
				top_state <= S_IDLE;
			end
			
			// top_state <= S_IDLE;
		end
			
		default: top_state <= S_IDLE;
		endcase
	end
end

/*
// Give access to SRAM for UART and other modules at appropriate time
assign SRAM_address = ((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX))
						? UART_SRAM_address
						: other_SRAM_address;

assign SRAM_write_data = UART_SRAM_write_data;

assign SRAM_we_n = ((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX))
						? UART_SRAM_we_n
						: 1'b1;
*/

// Give access to SRAM for UART and other modules at appropriate time
always_comb begin
	//sram address
	if((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX)) begin
		SRAM_address = UART_SRAM_address;
	end else if (top_state == S_M1) begin
		SRAM_address = SRAM_M1_address;
	end else if (top_state == S_M2) begin
		SRAM_address = SRAM_M2_address;
	end else begin
		SRAM_address = other_SRAM_address;
	end

	//write data	
	if((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX)) begin
		SRAM_write_data = UART_SRAM_write_data;
	end else if (top_state == S_M1) begin
		SRAM_write_data = SRAM_write_M1_data;
	end else if (top_state == S_M2) begin
		SRAM_write_data = SRAM_write_M2_data;
	end else begin
		SRAM_write_data = SRAM_write_M2_data;
	end

	//write enable
	if((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX)) begin
		SRAM_we_n = UART_SRAM_we_n;
	end else if(top_state == S_M1) begin
		SRAM_we_n = SRAM_we_M1_n;
	end else if(top_state == S_M2) begin
		SRAM_we_n = SRAM_we_M2_n;
	end else begin
		SRAM_we_n = 1'b1;
	end
end


// 7 segment displays
convert_hex_to_seven_segment unit7 (
	.hex_value(SRAM_read_data[15:12]),
	.converted_value(value_7_segment[7])
);

convert_hex_to_seven_segment unit6 (
	.hex_value(SRAM_read_data[11:8]),
	.converted_value(value_7_segment[6])
);

convert_hex_to_seven_segment unit5 (
	.hex_value(SRAM_read_data[7:4]),
	.converted_value(value_7_segment[5])
);

convert_hex_to_seven_segment unit4 (
	.hex_value(SRAM_read_data[3:0]),
	.converted_value(value_7_segment[4])
);

convert_hex_to_seven_segment unit3 (
	.hex_value(SRAM_address[19:16]),
	.converted_value(value_7_segment[3])
);

convert_hex_to_seven_segment unit2 (
	.hex_value(SRAM_address[15:12]),
	.converted_value(value_7_segment[2])
);

convert_hex_to_seven_segment unit1 (
	.hex_value(SRAM_address[11:8]),
	.converted_value(value_7_segment[1])
);

convert_hex_to_seven_segment unit0 (
	.hex_value(SRAM_address[7:4]),
	.converted_value(value_7_segment[0])
);

assign
   SEVEN_SEGMENT_N_O[0] = value_7_segment[0],
   SEVEN_SEGMENT_N_O[1] = value_7_segment[1],
   SEVEN_SEGMENT_N_O[2] = value_7_segment[2],
   SEVEN_SEGMENT_N_O[3] = value_7_segment[3],
   SEVEN_SEGMENT_N_O[4] = value_7_segment[4],
   SEVEN_SEGMENT_N_O[5] = value_7_segment[5],
   SEVEN_SEGMENT_N_O[6] = value_7_segment[6],
   SEVEN_SEGMENT_N_O[7] = value_7_segment[7];

assign LED_GREEN_O = {resetn, ~SRAM_we_n, Frame_error, top_state};

endmodule
