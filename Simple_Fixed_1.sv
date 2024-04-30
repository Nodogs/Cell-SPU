/***********************************************************************************************************
 * Module: Simple Fixed 1
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module implements a simple fixed-point arithmetic unit. It performs various arithmetic and logical
 *     operations based on the given instructions and inputs. The module contains separate stages for register
 *     file/forwarding and write back.
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

module Simple_Fixed_1 (
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

  input clock, reset;

  //Register File/Forwarding Stage
  // Decoded opcode, truncated based on instruction format
  input [0:10] op_code;
  // Format of instruction, used with opcode and immediate value
  input [2:0] instr_format;
  // Destination register address
  input [0:6] dest_reg_addr;
  // Values of source registers
  input [0:127] src_reg_a, src_reg_b, store_reg;
  // Immediate value, truncated based on instruction format
  input [0:17] imm_value;
  // Flag indicating if the current instruction will write to the Register Table
  input enable_reg_write;
  // Flag indicating if a branch was taken
  input branch_is_taken;

  //Write Back Stage
  // Output value of Stage 3
  output logic [0:127] wb_data;
  // Destination register for write back data
  output logic [0:6] wb_reg_addr;
  // Flag indicating if the write back data will be written to the Register Table
  output logic wb_enable_reg_write;

  //Internal Signals
  // Staging register for calculated values
  logic [3:0][0:127] delayed_rt_data;
  // Destination register for write back data
  output logic [1:0][0:6] delayed_rt_addr;
  // Flag indicating if the write back data will be written to the Register Table
  output logic [1:0] delayed_enable_reg_write;

  // 7-bit counter used for loops
  logic [6:0] i;

  // Define the maximum 32-bit signed value
  logic signed [31:0] max_value_32 = 32'h7FFFFFFF;
  // Define the minimum 32-bit signed value
  logic signed [31:0] min_value_32 = 32'h80000000;
  // Define the maximum 16-bit signed value
  logic signed [15:0] max_value_16 = 16'h7FFF;
  // Define the minimum 16-bit signed value
  logic signed [15:0] min_value_16 = 16'h8000;

  // A temporary variable used for intermediate computations
  logic [0:128] temporary_variable;

  always_comb begin
    wb_data = delayed_rt_data[0];
    wb_reg_addr = delayed_rt_addr[0];
    wb_enable_reg_write = delayed_enable_reg_write[0];
  end

  always_ff @(posedge clock) begin
    if (reset == 1) begin
      delayed_rt_data[1] <= 0;
      delayed_rt_addr[1] <= 0;
      delayed_enable_reg_write[1] <= 0;
      delayed_rt_data[0] <= 0;
      delayed_rt_addr[0] <= 0;
      delayed_enable_reg_write[0] <= 0;
      temporary_variable = 0;
    end else begin
      delayed_rt_data[1] <= delayed_rt_data[0];
      delayed_rt_addr[1] <= delayed_rt_addr[0];
      delayed_enable_reg_write[1] <= delayed_enable_reg_write[0];

      //nop : No Operation (Execute)
      if (instr_format == 0 && op_code == 0) begin
        delayed_rt_data[0] <= 0;
        delayed_rt_addr[0] <= 0;
        delayed_enable_reg_write[0] <= 0;
      end else begin
        delayed_rt_addr[0] <= dest_reg_addr;
        delayed_enable_reg_write[0] <= enable_reg_write;
        if (branch_is_taken) begin
          delayed_rt_data[0] = 0;
          delayed_rt_addr[0] = 0;
          delayed_enable_reg_write[0] = 0;
        end else if (instr_format == 0) begin
          case (op_code)
            // cg rt, ra, rb Carry Generate
            11'b00011000010: begin
              for (int i = 0; i < 16; i = i + 4) begin
                // Declare local variables
                bit [31:0] a_segment;
                bit [31:0] b_segment;
                bit [32:0] sum;
                // Extract 32-bit segments from src_reg_a and src_reg_b
                a_segment = src_reg_a[(i*32)+:32];
                b_segment = src_reg_b[(i*32)+:32];
                // Add src_reg_a and src_reg_b with carry-in of 0
                sum = {1'b0, a_segment} + {1'b0, b_segment};
                // Assign the result to delayed_rt_data[0]
                delayed_rt_data[0][(i*32)+:32] = sum[31:0];
                // Set carry flag based on comparison of src_reg_a and src_reg_b
                delayed_rt_data[0][((i+1)*32)] = (b_segment >= a_segment) ? 1'b1 : 1'b0;
              end
            end
            // Borrow Generate
            11'b00001000010: begin
              for (int i = 0; i < 16; i = i + 4) begin
                // Declare local variables
                bit [31:0] a_segment;
                bit [31:0] b_segment;
                bit [32:0] difference;
                // Extract 32-bit segments from src_reg_a and src_reg_b
                a_segment = src_reg_a[(i*32)+:32];
                b_segment = src_reg_b[(i*32)+:32];
                // Subtract src_reg_b from src_reg_a with borrow-in of 0
                difference = {1'b0, a_segment} - {1'b0, b_segment};
                // Assign the result to delayed_rt_data[0]
                delayed_rt_data[0][(i*32)+:32] = difference[31:0];
                // Set borrow flag based on comparison of src_reg_a and src_reg_b
                delayed_rt_data[0][((i+1)*32)] = (b_segment > a_segment) ? 1'b1 : 1'b0;
              end
            end
            //ah : Add Halfword
            11'b00011001000: begin
              for (int i = 0; i < 16; i = i + 1) begin
                // Declare the sum variable without initialization
                int sum;
                // Calculate the sum of src_reg_a and src_reg_b
                sum = $signed(src_reg_a[(i*16)+:16]) + $signed(src_reg_b[(i*16)+:16]);
                // Check for overflow and underflow conditions
                if (sum >= max_value_16) delayed_rt_data[0][(i*16)+:16] = max_value_16;
                else if (sum <= min_value_16) delayed_rt_data[0][(i*16)+:16] = min_value_16;
                else delayed_rt_data[0][(i*16)+:16] = sum;
              end
            end
            //ah : Add Word							
            11'b00011000000: begin
              for (int i = 0; i < 32; i = i + 1) begin
                // Declare the sum variable without initialization
                int sum;
                // Calculate the sum of src_reg_a and src_reg_b
                sum = $signed(src_reg_a[(i*32)+:32]) + $signed(src_reg_b[(i*32)+:32]);
                // Check for overflow and underflow conditions
                if (sum >= max_value_32) delayed_rt_data[0][(i*32)+:32] = max_value_32;
                else if (sum <= min_value_32) delayed_rt_data[0][(i*32)+:32] = min_value_32;
                else delayed_rt_data[0][(i*32)+:32] = sum;
              end
            end
            //sfh rt, ra, rb : Subtract from Halfword					
            11'b00001001000: begin
              for (int i = 0; i < 16; i = i + 1) begin
                // Declare the difference variable without initialization
                int difference;
                // Calculate the difference between src_reg_b and src_reg_a
                difference = $signed(src_reg_b[(i*16)+:16]) - $signed(src_reg_a[(i*16)+:16]);
                // Check for overflow and underflow conditions
                if (difference >= max_value_16) delayed_rt_data[0][(i*16)+:16] = max_value_16;
                else if (difference <= min_value_16) delayed_rt_data[0][(i*16)+:16] = min_value_16;
                else delayed_rt_data[0][(i*16)+:16] = difference;
              end
            end
            //sf rt, ra, rb : Subtract from Word
            11'b00001000000: begin
              for (int i = 0; i < 32; i = i + 1) begin
                // Declare the difference variable without initialization
                int difference;
                // Calculate the difference between src_reg_b and src_reg_a
                difference = $signed(src_reg_b[(i*32)+:32]) - $signed(src_reg_a[(i*32)+:32]);
                // Check for overflow and underflow conditions
                if (difference >= max_value_32) delayed_rt_data[0][(i*32)+:32] = max_value_32;
                else if (difference <= min_value_32) delayed_rt_data[0][(i*32)+:32] = min_value_32;
                else delayed_rt_data[0][(i*32)+:32] = difference;
              end
            end
            // and
            11'b00011000001: begin
              delayed_rt_data[0] = src_reg_a & src_reg_b;
            end
            // or
            11'b00001000001: begin
              delayed_rt_data[0] = src_reg_a | src_reg_b;
            end
            // xor
            11'b01001000001: begin
              delayed_rt_data[0] = src_reg_a ^ src_reg_b;
            end
            // nand
            11'b00011001001: begin
              delayed_rt_data[0] = ~(src_reg_a & src_reg_b);
            end
            // ceqh rt, ra, rb Compare Equal Halfword				
            11'b01111001000: begin
              for (int i = 0; i < 16; i = i + 2) begin
                // Check if the halfwords at position i in src_reg_a and src_reg_b are equal
                if (src_reg_a[(i*8)+:16] == src_reg_b[(i*8)+:16]) begin
                  // Set the result to 16'hFFFF if equal
                  delayed_rt_data[0][(i*8)+:16] = 16'hFFFF;
                end else begin
                  // Set the result to 16'h0000 if not equal
                  delayed_rt_data[0][(i*8)+:16] = 16'h0000;
                end
              end
            end
            // ceq rt, ra, rb Compare Equal Word			
            11'b01111000000: begin
              for (int i = 0; i < 16; i = i + 4) begin
                // Check if the words at position i in src_reg_a and src_reg_b are equal
                if (src_reg_a[(i*8)+:32] == src_reg_b[(i*8)+:32]) begin
                  // Set the result to 32'hFFFFFFFF if equal
                  delayed_rt_data[0][(i*8)+:32] = 32'hFFFFFFFF;
                end else begin
                  // Set the result to 32'h00000000 if not equal
                  delayed_rt_data[0][(i*8)+:32] = 32'h00000000;
                end
              end
            end
            // cgth rt, ra, rb Compare Greater Than Halfword				
            11'b01001001000: begin
              for (int i = 0; i < 16; i = i + 2) begin
                // Check if the halfwords at position i in src_reg_a is greater than src_reg_b
                if ($signed(src_reg_a[(i*8)+:16]) > $signed(src_reg_b[(i*8)+:16])) begin
                  // Set the result to 16'hFFFF if greater than
                  delayed_rt_data[0][(i*8)+:16] = 16'hFFFF;
                end else begin
                  // Set the result to 16'h0000 if not greater than
                  delayed_rt_data[0][(i*8)+:16] = 16'h0000;
                end
              end
            end
            // cgt rt, ra, rb Compare Greater Than Word	
            11'b01001000000: begin
              for (int i = 0; i < 16; i = i + 4) begin
                // Compare each word in src_reg_a and src_reg_b
                if ($signed(src_reg_a[(i*8)+:32]) > $signed(src_reg_b[(i*8)+:32])) begin
                  // Set to 32'hFFFFFFFF if src_reg_a > src_reg_b
                  delayed_rt_data[0][(i*8)+:32] = 32'hFFFFFFFF;
                end else begin
                  // Set to 32'h00000000 if src_reg_a <= src_reg_b
                  delayed_rt_data[0][(i*8)+:32] = 32'h00000000;
                end
              end
            end
            // clgtb rt, ra, rb Compare Logical Greater Than Byte				
            11'b01011010000: begin
              for (int i = 0; i < 16; i = i + 1) begin
                // Compare each byte in src_reg_a and src_reg_b
                if (src_reg_a[(i*8)+:8] > src_reg_b[(i*8)+:8]) begin
                  // Set to 8'hFF if src_reg_a > src_reg_b
                  delayed_rt_data[0][(i*8)+:8] = 8'hFF;
                end else begin
                  // Set to 8'h00 if src_reg_a <= src_reg_b
                  delayed_rt_data[0][(i*8)+:8] = 8'h00;
                end
              end
            end
            // clgth rt, ra, rb Compare Logical Greater Than Halfword				
            11'b01011001000: begin
              for (int i = 0; i < 16; i = i + 2) begin
                // Compare each halfword in src_reg_a and src_reg_b
                if (src_reg_a[(i*8)+:16] > src_reg_b[(i*8)+:16]) begin
                  // Set to 16'hFFFF if src_reg_a > src_reg_b
                  delayed_rt_data[0][(i*8)+:16] = 16'hFFFF;
                end else begin
                  // Set to 16'h0000 if src_reg_a <= src_reg_b
                  delayed_rt_data[0][(i*8)+:16] = 16'h0000;
                end
              end
            end
            // clgt rt, ra, rb Compare Logical Greater Than Word					
            11'b01011000000: begin
              for (int i = 0; i < 16; i = i + 4) begin
                // Compare each word in src_reg_a and src_reg_b
                if (src_reg_a[(i*8)+:32] > src_reg_b[(i*8)+:32]) begin
                  // Set to 32'hFFFFFFFF if src_reg_a > src_reg_b
                  delayed_rt_data[0][(i*8)+:32] = 32'hFFFFFFFF;
                end else begin
                  // Set to 32'h00000000 if src_reg_a <= src_reg_b
                  delayed_rt_data[0][(i*8)+:32] = 32'h00000000;
                end
              end
            end
            default begin
              delayed_rt_data[0] <= 0;
              delayed_rt_addr[0] <= 0;
              delayed_enable_reg_write[0] <= 0;
            end
          endcase
        end else if (instr_format == 4) begin  //RI10-type
          case (op_code)
            //ahi rt, ra, imm10 : Add Halfword Immediate	
            8'b00011101: begin
              for (int i = 0; i < 16; i = i + 1) begin
                // Calculate the sum of src_reg_a and the immediate value
                int sum;
                sum = $signed(src_reg_a[(i*16)+:16]) + $signed(imm_value[8:17]);
                // Clamp the sum within the specified range
                if (sum >= max_value_16) begin
                  delayed_rt_data[0][(i*16)+:16] = max_value_16;
                end else if (sum <= min_value_16) begin
                  delayed_rt_data[0][(i*16)+:16] = min_value_16;
                end else begin
                  delayed_rt_data[0][(i*16)+:16] = sum;
                end
              end
            end
            //ai rt, ra, imm10 : Add Word Immediate
            8'b00011100: begin
              for (int i = 0; i < 4; i = i + 1) begin
                // Calculate the sum of src_reg_a and the immediate value
                int sum;
                sum = $signed(src_reg_a[(i*32)+:32]) + $signed(imm_value[8:17]);
                // Clamp the sum within the specified range
                if (sum >= max_value_32) begin
                  delayed_rt_data[0][(i*32)+:32] = max_value_32;
                end else if (sum <= min_value_32) begin
                  delayed_rt_data[0][(i*32)+:32] = min_value_32;
                end else begin
                  delayed_rt_data[0][(i*32)+:32] = sum;
                end
              end
            end
            //sfhi rt, ra, imm10 : Subtract from Halfword Immediate				
            8'b00001101: begin
              for (int i = 0; i < 16; i = i + 1) begin
                // Calculate the difference between the immediate value and src_reg_a
                int difference;
                difference = $signed(imm_value[8:17]) - $signed(src_reg_a[(i*16)+:16]);
                // Clamp the difference within the specified range
                if (difference >= max_value_16) begin
                  delayed_rt_data[0][(i*16)+:16] = max_value_16;
                end else if (difference <= min_value_16) begin
                  delayed_rt_data[0][(i*16)+:16] = min_value_16;
                end else begin
                  delayed_rt_data[0][(i*16)+:16] = difference;
                end
              end
            end
            //sfi rt, ra, imm10 : Subtract from Word Immediate					
            8'b00001100: begin
              for (int i = 0; i < 32; i = i + 1) begin
                // Calculate the difference between the immediate value and src_reg_a
                int difference;
                difference = $signed(imm_value[8:17]) - $signed(src_reg_a[(i*32)+:32]);
                // Clamp the difference within the specified range
                if (difference >= max_value_32) begin
                  delayed_rt_data[0][(i*32)+:32] = max_value_32;
                end else if (difference <= min_value_32) begin
                  delayed_rt_data[0][(i*32)+:32] = min_value_32;
                end else begin
                  delayed_rt_data[0][(i*32)+:32] = difference;
                end
              end
            end
            // ceqhi rt, ra, imm10 Compare Equal Halfword Immediate				
            8'b01111101: begin
              // Extract the immediate value
              int imm_halfword;
              imm_halfword = {imm_value[8], imm_value[8:17]};
              // Iterate over each halfword in src_reg_a
              for (int i = 0; i < 16; i = i + 2) begin
                // Compare with the immediate value
                if (src_reg_a[(i*8)+:16] == imm_halfword) begin
                  delayed_rt_data[0][(i*8)+:16] = 16'hFFFF;
                end else begin
                  delayed_rt_data[0][(i*8)+:16] = 16'h0000;
                end
              end
            end
            // ceqi rt, ra, imm10 Compare Equal Word Immediate
            8'b01111100: begin
              // Extract the immediate value
              int imm_word;
              imm_word = {imm_value[8], imm_value[8:17]};
              // Iterate over each word in src_reg_a
              for (int i = 0; i < 16; i = i + 4) begin
                // Compare with the immediate value
                if (src_reg_a[(i*8)+:32] == imm_word) begin
                  delayed_rt_data[0][(i*8)+:32] = 32'hFFFFFFFF;
                end else begin
                  delayed_rt_data[0][(i*8)+:32] = 32'h00000000;
                end
              end
            end
            // cgthi rt, ra, imm10 Compare Greater Than Halfword Immediate					
            8'b01001101: begin
              // Extract the immediate value
              int imm_halfword;
              imm_halfword = {imm_value[8], imm_value[8:17]};
              // Iterate over each halfword in src_reg_a
              for (int i = 0; i < 16; i = i + 2) begin
                // Compare with the immediate value
                if ($signed(src_reg_a[(i*8)+:16]) > $signed(imm_halfword)) begin
                  delayed_rt_data[0][(i*8)+:16] = 16'hFFFF;
                end else begin
                  delayed_rt_data[0][(i*8)+:16] = 16'h0000;
                end
              end
            end
            // cgti rt, ra, imm10 Compare Greater Than Word Immediate
            8'b01001100: begin
              // Extract the immediate value
              int imm_word;
              imm_word = {imm_value[8], imm_value[8:17]};
              // Iterate over each word in src_reg_a
              for (int i = 0; i < 16; i = i + 4) begin
                // Compare with the immediate value
                if ($signed(src_reg_a[(i*8)+:32]) > $signed(imm_word)) begin
                  delayed_rt_data[0][(i*8)+:32] = 32'hFFFFFFFF;
                end else begin
                  delayed_rt_data[0][(i*8)+:32] = 32'h00000000;
                end
              end
            end
            // clgtbi rt, ra, imm10 Compare Logical Greater Than Byte Immediate
            8'b01011110: begin
              // Extract the immediate value
              int imm_byte;
              imm_byte = imm_value[10:17];
              // Iterate over each byte in src_reg_a
              for (int i = 0; i < 16; i = i + 1) begin
                // Compare with the immediate value
                if ($unsigned(src_reg_a[(i*8)+:8]) > $unsigned(imm_byte)) begin
                  delayed_rt_data[0][(i*8)+:8] = 8'hFF;
                end else begin
                  delayed_rt_data[0][(i*8)+:8] = 8'h00;
                end
              end
            end
            // clgthi rt, ra, imm10 Compare Logical Greater Than Halfword Immediate
            8'b01011101: begin
              // Extract the immediate value
              shortint imm_halfword;
              imm_halfword = {imm_value[8], imm_value[8:17]};
              // Iterate over each halfword in src_reg_a
              for (int i = 0; i < 16; i = i + 2) begin
                // Compare with the immediate halfword value
                if ($unsigned(src_reg_a[(i*8)+:16]) > $unsigned(imm_halfword)) begin
                  delayed_rt_data[0][(i*8)+:16] = 16'hFFFF;
                end else begin
                  delayed_rt_data[0][(i*8)+:16] = 16'h0000;
                end
              end
            end
            // clgti rt, ra, imm10 Compare Logical Greater Than Word Immediate
            8'b01011100: begin
              // Extract the immediate value
              bit [31:0] imm_word;
              imm_word = imm_value[8:17];
              // Iterate over each word in src_reg_a
              for (int i = 0; i < 16; i = i + 4) begin
                // Compare with the immediate word value
                if ($unsigned(src_reg_a[(i*8)+:32]) > $unsigned(imm_word)) begin
                  delayed_rt_data[0][(i*8)+:32] = 32'hFFFFFFFF;
                end else begin
                  delayed_rt_data[0][(i*8)+:32] = 32'h00000000;
                end
              end
            end
            default begin
              delayed_rt_data[0] = 0;
              delayed_rt_addr[0] = 0;
              delayed_enable_reg_write[0] = 0;
              temporary_variable = 0;
            end
          endcase
        end else if (instr_format == 5) begin
          case (op_code)
            // ilh rt, imm16 Immediate Load Halfword			
            9'b010000011: begin
              // Extract the immediate value
              bit [15:0] imm_halfword;
              imm_halfword = imm_value[2:17];
              // Iterate over each halfword in delayed_rt_data
              for (int i = 0; i < 16; i = i + 2) begin
                // Load the immediate halfword value
                delayed_rt_data[0][(i*8)+:16] = imm_halfword;
              end
            end
            // ilhu rt, imm16 Immediate Load Halfword Upper					
            9'b010000010: begin
              // Extract the immediate value
              bit [15:0] imm_halfword_upper;
              imm_halfword_upper = imm_value[2:17];
              // Iterate over each word in delayed_rt_data
              for (int i = 0; i < 16; i = i + 4) begin
                // Load the immediate halfword upper value with zero-extended lower halfword
                delayed_rt_data[0][(i*8)+:32] = {imm_halfword_upper, 16'h0000};
              end
            end
            // il rt, imm16 Immediate Load Word						
            9'b010000001: begin
              // Extract the immediate value
              bit [15:0] imm_word;
              imm_word = imm_value[2:17];
              // Iterate over each word in delayed_rt_data
              for (int i = 0; i < 4; i = i + 1) begin
                // Load the immediate word value into delayed_rt_data
                delayed_rt_data[0][(i*32)+:32] = $signed(imm_word);
              end
            end
            // iohl rt, imm16 Immediate Or Halfword Lower						
            9'b011000001: begin
              // Extract the immediate value
              bit [15:0] imm_halfword;
              imm_halfword = imm_value[2:17];
              // Iterate over each word in delayed_rt_data
              for (int i = 0; i < 16; i = i + 4) begin
                // Load the immediate halfword value into the lower half of each word in delayed_rt_data
                delayed_rt_data[0][(i*8)+:16] = store_reg[(i*8)+:16] | imm_halfword;
                // Copy the upper half from store_reg
                delayed_rt_data[0][((i+2)*8)+:16] = store_reg[((i+2)*8)+:16];
              end
            end
            default begin
              delayed_rt_data[0] = 0;
              delayed_rt_addr[0] = 0;
              delayed_enable_reg_write[0] = 0;
              temporary_variable = 0;
            end
          endcase
        end else if (instr_format == 6) begin
          case (op_code)
            // ila rt, imm18 Immediate Load Address					
            7'b0100001: begin
              // Extract the immediate value
              bit [17:0] imm_address;
              imm_address = imm_value[0:17];
              // Iterate over each word in delayed_rt_data
              for (int i = 0; i < 16; i = i + 4) begin
                // Load the immediate address value into the lower half of each word in delayed_rt_data
                delayed_rt_data[0][(i*8)+:18] = imm_address;
                // Copy the upper half from store_reg
                delayed_rt_data[0][((i+2)*8)+:14] = store_reg[((i+2)*8)+:14];
              end
            end
            // addx rt, ra, rb Add Extended							
            11'b01101000000: begin
              // Iterate over each word in delayed_rt_data
              for (int i = 0; i < 4; i = i + 1) begin
                // Calculate the sum with extension
                bit signed_sum;
                signed_sum = $signed(src_reg_a[(i*32)+:32]) + $signed(src_reg_b[(i*32)+:32]) +
                    $signed(store_reg[(i*32)+:32]);
                // Check for overflow
                if (signed_sum >= max_value_32) begin
                  delayed_rt_data[0][(i*32)+:32] = max_value_32;
                end else if (signed_sum <= min_value_32) begin
                  delayed_rt_data[0][(i*32)+:32] = min_value_32;
                end else begin
                  delayed_rt_data[0][(i*32)+:32] = signed_sum;
                end
              end
            end
            // sfx rt, ra, rb Subtract from Extended
            11'b01101000001: begin
              // Iterate over each word in delayed_rt_data
              for (int i = 0; i < 4; i = i + 1) begin
                // Calculate the difference with extension
                bit signed_diff;
                signed_diff = $signed(store_reg[(i*32)+:32]) - $signed(src_reg_b[(i*32)+:32]) -
                    $signed(src_reg_a[(i*32)+:32]);
                // Check for overflow
                if (signed_diff >= max_value_32) begin
                  delayed_rt_data[0][(i*32)+:32] = max_value_32;
                end else if (signed_diff <= min_value_32) begin
                  delayed_rt_data[0][(i*32)+:32] = min_value_32;
                end else begin
                  delayed_rt_data[0][(i*32)+:32] = signed_diff;
                end
              end
            end
            default begin
              delayed_rt_data[0] = 0;
              delayed_rt_addr[0] = 0;
              delayed_enable_reg_write[0] = 0;
              temporary_variable = 0;
            end
          endcase
        end
      end
    end
  end
endmodule
