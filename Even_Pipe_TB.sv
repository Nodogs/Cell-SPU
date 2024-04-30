/***********************************************************************************************************
 * Module: Even Pipe Testbench
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This testbench module verifies the functionality of the Even Pipe module, which represents the even 
 *     pipeline stage in a processor, handling instructions and forwarding logic.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Operation code for the instruction
 *   - instr_format: Instruction format
 *   - unit: Destination unit for the instruction
 *   - dest_reg_addr: Destination register address
 *   - src_reg_a: Value of source register A
 *   - src_reg_b: Value of source register B
 *   - temporary_register_c: Value of temporary register C
 *   - imm_value: Immediate value
 *   - enable_reg_write: Flag indicating whether register write is enabled
 *   - branch_is_taken: Flag indicating whether branch is taken	
  *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Data to be written back
 *   - wb_reg_addr: Address of the register to be written back
 *   - wb_enable_reg_write: Flag indicating whether register write is enabled for write-back stage
 *   - forwarded_data_wb: Forwarded data for write-back stage
 *   - forwarded_address_wb: Forwarded address for write-back stage
 *   - forwarded_write_flag_wb: Forwarded write flag for write-back stage
 *   - delayed_rt_addr_fp1: Delayed register addresses for fp1 unit
 *   - delayed_enable_reg_write_fp1: Delayed enable register write for fp1 unit
 *   - delayed_int_fp1: Internal delay for fp1 unit
 *   - delayed_rt_addr_fx2: Delayed register addresses for fx2 unit
 *   - delayed_enable_reg_write_fx2: Delayed enable register write for fx2 unit
 *   - delayed_rt_addr_b1: Delayed register addresses for b1 unit
 *   - delayed_enable_reg_write_b1: Delayed enable register write for b1 unit
 *   - delayed_rt_addr_fx1: Delayed register addresses for fx1 unit
 *   - delayed_enable_reg_write_fx1: Delayed enable register write for fx1 unit
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - fp1_op_code, fx2_op_code, b1_op_code, fx1_op_code: Operation codes for units
 *   - fp1_instr_format, fx2_instr_format, b1_instr_format, fx1_instr_format: Instruction formats for units
 *   - fp1_enable_reg_write, fx2_enable_reg_write, b1_enable_reg_write, fx1_enable_reg_write: 
 *     Enable register write flags for units
 *   - fp1_out, fx2_out, b1_out, fx1_out: Output data for units
 *   - fp1_addr_out, fx2_addr_out, b1_addr_out, fx1_addr_out: Output register addresses for units
 *   - fp1_write_out, fx2_write_out, b1_write_out, fx1_write_out: Write flags for units
 *   - fp1_int: Internal data for fp1 unit
 *   - fp1_addr_int: Internal register address for fp1 unit
 *   - fp1_write_int: Internal write flag for fp1 unit
 ***********************************************************************************************************/

