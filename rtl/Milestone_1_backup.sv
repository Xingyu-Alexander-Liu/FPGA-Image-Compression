

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"
`include "Milestone_1.h"

module Milestone_1 (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I, 		// 50 MHz clock
		input logic Resetn,
		input logic start1,
		output logic done1,
		input logic[15:0] SRAM_read_data,
		output logic[19:0] SRAM_address,
		output logic[15:0]SRAM_write_data,
		output logic SRAM_we_n,
		output logic signed [31:0] m1_op1,
		output logic signed [31:0] m1_op2,
		output logic signed [31:0] m1_op3,
		output logic signed [31:0] m1_op4,
		output logic signed [31:0] m1_op5,
		output logic signed [31:0] m1_op6,
		output logic signed [31:0] m1_op7,
		output logic signed [31:0] m1_op8,
		input logic signed [31:0] multi0,
		input logic signed [31:0] multi1,
		input logic signed [31:0] multi2,
		input logic signed [31:0] multi3

);

milestone1_state_type m1_state;


//SRAM address //init
logic[19:0] SRAM_address_RGB;
logic[19:0] SRAM_address_Y;
logic[19:0] SRAM_address_U;
logic[19:0] SRAM_address_V;

logic[19:0] addr_Y_OFFSET;
logic[19:0] addr_U_OFFSET;
logic[19:0] addr_V_OFFSET;

//temporarily assign the address offset of 640 * 480 image
assign addr_Y_OFFSET = 20'd614400;
assign addr_U_OFFSET = 20'd768000;
assign addr_V_OFFSET = 20'd844800;


// rgb buffers //init
logic [7:0] SRAM_data_R[1:0];
logic [7:0] SRAM_data_G[1:0];
logic [7:0] SRAM_data_B[1:0];

//buffer //init
logic [7:0] Y_buf[1:0];
logic [7:0] Up_buf[1:0];
logic [7:0] Vp_buf[1:0];
logic [7:0] U_buf[1:0];
logic [7:0] V_buf[2:0];

//ACC //init
logic signed [31:0] ACC_reg_0,ACC_reg_1;


//Y sum, shift, clipping  
logic [7:0] y_even_calc,y_odd_calc;
logic signed [15:0] y_even_calc_intermediate,y_odd_calc_intermediate;
logic signed [31:0] y_even_sum,y_odd_sum;

//U' sum, shift, clipping
logic [7:0] u_even_prime_calc,u_odd_prime_calc;
logic signed [15:0] u_even_prime_calc_intermediate,u_odd_prime_calc_intermediate;
logic signed [31:0] u_even_prime_sum,u_odd_prime_sum;
//V' sum, shift, clipping
logic [7:0] v_even_prime_calc,v_odd_prime_calc;
logic signed [15:0] v_even_prime_calc_intermediate,v_odd_prime_calc_intermediate;
logic signed [31:0] v_even_prime_sum,v_odd_prime_sum;

//U/V sum, shift, clipping
logic [7:0] u_calc,v_calc;
logic signed [31:0] u_calc_intermediate,v_calc_intermediate;
logic signed [31:0] u_sum,v_sum;


//shift register //init
logic[7:0] U_odd_shift_Reg[5:0]; //6 registers for u/v odd
logic[7:0] V_odd_shift_Reg[5:0];
logic[7:0] U_even_shift_Reg[2:0]; //3 registers for u/v even
logic[7:0] V_even_shift_Reg[2:0];

//calculation result 
logic signed [31:0] u_prime_calc;
logic signed [31:0] v_prime_calc;

//multiplier 
logic[4:0] select0;
logic[4:0] select1;
logic[4:0] select2;
logic[4:0] select3;

//coefficient assignments 
logic signed [31:0] y00;
assign y00 = $signed(32'd16843);
logic signed [31:0] y01;
assign y01 = $signed(32'd33030);
logic signed [31:0] y02;
assign y02 = $signed(32'd6423);
logic signed [31:0] u10;
assign u10 = $signed(-32'd9699);
logic signed [31:0] u11;
assign u11 = $signed(-32'd19071);
logic signed [31:0] u12;
assign u12 = $signed(32'd28770);
logic signed [31:0] v20;
assign v20 = $signed(32'd28770);
logic signed [31:0] v21;
assign v21 = $signed(-32'd24117);
logic signed [31:0] v22;
assign v22 = $signed(-32'd4653);
logic signed [31:0] p22;
assign p22 = $signed(32'd22);//22
logic signed [31:0] n52;
assign n52 = $signed(-32'd52);//-52
logic signed [31:0] p159;
assign p159 = $signed(32'd159);//159
logic signed [31:0] p256;
assign p256 = $signed(32'd256);//256
logic signed [31:0] p16;
assign p16 = $signed(32'd16);//16
logic signed [31:0] p128;
assign p128 = $signed(32'd128);//128
logic signed [31:0] p32768;
assign p32768 = $signed(32'd32768);//32768


//init
logic[9:0] Row_counter;
logic [10:0] Col_counter;
logic uv_write_flag;
logic uv_buf_flag;
parameter int no_cols = 640;
parameter int no_rows = 480;
////////////end of the definitions



// code for milestone 1
always_ff @ (posedge CLOCK_50_I or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		m1_state<=S_IDLE_m1;
		SRAM_address_RGB <= 20'd0;
		SRAM_address_Y <= addr_Y_OFFSET;
		SRAM_address_U <= addr_U_OFFSET;
		SRAM_address_V <= addr_V_OFFSET;
		SRAM_data_R[0] <= 8'd0;
		SRAM_data_R[1] <= 8'd0;
		SRAM_data_G[0] <= 8'd0;
		SRAM_data_G[1] <= 8'd0;
		SRAM_data_B[0] <= 8'd0;
		SRAM_data_B[1] <= 8'd0;
		Y_buf[0] <= 8'd0;
		Y_buf[1] <= 8'd0;
		Up_buf[0] <= 8'd0;
		Up_buf[1] <= 8'd0;
		Vp_buf[0] <= 8'd0;
		Vp_buf[1] <= 8'd0;
		U_buf[0] <= 8'd0;
		U_buf[1] <= 8'd0;
		V_buf[0] <= 8'd0;
		V_buf[1] <= 8'd0;
		V_buf[2] <= 8'd0;
		ACC_reg_0 <= 32'd0;
		ACC_reg_1 <= 32'd0;
		U_odd_shift_Reg[0] <= 8'd0;
		U_odd_shift_Reg[1] <= 8'd0;
		U_odd_shift_Reg[2] <= 8'd0;
		U_odd_shift_Reg[3] <= 8'd0;
		U_odd_shift_Reg[4] <= 8'd0;
		U_odd_shift_Reg[5] <= 8'd0;
		V_odd_shift_Reg[0] <= 8'd0;
		V_odd_shift_Reg[1] <= 8'd0;
		V_odd_shift_Reg[2] <= 8'd0;
		V_odd_shift_Reg[3] <= 8'd0;
		V_odd_shift_Reg[4] <= 8'd0;
		V_odd_shift_Reg[5] <= 8'd0;
		U_even_shift_Reg[0] <= 8'd0;
		U_even_shift_Reg[1] <= 8'd0;
		U_even_shift_Reg[2] <= 8'd0;
		V_even_shift_Reg[0] <= 8'd0;
		V_even_shift_Reg[1] <= 8'd0;
		V_even_shift_Reg[2] <= 8'd0;
		select0 <= 5'd0;
		select1 <= 5'd0;
		select2 <= 5'd0;
		select3 <= 5'd0;
		Row_counter <= 10'd0;
		Col_counter <= 10'd0;
		uv_write_flag <= 1'b0;
		uv_buf_flag <= 1'b0;
		//output
		SRAM_we_n <= 1'bx;
		SRAM_address <= 20'd0; //? do I need this?
		SRAM_write_data <= 16'd0; //?
		done1 <= 1'b0;//?

	end else begin
		case(m1_state)
		
			S_IDLE_m1:begin
				
				if ((start1 == 1'b1) && (done1 == 1'b0)) m1_state<=S_LI_0;
			end
			S_LI_0:begin
				//SRAM_address_Y<=18'd0;
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				Col_counter <= 10'd0;
				m1_state<=S_LI_1;
			end
			S_LI_1:begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				m1_state<=S_LI_2;
			end
			S_LI_2: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				m1_state<=S_LI_3;				
			end
			S_LI_3: begin
				SRAM_we_n <= 1'bx;
				SRAM_data_R[0] <= SRAM_read_data[15:8];
				SRAM_data_G[0] <= SRAM_read_data[7:0];
				m1_state<=S_LI_4;
			end
			S_LI_4: begin
				SRAM_data_B[0] <= SRAM_read_data[15:8];
				SRAM_data_R[1] <= SRAM_read_data[7:0];
				select0 <= 5'd1;
				select1 <= 5'd1;
				select2 <= 5'd1;
				select3 <= 5'd1;
				m1_state<=S_LI_5;
			end
			S_LI_5: begin
				SRAM_we_n <= 1'b0;
				SRAM_write_data <= {Y_buf[0],Y_buf[1]};
				SRAM_data_G[1] <= SRAM_read_data[15:8];
				SRAM_data_B[1] <= SRAM_read_data[7:0];
				select0 <= 5'd2;
				select1 <= 5'd2;
				select2 <= 5'd2;
				select3 <= 5'd2;
				ACC_reg_0 <= multi3;
				Y_buf[0] <= y_even_calc;
				Col_counter <= Col_counter + 10'd2;
				m1_state<=S_LI_6;
			end
			S_LI_6: begin
				SRAM_we_n <= 1'b0;
				select0 <= 5'd3;
				select1 <= 5'd3;
				select2 <= 5'd3;
				select3 <= 5'd3;
				ACC_reg_1 <= multi2 + multi3;
				Up_buf[0] <= u_even_prime_calc;
				m1_state<=S_LI_7;
			end
			S_LI_7: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd4;
				select1 <= 5'd4;
				select2 <= 5'd4;
				select3 <= 5'd4;
				Vp_buf[0] <= v_even_prime_calc;
				Y_buf[1] <= y_odd_calc;
				//shift register initiation U' odd
				U_odd_shift_Reg[0] <= Up_buf[0];
				U_odd_shift_Reg[1] <= Up_buf[0];
				U_odd_shift_Reg[2] <= Up_buf[0];
				U_odd_shift_Reg[3] <= Up_buf[0];
				U_odd_shift_Reg[4] <= Up_buf[0];
				U_odd_shift_Reg[5] <= Up_buf[0];
				//shift register initiation U' even
				U_even_shift_Reg[0] <= Up_buf[0];
				U_even_shift_Reg[1] <= Up_buf[0];
				U_even_shift_Reg[2] <= Up_buf[0];
				m1_state<=S_LI_8;
			end
			S_LI_8: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd5;
				select1 <= 5'd5;
				select2 <= 5'd0;
				select3 <= 5'd0;
				ACC_reg_0 <= multi3;
				Up_buf[1] <= u_odd_prime_calc;

				//shift register operation U' odd
				U_odd_shift_Reg[0] <= U_odd_shift_Reg[1];
				U_odd_shift_Reg[1] <= U_odd_shift_Reg[2];
				U_odd_shift_Reg[2] <= U_odd_shift_Reg[3];
				U_odd_shift_Reg[3] <= U_odd_shift_Reg[4];
				U_odd_shift_Reg[4] <= U_odd_shift_Reg[5];
				U_odd_shift_Reg[5] <= u_odd_prime_calc;
				//shift register U' even no operation
				//**//
				//shift register initiation V' odd
				V_odd_shift_Reg[0] <= Vp_buf[0];
				V_odd_shift_Reg[1] <= Vp_buf[0]; 
				V_odd_shift_Reg[2] <= Vp_buf[0];
				V_odd_shift_Reg[3] <= Vp_buf[0];
				V_odd_shift_Reg[4] <= Vp_buf[0];
				V_odd_shift_Reg[5] <= Vp_buf[0];
				//shift register initiation V' even
				V_even_shift_Reg[0] <= Vp_buf[0];
				V_even_shift_Reg[1] <= Vp_buf[0];
				V_even_shift_Reg[2] <= Vp_buf[0];
				m1_state<=S_LI_9;
			end
			S_LI_9: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd0;
				select1 <= 5'd0;
				select2 <= 5'd0;
				select3 <= 5'd0;
				Vp_buf[1] <= v_odd_prime_calc;
				//shift register operation V' odd
				V_odd_shift_Reg[0] <= V_odd_shift_Reg[1];
				V_odd_shift_Reg[1] <= V_odd_shift_Reg[2];
				V_odd_shift_Reg[2] <= V_odd_shift_Reg[3];
				V_odd_shift_Reg[3] <= V_odd_shift_Reg[4];
				V_odd_shift_Reg[4] <= V_odd_shift_Reg[5];
				V_odd_shift_Reg[5] <= v_odd_prime_calc;
				//shift register no operation V' even
				//**//
				m1_state<=S_LI_10;
			end
			S_LI_10: begin
				SRAM_we_n <= 1'bx;
				SRAM_data_R[0] <= SRAM_read_data[15:8];
				SRAM_data_G[0] <= SRAM_read_data[7:0];
				m1_state<=S_LI_11;
			end
			S_LI_11: begin
				SRAM_data_B[0] <= SRAM_read_data[15:8];
				SRAM_data_R[1] <= SRAM_read_data[7:0];
				select0 <= 5'd1;
				select1 <= 5'd1;
				select2 <= 5'd1;
				select3 <= 5'd1;
				m1_state<=S_LI_12;
			end
			S_LI_12: begin
				SRAM_we_n <= 1'b0;
				SRAM_address <= SRAM_address_Y;
				SRAM_address_Y <= SRAM_address_Y + 20'd1;
				SRAM_write_data <= {Y_buf[0],Y_buf[1]};
				SRAM_data_G[1] <= SRAM_read_data[15:8];
				SRAM_data_B[1] <= SRAM_read_data[7:0];
				select0 <= 5'd2;
				select1 <= 5'd2;
				select2 <= 5'd2;
				select3 <= 5'd2;
				ACC_reg_0 <= multi3;
				Y_buf[0] <= y_even_calc;
				Col_counter <= Col_counter + 10'd2;
				m1_state<=S_LI_13;
			end
			S_LI_13: begin
				SRAM_we_n <= 1'b0;
				select0 <= 5'd3;
				select1 <= 5'd3;
				select2 <= 5'd3;
				select3 <= 5'd3;
				ACC_reg_1 <= multi2 + multi3;
				Up_buf[0] <= u_even_prime_calc;
				m1_state<=S_LI_14;
			end
			S_LI_14: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd4;
				select1 <= 5'd4;
				select2 <= 5'd4;
				select3 <= 5'd4;
				Vp_buf[0] <= v_even_prime_calc;
				Y_buf[1] <= y_odd_calc;
				m1_state<=S_LI_15;
			end
			S_LI_15: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd5;
				select1 <= 5'd5;
				select2 <= 5'd0;
				select3 <= 5'd0;
				ACC_reg_0 <= multi3;
				Up_buf[1] <= u_odd_prime_calc;

				//shift register operation U' odd
				U_odd_shift_Reg[0] <= U_odd_shift_Reg[1];
				U_odd_shift_Reg[1] <= U_odd_shift_Reg[2];
				U_odd_shift_Reg[2] <= U_odd_shift_Reg[3];
				U_odd_shift_Reg[3] <= U_odd_shift_Reg[4];
				U_odd_shift_Reg[4] <= U_odd_shift_Reg[5];
				U_odd_shift_Reg[5] <= u_odd_prime_calc;
				//shift register operation U' even
				U_even_shift_Reg[0] <= U_even_shift_Reg[1];
				U_even_shift_Reg[1] <= U_even_shift_Reg[2];
				U_even_shift_Reg[2] <= Up_buf[0];
				m1_state<=S_LI_16;
			end
			S_LI_16: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd0;
				select1 <= 5'd0;
				select2 <= 5'd0;
				select3 <= 5'd0;
				Vp_buf[1] <= v_odd_prime_calc;
				//shift register operation V' odd
				V_odd_shift_Reg[0] <= V_odd_shift_Reg[1];
				V_odd_shift_Reg[1] <= V_odd_shift_Reg[2];
				V_odd_shift_Reg[2] <= V_odd_shift_Reg[3];
				V_odd_shift_Reg[3] <= V_odd_shift_Reg[4];
				V_odd_shift_Reg[4] <= V_odd_shift_Reg[5];
				V_odd_shift_Reg[5] <= v_odd_prime_calc;
				//shift register operation V' even
				V_even_shift_Reg[0] <= V_even_shift_Reg[1];
				V_even_shift_Reg[1] <= V_even_shift_Reg[2];
				V_even_shift_Reg[2] <= Vp_buf[0];
				m1_state<=S_LI_17;
			end
			S_LI_17: begin
				SRAM_we_n <= 1'bx;
				SRAM_data_R[0] <= SRAM_read_data[15:8];
				SRAM_data_G[0] <= SRAM_read_data[7:0];
				m1_state<=S_LI_18;
			end
			S_LI_18: begin
				SRAM_data_B[0] <= SRAM_read_data[15:8];
				SRAM_data_R[1] <= SRAM_read_data[7:0];
				select0 <= 5'd1;
				select1 <= 5'd1;
				select2 <= 5'd1;
				select3 <= 5'd1;
				m1_state<=S_LI_19;
			end
			S_LI_19: begin
				SRAM_we_n <= 1'b0;
				SRAM_address <= SRAM_address_Y;
				SRAM_address_Y <= SRAM_address_Y + 20'd1;
				SRAM_write_data <= {Y_buf[0],Y_buf[1]};
				SRAM_data_G[1] <= SRAM_read_data[15:8];
				SRAM_data_B[1] <= SRAM_read_data[7:0];
				select0 <= 5'd2;
				select1 <= 5'd2;
				select2 <= 5'd2;
				select3 <= 5'd2;
				ACC_reg_0 <= multi3;
				Y_buf[0] <= y_even_calc;
				Col_counter <= Col_counter + 10'd2;
				m1_state<=S_LI_20;
			end
			S_LI_20: begin
				SRAM_we_n <= 1'b0;
				select0 <= 5'd3;
				select1 <= 5'd3;
				select2 <= 5'd3;
				select3 <= 5'd3;
				ACC_reg_1 <= multi2 + multi3;
				Up_buf[0] <= u_even_prime_calc;
				m1_state<=S_LI_21;
			end
			S_LI_21: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd4;
				select1 <= 5'd4;
				select2 <= 5'd4;
				select3 <= 5'd4;
				Vp_buf[0] <= v_even_prime_calc;
				Y_buf[1] <= y_odd_calc;
				m1_state<=S_LI_22;
			end
			S_LI_22: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd5;
				select1 <= 5'd5;
				select2 <= 5'd5;
				select3 <= 5'd5;
				ACC_reg_0 <= multi3;
				Up_buf[1] <= u_odd_prime_calc;

				//shift register operation U' odd
				U_odd_shift_Reg[0] <= U_odd_shift_Reg[1];
				U_odd_shift_Reg[1] <= U_odd_shift_Reg[2];
				U_odd_shift_Reg[2] <= U_odd_shift_Reg[3];
				U_odd_shift_Reg[3] <= U_odd_shift_Reg[4];
				U_odd_shift_Reg[4] <= U_odd_shift_Reg[5];
				U_odd_shift_Reg[5] <= u_odd_prime_calc;
				//shift register operation U' even
				U_even_shift_Reg[0] <= U_even_shift_Reg[1];
				U_even_shift_Reg[1] <= U_even_shift_Reg[2];
				U_even_shift_Reg[2] <= Up_buf[0];
				m1_state<=S_LI_23;
			end
			S_LI_23: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd6;
				select1 <= 5'd6;
				select2 <= 5'd6;
				select3 <= 5'd6;
				ACC_reg_1 <= multi2 + multi3;
				Vp_buf[1] <= v_odd_prime_calc;
				//shift register operation V' odd
				V_odd_shift_Reg[0] <= V_odd_shift_Reg[1];
				V_odd_shift_Reg[1] <= V_odd_shift_Reg[2];
				V_odd_shift_Reg[2] <= V_odd_shift_Reg[3];
				V_odd_shift_Reg[3] <= V_odd_shift_Reg[4];
				V_odd_shift_Reg[4] <= V_odd_shift_Reg[5];
				V_odd_shift_Reg[5] <= v_odd_prime_calc;
				//shift register operation V' even
				V_even_shift_Reg[0] <= V_even_shift_Reg[1];
				V_even_shift_Reg[1] <= V_even_shift_Reg[2];
				V_even_shift_Reg[2] <= Vp_buf[0];
				m1_state<=S_LI_24;
			end
			S_LI_24: begin
				SRAM_we_n <= 1'bx;
				SRAM_data_R[0] <= SRAM_read_data[15:8];
				SRAM_data_G[0] <= SRAM_read_data[7:0];
				U_buf[0] <= u_calc;
				V_buf[0] <= v_calc;	
				m1_state<=S_LI_25;
			end
			S_LI_25: begin
				SRAM_data_B[0] <= SRAM_read_data[15:8];
				SRAM_data_R[1] <= SRAM_read_data[7:0];
				select0 <= 5'd1;
				select1 <= 5'd1;
				select2 <= 5'd1;
				select3 <= 5'd1;
				m1_state<=S_LI_26;
			end
			S_LI_26: begin
				SRAM_we_n <= 1'b0;
				SRAM_address <= SRAM_address_Y;
				SRAM_address_Y <= SRAM_address_Y + 20'd1;
				SRAM_write_data <= {Y_buf[0],Y_buf[1]};
				SRAM_data_G[1] <= SRAM_read_data[15:8];
				SRAM_data_B[1] <= SRAM_read_data[7:0];
				select0 <= 5'd2;
				select1 <= 5'd2;
				select2 <= 5'd2;
				select3 <= 5'd2;
				ACC_reg_0 <= multi3;
				Y_buf[0] <= y_even_calc;
				Col_counter <= Col_counter + 10'd2;
				m1_state<=S_LI_27;
			end
			S_LI_27: begin
				SRAM_we_n <= 1'b0;
				select0 <= 5'd3;
				select1 <= 5'd3;
				select2 <= 5'd3;
				select3 <= 5'd3;
				ACC_reg_1 <= multi2 + multi3;
				Up_buf[0] <= u_even_prime_calc;
				m1_state<=S_LI_28;
			end
			S_LI_28: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd4;
				select1 <= 5'd4;
				select2 <= 5'd4;
				select3 <= 5'd4;
				Vp_buf[0] <= v_even_prime_calc;
				Y_buf[1] <= y_odd_calc;
				m1_state<=S_LI_29;
			end
			S_LI_29: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd5;
				select1 <= 5'd5;
				select2 <= 5'd5;
				select3 <= 5'd5;
				ACC_reg_0 <= multi3;
				Up_buf[1] <= u_odd_prime_calc;

				//shift register operation U' odd
				U_odd_shift_Reg[0] <= U_odd_shift_Reg[1];
				U_odd_shift_Reg[1] <= U_odd_shift_Reg[2];
				U_odd_shift_Reg[2] <= U_odd_shift_Reg[3];
				U_odd_shift_Reg[3] <= U_odd_shift_Reg[4];
				U_odd_shift_Reg[4] <= U_odd_shift_Reg[5];
				U_odd_shift_Reg[5] <= u_odd_prime_calc;
				//shift register operation U' even
				U_even_shift_Reg[0] <= U_even_shift_Reg[1];
				U_even_shift_Reg[1] <= U_even_shift_Reg[2];
				U_even_shift_Reg[2] <= Up_buf[0];
				m1_state<=S_LI_30;
			end
			S_LI_30: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd6;
				select1 <= 5'd6;
				select2 <= 5'd6;
				select3 <= 5'd6;
				ACC_reg_1 <= multi2 + multi3;
				Vp_buf[1] <= v_odd_prime_calc;
				//shift register operation V' odd
				V_odd_shift_Reg[0] <= V_odd_shift_Reg[1];
				V_odd_shift_Reg[1] <= V_odd_shift_Reg[2];
				V_odd_shift_Reg[2] <= V_odd_shift_Reg[3];
				V_odd_shift_Reg[3] <= V_odd_shift_Reg[4];
				V_odd_shift_Reg[4] <= V_odd_shift_Reg[5];
				V_odd_shift_Reg[5] <= v_odd_prime_calc;
				//shift register operation V' even
				V_even_shift_Reg[0] <= V_even_shift_Reg[1];
				V_even_shift_Reg[1] <= V_even_shift_Reg[2];
				V_even_shift_Reg[2] <= Vp_buf[0];
				m1_state<=S_LI_31;
			end
			S_LI_31: begin
				SRAM_we_n <= 1'bx;
				SRAM_data_R[0] <= SRAM_read_data[15:8];
				SRAM_data_G[0] <= SRAM_read_data[7:0];
				U_buf[1] <= u_calc;
				V_buf[1] <= v_calc;	
				m1_state<=S_LI_32;
			end
			S_LI_32: begin
				SRAM_data_B[0] <= SRAM_read_data[15:8];
				SRAM_data_R[1] <= SRAM_read_data[7:0];
				select0 <= 5'd1;
				select1 <= 5'd1;
				select2 <= 5'd1;
				select3 <= 5'd1;
				m1_state<=S_CC_0;
			end
			S_CC_0: begin
				SRAM_we_n <= 1'b0;
				SRAM_address <= SRAM_address_Y;
				SRAM_address_Y <= SRAM_address_Y + 20'd1;
				SRAM_write_data <= {Y_buf[0],Y_buf[1]};
				SRAM_data_G[1] <= SRAM_read_data[15:8];
				SRAM_data_B[1] <= SRAM_read_data[7:0];
				select0 <= 5'd2;
				select1 <= 5'd2;
				select2 <= 5'd2;
				select3 <= 5'd2;
				ACC_reg_0 <= multi3;
				Y_buf[0] <= y_even_calc;
				Col_counter <= Col_counter + 10'd2;
				m1_state<=S_CC_1;
			end
			S_CC_1: begin
				SRAM_we_n <= 1'b0;
				if(uv_write_flag == 1'b0) begin
					SRAM_address <= SRAM_address_U;
					SRAM_address_U <= SRAM_address_U + 20'd1;
					SRAM_write_data <= {U_buf[0],U_buf[1]};
				end else begin
					SRAM_address <= SRAM_address_V;
					SRAM_address_V <= SRAM_address_V + 20'd1;
					SRAM_write_data <= {V_buf[2],V_buf[1]};
				end
				uv_write_flag <= ~uv_write_flag;
				select0 <= 5'd3;
				select1 <= 5'd3;
				select2 <= 5'd3;
				select3 <= 5'd3;
				ACC_reg_1 <= multi2 + multi3;
				Up_buf[0] <= u_even_prime_calc;
				m1_state<=S_CC_2;
			end
			S_CC_2: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd4;
				select1 <= 5'd4;
				select2 <= 5'd4;
				select3 <= 5'd4;
				Vp_buf[0] <= v_even_prime_calc;
				Y_buf[1] <= y_odd_calc;
				m1_state<=S_CC_3;
			end
			S_CC_3: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd5;
				select1 <= 5'd5;
				select2 <= 5'd5;
				select3 <= 5'd5;
				ACC_reg_0 <= multi3;
				Up_buf[1] <= u_odd_prime_calc;

				//shift register operation U' odd
				U_odd_shift_Reg[0] <= U_odd_shift_Reg[1];
				U_odd_shift_Reg[1] <= U_odd_shift_Reg[2];
				U_odd_shift_Reg[2] <= U_odd_shift_Reg[3];
				U_odd_shift_Reg[3] <= U_odd_shift_Reg[4];
				U_odd_shift_Reg[4] <= U_odd_shift_Reg[5];
				U_odd_shift_Reg[5] <= u_odd_prime_calc;
				//shift register operation U' even
				U_even_shift_Reg[0] <= U_even_shift_Reg[1];
				U_even_shift_Reg[1] <= U_even_shift_Reg[2];
				U_even_shift_Reg[2] <= Up_buf[0];
				m1_state<=S_CC_4;
			end
			S_CC_4: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd6;
				select1 <= 5'd6;
				select2 <= 5'd6;
				select3 <= 5'd6;
				ACC_reg_1 <= multi2 + multi3;
				Vp_buf[1] <= v_odd_prime_calc;
				if (uv_buf_flag == 1'b0) begin
					V_buf[2] <= V_buf[0];
				end
				//shift register operation V' odd
				V_odd_shift_Reg[0] <= V_odd_shift_Reg[1];
				V_odd_shift_Reg[1] <= V_odd_shift_Reg[2];
				V_odd_shift_Reg[2] <= V_odd_shift_Reg[3];
				V_odd_shift_Reg[3] <= V_odd_shift_Reg[4];
				V_odd_shift_Reg[4] <= V_odd_shift_Reg[5];
				V_odd_shift_Reg[5] <= v_odd_prime_calc;
				//shift register operation V' even
				V_even_shift_Reg[0] <= V_even_shift_Reg[1];
				V_even_shift_Reg[1] <= V_even_shift_Reg[2];
				V_even_shift_Reg[2] <= Vp_buf[0];
				m1_state<=S_CC_5;
			end
			S_CC_5: begin
				SRAM_we_n <= 1'bx;
				SRAM_data_R[0] <= SRAM_read_data[15:8];
				SRAM_data_G[0] <= SRAM_read_data[7:0];
				if(uv_buf_flag == 1'b0) begin
					U_buf[0] <= u_calc;
					V_buf[0] <= v_calc;
				end else begin
					U_buf[1] <= u_calc;
					V_buf[1] <= v_calc;
				end
				uv_buf_flag <= ~uv_buf_flag;
				m1_state<=S_CC_6;
			end
			S_CC_6: begin
				SRAM_data_B[0] <= SRAM_read_data[15:8];
				SRAM_data_R[1] <= SRAM_read_data[7:0];
				select0 <= 5'd1;
				select1 <= 5'd1;
				select2 <= 5'd1;
				select3 <= 5'd1;
				if(Col_counter == no_cols - 4) begin
					m1_state<=S_LO_0;
				end else begin
					m1_state <= S_CC_0;
				end
			end
			S_LO_0: begin
				Row_counter <= Row_counter + 10'd1;
				SRAM_we_n <= 1'b0;
				SRAM_address <= SRAM_address_Y;
				SRAM_address_Y <= SRAM_address_Y + 20'd1;
				SRAM_write_data <= {Y_buf[0],Y_buf[1]};
				SRAM_data_G[1] <= SRAM_read_data[15:8];
				SRAM_data_B[1] <= SRAM_read_data[7:0];
				select0 <= 5'd2;
				select1 <= 5'd2;
				select2 <= 5'd2;
				select3 <= 5'd2;
				ACC_reg_0 <= multi3;
				Y_buf[0] <= y_even_calc;
				//Col_counter <= Col_counter + 10'd2;
				m1_state<=S_LO_1;
			end
			S_LO_1: begin
				SRAM_we_n <= 1'b0;
				SRAM_address <= SRAM_address_U;
				SRAM_address_U <= SRAM_address_U + 20'd1;
				SRAM_write_data <= {U_buf[0],U_buf[1]};
				// SRAM_address <= SRAM_address_V;
				// SRAM_address_V <= SRAM_address_V + 20'd1;
				// SRAM_write_data <= {V_buf[2],V_buf[1]};
				select0 <= 5'd3;
				select1 <= 5'd3;
				select2 <= 5'd3;
				select3 <= 5'd3;
				ACC_reg_1 <= multi2 + multi3;
				Up_buf[0] <= u_even_prime_calc;
				m1_state<=S_LO_2;
			end
			S_LO_2: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd4;
				select1 <= 5'd4;
				select2 <= 5'd4;
				select3 <= 5'd4;
				Vp_buf[0] <= v_even_prime_calc;
				Y_buf[1] <= y_odd_calc;
				m1_state<=S_LO_3;
			end
			S_LO_3: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd5;
				select1 <= 5'd5;
				select2 <= 5'd5;
				select3 <= 5'd5;
				ACC_reg_0 <= multi3;
				Up_buf[1] <= u_odd_prime_calc;

				//shift register operation U' odd
				U_odd_shift_Reg[0] <= U_odd_shift_Reg[1];
				U_odd_shift_Reg[1] <= U_odd_shift_Reg[2];
				U_odd_shift_Reg[2] <= U_odd_shift_Reg[3];
				U_odd_shift_Reg[3] <= U_odd_shift_Reg[4];
				U_odd_shift_Reg[4] <= U_odd_shift_Reg[5];
				U_odd_shift_Reg[5] <= u_odd_prime_calc;
				//shift register operation U' even
				U_even_shift_Reg[0] <= U_even_shift_Reg[1];
				U_even_shift_Reg[1] <= U_even_shift_Reg[2];
				U_even_shift_Reg[2] <= Up_buf[0];
				m1_state<=S_LO_4;
			end
			S_LO_4: begin
				SRAM_address<=SRAM_address_RGB;
				SRAM_address_RGB <= SRAM_address_RGB + 20'd1;
				SRAM_we_n <= 1'b1;
				select0 <= 5'd6;
				select1 <= 5'd6;
				select2 <= 5'd6;
				select3 <= 5'd6;
				ACC_reg_1 <= multi2 + multi3;
				Vp_buf[1] <= v_odd_prime_calc;
				V_buf[2] <= V_buf[0];//don't need flag
				//shift register operation V' odd
				V_odd_shift_Reg[0] <= V_odd_shift_Reg[1];
				V_odd_shift_Reg[1] <= V_odd_shift_Reg[2];
				V_odd_shift_Reg[2] <= V_odd_shift_Reg[3];
				V_odd_shift_Reg[3] <= V_odd_shift_Reg[4];
				V_odd_shift_Reg[4] <= V_odd_shift_Reg[5];
				V_odd_shift_Reg[5] <= v_odd_prime_calc;
				//shift register operation V' even
				V_even_shift_Reg[0] <= V_even_shift_Reg[1];
				V_even_shift_Reg[1] <= V_even_shift_Reg[2];
				V_even_shift_Reg[2] <= Vp_buf[0];
				m1_state<=S_LO_5;
			end
			S_LO_5: begin
				SRAM_we_n <= 1'bx;
				SRAM_data_R[0] <= SRAM_read_data[15:8];
				SRAM_data_G[0] <= SRAM_read_data[7:0];
				U_buf[0] <= u_calc;//dont need flag
				V_buf[0] <= v_calc;
				m1_state<=S_LO_6;
			end
			S_LO_6: begin
				SRAM_data_B[0] <= SRAM_read_data[15:8];
				SRAM_data_R[1] <= SRAM_read_data[7:0];
				select0 <= 5'd1;
				select1 <= 5'd1;
				select2 <= 5'd1;
				select3 <= 5'd1;
				m1_state <= S_LO_7;
			end
			S_LO_7: begin
				SRAM_we_n <= 1'b0;
				SRAM_address <= SRAM_address_Y;
				SRAM_address_Y <= SRAM_address_Y + 20'd1;
				SRAM_write_data <= {Y_buf[0],Y_buf[1]};
				SRAM_data_G[1] <= SRAM_read_data[15:8];
				SRAM_data_B[1] <= SRAM_read_data[7:0];
				select0 <= 5'd2;
				select1 <= 5'd2;
				select2 <= 5'd2;
				select3 <= 5'd2;
				ACC_reg_0 <= multi3;
				Y_buf[0] <= y_even_calc;
				// Col_counter <= Col_counter + 10'd2;
				m1_state<=S_LO_8;
			end
			S_LO_8: begin
				SRAM_we_n <= 1'b0;
				// SRAM_address <= SRAM_address_U;
				// SRAM_address_U <= SRAM_address_U + 20'd1;
				// SRAM_write_data <= {U_buf[0],U_buf[1]};
				SRAM_address <= SRAM_address_V;
				SRAM_address_V <= SRAM_address_V + 20'd1;
				SRAM_write_data <= {V_buf[2],V_buf[1]};
				select0 <= 5'd3;
				select1 <= 5'd3;
				select2 <= 5'd3;
				select3 <= 5'd3;
				ACC_reg_1 <= multi2 + multi3;
				Up_buf[0] <= u_even_prime_calc;
				m1_state<=S_LO_9;
			end
			S_LO_9: begin
				SRAM_we_n <= 1'bx;
				select0 <= 5'd4;
				select1 <= 5'd4;
				select2 <= 5'd4;
				select3 <= 5'd4;
				Vp_buf[0] <= v_even_prime_calc;
				Y_buf[1] <= y_odd_calc;
				m1_state<=S_LO_10;
			end
			S_LO_10: begin
				select0 <= 5'd5;
				select1 <= 5'd5;
				select2 <= 5'd5;
				select3 <= 5'd5;
				ACC_reg_0 <= multi3;
				Up_buf[1] <= u_odd_prime_calc;

				//shift register operation U' odd
				U_odd_shift_Reg[0] <= U_odd_shift_Reg[1];
				U_odd_shift_Reg[1] <= U_odd_shift_Reg[2];
				U_odd_shift_Reg[2] <= U_odd_shift_Reg[3];
				U_odd_shift_Reg[3] <= U_odd_shift_Reg[4];
				U_odd_shift_Reg[4] <= U_odd_shift_Reg[5];
				U_odd_shift_Reg[5] <= u_odd_prime_calc;
				//shift register operation U' even
				U_even_shift_Reg[0] <= U_even_shift_Reg[1];
				U_even_shift_Reg[1] <= U_even_shift_Reg[2];
				U_even_shift_Reg[2] <= Up_buf[0];
				m1_state<=S_LO_11;
			end
			S_LO_11: begin
				select0 <= 5'd6;
				select1 <= 5'd6;
				select2 <= 5'd6;
				select3 <= 5'd6;
				ACC_reg_1 <= multi2 + multi3;
				Vp_buf[1] <= v_odd_prime_calc;
				//V_buf[2] <= V_buf[0];//don't need flag
				//shift register operation V' odd
				V_odd_shift_Reg[0] <= V_odd_shift_Reg[1];
				V_odd_shift_Reg[1] <= V_odd_shift_Reg[2];
				V_odd_shift_Reg[2] <= V_odd_shift_Reg[3];
				V_odd_shift_Reg[3] <= V_odd_shift_Reg[4];
				V_odd_shift_Reg[4] <= V_odd_shift_Reg[5];
				V_odd_shift_Reg[5] <= v_odd_prime_calc;
				//shift register operation V' even
				V_even_shift_Reg[0] <= V_even_shift_Reg[1];
				V_even_shift_Reg[1] <= V_even_shift_Reg[2];
				V_even_shift_Reg[2] <= Vp_buf[0];
				m1_state<=S_LO_12;
			end
			S_LO_12: begin
				U_buf[1] <= u_calc;//dont need flag
				V_buf[1] <= v_calc;
				m1_state<=S_LO_13;
			end
			S_LO_13: begin
				m1_state <= S_LO_14;
			end
			S_LO_14: begin
				SRAM_we_n <= 1'b0;
				SRAM_address <= SRAM_address_Y;
				SRAM_address_Y <= SRAM_address_Y + 20'd1;
				SRAM_write_data <= {Y_buf[0],Y_buf[1]};
				// SRAM_data_G[1] <= SRAM_read_data[15:8];
				// SRAM_data_B[1] <= SRAM_read_data[7:0];
				select0 <= 5'd0;
				select1 <= 5'd0;
				select2 <= 5'd0;
				select3 <= 5'd0;
				//ACC_reg_0 <= multi3;
				//Y_buf[0] <= y_even_calc;
				// Col_counter <= Col_counter + 10'd2;
				m1_state<=S_LO_15;
			end
			S_LO_15: begin
				SRAM_we_n <= 1'b0;
				SRAM_address <= SRAM_address_U;
				SRAM_address_U <= SRAM_address_U + 20'd1;
				SRAM_write_data <= {U_buf[0],U_buf[1]};
				// SRAM_address <= SRAM_address_V;
				// SRAM_address_V <= SRAM_address_V + 20'd1;
				// SRAM_write_data <= {V_buf[2],V_buf[1]};
				select0 <= 5'd0;
				select1 <= 5'd0;
				select2 <= 5'd0;
				select3 <= 5'd0;
				//ACC_reg_1 <= multi2 + multi3;
				//Up_buf[0] <= u_even_prime_calc;
				m1_state<=S_LO_16;
			end
			S_LO_16: begin
				SRAM_we_n <= 1'bx;
				select0 <= 5'd0;
				select1 <= 5'd0;
				select2 <= 5'd0;
				select3 <= 5'd0;
				//Vp_buf[0] <= v_even_prime_calc;
				//Y_buf[1] <= y_odd_calc;
				m1_state<=S_LO_17;
			end
			S_LO_17: begin
				select0 <= 5'd0;
				select1 <= 5'd0;
				select2 <= 5'd5;
				select3 <= 5'd5;
				//ACC_reg_0 <= multi3;
				//Up_buf[1] <= u_odd_prime_calc;

				//shift register operation U' odd
				U_odd_shift_Reg[0] <= U_odd_shift_Reg[1];
				U_odd_shift_Reg[1] <= U_odd_shift_Reg[2];
				U_odd_shift_Reg[2] <= U_odd_shift_Reg[3];
				U_odd_shift_Reg[3] <= U_odd_shift_Reg[4];
				U_odd_shift_Reg[4] <= U_odd_shift_Reg[5];
				U_odd_shift_Reg[5] <= Up_buf[1];
				//shift register operation U' even
				U_even_shift_Reg[0] <= U_even_shift_Reg[1];
				U_even_shift_Reg[1] <= U_even_shift_Reg[2];
				U_even_shift_Reg[2] <= Up_buf[1];
				m1_state<=S_LO_18;
			end
			S_LO_18: begin
				select0 <= 5'd6;
				select1 <= 5'd6;
				select2 <= 5'd6;
				select3 <= 5'd6;
				ACC_reg_1 <= multi2 + multi3;
				//Vp_buf[1] <= v_odd_prime_calc;
				V_buf[2] <= V_buf[0];//don't need flag
				//shift register operation V' odd
				V_odd_shift_Reg[0] <= V_odd_shift_Reg[1];
				V_odd_shift_Reg[1] <= V_odd_shift_Reg[2];
				V_odd_shift_Reg[2] <= V_odd_shift_Reg[3];
				V_odd_shift_Reg[3] <= V_odd_shift_Reg[4];
				V_odd_shift_Reg[4] <= V_odd_shift_Reg[5];
				V_odd_shift_Reg[5] <= Vp_buf[1];
				//shift register operation V' even
				V_even_shift_Reg[0] <= V_even_shift_Reg[1];
				V_even_shift_Reg[1] <= V_even_shift_Reg[2];
				V_even_shift_Reg[2] <= Vp_buf[1];
				m1_state<=S_LO_19;
			end
			S_LO_19: begin
				U_buf[0] <= u_calc;//dont need flag
				V_buf[0] <= v_calc;
				m1_state<=S_LO_20;
			end
			S_LO_20: begin
				m1_state <= S_LO_21;
			end
			S_LO_21: begin
				// SRAM_we_n <= 1'b0;
				// SRAM_address <= SRAM_address_Y;
				// SRAM_address_Y <= SRAM_address_Y + 20'd1;
				// SRAM_write_data <= {Y_buf[0],Y_buf[1]};
				// SRAM_data_G[1] <= SRAM_read_data[15:8];
				// SRAM_data_B[1] <= SRAM_read_data[7:0];
				select0 <= 5'd0;
				select1 <= 5'd0;
				select2 <= 5'd0;
				select3 <= 5'd0;
				//ACC_reg_0 <= multi3;
				//Y_buf[0] <= y_even_calc;
				// Col_counter <= Col_counter + 10'd2;
				m1_state<=S_LO_22;
			end
			S_LO_22: begin
				SRAM_we_n <= 1'b0;
				// SRAM_address <= SRAM_address_U;
				// SRAM_address_U <= SRAM_address_U + 20'd1;
				// SRAM_write_data <= {U_buf[0],U_buf[1]};
				SRAM_address <= SRAM_address_V;
				SRAM_address_V <= SRAM_address_V + 20'd1;
				SRAM_write_data <= {V_buf[2],V_buf[1]};
				select0 <= 5'd0;
				select1 <= 5'd0;
				select2 <= 5'd0;
				select3 <= 5'd0;
				//ACC_reg_1 <= multi2 + multi3;
				//Up_buf[0] <= u_even_prime_calc;
				m1_state<=S_LO_23;
			end
			S_LO_23: begin
				SRAM_we_n <= 1'bx;
				select0 <= 5'd0;
				select1 <= 5'd0;
				select2 <= 5'd0;
				select3 <= 5'd0;
				//Vp_buf[0] <= v_even_prime_calc;
				//Y_buf[1] <= y_odd_calc;
				m1_state<=S_LO_24;
			end
			S_LO_24: begin
				select0 <= 5'd0;
				select1 <= 5'd0;
				select2 <= 5'd5;
				select3 <= 5'd5;
				//ACC_reg_0 <= multi3;
				//Up_buf[1] <= u_odd_prime_calc;

				//shift register operation U' odd
				U_odd_shift_Reg[0] <= U_odd_shift_Reg[1];
				U_odd_shift_Reg[1] <= U_odd_shift_Reg[2];
				U_odd_shift_Reg[2] <= U_odd_shift_Reg[3];
				U_odd_shift_Reg[3] <= U_odd_shift_Reg[4];
				U_odd_shift_Reg[4] <= U_odd_shift_Reg[5];
				U_odd_shift_Reg[5] <= Up_buf[1];
				//shift register operation U' even
				U_even_shift_Reg[0] <= U_even_shift_Reg[1];
				U_even_shift_Reg[1] <= U_even_shift_Reg[2];
				U_even_shift_Reg[2] <= Up_buf[1];
				m1_state<=S_LO_25;
			end
			S_LO_25: begin
				select0 <= 5'd6;
				select1 <= 5'd6;
				select2 <= 5'd6;
				select3 <= 5'd6;
				ACC_reg_1 <= multi2 + multi3;
				//Vp_buf[1] <= v_odd_prime_calc;
				// V_buf[2] <= V_buf[0];//don't need flag
				//shift register operation V' odd
				V_odd_shift_Reg[0] <= V_odd_shift_Reg[1];
				V_odd_shift_Reg[1] <= V_odd_shift_Reg[2];
				V_odd_shift_Reg[2] <= V_odd_shift_Reg[3];
				V_odd_shift_Reg[3] <= V_odd_shift_Reg[4];
				V_odd_shift_Reg[4] <= V_odd_shift_Reg[5];
				V_odd_shift_Reg[5] <= Vp_buf[1];
				//shift register operation V' even
				V_even_shift_Reg[0] <= V_even_shift_Reg[1];
				V_even_shift_Reg[1] <= V_even_shift_Reg[2];
				V_even_shift_Reg[2] <= Vp_buf[1];
				m1_state<=S_LO_26;
			end
			S_LO_26: begin
				U_buf[1] <= u_calc;//dont need flag
				V_buf[1] <= v_calc;
				m1_state<=S_LO_27;
			end
			S_LO_27: begin
				m1_state <= S_LO_28;
			end
			S_LO_28: begin
				SRAM_we_n <= 1'b0;
				SRAM_address <= SRAM_address_U;
				SRAM_address_U <= SRAM_address_U + 20'd1;
				SRAM_write_data <= {U_buf[0],U_buf[1]};
				V_buf[2] <= V_buf[0];//don't need flag
				m1_state <= S_LO_29;
			end
			S_LO_29: begin
				SRAM_we_n <= 1'b0;
				SRAM_address <= SRAM_address_V;
				SRAM_address_V <= SRAM_address_V + 20'd1;
				SRAM_write_data <= {V_buf[2],V_buf[1]};
				if(Row_counter == no_rows) begin
					m1_state <= S_IDLE_m1;
					done1 <= 1'b1;
				end else begin
					m1_state <= S_LI_0;
				end
			end

		default:m1_state<=S_IDLE_m1;
endcase
end
end

always_comb begin

//multiplier 0 
	case(select0)
	5'd1: begin m1_op1=y00;m1_op2={{24{1'b0}},SRAM_data_R[0]};end //y00*r8
	5'd2:begin m1_op1=u11;m1_op2={{24{1'b0}},SRAM_data_G[0]};end //u11*g8
	5'd3:begin m1_op1=v22;m1_op2={{24{1'b0}},SRAM_data_B[0]};end//v22*b8
	5'd4:begin m1_op1=u10;m1_op2={{24{1'b0}},SRAM_data_R[1]};end//u10*r9
	5'd5:begin m1_op1=v21;m1_op2={{24{1'b0}},SRAM_data_G[1]};end//v21*g9
	5'd6:begin m1_op1=p159;m1_op2=$signed({24'b0, U_odd_shift_Reg[2]}) + $signed({24'b0, U_odd_shift_Reg[3]});end
	default:begin m1_op1=32'd0;m1_op2=32'd0;end
	endcase
	
//multiplier 1 
	case(select1)
	5'd1:begin m1_op3=y01;m1_op4={{24{1'b0}},SRAM_data_G[0]};end//y01*g6
	5'd2:begin m1_op3=u12;m1_op4={{24{1'b0}},SRAM_data_B[0]};end//u12*b6
	5'd3:begin m1_op3=y00;m1_op4={{24{1'b0}},SRAM_data_R[1]};end//y00*r7
	5'd4:begin m1_op3=u11;m1_op4={{24{1'b0}},SRAM_data_G[1]};end//u11*g7
	5'd5:begin m1_op3=v22;m1_op4={{24{1'b0}},SRAM_data_B[1]};end //v22*b7
	5'd6:begin m1_op3=p22;m1_op4=$signed({24'b0, V_odd_shift_Reg[0]}) + $signed({24'b0, V_odd_shift_Reg[5]});end//22*(v_shift[0]+[5])
	default:begin m1_op3=32'd0;m1_op4=32'd0;end
	endcase
	
//multiplier 2 
	case(select2)
	5'd1:begin m1_op5= y02;m1_op6={{24{1'b0}},SRAM_data_B[0]};end // y02*b6
	5'd2:begin m1_op5= v20;m1_op6={{24{1'b0}},SRAM_data_R[0]};end // v20*r6
	5'd3:begin m1_op5= y01;m1_op6={{24{1'b0}},SRAM_data_G[1]};end // y01*g7
	5'd4:begin m1_op5= u12;m1_op6={{24{1'b0}},SRAM_data_B[1]};end // u12*b7
	5'd5:begin m1_op5= p22;m1_op6=$signed({24'b0, U_odd_shift_Reg[0]}) + $signed({24'b0, U_odd_shift_Reg[5]});end //22*(u_shift[0]+[5])
	5'd6:begin m1_op5= n52;m1_op6=$signed({24'b0, V_odd_shift_Reg[1]}) + $signed({24'b0, V_odd_shift_Reg[4]});end//-52*(v_shift[1]+[4])
	default:begin m1_op5=32'd0;m1_op6=32'd0;end
	endcase

//multiplier 3 
	case(select3)
	5'd1:begin m1_op7= u10;m1_op8={{24{1'b0}},SRAM_data_R[0]};end // u10*r6
	5'd2:begin m1_op7= v21;m1_op8={{24{1'b0}},SRAM_data_G[0]};end // v21*g6
	5'd3:begin m1_op7= y02;m1_op8={{24{1'b0}},SRAM_data_B[1]};end // y02*b7
	5'd4:begin m1_op7= v20;m1_op8={{24{1'b0}},SRAM_data_R[1]};end // v20*r7
	5'd5:begin m1_op7= n52;m1_op8=$signed({24'b0, U_odd_shift_Reg[1]}) + $signed({24'b0, U_odd_shift_Reg[4]});end // -52*(u_shift[1]+[4])
	5'd6:begin m1_op7= p159;m1_op8=$signed({24'b0, V_odd_shift_Reg[2]}) + $signed({24'b0, V_odd_shift_Reg[3]});end // 159*(v_shift[2]+[3])
	default:begin m1_op7=32'd0;m1_op8=32'd0;end
	endcase
end


//multiplier new
/*
assign multi0=($signed(m1_op1)*$signed(m1_op2));
assign multi1=($signed(m1_op3)*$signed(m1_op4));
assign multi2=($signed(m1_op5)*$signed(m1_op6));
assign multi3=($signed(m1_op7)*$signed(m1_op8));
*/

//sum, shift and clipping Y even 
always_comb begin
	y_even_sum = multi0 + multi1 + multi2 + p32768;
	y_even_calc_intermediate = y_even_sum>>>16;
	y_even_calc_intermediate = y_even_calc_intermediate + 16'd16;
	y_even_calc = (y_even_calc_intermediate[15]) ? 8'd0 : (|y_even_calc_intermediate[14:8]) ? 8'd255 : y_even_calc_intermediate[7:0];
end
//sum, shift and clipping Y odd 
always_comb begin
	y_odd_sum = multi1 + multi2 + multi3 + p32768;
	y_odd_calc_intermediate = y_odd_sum>>>16;
	y_odd_calc_intermediate = y_odd_calc_intermediate + 16'd16;
	y_odd_calc = (y_odd_calc_intermediate[15]) ? 8'd0 : (|y_odd_calc_intermediate[14:8]) ? 8'd255 : y_odd_calc_intermediate[7:0];
end
//sum, shift and clipping U' even 
always_comb begin
	u_even_prime_sum = multi0 + multi1 + ACC_reg_0 + p32768;
	u_even_prime_calc_intermediate = u_even_prime_sum>>>16;
	u_even_prime_calc_intermediate = u_even_prime_calc_intermediate + p128;
	u_even_prime_calc = (u_even_prime_calc_intermediate[15]) ? 8'd0 : (|u_even_prime_calc_intermediate[14:8]) ? 8'd255 : u_even_prime_calc_intermediate[7:0];
end
//sum, shift and clipping U' odd 
always_comb begin
	u_odd_prime_sum = multi0 + multi1 + multi2 + p32768;
	u_odd_prime_calc_intermediate = u_odd_prime_sum>>>16;
	u_odd_prime_calc_intermediate = u_odd_prime_calc_intermediate + p128;
	u_odd_prime_calc = (u_odd_prime_calc_intermediate[15]) ? 8'd0 : (|u_odd_prime_calc_intermediate[14:8]) ? 8'd255 : u_odd_prime_calc_intermediate[7:0];
end

//sum, shift and clipping V' even 
always_comb begin
	v_even_prime_sum = multi0 + ACC_reg_1 + p32768; //ACC_reg_1 = multi2 + multi3
	v_even_prime_calc_intermediate = v_even_prime_sum>>>16;
	v_even_prime_calc_intermediate = v_even_prime_calc_intermediate + p128;
	v_even_prime_calc = (v_even_prime_calc_intermediate[15]) ? 8'd0 : (|v_even_prime_calc_intermediate[14:8]) ? 8'd255 : v_even_prime_calc_intermediate[7:0];
end
//sum, shift and clipping V' odd 
always_comb begin
	v_odd_prime_sum = multi0 + multi1 + ACC_reg_0 + p32768; //ACC_reg_0 = multi3
	v_odd_prime_calc_intermediate = v_odd_prime_sum>>>16;
	v_odd_prime_calc_intermediate = v_odd_prime_calc_intermediate + p128;
	v_odd_prime_calc = (v_odd_prime_calc_intermediate[15]) ? 8'd0 : (|v_odd_prime_calc_intermediate[14:8]) ? 8'd255 : v_odd_prime_calc_intermediate[7:0];
end

//sum, shift and clipping U 
always_comb begin
	u_sum = multi0 + ACC_reg_1 + (({{24{1'b0}},U_even_shift_Reg[0]})<<<8) + p256; //ACC_reg_1 = multi2 + multi3
	u_calc_intermediate = u_sum>>>9;
	u_calc = (u_calc_intermediate[31]) ? 8'd0 : (|u_calc_intermediate[30:8]) ? 8'd255 : u_calc_intermediate[7:0];
end
//sum, shift and clipping V 
always_comb begin
	v_sum = multi1 + multi2 + multi3 + (({{24{1'b0}},V_even_shift_Reg[0]})<<<8) + p256; //ACC_reg_1 = multi2 + multi3
	v_calc_intermediate = v_sum>>>9;
	v_calc = (v_calc_intermediate[31]) ? 8'd0 : (|v_calc_intermediate[30:8]) ? 8'd255 : v_calc_intermediate[7:0];
end
// logic [7:0] u_calc,v_calc;{{24{1'b0}},SRAM_data_B[1]}
// logic signed [31:0] u_calc_intermediate,v_calc_intermediate;
// logic signed [31:0] u_sum,v_sum;

endmodule

