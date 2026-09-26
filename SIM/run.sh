
# Compile SystemVerilog code with IEEE 1800-2012 flag
#iverilog -g2012 -f filelist.f -o dma_sim.out
#
## Run the simulation
#vvp dma_sim.out

# 1. Compile SystemVerilog to binary simulator executable
#verilator --binary --sv -Wall -f filelist.f 

source ./setup.sh

verilator --binary --sv -Wall --timescale 1ns/1ps\
  -Wno-WAITCONST\
   --trace \
  -f filelist.f \
  -Wno-lint -Wno-INITIALDLY -Wno-UNOPTFLAT

# 2. Run the generated simulation executable
#./obj_dir/Vtop
./obj_dir/Vtb
