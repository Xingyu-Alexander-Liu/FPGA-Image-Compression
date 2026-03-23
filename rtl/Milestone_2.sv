
`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"

module Milestone_2 #(
		parameter int no_cols,
		parameter int no_rows
	) (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I, 		// 50 MHz clock
		input logic Resetn,
		input logic start2,
		output logic done2,
		input logic[15:0] SRAM_read_data,
		output logic[19:0] SRAM_address,
		output logic[15:0]SRAM_write_data,
		output logic SRAM_we_n,
		output logic signed [31:0] m2_op1,
		output logic signed [31:0] m2_op2,
		output logic signed [31:0] m2_op3,
		output logic signed [31:0] m2_op4,
		output logic signed [31:0] m2_op5,
		output logic signed [31:0] m2_op6,
		output logic signed [31:0] m2_op7,
		output logic signed [31:0] m2_op8,
		input logic signed [31:0] multi0,
		input logic signed [31:0] multi1,
		input logic signed [31:0] multi2,
		input logic signed [31:0] multi3

);
/*
sram address management location: 
fetch s: 
S_MEGA_FS_CSP_CC_7

write s': 
S_MEGA_WSP_CT_LO_4
S_WSP_LO_4 
using this: (640x480 only)SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
instead of this: (any size images) SRAM_address <= sram_fs_addr_offset + {3'd0, rb_s, sc_s[4:2], 8'd0} + {5'd0, rb_s, sc_s[4:2], 6'd0} + {11'd0, cb_s, sc_s[1:0]};
*/
milestone2_state_type m2_state;
localparam int MAX_CB_Y  = (no_cols / 8) - 1;  
localparam int MAX_CB_UV = (no_cols / 16) - 1; 
localparam int MAX_RB    = (no_rows / 8) - 1; 
//(Row Stride)
localparam int Y_FS_STRIDE   = no_cols / 2; // Fetch S y
localparam int UV_FS_STRIDE  = no_cols / 4; // Fetch S u/v
localparam int Y_WSP_STRIDE  = no_cols;     // Write S' y
localparam int UV_WSP_STRIDE = no_cols / 2; // Write S' u/v
//sc_s[4:2] - ri; sc_s[1:0] - ci; sc_sp_dp0 [5:3] - ri; sc_sp_dp0 [2:0] - ci; cb_s - block index (column); rb_s - block index (row)
logic [4:0] sc_s; logic [5:0] sc_sp_dp0,sc_sp_sram,sc_t; logic [6:0] cb_s,cb_sp; logic [5:0] rb_s,rb_sp;
//lead in fs variable
logic [15:0] fs_buf;
logic [6:0] LI_FS_addr_a0_cnt,addr_a1_T_cnt;
logic [7:0] s0_reg_0,s1_reg_0,s2_reg_0,s3_reg_0,s4_reg_0,s5_reg_0,s6_reg_0,s7_reg_0;
logic [7:0] s0_reg_1,s1_reg_1,s2_reg_1,s3_reg_1,s4_reg_1,s5_reg_1,s6_reg_1,s7_reg_1;
logic signed [31:0] t0_reg_0,t1_reg_0,t2_reg_0,t3_reg_0,t4_reg_0,t5_reg_0,t6_reg_0,t7_reg_0;
logic signed [31:0] t0_reg_1,t1_reg_1,t2_reg_1,t3_reg_1,t4_reg_1,t5_reg_1,t6_reg_1,t7_reg_1;
logic signed [31:0] ACC_reg_0;
logic FS_CSP_flag,WSP_CT_flag,finish_mega_flag;
//multi
logic[4:0] select0;
logic[4:0] select1;
logic[4:0] select2;
logic[4:0] select3;
logic signed [31:0] reg_0_multi,reg_1_multi,reg_2_multi,reg_3_multi;
logic signed [31:0] C_matrix [3:0];
logic [4:0] c_idx [3:0];
/*
addr = {2'd0, ({rb_s,SC[5:3]}<<9)}+{4'd0, ({rb_s, SC[5:3]}<<7)}+{10'd0, cb_s, SC[2:0]}
fetch s (y) addr = 20'd614400 + {3'd0, ({rb_s,SC[4:2]}<<8)}+{5'd0, ({rb_s, SC[4:2]}<<6)}+{11'd0, cb_s, SC[1:0]}
fetch s (u) addr = 20'd768000 + {4'd0, ({rb_s,SC[4:2]}<<7)}+{6'd0, ({rb_s, SC[4:2]}<<5)}+{11'd0, cb_s, SC[1:0]}
fetch s (v) addr = 20'd844800 + {4'd0, ({rb_s,SC[4:2]}<<7)}+{6'd0, ({rb_s, SC[4:2]}<<5)}+{11'd0, cb_s, SC[1:0]}
*/

logic [6:0] address_a[1:0];
logic [6:0] address_b[1:0];
logic [31:0] write_data_a [1:0];
logic [31:0] write_data_b [1:0];
logic write_enable_a [1:0];
logic write_enable_b [1:0];
logic [31:0] read_data_a [1:0];
logic [31:0] read_data_b [1:0];
//dpram 0 store s (from fetch s) and s' (from compute s')
dual_port_RAM0 RAM_inst0 (
	.address_a ( address_a[0] ),
	.address_b ( address_b[0] ),
	.clock ( CLOCK_50_I ),
	.data_a ( write_data_a[0] ),
	.data_b ( write_data_b[0] ),
	.wren_a ( write_enable_a[0] ),
	.wren_b ( write_enable_b[0] ),
	.q_a ( read_data_a[0] ),
	.q_b ( read_data_b[0] )
	);

//dpram1 store t from compute t
dual_port_RAM1 RAM_inst1 (
	.address_a ( address_a[1] ),
	.address_b ( address_b[1] ),
	.clock ( CLOCK_50_I ),
	.data_a ( write_data_a[1] ),
	.data_b ( write_data_b[1] ),
	.wren_a ( write_enable_a[1] ),
	.wren_b ( write_enable_b[1] ),
	.q_a ( read_data_a[1] ),
	.q_b ( read_data_b[1] )
	);

logic [19:0] sram_fs_addr_offset,sram_wsp_addr_offset;
logic [1:0]sram_fs_offset_flag,sram_wsp_offset_flag; 
parameter Y_OFFSET = 20'd614400,
		  U_OFFSET = 20'd768000,
		  V_OFFSET = 20'd844800,   
          Y_POST_OFFSET = 20'd0,
          U_POST_OFFSET = 20'd307200,
          V_POST_OFFSET = 20'd460800;
always_comb begin
    case(sram_fs_offset_flag)
        2'd0 : sram_fs_addr_offset = Y_OFFSET;
        2'd1 : sram_fs_addr_offset = U_OFFSET;
        2'd2 : sram_fs_addr_offset = V_OFFSET;
    endcase
    case(sram_wsp_offset_flag)
        2'd0 : sram_wsp_addr_offset = Y_POST_OFFSET;
        2'd1 : sram_wsp_addr_offset = U_POST_OFFSET;
        2'd2 : sram_wsp_addr_offset = V_POST_OFFSET;
    endcase
end

always_ff @ (posedge CLOCK_50_I or negedge Resetn) begin
	if (Resetn == 1'b0) begin
        sc_s <= 5'd0;
        sc_sp_dp0 <= 6'd0;
        sc_sp_sram <= 6'd0;
        rb_s <= 6'd0;
        rb_sp <= 6'd0;
        cb_s <= 7'd0;
        cb_sp <= 7'd0;
        address_a[0] <= 7'd0;
        address_b[0] <= 7'd0;
        address_a[1] <= 7'd0;
        address_b[1] <= 7'd0;
        write_data_a[0] <= 32'd0;
        write_data_b[0] <= 32'd0;
        write_data_a[1] <= 32'd0;
        write_data_b[1] <= 32'd0;
        write_enable_a[0] <= 1'b0;
        write_enable_b[0] <= 1'b0;
        write_enable_a[1] <= 1'b0;
        write_enable_b[1] <= 1'b0;
        SRAM_we_n <= 1'b1;
        done2 <= 1'b0;
        SRAM_address <= 20'd0;
        SRAM_write_data <= 16'd0;
        sram_fs_offset_flag <= 2'd0;
        sram_wsp_offset_flag <= 2'd0;
        fs_buf <= 16'd0;
        LI_FS_addr_a0_cnt <= 7'd0;
        addr_a1_T_cnt <= 7'd0;
		select0 <= 5'd0;
		select1 <= 5'd0;
		select2 <= 5'd0;
		select3 <= 5'd0;
        reg_0_multi <= 32'd0;
        reg_1_multi <= 32'd0;
        reg_2_multi <= 32'd0;
        reg_3_multi <= 32'd0;
        s0_reg_0 <= 8'd0;
        s1_reg_0 <= 8'd0;
        s2_reg_0 <= 8'd0;
        s3_reg_0 <= 8'd0;
        s4_reg_0 <= 8'd0;
        s5_reg_0 <= 8'd0;
        s6_reg_0 <= 8'd0;
        s7_reg_0 <= 8'd0;
        s0_reg_1 <= 8'd0;
        s1_reg_1 <= 8'd0;
        s2_reg_1 <= 8'd0;
        s3_reg_1 <= 8'd0;
        s4_reg_1 <= 8'd0;
        s5_reg_1 <= 8'd0;
        s6_reg_1 <= 8'd0;
        s7_reg_1 <= 8'd0;
        t0_reg_0 <= 32'd0;
        t1_reg_0 <= 32'd0;
        t2_reg_0 <= 32'd0;
        t3_reg_0 <= 32'd0;
        t4_reg_0 <= 32'd0;
        t5_reg_0 <= 32'd0;
        t6_reg_0 <= 32'd0;
        t7_reg_0 <= 32'd0;
        t0_reg_1 <= 32'd0;
        t1_reg_1 <= 32'd0;
        t2_reg_1 <= 32'd0;
        t3_reg_1 <= 32'd0;
        t4_reg_1 <= 32'd0;
        t5_reg_1 <= 32'd0;
        t6_reg_1 <= 32'd0;
        t7_reg_1 <= 32'd0;
        c_idx[0] <= 5'd0;
        c_idx[1] <= 5'd0;
        c_idx[2] <= 5'd0;
        c_idx[3] <= 5'd0;
        ACC_reg_0 <= 32'd0;
        sc_t <= 6'd0;
        FS_CSP_flag <= 1'b0;
        WSP_CT_flag <= 1'b0;
        finish_mega_flag <= 1'b0;
	end else begin
		case(m2_state)
		
			S_IDLE_m2:begin
                if ((start2 == 1'b1) && (done2 == 1'b0)) m2_state<=S_FS_LI_0;
            end
            S_FS_LI_0: begin
                SRAM_we_n <= 1'b1;
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end
                sc_s <= sc_s + 5'd1;
                m2_state <= S_FS_LI_1;
            end
            S_FS_LI_1: begin
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end
                sc_s <= sc_s + 5'd1;
                m2_state <= S_FS_LI_2;                
            end
            S_FS_LI_2: begin
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end
                sc_s <= sc_s + 5'd1;
                m2_state <= S_FS_CC_0;                
            end
            S_FS_CC_0: begin
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end
                sc_s <= sc_s + 5'd1;  
                fs_buf <= SRAM_read_data;
                write_enable_a[0] <= 1'b0;
                m2_state <= S_FS_CC_1;          
            end
            S_FS_CC_1: begin
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end
                sc_s <= sc_s + 5'd1;  
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= LI_FS_addr_a0_cnt + 7'd1;
                write_data_a[0] <= {fs_buf,SRAM_read_data};
                write_enable_a[0] <= 1'b1;
                if(sc_s == 5'd30) begin
                    m2_state <= S_FS_LO_0;
                end else begin
                    m2_state <= S_FS_CC_0;   
                end        
            end
            S_FS_LO_0: begin
                //read the (ri,ci) = (7,7) element of the first block from sram
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end
                sc_s <= sc_s + 5'd1;  //31 + 1 = 0
                if(sc_s == 5'd31) cb_s <= cb_s + 7'd1;
                fs_buf <= SRAM_read_data;
                write_enable_a[0] <= 1'b0;          
                m2_state <= S_FS_LO_1;      
            end
            S_FS_LO_1: begin
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= LI_FS_addr_a0_cnt + 7'd1;
                write_data_a[0] <= {fs_buf,SRAM_read_data};
                write_enable_a[0] <= 1'b1;   
                m2_state <= S_FS_LO_2;             
            end
            S_FS_LO_2: begin
                fs_buf <= SRAM_read_data;
                write_enable_a[0] <= 1'b0;   
                m2_state <= S_FS_LO_3;             
            end
            S_FS_LO_3: begin
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= 7'd0;
                write_data_a[0] <= {fs_buf,SRAM_read_data};
                write_enable_a[0] <= 1'b1;       
                m2_state <= S_CT_LI_0;
                addr_a1_T_cnt <= 7'd0;//initialize the dpram1 address counter          
            end
////////////////////////////////////////////////Lead in Ct///////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            S_CT_LI_0: begin
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= LI_FS_addr_a0_cnt + 7'd1; 
                write_enable_a[0] <= 1'b0;     
                write_enable_a[1] <= 1'b0;
                m2_state <= S_CT_LI_1;          
            end
            S_CT_LI_1: begin
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= LI_FS_addr_a0_cnt + 7'd1;    
                m2_state <= S_CT_LI_2;             
            end
            S_CT_LI_2: begin
                s0_reg_0 <= read_data_a[0][31:24];
                s1_reg_0 <= read_data_a[0][23:16];
                s2_reg_0 <= read_data_a[0][15:8];
                s3_reg_0 <= read_data_a[0][7:0];
                m2_state <= S_CT_LI_3;
            end
            S_CT_LI_3: begin
                select0 <= 5'd1;
                select1 <= 5'd1;
                select2 <= 5'd1;
                select3 <= 5'd1;                    
                c_idx[0] <= 5'd0;
                c_idx[1] <= 5'd1;
                c_idx[2] <= 5'd2;
                c_idx[3] <= 5'd3;
                s4_reg_0 <= read_data_a[0][31:24];
                s5_reg_0 <= read_data_a[0][23:16];
                s6_reg_0 <= read_data_a[0][15:8];
                s7_reg_0 <= read_data_a[0][7:0];
                m2_state <= S_CT_LI_4;                
            end
            S_CT_LI_4: begin
                select0 <= 5'd2;
                select1 <= 5'd2;
                select2 <= 5'd2;
                select3 <= 5'd2;                   
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;
                m2_state <= S_CT_LI_5;
            end
            S_CT_LI_5: begin
                select0 <= 5'd1;
                select1 <= 5'd1;
                select2 <= 5'd1;
                select3 <= 5'd1;  
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;
                ACC_reg_0 <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128;
                m2_state <= S_CT_CC_0;
            end
            S_CT_CC_0: begin
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;
                if(select0 == 5'd1) begin
                    select0 <= 5'd2;
                    select1 <= 5'd2;
                    select2 <= 5'd2;
                    select3 <= 5'd2;                    
                end else begin
                    select0 <= 5'd1;
                    select1 <= 5'd1;
                    select2 <= 5'd1;
                    select3 <= 5'd1;                    
                end
                write_enable_a[1] <= 1'b1;
                write_data_a[1] <= { {16{ACC_reg_0[23]}}, ACC_reg_0[23:8] };//32 bits T -> right shift by 8 bits -> 24 bits T ->
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                ACC_reg_0 <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128;
                if(c_idx[0] == 5'd28) begin
                    m2_state <= S_CT_LO_0;
                end                 
            end
            S_CT_LO_0: begin
                write_enable_a[1] <= 1'b1;
                write_data_a[1] <= { {16{ACC_reg_0[23]}}, ACC_reg_0[23:8] };
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;
                ACC_reg_0 <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128;
                m2_state <= S_CT_LO_1;        
            end
            S_CT_LO_1: begin
                write_enable_a[1] <= 1'b1;
                write_data_a[1] <= { {16{ACC_reg_0[23]}}, ACC_reg_0[23:8] };
                address_a[1] <= addr_a1_T_cnt;
                if(address_a[0] == 7'd15) begin
                    m2_state <= S_MEGA_FS_CSP_LI_0;
                    addr_a1_T_cnt <= 7'd0;
                end else begin
                    m2_state <= S_CT_LI_0;
                    addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;
                end                
            end
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////fetch s & compute s'///////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

            S_MEGA_FS_CSP_LI_0: begin
                //no fetch s
                SRAM_we_n <= 1'b1;
                //compute s'
                sc_t <= sc_t + 6'd2;
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                write_enable_a[1] <= 1'b0;
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]};
                write_enable_b[1] <= 1'b0;
                m2_state <= S_MEGA_FS_CSP_LI_1;
            end
            S_MEGA_FS_CSP_LI_1: begin
                //no fetch s
                //compute s'
                sc_t <= sc_t + 6'd2;
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]};
                m2_state <= S_MEGA_FS_CSP_LI_2;              
            end
            S_MEGA_FS_CSP_LI_2: begin
                //fetch s
                SRAM_we_n <= 1'b1;
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end                sc_s <= sc_s + 5'd1; 
                //compute s'
                sc_t <= sc_t + 6'd2;
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]};                
                t0_reg_0 <= read_data_a[1];
                t1_reg_0 <= read_data_b[1];
                m2_state <= S_MEGA_FS_CSP_LI_3;
            end
            S_MEGA_FS_CSP_LI_3: begin
                //fetch s
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end                sc_s <= sc_s + 5'd1;   
                //compute s'
                sc_t <= sc_t + 6'd2;
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]};          
                t2_reg_0 <= read_data_a[1];
                t3_reg_0 <= read_data_b[1];     
                m2_state <= S_MEGA_FS_CSP_LI_4;       
            end
            S_MEGA_FS_CSP_LI_4: begin
                //fetch s
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end
                sc_s <= sc_s + 5'd1; 
                //compute s'
                t4_reg_0 <= read_data_a[1];
                t5_reg_0 <= read_data_b[1];    
                select0 <= 5'd3;
                select1 <= 5'd3;
                select2 <= 5'd3;
                select3 <= 5'd3;
                c_idx[0] <= 5'd0;
                c_idx[1] <= 5'd1;
                c_idx[2] <= 5'd2;
                c_idx[3] <= 5'd3;
                m2_state <= S_MEGA_FS_CSP_LI_5;
            end
            S_MEGA_FS_CSP_LI_5: begin
                //fs
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end
                sc_s <= sc_s + 5'd1;  
                fs_buf <= SRAM_read_data;
                write_enable_a[0] <= 1'b0;
                //compute s'
                t6_reg_0 <= read_data_a[1];
                t7_reg_0 <= read_data_b[1];   
                FS_CSP_flag <= 1'b0;
                select0 <= 5'd5;
                select1 <= 5'd5;
                select2 <= 5'd5;
                select3 <= 5'd5;
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4;       
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                sc_sp_dp0 <= 6'd0;//init
                LI_FS_addr_a0_cnt <= 7'd0;//init
                m2_state <= S_MEGA_FS_CSP_CC_0;                      
            end
            S_MEGA_FS_CSP_CC_0: begin
                //fs
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= LI_FS_addr_a0_cnt + 7'd1;
                write_data_a[0] <= {fs_buf,SRAM_read_data};
                write_enable_a[0] <= 1'b1;

                //compute s'
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //dpram1
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]}; 
                sc_t <= sc_t + 6'd2;
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_MEGA_FS_CSP_CC_1;                
            end
            S_MEGA_FS_CSP_CC_1: begin
                //fs
                fs_buf <= SRAM_read_data;
                write_enable_a[0] <= 1'b0;
                //compute s'
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //dpram1
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]}; 
                sc_t <= sc_t + 6'd2;
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_MEGA_FS_CSP_CC_2;
            end
            S_MEGA_FS_CSP_CC_2: begin
                //fs
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= LI_FS_addr_a0_cnt + 7'd1;
                write_data_a[0] <= {fs_buf,SRAM_read_data};
                write_enable_a[0] <= 1'b1;
                //compute s'
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //dpram1
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]}; 
                sc_t <= sc_t + 6'd2;
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                    t0_reg_1 <= read_data_a[1];
                    t1_reg_1 <= read_data_b[1];
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                    t0_reg_0 <= read_data_a[1];
                    t1_reg_0 <= read_data_b[1];
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;
                m2_state <= S_MEGA_FS_CSP_CC_3;              
            end
            S_MEGA_FS_CSP_CC_3: begin
                //no fs
                write_enable_a[0] <= 1'b0;

                //compute s'
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //dpram1
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]}; 
                sc_t <= sc_t + 6'd2;
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                    t2_reg_1 <= read_data_a[1];
                    t3_reg_1 <= read_data_b[1];
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                    t2_reg_0 <= read_data_a[1];
                    t3_reg_0 <= read_data_b[1];
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;
                m2_state <= S_MEGA_FS_CSP_CC_4;             
            end
            S_MEGA_FS_CSP_CC_4: begin
                //fetch s
                SRAM_we_n <= 1'b1;
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end
                sc_s <= sc_s + 5'd1;  

                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                    t4_reg_1 <= read_data_a[1];
                    t5_reg_1 <= read_data_b[1];
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                    t4_reg_0 <= read_data_a[1];
                    t5_reg_0 <= read_data_b[1];
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_MEGA_FS_CSP_CC_5;             
            end
            S_MEGA_FS_CSP_CC_5: begin
                //fetch s
                SRAM_we_n <= 1'b1;
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end
                sc_s <= sc_s + 5'd1;    

                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                FS_CSP_flag <= ~FS_CSP_flag;
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                    t6_reg_1 <= read_data_a[1];
                    t7_reg_1 <= read_data_b[1];
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                    t6_reg_0 <= read_data_a[1];
                    t7_reg_0 <= read_data_b[1];
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_MEGA_FS_CSP_CC_6;             
            end
            S_MEGA_FS_CSP_CC_6: begin
                //fetch s
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end
                sc_s <= sc_s + 5'd1;      

                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;
                m2_state <= S_MEGA_FS_CSP_CC_7;            
            end
            S_MEGA_FS_CSP_CC_7: begin
                //fs
                if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * Y_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
                    SRAM_address <= sram_fs_addr_offset + ({11'd0, rb_s, sc_s[4:2]} * UV_FS_STRIDE) + {11'd0, cb_s, sc_s[1:0]};
                end
                sc_s <= sc_s + 5'd1;  
                fs_buf <= SRAM_read_data;
                write_enable_a[0] <= 1'b0;         
                //fetch s sram location management
                if(sram_fs_offset_flag == 2'd0) begin 
                    // FSM is fetching Y value from SRAM
                    if (sc_s == 5'd31) begin
                        if (cb_s == MAX_CB_Y) begin
                            cb_s <= 7'd0;             
                            if (rb_s == MAX_RB) begin
                                rb_s <= 6'd0;            
                                sram_fs_offset_flag <= 2'd1; 
                            end else begin
                                rb_s <= rb_s + 6'd1;    
                            end
                        end else begin
                            cb_s <= cb_s + 7'd1;    
                        end
                    end

                end else if(sram_fs_offset_flag == 2'd1) begin 
                    // FSM is fetching U value from SRAM
                    if (sc_s == 5'd31) begin
                        if (cb_s == MAX_CB_UV) begin       
                            cb_s <= 7'd0;             
                            if (rb_s == MAX_RB) begin
                                rb_s <= 6'd0;           
                                sram_fs_offset_flag <= 2'd2;
                            end else begin
                                rb_s <= rb_s + 6'd1;
                            end
                        end else begin
                            cb_s <= cb_s + 7'd1;         
                        end
                    end

                end else if(sram_fs_offset_flag == 2'd2) begin 
                    // FSM is fetching V value from SRAM
                    if (sc_s == 5'd31) begin
                        if (cb_s == MAX_CB_UV) begin     
                            cb_s <= 7'd0;              
                            if (rb_s == MAX_RB) begin
                                rb_s <= 6'd0;            
                                sram_fs_offset_flag <= 2'd0; 
                                finish_mega_flag <= 1'b1;     
                            end else begin
                                rb_s <= rb_s + 6'd1;   
                            end
                        end else begin
                            cb_s <= cb_s + 7'd1;         
                        end
                    end        
                end                

                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;
                if((sc_sp_dp0 == 6'd55) && (sc_s == 5'd31)) begin
                    m2_state <= S_MEGA_FS_CSP_LO_0;
                end else begin
                    m2_state <= S_MEGA_FS_CSP_CC_0;
                end
            end
            S_MEGA_FS_CSP_LO_0: begin
                //fs
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= LI_FS_addr_a0_cnt + 7'd1;
                write_data_a[0] <= {fs_buf,SRAM_read_data};
                write_enable_a[0] <= 1'b1;    

                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_MEGA_FS_CSP_LO_1;          
            end
            S_MEGA_FS_CSP_LO_1: begin
                //fs
                fs_buf <= SRAM_read_data;
                write_enable_a[0] <= 1'b0; 

                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_MEGA_FS_CSP_LO_2;                 
            end
            S_MEGA_FS_CSP_LO_2: begin
                //fs
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= 7'd0;
                write_data_a[0] <= {fs_buf,SRAM_read_data};
                write_enable_a[0] <= 1'b1; 

                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_MEGA_FS_CSP_LO_3;                   
            end
            S_MEGA_FS_CSP_LO_3: begin
                //no fs 
                write_enable_a[0] <= 1'b0;

                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_MEGA_FS_CSP_LO_4; 
            end
            S_MEGA_FS_CSP_LO_4: begin
                // no fs
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_MEGA_FS_CSP_LO_5; 
            end
            S_MEGA_FS_CSP_LO_5: begin
                // no fs
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_MEGA_FS_CSP_LO_6;                 
            end
            S_MEGA_FS_CSP_LO_6: begin
                // no fs
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_MEGA_FS_CSP_LO_7;                 
            end
            S_MEGA_FS_CSP_LO_7: begin
                // no fs
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //no multi operation
                m2_state <= S_MEGA_WSP_CT_LI_0;                 
            end
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////write s' & compute T///////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
            S_MEGA_WSP_CT_LI_0: begin
                write_enable_b[0] <= 1'b0;//finalize the mefa fs/csp states.
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= 6'd1;

                //compute T (block n+1)
                //ct dp0
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= LI_FS_addr_a0_cnt + 7'd1; 
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b0;
                //ct multi no operation  
                m2_state <= S_MEGA_WSP_CT_LI_1;
            end
            S_MEGA_WSP_CT_LI_1: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= LI_FS_addr_a0_cnt + 7'd1; 
                write_enable_a[0] <= 1'b0; 
                //ct multi & dp1 no operation  
                m2_state <= S_MEGA_WSP_CT_LI_2;               
            end
            S_MEGA_WSP_CT_LI_2: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0 dp1 multi no operation
                write_enable_a[0] <= 1'b0; 
                //ct s0123 reg
                s0_reg_0 <= read_data_a[0][31:24];
                s1_reg_0 <= read_data_a[0][23:16];
                s2_reg_0 <= read_data_a[0][15:8];
                s3_reg_0 <= read_data_a[0][7:0];
                m2_state <= S_MEGA_WSP_CT_LI_3;               
            end       
            S_MEGA_WSP_CT_LI_3: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1)
                //ct dp0 dp1 no operation
                write_enable_a[0] <= 1'b0; 
                //ct s0123 reg
                s4_reg_0 <= read_data_a[0][31:24];
                s5_reg_0 <= read_data_a[0][23:16];
                s6_reg_0 <= read_data_a[0][15:8];
                s7_reg_0 <= read_data_a[0][7:0]; 
                //ct multi
                select0 <= 5'd1;
                select1 <= 5'd1;
                select2 <= 5'd1;
                select3 <= 5'd1;
                c_idx[0] <= 5'd0;
                c_idx[1] <= 5'd1;
                c_idx[2] <= 5'd2;
                c_idx[3] <= 5'd3;
                m2_state <= S_MEGA_WSP_CT_LI_4;               
            end     
            S_MEGA_WSP_CT_LI_4: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0 dp1 reg no operation
                write_enable_a[0] <= 1'b0; 
                //ct multi
                select0 <= 5'd2;
                select1 <= 5'd2;
                select2 <= 5'd2;
                select3 <= 5'd2;                   
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;
                WSP_CT_flag <= 1'b0;//initialize flag
                m2_state <= S_MEGA_WSP_CT_CC_0;               
            end
            S_MEGA_WSP_CT_CC_0: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= LI_FS_addr_a0_cnt + 7'd1; 
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd1;
                    select1 <= 5'd1;
                    select2 <= 5'd1;
                    select3 <= 5'd1;                  
                end else begin //flag == 1
                    select0 <= 5'd8;
                    select1 <= 5'd8;
                    select2 <= 5'd8;
                    select3 <= 5'd8;                    
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;               
                m2_state <= S_MEGA_WSP_CT_CC_1;               
            end
            S_MEGA_WSP_CT_CC_1: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0
                address_a[0] <= LI_FS_addr_a0_cnt;
                LI_FS_addr_a0_cnt <= LI_FS_addr_a0_cnt + 7'd1; 
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd2;
                    select1 <= 5'd2;
                    select2 <= 5'd2;
                    select3 <= 5'd2;                  
                end else begin //flag == 1
                    select0 <= 5'd9;
                    select1 <= 5'd9;
                    select2 <= 5'd9;
                    select3 <= 5'd9;                    
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;               

                m2_state <= S_MEGA_WSP_CT_CC_2;               
            end
            S_MEGA_WSP_CT_CC_2: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd1;
                    select1 <= 5'd1;
                    select2 <= 5'd1;
                    select3 <= 5'd1;  
                    s0_reg_1 <= read_data_a[0][31:24];
                    s1_reg_1 <= read_data_a[0][23:16];
                    s2_reg_1 <= read_data_a[0][15:8];
                    s3_reg_1 <= read_data_a[0][7:0];                
                end else begin //flag == 1
                    select0 <= 5'd8;
                    select1 <= 5'd8;
                    select2 <= 5'd8;
                    select3 <= 5'd8;
                    s0_reg_0 <= read_data_a[0][31:24];
                    s1_reg_0 <= read_data_a[0][23:16];
                    s2_reg_0 <= read_data_a[0][15:8];
                    s3_reg_0 <= read_data_a[0][7:0];                    
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3; 
                m2_state <= S_MEGA_WSP_CT_CC_3;               
            end
            S_MEGA_WSP_CT_CC_3: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd2;
                    select1 <= 5'd2;
                    select2 <= 5'd2;
                    select3 <= 5'd2;
                    s4_reg_1 <= read_data_a[0][31:24];
                    s5_reg_1 <= read_data_a[0][23:16];
                    s6_reg_1 <= read_data_a[0][15:8];
                    s7_reg_1 <= read_data_a[0][7:0];                   
                end else begin //flag == 1
                    select0 <= 5'd9;
                    select1 <= 5'd9;
                    select2 <= 5'd9;
                    select3 <= 5'd9; 
                    s4_reg_0 <= read_data_a[0][31:24];
                    s5_reg_0 <= read_data_a[0][23:16];
                    s6_reg_0 <= read_data_a[0][15:8];
                    s7_reg_0 <= read_data_a[0][7:0];                    
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;               

                m2_state <= S_MEGA_WSP_CT_CC_4;               
            end
            S_MEGA_WSP_CT_CC_4: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd1;
                    select1 <= 5'd1;
                    select2 <= 5'd1;
                    select3 <= 5'd1;                 
                end else begin //flag == 1
                    select0 <= 5'd8;
                    select1 <= 5'd8;
                    select2 <= 5'd8;
                    select3 <= 5'd8;                   
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3; 
                m2_state <= S_MEGA_WSP_CT_CC_5;               
            end
            S_MEGA_WSP_CT_CC_5: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                WSP_CT_flag <= ~WSP_CT_flag;
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd2;
                    select1 <= 5'd2;
                    select2 <= 5'd2;
                    select3 <= 5'd2;                 
                end else begin //flag == 1
                    select0 <= 5'd9;
                    select1 <= 5'd9;
                    select2 <= 5'd9;
                    select3 <= 5'd9;                    
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3; 
                m2_state <= S_MEGA_WSP_CT_CC_6;               
            end
            S_MEGA_WSP_CT_CC_6: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd1;
                    select1 <= 5'd1;
                    select2 <= 5'd1;
                    select3 <= 5'd1;                 
                end else begin //flag == 1
                    select0 <= 5'd8;
                    select1 <= 5'd8;
                    select2 <= 5'd8;
                    select3 <= 5'd8;                   
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3; 
                m2_state <= S_MEGA_WSP_CT_CC_7;               
            end
            S_MEGA_WSP_CT_CC_7: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd2;
                    select1 <= 5'd2;
                    select2 <= 5'd2;
                    select3 <= 5'd2;                 
                end else begin //flag == 1
                    select0 <= 5'd9;
                    select1 <= 5'd9;
                    select2 <= 5'd9;
                    select3 <= 5'd9;                    
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3; 
                if (sc_sp_dp0 == 6'd60) begin
                    m2_state <= S_MEGA_WSP_CT_LO_0;      
                end else begin
                    m2_state <= S_MEGA_WSP_CT_CC_0;
                end         
            end
            S_MEGA_WSP_CT_LO_0: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd1;
                    select1 <= 5'd1;
                    select2 <= 5'd1;
                    select3 <= 5'd1;                 
                end else begin //flag == 1
                    select0 <= 5'd8;
                    select1 <= 5'd8;
                    select2 <= 5'd8;
                    select3 <= 5'd8;                   
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3; 
                m2_state <= S_MEGA_WSP_CT_LO_1;               
            end
            S_MEGA_WSP_CT_LO_1: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd2;
                    select1 <= 5'd2;
                    select2 <= 5'd2;
                    select3 <= 5'd2;                 
                end else begin //flag == 1
                    select0 <= 5'd9;
                    select1 <= 5'd9;
                    select2 <= 5'd9;
                    select3 <= 5'd9;                    
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3; 
 
                m2_state <= S_MEGA_WSP_CT_LO_2;               
            end
            S_MEGA_WSP_CT_LO_2: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd1;
                    select1 <= 5'd1;
                    select2 <= 5'd1;
                    select3 <= 5'd1;                 
                end else begin //flag == 1
                    select0 <= 5'd8;
                    select1 <= 5'd8;
                    select2 <= 5'd8;
                    select3 <= 5'd8;                   
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3; 

                m2_state <= S_MEGA_WSP_CT_LO_3;               
            end
            S_MEGA_WSP_CT_LO_3: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                // no ws' dp0 operation

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd2;
                    select1 <= 5'd2;
                    select2 <= 5'd2;
                    select3 <= 5'd2;                 
                end else begin //flag == 1
                    select0 <= 5'd9;
                    select1 <= 5'd9;
                    select2 <= 5'd9;
                    select3 <= 5'd9;                    
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3; 
 
                m2_state <= S_MEGA_WSP_CT_LO_4;               
            end
            S_MEGA_WSP_CT_LO_4: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                // no ws' dp0 operation

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd1;
                    select1 <= 5'd1;
                    select2 <= 5'd1;
                    select3 <= 5'd1;                 
                end else begin //flag == 1
                    select0 <= 5'd8;
                    select1 <= 5'd8;
                    select2 <= 5'd8;
                    select3 <= 5'd8;                   
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3; 

                //write s' sram address management
                if(sram_wsp_offset_flag == 2'd0) begin 
                    // FSM is fetching Y value from SRAM
                    if (sc_sp_sram == 6'd63) begin
                        if (cb_sp == MAX_CB_Y) begin
                            cb_sp <= 7'd0;                
                            if (rb_sp == MAX_RB) begin
                                rb_sp <= 6'd0;            
                                sram_wsp_offset_flag <= 2'd1;
                            end else begin
                                rb_sp <= rb_sp + 6'd1;      
                            end
                        end else begin
                            cb_sp <= cb_sp + 7'd1;         
                        end
                    end

                end else if(sram_wsp_offset_flag == 2'd1) begin 
                    // FSM is fetching U value from SRAM
                    if (sc_sp_sram == 6'd63) begin
                        if (cb_sp == MAX_CB_UV) begin          
                            cb_sp <= 7'd0;                 
                            if (rb_sp == MAX_RB) begin
                                rb_sp <= 6'd0;            
                                sram_wsp_offset_flag <= 2'd2;
                            end else begin
                                rb_sp <= rb_sp + 6'd1;    
                            end
                        end else begin
                            cb_sp <= cb_sp + 7'd1;        
                        end
                    end

                end else if(sram_wsp_offset_flag == 2'd2) begin 
                    // FSM is fetching V value from SRAM
                    if (sc_sp_sram == 6'd63) begin
                        if (cb_sp == MAX_CB_UV) begin         
                            cb_sp <= 7'd0;              
                            if (rb_sp == MAX_RB) begin
                                rb_sp <= 6'd0;            
                                sram_wsp_offset_flag <= 2'd0; 
                                //finish_mega_flag <= 1'b1;    
                            end else begin
                                rb_sp <= rb_sp + 6'd1;   
                            end
                        end else begin
                            cb_sp <= cb_sp + 7'd1;      
                        end
                    end        
                end  
                m2_state <= S_MEGA_WSP_CT_LO_5;               
            end
            S_MEGA_WSP_CT_LO_5: begin
                //no write s' (block n) operation
                SRAM_we_n <= 1'b1;

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                if(WSP_CT_flag == 1'b0) begin
                    select0 <= 5'd2;
                    select1 <= 5'd2;
                    select2 <= 5'd2;
                    select3 <= 5'd2;                 
                end else begin //flag == 1
                    select0 <= 5'd9;
                    select1 <= 5'd9;
                    select2 <= 5'd9;
                    select3 <= 5'd9;                    
                end 
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3; 
 
                m2_state <= S_MEGA_WSP_CT_LO_6;               
            end
            S_MEGA_WSP_CT_LO_6: begin
                //no write s' (block n) operation
                SRAM_we_n <= 1'b1;

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= addr_a1_T_cnt + 7'd1;   
                //ct multi
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3; 
 
                m2_state <= S_MEGA_WSP_CT_LO_7;               
            end
            S_MEGA_WSP_CT_LO_7: begin
                //no write s' (block n) operation
                SRAM_we_n <= 1'b1;

                //compute T (block n+1) 
                //ct dp0 no operation
                write_enable_a[0] <= 1'b0;  
                //ct dp1   
                write_enable_a[1] <= 1'b1;   
                write_data_a[1] <= (reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd128)>>>8; 
                address_a[1] <= addr_a1_T_cnt;
                addr_a1_T_cnt <= 7'd0;   
                //ct multi no operation

                if(finish_mega_flag == 1'b1) begin
                    m2_state <= S_CSP_LI_0;
                end else begin
                    m2_state <= S_MEGA_FS_CSP_LI_0;
                end
            end
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////compute s'///////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

            S_CSP_LI_0: begin
                write_enable_a[1] <= 1'b0;//finalize mega wsp ct states
                //compute s'
                sc_t <= sc_t + 6'd2;
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                write_enable_a[1] <= 1'b0;
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]};
                write_enable_b[1] <= 1'b0;
                m2_state <= S_CSP_LI_1;
            end
            S_CSP_LI_1: begin
                //compute s'
                sc_t <= sc_t + 6'd2;
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]};
                m2_state <= S_CSP_LI_2;              
            end
            S_CSP_LI_2: begin
                //compute s'
                sc_t <= sc_t + 6'd2;
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]};                
                t0_reg_0 <= read_data_a[1];
                t1_reg_0 <= read_data_b[1];
                m2_state <= S_CSP_LI_3;
            end
            S_CSP_LI_3: begin
                //compute s'
                sc_t <= sc_t + 6'd2;
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]};          
                t2_reg_0 <= read_data_a[1];
                t3_reg_0 <= read_data_b[1];     
                m2_state <= S_CSP_LI_4;       
            end
            S_CSP_LI_4: begin
                //compute s'
                t4_reg_0 <= read_data_a[1];
                t5_reg_0 <= read_data_b[1];    
                select0 <= 5'd3;
                select1 <= 5'd3;
                select2 <= 5'd3;
                select3 <= 5'd3;
                c_idx[0] <= 5'd0;
                c_idx[1] <= 5'd1;
                c_idx[2] <= 5'd2;
                c_idx[3] <= 5'd3;
                m2_state <= S_CSP_LI_5;
            end
            S_CSP_LI_5: begin
                //compute s'
                t6_reg_0 <= read_data_a[1];
                t7_reg_0 <= read_data_b[1];   
                FS_CSP_flag <= 1'b0;//init
                select0 <= 5'd5;
                select1 <= 5'd5;
                select2 <= 5'd5;
                select3 <= 5'd5;
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4;       
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                sc_sp_dp0 <= 6'd0;//init
                LI_FS_addr_a0_cnt <= 7'd0;//init
                m2_state <= S_CSP_CC_0;                      
            end
            S_CSP_CC_0: begin
                //compute s'
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //dpram1
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]}; 
                sc_t <= sc_t + 6'd2;
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_CSP_CC_1;                
            end
            S_CSP_CC_1: begin
                //compute s'
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //dpram1
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]}; 
                sc_t <= sc_t + 6'd2;
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_CSP_CC_2;
            end
            S_CSP_CC_2: begin
                //compute s'
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //dpram1
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]}; 
                sc_t <= sc_t + 6'd2;
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                    t0_reg_1 <= read_data_a[1];
                    t1_reg_1 <= read_data_b[1];
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                    t0_reg_0 <= read_data_a[1];
                    t1_reg_0 <= read_data_b[1];
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;
                m2_state <= S_CSP_CC_3;              
            end
            S_CSP_CC_3: begin
                //compute s'
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //dpram1
                address_a[1] <= {1'b0,sc_t[2:0],sc_t[5:3]};
                address_b[1] <= {1'b0,(sc_t[2:0]+3'b1),sc_t[5:3]}; 
                sc_t <= sc_t + 6'd2;
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                    t2_reg_1 <= read_data_a[1];
                    t3_reg_1 <= read_data_b[1];
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                    t2_reg_0 <= read_data_a[1];
                    t3_reg_0 <= read_data_b[1];
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;
                m2_state <= S_CSP_CC_4;             
            end
            S_CSP_CC_4: begin
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                    t4_reg_1 <= read_data_a[1];
                    t5_reg_1 <= read_data_b[1];
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                    t4_reg_0 <= read_data_a[1];
                    t5_reg_0 <= read_data_b[1];
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_CSP_CC_5;             
            end
            S_CSP_CC_5: begin
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                FS_CSP_flag <= ~FS_CSP_flag;
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                    t6_reg_1 <= read_data_a[1];
                    t7_reg_1 <= read_data_b[1];
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                    t6_reg_0 <= read_data_a[1];
                    t7_reg_0 <= read_data_b[1];
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_CSP_CC_6;             
            end
            S_CSP_CC_6: begin
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;
                m2_state <= S_CSP_CC_7;            
            end
            S_CSP_CC_7: begin
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;
                if(sc_sp_dp0 == 6'd55) begin
                    m2_state <= S_CSP_LO_0;
                end else begin
                    m2_state <= S_CSP_CC_0;
                end
            end
            S_CSP_LO_0: begin
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_CSP_LO_1;          
            end
            S_CSP_LO_1: begin
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_CSP_LO_2;                 
            end
            S_CSP_LO_2: begin
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_CSP_LO_3;                   
            end
            S_CSP_LO_3: begin
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_CSP_LO_4; 
            end
            S_CSP_LO_4: begin
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_CSP_LO_5; 
            end
            S_CSP_LO_5: begin
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                if(FS_CSP_flag == 1'b0) begin
                    if(select0 == 5'd4) begin
                        select0 <= 5'd5;
                        select1 <= 5'd5;
                        select2 <= 5'd5;
                        select3 <= 5'd5;
                    end else begin // select0 == 5'd5
                        select0 <= 5'd4;
                        select1 <= 5'd4;
                        select2 <= 5'd4;
                        select3 <= 5'd4;                        
                    end
                end else begin // FS_CSP_flag == 1'b1
                    if(select0 == 5'd6) begin
                        select0 <= 5'd7;
                        select1 <= 5'd7;
                        select2 <= 5'd7;
                        select3 <= 5'd7;                        
                    end else begin //select0 == 5'd7 or 4 or 5
                        select0 <= 5'd6;
                        select1 <= 5'd6;
                        select2 <= 5'd6;
                        select3 <= 5'd6;                          
                    end
                end
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_CSP_LO_6;                 
            end
            S_CSP_LO_6: begin
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //multi
                c_idx[0] <= c_idx[0] + 5'd4;
                c_idx[1] <= c_idx[1] + 5'd4;
                c_idx[2] <= c_idx[2] + 5'd4;
                c_idx[3] <= c_idx[3] + 5'd4; 
                reg_0_multi <= multi0;
                reg_1_multi <= multi1;
                reg_2_multi <= multi2;
                reg_3_multi <= multi3;  
                m2_state <= S_CSP_LO_7;                 
            end
            S_CSP_LO_7: begin
                //compute s'
                //dpram0
                address_b[0] <= {1'b0,sc_sp_dp0[2:0],sc_sp_dp0[5:3]}+7'd16;//s' save start on line 16 in dp0
                sc_sp_dp0 <= 6'd0;
                write_data_b[0] <= reg_0_multi + reg_1_multi + reg_2_multi + reg_3_multi + 32'sd32768;
                write_enable_b[0] <= 1'b1;
                //no dpram1 operation
                //no multi operation
                m2_state <= S_WSP_LI_0;                 
            end
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////write s'///////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

            S_WSP_LI_0: begin
                write_enable_b[0] <= 1'b0;
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= 6'd1; 
                m2_state <= S_WSP_LI_1;               
            end
            S_WSP_LI_1: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_LI_2;               
            end
            S_WSP_LI_2: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_LI_3;               
            end       
            S_WSP_LI_3: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_LI_4;               
            end     
            S_WSP_LI_4: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_CC_0;               
            end
            S_WSP_CC_0: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_CC_1;               
            end
            S_WSP_CC_1: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_CC_2;               
            end
            S_WSP_CC_2: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_CC_3;               
            end
            S_WSP_CC_3: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_CC_4;               
            end
            S_WSP_CC_4: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_CC_5;               
            end
            S_WSP_CC_5: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_CC_6;               
            end
            S_WSP_CC_6: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_CC_7;               
            end
            S_WSP_CC_7: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                if (sc_sp_dp0 == 6'd60) begin
                    m2_state <= S_WSP_LO_0;      
                end else begin
                    m2_state <= S_WSP_CC_0;
                end         
            end
            S_WSP_LO_0: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_LO_1;               
            end
            S_WSP_LO_1: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;
 
                m2_state <= S_WSP_LO_2;               
            end
            S_WSP_LO_2: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                //ws' dp0
                address_b[0] <= {1'b0,sc_sp_dp0}+7'd16;
                sc_sp_dp0 <= sc_sp_dp0 + 6'd1;
                write_enable_b[0] <= 1'b0;

                m2_state <= S_WSP_LO_3;               
            end
            S_WSP_LO_3: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                // no ws' dp0 operation

                m2_state <= S_WSP_LO_4;               
            end
            S_WSP_LO_4: begin
                //write s' (block n)
                //ws' sram
                SRAM_we_n <= 1'b0;
                SRAM_write_data <= read_data_b[0][31:16];
                if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * Y_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
                    SRAM_address <= sram_wsp_addr_offset + ({11'd0, rb_sp, sc_sp_sram[5:3]} * UV_WSP_STRIDE) + {10'd0, cb_sp, sc_sp_sram[2:0]};
                end
                sc_sp_sram <= sc_sp_sram + 6'd1;
                // no ws' dp0 operation

                //write s' sram address management
                if(sram_wsp_offset_flag == 2'd0) begin 
                    // FSM is fetching Y value from SRAM
                    if (sc_sp_sram == 6'd63) begin
                        if (cb_sp == MAX_CB_Y) begin
                            cb_sp <= 7'd0;             
                            if (rb_sp == MAX_RB) begin
                                rb_sp <= 6'd0;           
                                sram_wsp_offset_flag <= 2'd1; 
                                rb_sp <= rb_sp + 6'd1;      
                            end
                        end else begin
                            cb_sp <= cb_sp + 7'd1;          
                        end
                    end

                end else if(sram_wsp_offset_flag == 2'd1) begin 
                    // FSM is fetching U value from SRAM
                    if (sc_sp_sram == 6'd63) begin
                        if (cb_sp == MAX_CB_UV) begin        
                            cb_sp <= 7'd0;               
                            if (rb_sp == MAX_RB) begin
                                rb_sp <= 6'd0;          
                                sram_wsp_offset_flag <= 2'd2; 
                            end else begin
                                rb_sp <= rb_sp + 6'd1;   
                            end
                        end else begin
                            cb_sp <= cb_sp + 7'd1;       
                        end
                    end

                end else if(sram_wsp_offset_flag == 2'd2) begin 
                    // FSM is fetching V value from SRAM
                    if (sc_sp_sram == 6'd63) begin
                        if (cb_sp == MAX_CB_UV) begin    
                            cb_sp <= 7'd0;               
                            if (rb_sp == MAX_RB) begin
                                rb_sp <= 6'd0;           
                                sram_wsp_offset_flag <= 2'd0; 
                                //finish_mega_flag <= 1'b1;      
                            end else begin
                                rb_sp <= rb_sp + 6'd1;  
                            end
                        end else begin
                            cb_sp <= cb_sp + 7'd1;       
                        end
                    end        
                end  
                m2_state <= S_WSP_LO_5;               
            end
            S_WSP_LO_5: begin
                //no write s' (block n) operation
                SRAM_we_n <= 1'b1;

                m2_state <= S_IDLE_m2;
                done2 <= 1'b1;              
            end
		default:m2_state<=S_IDLE_m2;
        endcase
    end
end
assign m2_op2 = C_matrix[0];
assign m2_op4 = C_matrix[1];
assign m2_op6 = C_matrix[2];
assign m2_op8 = C_matrix[3];

always_comb begin
//multiplier 0 
	case(select0)
	5'd1: begin m2_op1=$signed({24'd0, s0_reg_0})+$signed({24'd0, s7_reg_0});end
    5'd2: begin m2_op1=$signed({24'd0, s0_reg_0})-$signed({24'd0, s7_reg_0});end
    5'd3: begin m2_op1=t0_reg_0+$signed(read_data_b[1]);end
    5'd4: begin m2_op1=t0_reg_0+t7_reg_0;end
    5'd5: begin m2_op1=t0_reg_0-t7_reg_0;end
    5'd6: begin m2_op1=t0_reg_1+t7_reg_1;end
    5'd7: begin m2_op1=t0_reg_1-t7_reg_1;end
    5'd8: begin m2_op1=$signed({24'd0, s0_reg_1})+$signed({24'd0, s7_reg_1});end
    5'd9: begin m2_op1=$signed({24'd0, s0_reg_1})-$signed({24'd0, s7_reg_1});end
	default:begin m2_op1=32'd0;end
	endcase
	
//multiplier 1 
	case(select1)
	5'd1:begin m2_op3=$signed({24'd0, s1_reg_0})+$signed({24'd0, s6_reg_0});end
    5'd2:begin m2_op3=$signed({24'd0, s1_reg_0})-$signed({24'd0, s6_reg_0});end
    5'd3: begin m2_op3=t1_reg_0+$signed(read_data_a[1]);end
    5'd4: begin m2_op3=t1_reg_0+t6_reg_0;end
    5'd5: begin m2_op3=t1_reg_0-t6_reg_0;end
    5'd6: begin m2_op3=t1_reg_1+t6_reg_1;end
    5'd7: begin m2_op3=t1_reg_1-t6_reg_1;end
    5'd8:begin m2_op3=$signed({24'd0, s1_reg_1})+$signed({24'd0, s6_reg_1});end
    5'd9:begin m2_op3=$signed({24'd0, s1_reg_1})-$signed({24'd0, s6_reg_1});end
	default:begin m2_op3=32'd0;end
	endcase
	
//multiplier 2 
	case(select2)
	5'd1:begin m2_op5= $signed({24'd0, s2_reg_0})+$signed({24'd0, s5_reg_0});end
    5'd2:begin m2_op5= $signed({24'd0, s2_reg_0})-$signed({24'd0, s5_reg_0});end 
    5'd3: begin m2_op5=t2_reg_0+t5_reg_0;end
    5'd4: begin m2_op5=t2_reg_0+t5_reg_0;end
    5'd5: begin m2_op5=t2_reg_0-t5_reg_0;end
    5'd6: begin m2_op5=t2_reg_1+t5_reg_1;end
    5'd7: begin m2_op5=t2_reg_1-t5_reg_1;end
	5'd8:begin m2_op5= $signed({24'd0, s2_reg_1})+$signed({24'd0, s5_reg_1});end
    5'd9:begin m2_op5= $signed({24'd0, s2_reg_1})-$signed({24'd0, s5_reg_1});end 
	default:begin m2_op5=32'd0;end
	endcase

//multiplier 3 
	case(select3)
	5'd1:begin m2_op7= $signed({24'd0, s3_reg_0})+$signed({24'd0, s4_reg_0});end
    5'd2:begin m2_op7= $signed({24'd0, s3_reg_0})-$signed({24'd0, s4_reg_0});end 
    5'd3: begin m2_op7=t3_reg_0+t4_reg_0;end
    5'd4: begin m2_op7=t3_reg_0+t4_reg_0;end
    5'd5: begin m2_op7=t3_reg_0-t4_reg_0;end
    5'd6: begin m2_op7=t3_reg_1+t4_reg_1;end
    5'd7: begin m2_op7=t3_reg_1-t4_reg_1;end
	5'd8:begin m2_op7= $signed({24'd0, s3_reg_1})+$signed({24'd0, s4_reg_1});end
    5'd9:begin m2_op7= $signed({24'd0, s3_reg_1})-$signed({24'd0, s4_reg_1});end 
	default:begin m2_op7=32'd0;end
	endcase
end



always_comb begin
	case(c_idx[0])
	0:   C_matrix[0] = 32'sd1448;   //C00
	1:   C_matrix[0] = 32'sd1448;   //C01
	2:   C_matrix[0] = 32'sd1448;   //C02
	3:   C_matrix[0] = 32'sd1448;   //C03

	4:   C_matrix[0] = 32'sd2008;   //C10
	5:   C_matrix[0] = 32'sd1702;   //C11
	6:  C_matrix[0] = 32'sd1137;   //C12
	7:  C_matrix[0] = 32'sd399;    //C13

	8:  C_matrix[0] = 32'sd1892;   //C20
	9:  C_matrix[0] = 32'sd783;    //C21
	10:  C_matrix[0] = -32'sd783;   //C22
	11:  C_matrix[0] = -32'sd1892;  //C23

	12:  C_matrix[0] = 32'sd1702;   //C30
	13:  C_matrix[0] = -32'sd399;   //C31
	14:  C_matrix[0] = -32'sd2008;  //C32
	15:  C_matrix[0] = -32'sd1137;  //C33

	16:  C_matrix[0] = 32'sd1448;   //C40
	17:  C_matrix[0] = -32'sd1448;  //C41
	18:  C_matrix[0] = -32'sd1448;  //C42
	19:  C_matrix[0] = 32'sd1448;   //C43

	20:  C_matrix[0] = 32'sd1137;   //C50
	21:  C_matrix[0] = -32'sd2008;  //C51
	22:  C_matrix[0] = 32'sd399;    //C52
	23:  C_matrix[0] = 32'sd1702;   //C53

	24:  C_matrix[0] = 32'sd783;    //C60
	25:  C_matrix[0] = -32'sd1892;  //C61
	26:  C_matrix[0] = 32'sd1892;   //C62
	27:  C_matrix[0] = -32'sd783;   //C63

	28:  C_matrix[0] = 32'sd399;    //C70
    29:  C_matrix[0] = -32'sd1137;  //C71
    30:  C_matrix[0] = 32'sd1702;   //C72
    31:  C_matrix[0] = -32'sd2008;  //C73
	endcase
end
always_comb begin
	case(c_idx[1])
	0:   C_matrix[1] = 32'sd1448;   //C00
	1:   C_matrix[1] = 32'sd1448;   //C01
	2:   C_matrix[1] = 32'sd1448;   //C02
	3:   C_matrix[1] = 32'sd1448;   //C03

	4:   C_matrix[1] = 32'sd2008;   //C10
	5:   C_matrix[1] = 32'sd1702;   //C11
	6:  C_matrix[1] = 32'sd1137;   //C12
	7:  C_matrix[1] = 32'sd399;    //C13

	8:  C_matrix[1] = 32'sd1892;   //C20
	9:  C_matrix[1] = 32'sd783;    //C21
	10:  C_matrix[1] = -32'sd783;   //C22
	11:  C_matrix[1] = -32'sd1892;  //C23

	12:  C_matrix[1] = 32'sd1702;   //C30
	13:  C_matrix[1] = -32'sd399;   //C31
	14:  C_matrix[1] = -32'sd2008;  //C32
	15:  C_matrix[1] = -32'sd1137;  //C33

	16:  C_matrix[1] = 32'sd1448;   //C40
	17:  C_matrix[1] = -32'sd1448;  //C41
	18:  C_matrix[1] = -32'sd1448;  //C42
	19:  C_matrix[1] = 32'sd1448;   //C43

	20:  C_matrix[1] = 32'sd1137;   //C50
	21:  C_matrix[1] = -32'sd2008;  //C51
	22:  C_matrix[1] = 32'sd399;    //C52
	23:  C_matrix[1] = 32'sd1702;   //C53

	24:  C_matrix[1] = 32'sd783;    //C60
	25:  C_matrix[1] = -32'sd1892;  //C61
	26:  C_matrix[1] = 32'sd1892;   //C62
	27:  C_matrix[1] = -32'sd783;   //C63

	28:  C_matrix[1] = 32'sd399;    //C70
    29:  C_matrix[1] = -32'sd1137;  //C71
    30:  C_matrix[1] = 32'sd1702;   //C72
    31:  C_matrix[1] = -32'sd2008;  //C73
	endcase
end
always_comb begin
	case(c_idx[2])
	0:   C_matrix[2] = 32'sd1448;   //C00
	1:   C_matrix[2] = 32'sd1448;   //C01
	2:   C_matrix[2] = 32'sd1448;   //C02
	3:   C_matrix[2] = 32'sd1448;   //C03

	4:   C_matrix[2] = 32'sd2008;   //C10
	5:   C_matrix[2] = 32'sd1702;   //C11
	6:  C_matrix[2] = 32'sd1137;   //C12
	7:  C_matrix[2] = 32'sd399;    //C13

	8:  C_matrix[2] = 32'sd1892;   //C20
	9:  C_matrix[2] = 32'sd783;    //C21
	10:  C_matrix[2] = -32'sd783;   //C22
	11:  C_matrix[2] = -32'sd1892;  //C23

	12:  C_matrix[2] = 32'sd1702;   //C30
	13:  C_matrix[2] = -32'sd399;   //C31
	14:  C_matrix[2] = -32'sd2008;  //C32
	15:  C_matrix[2] = -32'sd1137;  //C33

	16:  C_matrix[2] = 32'sd1448;   //C40
	17:  C_matrix[2] = -32'sd1448;  //C41
	18:  C_matrix[2] = -32'sd1448;  //C42
	19:  C_matrix[2] = 32'sd1448;   //C43

	20:  C_matrix[2] = 32'sd1137;   //C50
	21:  C_matrix[2] = -32'sd2008;  //C51
	22:  C_matrix[2] = 32'sd399;    //C52
	23:  C_matrix[2] = 32'sd1702;   //C53

	24:  C_matrix[2] = 32'sd783;    //C60
	25:  C_matrix[2] = -32'sd1892;  //C61
	26:  C_matrix[2] = 32'sd1892;   //C62
	27:  C_matrix[2] = -32'sd783;   //C63

	28:  C_matrix[2] = 32'sd399;    //C70
    29:  C_matrix[2] = -32'sd1137;  //C71
    30:  C_matrix[2] = 32'sd1702;   //C72
    31:  C_matrix[2] = -32'sd2008;  //C73
	endcase
end
always_comb begin
	case(c_idx[3])
	0:   C_matrix[3] = 32'sd1448;   //C00
	1:   C_matrix[3] = 32'sd1448;   //C01
	2:   C_matrix[3] = 32'sd1448;   //C02
	3:   C_matrix[3] = 32'sd1448;   //C03

	4:   C_matrix[3] = 32'sd2008;   //C10
	5:   C_matrix[3] = 32'sd1702;   //C11
	6:  C_matrix[3] = 32'sd1137;   //C12
	7:  C_matrix[3] = 32'sd399;    //C13

	8:  C_matrix[3] = 32'sd1892;   //C20
	9:  C_matrix[3] = 32'sd783;    //C21
	10:  C_matrix[3] = -32'sd783;   //C22
	11:  C_matrix[3] = -32'sd1892;  //C23

	12:  C_matrix[3] = 32'sd1702;   //C30
	13:  C_matrix[3] = -32'sd399;   //C31
	14:  C_matrix[3] = -32'sd2008;  //C32
	15:  C_matrix[3] = -32'sd1137;  //C33

	16:  C_matrix[3] = 32'sd1448;   //C40
	17:  C_matrix[3] = -32'sd1448;  //C41
	18:  C_matrix[3] = -32'sd1448;  //C42
	19:  C_matrix[3] = 32'sd1448;   //C43

	20:  C_matrix[3] = 32'sd1137;   //C50
	21:  C_matrix[3] = -32'sd2008;  //C51
	22:  C_matrix[3] = 32'sd399;    //C52
	23:  C_matrix[3] = 32'sd1702;   //C53

	24:  C_matrix[3] = 32'sd783;    //C60
	25:  C_matrix[3] = -32'sd1892;  //C61
	26:  C_matrix[3] = 32'sd1892;   //C62
	27:  C_matrix[3] = -32'sd783;   //C63

	28:  C_matrix[3] = 32'sd399;    //C70
    29:  C_matrix[3] = -32'sd1137;  //C71
    30:  C_matrix[3] = 32'sd1702;   //C72
    31:  C_matrix[3] = -32'sd2008;  //C73
	endcase
end
/*
always_comb begin
	case(c_idx)
	0:   C_matrix[0] = 32'sd1448;   //C00
	1:   C_matrix[0] = 32'sd1448;   //C01
	2:   C_matrix[0] = 32'sd1448;   //C02
	3:   C_matrix[0] = 32'sd1448;   //C03
	4:   C_matrix[0] = 32'sd1448;   //C04
	5:   C_matrix[0] = 32'sd1448;   //C_matrix[0]05
	6:   C_matrix[0] = 32'sd1448;   //C_matrix[0]06
	7:   C_matrix[0] = 32'sd1448;   //C_matrix[0]07

	8:   C_matrix[0] = 32'sd2008;   //C10
	9:   C_matrix[0] = 32'sd1702;   //C11
	10:  C_matrix[0] = 32'sd1137;   //C12
	11:  C_matrix[0] = 32'sd399;    //C13
	12:  C_matrix[0] = -32'sd399;   //C14
	13:  C_matrix[0] = -32'sd1137;  //C15
	14:  C_matrix[0] = -32'sd1702;  //C16
	15:  C_matrix[0] = -32'sd2008;  //C17

	16:  C_matrix[0] = 32'sd1892;   //C20
	17:  C_matrix[0] = 32'sd783;    //C21
	18:  C_matrix[0] = -32'sd783;   //C22
	19:  C_matrix[0] = -32'sd1892;  //C23
	20:  C_matrix[0] = -32'sd1892;  //C24
	21:  C_matrix[0] = -32'sd783;   //C25
	22:  C_matrix[0] = 32'sd783;    //C26
	23:  C_matrix[0] = 32'sd1892;   //C27

	24:  C_matrix[0] = 32'sd1702;   //C30
	25:  C_matrix[0] = -32'sd399;   //C31
	26:  C_matrix[0] = -32'sd2008;  //C32
	27:  C_matrix[0] = -32'sd1137;  //C33
	28:  C_matrix[0] = 32'sd1137;   //C34
	29:  C_matrix[0] = 32'sd2008;   //C35
	30:  C_matrix[0] = 32'sd399;    //C36
	31:  C_matrix[0] = -32'sd1702;  //C37

	32:  C_matrix[0] = 32'sd1448;   //C40
	33:  C_matrix[0] = -32'sd1448;  //C41
	34:  C_matrix[0] = -32'sd1448;  //C42
	35:  C_matrix[0] = 32'sd1448;   //C43
	36:  C_matrix[0] = 32'sd1448;   //C44
	37:  C_matrix[0] = -32'sd1448;  //C45
	38:  C_matrix[0] = -32'sd1448;  //C46
	39:  C_matrix[0] = 32'sd1448;   //C47

	40:  C_matrix[0] = 32'sd1137;   //C50
	41:  C_matrix[0] = -32'sd2008;  //C51
	42:  C_matrix[0] = 32'sd399;    //C52
	43:  C_matrix[0] = 32'sd1702;   //C53
	44:  C_matrix[0] = -32'sd1702;  //C54
	45:  C_matrix[0] = -32'sd399;   //C55
	46:  C_matrix[0] = 32'sd2008;   //C56
	47:  C_matrix[0] = -32'sd1137;  //C57

	48:  C_matrix[0] = 32'sd783;    //C60
	49:  C_matrix[0] = -32'sd1892;  //C61
	50:  C_matrix[0] = 32'sd1892;   //C62
	51:  C_matrix[0] = -32'sd783;   //C63
	52:  C_matrix[0] = -32'sd783;   //C64
	53:  C_matrix[0] = 32'sd1892;   //C65
	54:  C_matrix[0] = -32'sd1892;  //C66
	55:  C_matrix[0] = 32'sd783;    //C67

	56:  C_matrix[0] = 32'sd399;    //C70
    57:  C_matrix[0] = -32'sd1137;  //C71
    58:  C_matrix[0] = 32'sd1702;   //C72
    59:  C_matrix[0] = -32'sd2008;  //C73
    60:  C_matrix[0] = 32'sd2008;   //C74
    61:  C_matrix[0] = -32'sd1702;  //C75
    62:  C_matrix[0] = 32'sd1137;   //C76
    63:  C_matrix[0] = -32'sd399;   //C77
	endcase
end

// DCT coefficient matrix C (Q12, scaled by 4096)
localparam logic signed [15:0] C [0:7][0:7] = '{
  '{ 16'sd1448,  16'sd1448,  16'sd1448,  16'sd1448,  16'sd1448,  16'sd1448,  16'sd1448,  16'sd1448 },
  '{ 16'sd2008,  16'sd1702,  16'sd1137,  16'sd399,  -16'sd399, -16'sd1137, -16'sd1702, -16'sd2008 },
  '{ 16'sd1892,  16'sd783,  -16'sd783, -16'sd1892, -16'sd1892, -16'sd783,  16'sd783,  16'sd1892 },
  '{ 16'sd1702, -16'sd399, -16'sd2008, -16'sd1137,  16'sd1137,  16'sd2008,  16'sd399, -16'sd1702 },
  '{ 16'sd1448, -16'sd1448, -16'sd1448,  16'sd1448,  16'sd1448, -16'sd1448, -16'sd1448,  16'sd1448 },
  '{ 16'sd1137, -16'sd2008,  16'sd399,  16'sd1702, -16'sd1702, -16'sd399,  16'sd2008, -16'sd1137 },
  '{ 16'sd783,  -16'sd1892,  16'sd1892, -16'sd783,  -16'sd783,  16'sd1892, -16'sd1892,  16'sd783 },
  '{ 16'sd399,  -16'sd1137,  16'sd1702, -16'sd2008,  16'sd2008, -16'sd1702,  16'sd1137, -16'sd399 }
};
*/

endmodule

////////////////////////////////////////////////////////////////////////

/*
correct logic on sram address management: 

SRAM_address <= sram_fs_addr_offset + {3'd0, ({rb_s,sc_s[4:2]}<<8)}+{5'd0, ({rb_s, sc_s[4:2]}<<6)}+{11'd0, cb_s, sc_s[1:0]};


if(sc_s == 5'd31) begin
    if(cb_s == 7'd79) begin
        cb_s <= 7'd0;
        if(rb_s == 6'd59) begin
            rb_s <= 6'd0;
        end else begin
            rb_s <= rb_s + 6'd1;
        end
    end else begin
        cb_s <= cb_s + 7'd1;
    end
end
*/


// //fs
//                 if(sram_fs_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*320 + (CB*4+ci) //320=256+64, <<8 <<6
//                     SRAM_address <= sram_fs_addr_offset + {3'd0, rb_s, sc_s[4:2], 8'd0} + {5'd0, rb_s, sc_s[4:2], 6'd0} + {11'd0, cb_s, sc_s[1:0]};
//                 end else begin // UV address: (RB*8 + ri)*160 + (CB*4+ci) / 160 = 128 + 32, <<7 <<5
//                     SRAM_address <= sram_fs_addr_offset + {4'd0, rb_s, sc_s[4:2], 7'd0} + {6'd0, rb_s, sc_s[4:2], 5'd0} + {11'd0, cb_s, sc_s[1:0]};
//                 end

// //ws'
//                 if(sram_wsp_offset_flag == 2'd0) begin // Y address: (RB*8 + ri)*640 + (CB*8+ci) //640=512+128, <<9 <<7
//                     SRAM_address <= sram_wsp_addr_offset + {2'd0, rb_sp, sc_sp_sram[5:3], 9'd0} + {4'd0, rb_sp, sc_sp_sram[5:3], 7'd0} + {10'd0, cb_sp, sc_sp_sram[2:0]};
//                 end else begin // UV address: (RB*8 + ri)*320 + (CB*8+ci) / 320 = 256 + 64, <<8 <<6
//                     SRAM_address <= sram_wsp_addr_offset + {3'd0, rb_sp, sc_sp_sram[5:3], 8'd0} + {5'd0, rb_sp, sc_sp_sram[5:3], 6'd0} + {10'd0, cb_sp, sc_sp_sram[2:0]};
//                 end
