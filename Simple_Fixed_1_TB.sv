/***********************************************************************************************************
 * Module: Simple Fixed 1 Testbench
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This test bench module is used to verify the functionality of the Simple_Fixed_1 module. It provides
 *     stimulus to the module inputs and monitors the module outputs to ensure correct behavior. The test bench
 *     includes various test cases covering different arithmetic and logical operations supported by the
 *     Simple_Fixed_1 module.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Operation code
 *   - instr_format: Instruction format
 *   - dest_reg_addr: Destination register address
 *   - src_reg_a: Source register A
 *   - src_reg_b: Source register B
 *   - store_reg: Store register
 *   - imm_value: Immediate value
 *   - enable_reg_write: Flag indicating register write operation
 *   - branch_is_taken: Flag indicating branch taken
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Data to be written back to the register file
 *   - wb_reg_addr: Address of the register to be written back
 *   - wb_enable_reg_write: Flag indicating register write operation in WB stage
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - delayed_rt_data: Delayed register data for forwarding
 *   - delayed_rt_addr: Delayed register address for forwarding
 *   - delayed_enable_reg_write: Delayed register write flag for forwarding
 ***********************************************************************************************************/

module Simple_Fixed_1_TB ();

  logic clock, reset;

  //Register File/Forwarding Stage
  // Decoded opcode, truncated based on instruction format
  logic [0:10] op_code;
  // Format of instruction, used with opcode and immediate value
  logic [ 2:0] instr_format;
  // Destination register address
  logic [ 0:6] dest_reg_addr;
  // Values of source registers
  logic [0:127] src_reg_a, src_reg_b, store_reg;
  // Immediate value, truncated based on instruction format
  logic [0:17] imm_value;
  // Flag indicating if the current instruction will write to the Register Table
  logic enable_reg_write;
  // Flag indicating if a branch was taken

  //Write Back Stage
  // Output value of Stage 3
  logic [0:127] wb_data;
  // Destination register for write back data
  logic [0:6] wb_reg_addr;
  // Flag indicating if the write back data will be written to the Register Table
  logic wb_enable_reg_write;
  // Indicates whether a branch is taken
  logic branch_is_taken;
  // Represents the delayed register address
  logic delayed_rt_addr;
  // Represents the delayed enable register write signal
  logic delayed_enable_reg_write;


  Simple_Fixed_1 dut (
      clock,
      reset,
      op_code,
      instr_format,
      dest_reg_addr,
      src_reg_a,
      src_reg_b,
      store_reg,
      imm_value,
      enable_reg_write,
      wb_data,
      wb_reg_addr,
      wb_enable_reg_write,
      branch_is_taken,
      delayed_rt_addr,
      delayed_enable_reg_write
  );

  // Set the initial state of the clock to zero
  initial clock = 0;

  // Toggle the clock value every 5 time units to simulate oscillation
  always begin
    #5 clock = ~clock;
  end

  initial begin
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
