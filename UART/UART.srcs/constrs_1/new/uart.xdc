############################## Clock pins ############################## 
# IO_L12P_T1_MRCC_13, using MRCC pin V19
set_property PACKAGE_PIN V19 [get_ports Clk] 
set_property IOSTANDARD LVCMOS33 [get_ports Clk]
create_clock -period 10.000 -name Clk -waveform {0.000 5.000} [get_ports Clk]

# IO_L13P_T2_MRCC_13, using MRCC pin V19
set_property PACKAGE_PIN Y18 [get_ports Clk200] 
set_property IOSTANDARD LVCMOS33 [get_ports Clk200]
create_clock -period 5.000 -name Clk200 -waveform {0.000 2.500} [get_ports Clk200]

############################## Reset pin ############################## 
# IO_L1P_T0_13
set_property PACKAGE_PIN T21 [get_ports Rst] 
set_property IOSTANDARD LVCMOS33 [get_ports Rst]

############################## Error output ############################## 
# IO_L1N_T0_13
set_property PACKAGE_PIN U21 [get_ports Error]              
set_property IOSTANDARD LVCMOS33 [get_ports Error]

############################## TX ports ############################## 
# IO_L2P_T0_13
set_property PACKAGE_PIN U22 [get_ports Tx]                 
set_property IOSTANDARD LVCMOS33 [get_ports Tx]

# IO_L2N_T0_13
set_property PACKAGE_PIN V22 [get_ports {InputData[7]}]  
# IO_L4P_T0_13   
set_property PACKAGE_PIN W21 [get_ports {InputData[6]}] 
# IO_L4N_T0_13    
set_property PACKAGE_PIN W22 [get_ports {InputData[5]}]  
# IO_L5P_T0_13   
set_property PACKAGE_PIN U17 [get_ports {InputData[4]}]  
# IO_L5N_T0_13   
set_property PACKAGE_PIN V18 [get_ports {InputData[3]}]   
# IO_L6P_T0_13  
set_property PACKAGE_PIN T20 [get_ports {InputData[2]}]   
# IO_L7P_T1_13  
set_property PACKAGE_PIN Y21 [get_ports {InputData[1]}]  
# IO_L7N_T1_13   
set_property PACKAGE_PIN Y22 [get_ports {InputData[0]}]     
set_property IOSTANDARD LVCMOS33 [get_ports {InputData[*]}]

# IO_L8P_T1_13
set_property PACKAGE_PIN AA20 [get_ports InputValid]        
set_property IOSTANDARD LVCMOS33 [get_ports InputValid]


############################## RX ports ############################## 
# IO_L10P_T1_13
set_property PACKAGE_PIN AA19 [get_ports {OutputData[7]}]   
# IO_L10N_T1_13
set_property PACKAGE_PIN AB20 [get_ports {OutputData[6]}]   
# IO_L16P_T2_13
set_property PACKAGE_PIN AB15 [get_ports {OutputData[5]}]   
# IO_L16N_T2_13
set_property PACKAGE_PIN AB16 [get_ports {OutputData[4]}]   
# IO_L17P_T2_13
set_property PACKAGE_PIN AA16 [get_ports {OutputData[3]}]   
# IO_L17N_T2_13
set_property PACKAGE_PIN AB17 [get_ports {OutputData[2]}]   
# IO_L18P_T2_13
set_property PACKAGE_PIN AA14 [get_ports {OutputData[1]}]  
# IO_L18N_T2_13 
set_property PACKAGE_PIN AA15 [get_ports {OutputData[0]}]   
set_property IOSTANDARD LVCMOS33 [get_ports {OutputData[*]}]

# IO_L19P_T3_13
set_property PACKAGE_PIN U16 [get_ports OutputValid]        
set_property IOSTANDARD LVCMOS33 [get_ports OutputValid]

# IO_L20P_T3_13
set_property PACKAGE_PIN R16 [get_ports Rx]                 
set_property IOSTANDARD LVCMOS33 [get_ports Rx]
