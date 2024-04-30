/***********************************************************************************************************
 * Module: Simple Fixed 2
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

module Simple_Fixed_2 (
    clock,
    reset,
    op_code,
    instr_format,
    dest_reg_addr,
    src_reg_a,
    src_reg_b,
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
  input [0:127] src_reg_a, src_reg_b;
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
  output logic [3:0][0:6] delayed_rt_addr;
  // Flag indicating if the write back data will be written to the Register Table
  output logic [3:0] delayed_enable_reg_write;

  // 7-bit counter used for loops
  logic [6:0] i;
  // A temporary variable used for intermediate computations
  logic [0:127] temporary_variable, s;

  always_comb begin
    wb_data = delayed_rt_data[2];
    wb_reg_addr = delayed_rt_addr[2];
    wb_enable_reg_write = delayed_enable_reg_write[2];
  end

  always_ff @(posedge clock) begin
    if (reset == 1) begin
      delayed_rt_data[3] <= 0;
      delayed_rt_addr[3] <= 0;
      delayed_enable_reg_write[3] <= 0;
      for (i = 0; i < 3; i = i + 1) begin
        delayed_rt_data[i] <= 0;
        delayed_rt_addr[i] <= 0;
        delayed_enable_reg_write[i] <= 0;
      end
    end else begin
      delayed_rt_data[3] <= delayed_rt_data[2];
      delayed_rt_addr[3] <= delayed_rt_addr[2];
      delayed_enable_reg_write[3] <= delayed_enable_reg_write[2];

      delayed_rt_data[2] <= delayed_rt_data[1];
      delayed_rt_addr[2] <= delayed_rt_addr[1];
      delayed_enable_reg_write[2] <= delayed_enable_reg_write[1];

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
          delayed_rt_data[0] <= 0;
          delayed_rt_addr[0] <= 0;
          delayed_enable_reg_write[0] <= 0;
        end else if (instr_format == 0) begin
          case (op_code)
            //shlh : Shift Left Halfword						
            11'b00001011111: begin
              // Iterate over each halfword in src_reg_b and compute the shifted result
              for (int i = 0; i < 8; i = i + 1) begin
                // Extract the lower 5 bits of src_reg_b
                bit [4:0] shift_amount;
                shift_amount = src_reg_b[(i*16)+:5];
                // Check if shift_amount is less than 16
                if (shift_amount < 16) begin
                  // Perform left shift of src_reg_a by shift_amount
                  delayed_rt_data[0][(i*16)+:16] = src_reg_a[(i*16)+:16] << shift_amount;
                end else begin
                  // If shift_amount is 16 or greater, set the result to 0
                  delayed_rt_data[0][(i*16)+:16] = 16'h0000;
                end
              end
            end
            // shlhi rt, ra, value : Shift Left Halfword Immediate					
            11'b00001111111: begin
              for (i = 0; i <= 15; i = i + 2) begin
                s = (imm_value & 7'h1F);
                temporary_variable = src_reg_a[(i*8)+:16];
                for (int b = 0; b < 16; b = b + 1) begin
                  if (b + s < 16) delayed_rt_data[0][(i*8)+b] = temporary_variable[b+s];
                  else delayed_rt_data[0][(i*8)+b] = 0;
                end
              end
            end
            //shl rt, ra, rb : Shift Left Word						
            11'b00001011011: begin
              // Iterate over each word in src_reg_a
              for (int i = 0; i < 16; i = i + 4) begin
                // Extract the lower 6 bits of src_reg_b to determine the shift amount
                bit [5:0] shift_amount;
                shift_amount = src_reg_b[(i*8)+:32] & 32'h0000003F;
                // Perform left shift if the shift amount is within the word size
                delayed_rt_data[0][(i * 8) +: 32] = (shift_amount < 32) ? (src_reg_a[(i * 8) +: 32] << shift_amount) : 32'h00000000;
              end
            end
            //roth rt, ra, rb : Rotate Halfword						
            11'b00001011100: begin
              for (i = 0; i <= 15; i = i + 2) begin
                temporary_variable[0:15] = src_reg_a[(i*8)+:16];
                for (int b = 0; b < 16; b = b + 1) begin
                  if ((b + (src_reg_b[(i*8)+:16] & 16'h000F)) < 16) begin
                    delayed_rt_data[0][(i*8)+b] = temporary_variable[b+(src_reg_b[(i*8) +: 16] & 16'h000F)];
                  end else begin
                    delayed_rt_data[0][(i*8)+b] = temporary_variable[b+(src_reg_b[(i*8) +: 16] & 16'h000F)-16];
                  end
                end
              end
            end
            //rot rt, ra, rb : Rotate Word						
            11'b00001011000: begin
              for (i = 0; i <= 15; i = i + 4) begin
                temporary_variable[0:31] = src_reg_a[(i*8)+:32];
                for (int b = 0; b < 32; b = b + 1) begin
                  if ((b + (src_reg_b[(i*8)+:32] & 32'h0000001F)) < 32) begin
                    delayed_rt_data[0][(i*8)+b] = temporary_variable[b+(src_reg_b[(i*8) +: 32] & 32'h0000001F)];
                  end else begin
                    delayed_rt_data[0][(i*8)+b] = temporary_variable[b+(src_reg_b[(i*8) +: 32] & 32'h0000001F)-32];
                  end
                end
              end
            end
            //shli rt, ra, imm7 : Shift Left Word Immediate					
            11'b00001111011: begin
              // Extract the shift amount from imm_value
              bit [6:0] shift_amount;
              shift_amount = imm_value[11:17];
              // Iterate over each word in src_reg_a
              for (int i = 0; i <= 15; i = i + 4) begin
                // Assign the current word to a temporary variable
                bit [31:0] temporary_variable;
                temporary_variable = src_reg_a[(i*8)+:32];
                // Perform left shift based on the shift_amount
                for (int b = 0; b < 32; b = b + 1) begin
                  // Check if the shifted index is within bounds
                  if (b + shift_amount < 32)
                    delayed_rt_data[0][(i*8)+b] = temporary_variable[b+shift_amount];
                  else delayed_rt_data[0][(i*8)+b] = 0;
                end
              end
            end
            // rothi rt, ra, imm7 : Rotate Halfword Immediate				
            11'b00001111100: begin
              // Extract the shift amount from imm_value
              bit [6:0] shift_amount;
              shift_amount = imm_value[11:17];
              // Iterate over each halfword in src_reg_a
              for (int i = 0; i <= 15; i = i + 2) begin
                // Assign the current halfword to a temporary variable
                bit [15:0] temporary_variable;
                temporary_variable = src_reg_a[(i*8)+:16];
                // Perform rotation based on the shift_amount
                for (int b = 0; b < 16; b = b + 1) begin
                  // Calculate the rotated index
                  int rotated_index;
                  rotated_index = (b + (shift_amount & 16'h000F)) % 16;
                  // Assign the rotated value to delayed_rt_data
                  delayed_rt_data[0][(i*8)+b] = temporary_variable[rotated_index];
                end
              end
            end
            //roti rt, ra, imm7 : Rotate Word Immediate					
            11'b00001111000: begin
              // Extract the shift amount from imm_value
              bit [6:0] shift_amount;
              shift_amount = imm_value[11:17];
              // Iterate over each word in src_reg_a
              for (int i = 0; i <= 15; i = i + 4) begin
                // Assign the current word to a temporary variable
                bit [31:0] temporary_variable;
                temporary_variable = src_reg_a[(i*8)+:32];
                // Perform rotation based on the shift_amount
                for (int b = 0; b < 32; b = b + 1) begin
                  // Calculate the rotated index
                  int rotated_index;
                  rotated_index = (b + (shift_amount & 32'h0000001F)) % 32;
                  // Assign the rotated value to delayed_rt_data
                  delayed_rt_data[0][(i*8)+b] = temporary_variable[rotated_index];
                end
              end
            end
          endcase
        end
      end
    end
  end
endmodule