module Even_Pipe_TB ();
  logic clock, reset;

  // Register File/Forwarding Stage
  // Decoded opcode, truncated based on instruction format
  logic [0:10] op_code;
  // Format of instruction, used with opcode and immediate value
  logic [ 2:0] instr_format;
  // Execution unit of instruction
  logic [ 1:0] unit;
  // Destination register address
  logic [ 0:6] dest_reg_addr;
  // Values of source registers
  logic [0:127] src_reg_a, src_reg_b, temporary_register_c, store_reg;
  // Immediate value, truncated based on instruction format
  logic [0:17] imm_value;
  // Flag indicating if the current instruction will write to the Register Table
  logic enable_reg_write;

  // Write Back Stage
  // Output value of Stage 7
  logic [0:127] wb_data;
  // Destination register for write back data
  logic [0:6] wb_reg_addr;
  // Flag indicating if the write back data will be written to the Register Table
  logic wb_enable_reg_write;
  // Indicates whether a branch instruction is taken
  logic branch_is_taken;
  // Indicates if data is forwarded from the write-back stage
  logic forwarded_data_wb;
  // Indicates if address is forwarded from the write-back stage
  logic forwarded_address_wb;
  // Indicates if write flag is forwarded from the write-back stage
  logic forwarded_write_flag_wb;
  // Indicates the delayed register address in the Single Precision Unit 1
  logic delayed_rt_addr_fp1;
  // Indicates if register write is delayed in Single Precision Unit 1
  logic delayed_enable_reg_write_fp1;
  // Indicates the delayed interrupt in the Single Precision Unit 1
  logic delayed_int_fp1;
  // Indicates the delayed register address in the Simple Fixed 2 Unit 2
  logic delayed_rt_addr_fx2;
  // Indicates if register write is delayed in the Simple Fixed 2 Unit 2
  logic delayed_enable_reg_write_fx2;
  // Indicates the delayed register address in Byte Unit 1
  logic delayed_rt_addr_b1;
  // Indicates if register write is delayed in Byte Unit 1
  logic delayed_enable_reg_write_b1;
  // Indicates the delayed register address in the Simple Fixed 1 Unit 1
  logic delayed_rt_addr_fx1;
  // Indicates if register write is delayed in the Simple Fixed 1 Unit 1
  logic delayed_enable_reg_write_fx1;

  Even_Pipe dut (
      clock,
      reset,
      op_code,
      instr_format,
      unit,
      dest_reg_addr,
      src_reg_a,
      src_reg_b,
      temporary_register_c,
      imm_value,
      enable_reg_write,
      wb_data,
      branch_is_taken,
      forwarded_data_wb,
      forwarded_address_wb,
      forwarded_write_flag_wb,
      delayed_rt_addr_fp1,
      delayed_enable_reg_write_fp1,
      delayed_int_fp1,
      delayed_rt_addr_fx2,
      delayed_enable_reg_write_fx2,
      delayed_rt_addr_b1,
      delayed_enable_reg_write_b1,
      delayed_rt_addr_fx1,
      delayed_enable_reg_write_fx1,
      wb_reg_addr,
      wb_enable_reg_write
  );

  // Set the initial state of the clock to zero
  initial clock = 0;

  // Oscillate the clock: every 5 time units, it changes its value
  always begin
    #5 clock = ~clock;
  end

  initial begin
    //***********************************************************************************************************	
    //Single_Precision_TB
    reset = 1;
    instr_format = 3'b000;
    // Multiply
    op_code = 11'b01111000100;
    dest_reg_addr = 7'b0000011;
    src_reg_a = 128'h3F1A6D9E42B7C8F1A1E2D3F4A5B6C7D8;
    src_reg_b = 128'h9B8C7D6E5F4A3B2C1D2E3F4A5B6C7D8;
    temporary_register_c = 128'hF5E4D3C2B1A09876543210ABCDEF012;
    imm_value = 42;
    enable_reg_write = 1;
    #6;
    reset = 0;
    @(posedge clock);
    #8;
    // Multiply Unsigned
    op_code = 11'b01111001100;
    @(posedge clock);
    #8;
    // Multiply Immediate
    op_code = 8'b01110100;
    @(posedge clock);
    #8;
    // Multiply Unsigned Immediate
    op_code = 8'b01110101;
    @(posedge clock);
    #8;
    // Multiply and Add
    op_code = 4'b1100;
    @(posedge clock);
    #8;
    // Multiply High
    op_code = 11'b01111000101;
    @(posedge clock);
    #8;
    // Multiply and Shift Right
    op_code = 11'b01111000111;
    @(posedge clock);
    #8;
    // Multiply High High
    op_code = 11'b01111000110;
    @(posedge clock);
    #8;
    // Floating Add
    op_code = 11'b01011000100;
    dest_reg_addr = 7'b0000011;
    src_reg_a = 128'hABCDEF0123456789ABCDEF012345678;
    src_reg_b = 128'hFEDCBA9876543210FEDCBA987654321;
    temporary_register_c = 128'h0123456789ABCDEF0123456789ABCDEF;
    imm_value = 173;
    @(posedge clock);
    #8;
    // Floating Subtract
    op_code = 11'b01011000101;
    @(posedge clock);
    #8;
    // Floating Multiply
    op_code = 11'b01011000110;
    @(posedge clock);
    #8;
    // Floating Multiply and Add
    op_code = 4'b1110;
    @(posedge clock);
    #8;
    // Floating Negative Multiply and Subtract
    op_code = 4'b1101;
    @(posedge clock);
    #8;
    // Floating Multiply and Subtract
    op_code = 4'b1111;
    @(posedge clock);
    #8;
    // Pause the simulation for 100 time units, then stop the simulation (Stop and Signal)
    #200;
    op_code = 11'b00000000000;
    //***********************************************************************************************************			
    //Simple_Fixed_2_TB
    reset = 1;
    instr_format = 3'b000;
    // Set the opcode for the Shift Left Halfword (shlh) operation
    op_code = 11'b00001011111;
    // Set the destination register address to $r3
    dest_reg_addr = 7'b0000011;
    // Set the value of source register A, Halfwords: 16'h0010
    src_reg_a = 128'h7F8A9BACBDBECFD0E1F2030405060708;
    // Set the value of source register B, Halfwords: 16'h0001
    src_reg_b = 128'h0123456789ABCDEFABCDEF012345678;
    imm_value = 0;
    enable_reg_write = 1;
    #6;
    // At 11ns, disable the reset, enabling the unit
    reset = 0;
    @(posedge clock);
    #1;
    // Set the opcode for the No Operation (nop) instruction
    op_code = 0;
    @(posedge clock);
    #1;
    op_code = 11'b01000000001;
    @(posedge clock);
    #1;
    op_code = 0;
    @(posedge clock);
    #1;
    op_code = 11'b01000000001;
    @(posedge clock);
    #1;
    op_code = 0;
    @(posedge clock);
    #1;
    op_code = 11'b01000000001;
    @(posedge clock);
    #1;
    // Handling the "Shift Left Word" operation (shl)
    op_code   = 11'b00001011011;
    src_reg_b = 128'hFEDCBA9876543210FEDCBA987654321;
    src_reg_a = 128'hA1B2C3D4E5F67890A1B2C3D4E5F6789;
    @(posedge clock);
    #4;
    // Handling the "Rotate Halfword" operation (roth)
    op_code   = 11'b00001011100;
    src_reg_b = 128'h1234567890ABCDEF1234567890ABCDEF;
    src_reg_a = 128'hFEDCBA0987654321FEDCBA098765432;
    @(posedge clock);
    #4;
    // Handling the "Rotate Word" operation (rot)
    op_code   = 11'b00001011000;
    src_reg_b = 128'h9876543210ABCDEF0123456789ABCDEF;
    src_reg_a = 128'hFEDCBA98765432100123456789ABCDEF;
    @(posedge clock);
    #4;
    // Handling the "Rotate Word" operation (rot)
    op_code   = 11'b00001011000;
    src_reg_b = 128'hABCDEFFEDCBA9876543210ABCDEF012;
    src_reg_a = 128'h0123456789ABCDEFABCDEF012345678;
    @(posedge clock);
    #4;
    // Shift Left Halfword
    op_code   = 11'b00001011111;
    src_reg_b = 128'hFEDCBA9876543210FEDCBA9876543210;
    src_reg_a = 128'h13579BDF2468ACE02468ACE13579BDF;
    @(posedge clock);
    #4;
    // Shift Left Halfword Immediate
    op_code = 11'b00001111111;
    instr_format = 3'b010;
    imm_value = 5;
    src_reg_b = 128'hFEDCBA9876543210ABCDEF012345678;
    src_reg_a = 128'h0123456789ABCDEFABCDEF0123456789;
    @(posedge clock);
    #4;
    // Shift Left Word
    op_code   = 11'b00001011011;
    src_reg_b = 128'hFEDCBA9876543210FEDCBA987654321;
    src_reg_a = 128'hABCDEFFEDCBA9876543210ABCDEFABC;
    @(posedge clock);
    #4;
    // Shift Left Word Immediate
    op_code = 11'b00001111011;
    instr_format = 3'b010;
    imm_value = 5;
    src_reg_b = 128'h5A23F8F5A0CDE28F50E78A5A23F8F5A0;
    src_reg_a = 128'h3B7912D6EFD84AB41021A683B7912D6E;
    @(posedge clock);
    #4;
    // Rotate Word
    op_code   = 11'b00001011000;
    src_reg_b = 128'h8EBA1945D1C7F26378EBA1945D1C7F26;
    src_reg_a = 128'hF4C65329B71D890F9DC17E8F4C65329B;
    @(posedge clock);
    #4;
    // Rotate Word Immediate
    op_code = 11'b00001111000;
    instr_format = 3'b010;
    imm_value = 5;
    src_reg_b = 128'hE2A719385F2B91CDE89E2A719385F2B9;
    src_reg_a = 128'h620DF4EAC1723B856BCA55B620DF4EAC;
    @(posedge clock);
    #4;
    // Rotate Halfword
    op_code   = 11'b00001011100;
    src_reg_b = 128'h15781AD7E4B6298F6F90B5F15781AD7E;
    src_reg_a = 128'h478D6AC01257E3FBA7C3DEA478D6AC01;
    @(posedge clock);
    #4;
    // Rotate Halfword Immediate
    op_code = 11'b00001111100;
    instr_format = 3'b010;
    imm_value = 5;
    src_reg_b = 128'hC1E9B54AD6F30E271BDE5A1C1E9B54AD;
    src_reg_a = 128'h3C2FA791D68BFE92EDD6B7B3C2FA791D;
    @(posedge clock);
    #4;
    // Pause the simulation for 100 time units, then stop the simulation (Stop and Signal)
    #100;
    op_code = 11'b00000000000;
    //***********************************************************************************************************			
    //Byte_TB
    reset = 1;
    instr_format = 3'b000;
    // Set the opcode for the Count Ones in Bytes (cntb) operation
    op_code = 11'b01010110100;
    // Set the destination register address to $r3
    dest_reg_addr = 7'b0000011;
    // Set the value of source register A,  Halfwords: 16'h0010
    src_reg_a = 128'hABCDEF1234567890ABCDEF123456789;
    // Set the value of source register B, Halfwords: 16'h0001
    src_reg_b = 128'hFEDCBA0987654321FEDCBA098765432;
    imm_value = 0;
    enable_reg_write = 1;
    #6;
    // At 11ns, disable the reset, enabling the unit
    reset = 0;
    @(posedge clock);
    #4;
    // Set the opcode for the Average Bytes (avgb) operation
    op_code = 11'b00011010011;
    @(posedge clock);
    #4;
    // Set the opcode for the Absolute Differences of Bytes (absdb) operation
    op_code = 11'b00001010011;
    @(posedge clock);
    #4;
    // Set the opcode for the Sum Bytes into Halfwords (sumb) operation
    op_code = 11'b01001010011;
    @(posedge clock);
    #4;
    // Set the opcode for the No Operation (nop) instruction
    op_code = 0;
    // Pause the simulation for 100 time units, then stop the simulation (Stop and Signal)
    #100;
    op_code = 11'b00000000000;
    //***********************************************************************************************************			
    //Simple_Fixed_1_TB
    reset = 1;
    instr_format = 3'b000;
    // Set the opcode for the Shift Left Halfword (shlh) operation
    op_code = 11'b00001011111;
    // Set the destination register address to $r3
    dest_reg_addr = 7'b0000011;
    // Set the value of source register A, Halfwords: 16'h0010
    src_reg_a = 128'h1A2B3C4D5E6F7A8B9C0D1E2F3A4B5C6;
    // Set the value of source register B, Halfwords: 16'h0001
    src_reg_b = 128'hF0E1D2C3B4A59687766554433221100;
    imm_value = 0;
    enable_reg_write = 1;
    #6;
    // At 11ns, disable the reset, enabling the unit
    reset = 0;
    @(posedge clock);
    #1;
    // Set the opcode for the No Operation (nop) instruction
    op_code = 0;
    @(posedge clock);
    // Add Extended
    #3;
    op_code   = 11'b01101000000;
    src_reg_a = 128'h8C15F2E6A90DC4BF2A7899E8C15F2E6A;
    src_reg_b = 128'h9AF507D38A4E62C711B7D459AF507D38;
    @(posedge clock);
    // Carry Generate
    #3;
    op_code   = 11'b00011000010;
    src_reg_a = 128'h56187F3ED26A950DBF2AC3C56187F3ED;
    src_reg_b = 128'hB6A9C81E57D9AF32F5E483BB6A9C81E5;
    @(posedge clock);
    // Subtract from Extended
    #3;
    op_code   = 11'b01101000001;
    src_reg_a = 128'h6D475C3A1809E6ABDC30E126D475C3A1;
    src_reg_b = 128'h294C7FAEB5D281AEC35F191294C7FAEB;
    @(posedge clock);
    // Borrow Generate
    #3;
    op_code   = 11'b00001000010;
    src_reg_a = 128'h294C7FAEB5D281AEC35F191294C7FAEB;
    src_reg_b = 128'h8F6D3BA24C7159FACF3F08C8F6D3BA24;
    @(posedge clock);
    // Add Halfword
    #3;
    op_code   = 11'b00011001000;
    src_reg_a = 128'h15781AD7E4B6298F6F90B5F15781AD7E;
    src_reg_b = 128'h00000000000000000000000000000001;
    @(posedge clock);
    // Add Halfword
    src_reg_a = 128'h9AF507D38A4E62C711B7D459AF507D38;
    src_reg_b = 128'h0A21DECB7EF548D1D36E7860A21DECB7;
    @(posedge clock);
    #3;
    op_code   = 11'b00011001000;
    // Add Halfword
    src_reg_a = 128'h849F36E1D4B5A2FC94DC931849F36E1D;
    src_reg_b = 128'hE58179AFDB023865EEABE3DE58179AFD;
    @(posedge clock);
    #3;
    src_reg_a = 128'h6A81F2CD45B796EDC7B2E996A81F2CD4;
    @(posedge clock);
    //sfh rt, ra, rb : Subtract from Halfword
    #3;
    op_code   = 11'b00001001000;
    src_reg_a = 128'h478D6AC01257E3FBA7C3DEA478D6AC01;
    src_reg_b = 128'h3B7912D6EFD84AB41021A683B7912D6E;
    @(posedge clock);
    //sfh rt, ra, rb : Subtract from Halfword
    #3;
    op_code   = 11'b00001001000;
    src_reg_a = 128'hFD45F8F5A0CDE28F50E78A5A23F8F5A0;
    src_reg_b = 128'h8EBA1945D1C7F26378EBA1945D1C7F26;
    @(posedge clock);
    //sf rt, ra, rb : Subtract from Word
    #3;
    op_code   = 11'b00001000000;
    src_reg_a = 128'h6D475C3A1809E6ABDC30E126D475C3A1;
    src_reg_b = 128'hDFA5C9B3824FA71DB7B2EC5DFA5C9B38;
    @(posedge clock);
    //sf rt, ra, rb : Subtract from Word
    #3;
    op_code   = 11'b00001000000;
    src_reg_a = 128'h15781AD7E4B6298F6F90B5F15781AD7E;
    src_reg_b = 128'h91BE7CAE5F34D2A4DB1E38C91BE7CAE5;
    @(posedge clock);
    //sfhi rt, ra, imm10 : Subtract from Halfword Immediate
    #3;
    op_code = 8'b00001101;
    instr_format = 4;
    src_reg_a = 128'h294C7FAEB5D281AEC35F191294C7FAEB;
    imm_value = 10'b0011111111;
    @(posedge clock);
    //sfhi rt, ra, imm10 : Subtract from Halfword Immediate
    #3;
    op_code = 8'b00001101;
    instr_format = 4;
    src_reg_a = 128'h0F3A9C15E6D7A8C34C27C930F3A9C15E;
    imm_value = 10'b1011111111;
    @(posedge clock);
    //sfi rt, ra, imm10 : Subtract from Word Immediate
    #3;
    op_code = 8'b00001100;
    instr_format = 4;
    src_reg_a = 128'h4228000040647AE1BFC00000BB83126F;
    imm_value = 10'b0011111111;
    @(posedge clock);
    //sfi rt, ra, imm10 : Subtract from Word Immediate
    #3;
    op_code = 8'b00001100;
    src_reg_a = 128'h6246BA3C1485D99AC471226246BA3C14;
    imm_value = 10'b1011111111;
    instr_format = 4;
    @(posedge clock);
    //Add Word
    #3;
    op_code = 11'b00011000000;
    instr_format = 0;
    src_reg_a = 128'hBF80DDF5A0CDE28F50E78A5A23F8F5A0;
    src_reg_b = 128'h3C2FA791D68BFE92EDD6B7B3C2FA791D;
    @(posedge clock);
    //Add Word
    #3;
    op_code   = 11'b00011000000;
    src_reg_a = 128'h0A21DECB7EF548D1D36E7860A21DECB7;
    src_reg_b = 128'h849F36E1D4B5A2FC94DC931849F36E1D;
    @(posedge clock);
    //ahi rt, ra, imm10 : Add Halfword Immediate
    #3;
    op_code = 8'b00011101;
    instr_format = 4;
    src_reg_a = 128'h15781AD7E4B6298F6F90B5F15781AD7E;
    imm_value = 10'b0011111111;
    @(posedge clock);
    //ai rt, ra, imm10 : Add Word Immediate
    #3;
    op_code = 8'b00011100;
    instr_format = 4;
    src_reg_a = 128'h8F6D3BA24C7159FACF3F08C8F6D3BA24;
    imm_value = 10'b1011111111;
    @(posedge clock);
    instr_format = 3'b000;
    // Handling the "AND" operation (and)
    #3;
    op_code   = 11'b00011000001;
    src_reg_a = 128'h294C7FAEB5D281AEC35F191294C7FAEB;
    src_reg_b = 128'h3F87EDD295C61BAE46EF23B3F87EDD29;
    @(posedge clock);
    // Handling the "OR" operation (or)
    #3;
    op_code   = 11'b00001000001;
    src_reg_a = 128'h4228000040647AE1BFC00000BB83126F;
    src_reg_b = 128'hBF80DDF5A0CDE28F50E78A5A23F8F5A0;
    @(posedge clock);
    // Handling the "XOR" operation (xor)
    #3;
    op_code = 11'b01001000001;
    @(posedge clock);
    // Handling the "NAND" operation (nand)
    #3;
    op_code = 11'b00011001001;
    @(posedge clock);
    src_reg_a = 128'hE2A719385F2B91CDE89E2A719385F2B9;
    src_reg_b = 128'h91BE7CAE5F34D2A4DB1E38C91BE7CAE5;
    @(posedge clock);
    // ceqh rt, ra, rb Compare Equal Halfword
    #3;
    op_code   = 11'b01111001000;
    src_reg_a = 128'h294C7FAEB5D281AEC35F191294C7FAEB;
    src_reg_b = 128'h15781AD7E4B6298F6F90B5F15781AD7E;
    @(posedge clock);
    // ceq rt, ra, rb Compare Equal Word
    #3;
    op_code   = 11'b01111000000;
    src_reg_a = 128'hBF80DDF5A0CDE28F50E78A5A23F8F5A0;
    src_reg_b = 128'h8C15F2E6A90DC4BF2A7899E8C15F2E6A;
    @(posedge clock);
    // cgth rt, ra, rb Compare Greater Than Halfword
    #3;
    op_code   = 11'b01001001000;
    src_reg_a = 128'h6246BA3C1485D99AC471226246BA3C14;
    src_reg_b = 128'h15781AD7E4B6298F6F90B5F15781AD7E;
    @(posedge clock);
    // cgt rt, ra, rb Compare Greater Than Word
    #3;
    op_code   = 11'b01001000000;
    src_reg_a = 128'hBF80DDF5A0CDE28F50E78A5A23F8F5A0;
    src_reg_b = 128'h91BE7CAE5F34D2A4DB1E38C91BE7CAE5;
    @(posedge clock);
    // clgtb rt, ra, rb Compare Logical Greater Than Byte
    #3;
    op_code   = 11'b01011010000;
    src_reg_a = 128'h294C7FAEB5D281AEC35F191294C7FAEB;
    src_reg_b = 128'h849F36E1D4B5A2FC94DC931849F36E1D;
    @(posedge clock);
    // clgth rt, ra, rb Compare Logical Greater Than Halfword
    #3;
    op_code   = 11'b01011001000;
    src_reg_a = 128'h15781AD7E4B6298F6F90B5F15781AD7E;
    src_reg_b = 128'h3C2FA791D68BFE92EDD6B7B3C2FA791D;
    @(posedge clock);
    // clgt rt, ra, rb Compare Logical Greater Than Word
    #3;
    op_code   = 11'b01011000000;
    src_reg_a = 128'hBF80DDF5A0CDE28F50E78A5A23F8F5A0;
    src_reg_b = 128'h91BE7CAE5F34D2A4DB1E38C91BE7CAE5;
    @(posedge clock);
    // ceqhi rt, ra, imm10 Compare Equal Halfword Immediate
    #3;
    op_code = 8'b01111101;
    instr_format = 4;
    src_reg_a = 128'h294C7FAEB5D281AEC35F191294C7FAEB;
    imm_value = 10'b1011111111;
    @(posedge clock);
    // ceqi rt, ra, imm10 Compare Equal Word Immediate
    #3;
    op_code = 8'b01111100;
    instr_format = 4;
    src_reg_a = 128'h849F36E1D4B5A2FC94DC931849F36E1D;
    imm_value = 10'b1111111111;
    @(posedge clock);
    // cgthi rt, ra, imm10 Compare Greater Than Halfword Immediate
    #3;
    op_code = 8'b01001101;
    instr_format = 4;
    src_reg_a = 128'h15781AD7E4B6298F6F90B5F15781AD7E;
    imm_value = 10'b1111111111;
    @(posedge clock);
    // cgti rt, ra, imm10 Compare Greater Than Word Immediate
    #3;
    op_code = 8'b01001100;
    instr_format = 4;
    src_reg_a = 128'h3C2FA791D68BFE92EDD6B7B3C2FA791D;
    imm_value = 10'b0111111111;
    @(posedge clock);
    // clgtbi rt, ra, imm10 Compare Logical Greater Than Byte Immediate
    #3;
    op_code = 8'b01011110;
    instr_format = 4;
    src_reg_a = 128'h57A8B910243E75FD124ED85957A8B910;
    imm_value = 10'b1101111111;
    @(posedge clock);
    // clgthi rt, ra, imm10 Compare Logical Greater Than Halfword Immediate
    #3;
    op_code = 8'b01011101;
    instr_format = 4;
    src_reg_a = 128'h1D964C0EF27AB9C9A62ED4F91D964C0E;
    imm_value = 10'b0111111111;
    @(posedge clock);
    // ilh rt, imm16 Immediate Load Halfword
    #3;
    op_code = 9'b010000011;
    instr_format = 5;
    src_reg_a = 128'hA3F1706B924E3D8B1C9F0B85A3F1706B;
    imm_value = 16'b0110011001100110;
    @(posedge clock);
    // Immediate Load Halfword Upper
    #3;
    op_code = 9'b010000010;
    instr_format = 5;
    src_reg_a = 128'hF5E892A65B7C341F0E6F7DA6F5E892A6;
    imm_value = 16'b1111111111111110;
    @(posedge clock);
    // Immediate Load Word
    #3;
    op_code = 9'b010000001;
    instr_format = 5;
    src_reg_a = 128'hD8A21F3B5690C7E51D3BF48BD8A21F3B;
    imm_value = 32'b11111111111111111111111111111110;
    @(posedge clock);
    // iohl rt, imm16 Immediate Or Halfword Lower
    #3;
    op_code = 9'b011000001;
    instr_format = 5;
    src_reg_a = 128'h2E7F46C1583A9B04AD76A8C72E7F46C1;
    imm_value = 16'b0110011001100110;
    store_reg = 128'hBC30291F745ED6A58765DDE4BC30291F;
    @(posedge clock);
    // ila rt, imm18 Immediate Load Address
    #3;
    op_code = 7'b0100001;
    instr_format = 6;
    src_reg_a = 128'h76B819FCE45A3D76A5D49F9F76B819FC;
    imm_value = 18'b000110011001100110;
    store_reg = 128'hF3D6B40271A5C8E14FD38C1EF3D6B402;
    @(posedge clock);
    #3;
    op_code = 0;
    @(posedge clock);
    // Pause the simulation for 100 time units, then stop the simulation (Stop and Signal)
    #100;
    op_code = 11'b00000000000;
    $stop;
  end
endmodule
