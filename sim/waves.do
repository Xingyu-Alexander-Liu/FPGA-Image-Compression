# activate waveform simulation

view wave

# format signal names in waveform

configure wave -signalnamewidth 1
configure wave -timeline 0
configure wave -timelineunits us

# add signals to waveform

add wave -divider -height 20 {}
add wave -bin UUT/CLOCK_50_I
add wave -bin UUT/resetn
add wave -hex {UUT/PB_pushed[0]}
add wave UUT/top_state
add wave UUT/Milestone_2_unit/m2_state
add wave UUT/Milestone_1_unit/m1_state
add wave UUT/Milestone_1_unit/Row_counter
add wave UUT/Milestone_1_unit/Col_counter
# add wave -uns UUT/UART_timer

add wave -divider -height 10 {}
add wave -uns UUT/SRAM_address
add wave -hex UUT/SRAM_write_data
add wave -bin UUT/SRAM_we_n
add wave -hex UUT/SRAM_read_data


