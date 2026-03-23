
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET +define+SIMULATION $rtl/SRAM_controller.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/PB_controller.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/convert_hex_to_seven_segment.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/UART_receive_controller.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/UART_SRAM_interface.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/Milestone_1.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/Milestone_2.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/project1.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/dual_port_RAM0.v
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $rtl/dual_port_RAM1.v

vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $tb/tb_SRAM_Emulator.sv
vlog -sv -work my_work +define+DISABLE_DEFAULT_NET $tb/testbench.sv

