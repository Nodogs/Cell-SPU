/***********************************************************************************************************
 * Module: Permute
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module performs various operations based on the opcode and instruction format, such as shifting,
 *     rotating, and storing data. It handles both register forwarding and write-back stages.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Decoded opcode truncated based on instr_format
 *   - instr_format: Format of the instruction, used with op_code and imm_value
 *   - dest_reg_addr: Destination register address
 *   - src_reg_a: Value of source register A
 *   - src_reg_b: Value of source register B
 *   - imm_value: Immediate value truncated based on instr_format
 *   - enable_reg_write: Flag indicating whether the current instruction writes to the register table
 *   - branch_is_taken: Signal indicating if a branch was taken
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Output value of Stage 3
 *   - wb_reg_addr: Destination register for wb_data
 *   - wb_enable_reg_write: Will wb_data write to the register table
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - delayed_rt_data: Staging register for calculated values
 *   - delayed_rt_addr: Destination register for wb_data, delayed by one clock cycle
 *   - delayed_enable_reg_write: Will wb_data write to the register table, delayed by one clock cycle
 ***********************************************************************************************************/

module Permute (
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

  // Register File/Forwarding Stage
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
  // Was branch taken?
  input branch_is_taken;

  // Write Back Stage
  // Output value of Stage 3
  output logic [0:127] wb_data;
  // Destination register for write back data
  output logic [0:6] wb_reg_addr;
  // Flag indicating if the write back data will be written to the Register Table
  output logic wb_enable_reg_write;

  // Internal Signals
  // Staging register for calculated values
  logic [3:0][0:127] delayed_rt_data;
  // Destination register for write back data
  output logic [3:0][0:6] delayed_rt_addr;
  // Flag indicating if the write back data will be written to the Register Table
  output logic [3:0] delayed_enable_reg_write;

  // 7-bit counter used for loops
  logic [  6:0] i;
  // Temporary variables used for intermediate calculations
  logic [0:127] temporary_variable;

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
      temporary_variable <= 0;
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
      //nop : No Operation (Load)
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
            //shlqbi : Shift Left Quadword by Bits
            11'b00111011011: begin
              int shift_amount;
              shift_amount = src_reg_b[29:31];
              delayed_rt_data[0] <= src_reg_a << shift_amount;
            end
            //shlqby rt, ra, rb : Shift Left Quadword by Bytes
            11'b00111011111: begin
              int shift_amount;
              shift_amount = src_reg_b[27:31] * 8;
              delayed_rt_data[0] <= src_reg_a << shift_amount;
            end
            //rotqby rt,ra,rb Rotate Quadword by Bytes
            11'b00111011100: begin
              temporary_variable = src_reg_b[28:31];
              for (int b = 0; b <= 15; b++) begin
                if (b + temporary_variable < 16) begin
                  for (int i = b * 8; i < (b * 8 + 8); i++) begin
                    delayed_rt_data[0][i] = src_reg_a[i+temporary_variable*8];
                  end
                end else begin
                  for (int i = b * 8; i < (b * 8 + 8); i++) begin
                    delayed_rt_data[0][i] = src_reg_a[i+temporary_variable*8-16*8];
                  end
                end
              end
            end
          endcase
        end else if (instr_format == 2) begin
          case (op_code)
            //shlqbi : Shift Left Quadword by Bits	 
            11'b00111011011: begin
              int shift_amount;
              int new_index;
              shift_amount = imm_value & 7'b0000111;
              // Initialize delayed_rt_data[0] to avoid uninitialized elements
              for (int i = 0; i < 128; i++) begin
                delayed_rt_data[0][i] = 0;
              end
              for (int b = 0; b < 128; b++) begin
                new_index = b + shift_amount;
                if (new_index < 128) begin
                  delayed_rt_data[0][b] = src_reg_a[new_index];
                end
              end
            end
            //shlqbii rt, ra, value Shift Left Quadword by Bits Immediate
            11'b00111111011: begin
              int shift_amount;
              int new_index;
              shift_amount = imm_value & 7'b0001111;
              // Initialize delayed_rt_data[0] to avoid uninitialized elements
              for (int i = 0; i < 128; i++) begin
                delayed_rt_data[0][i] = 0;
              end
              for (int b = 0; b < 128; b = b + 1) begin
                new_index = b + shift_amount;
                if (new_index < 128) begin
                  delayed_rt_data[0][b] = src_reg_a[new_index];
                end
              end
            end
            //shlqbyi rt,ra,value Shift Left Quadword by Bytes Immediate
            11'b00111111111: begin
              int shift_amount;
              shift_amount = imm_value & 7'b0001111;
              // Initialize delayed_rt_data[0] to avoid uninitialized elements
              for (int i = 0; i < 128; i++) begin
                delayed_rt_data[0][i] = 0;
              end
              for (int b = 0; b < 16; b++) begin
                if (b + shift_amount < 16) begin
                  for (int i = 0; i < 8; i++) begin
                    delayed_rt_data[0][b*8+i] = src_reg_a[(b+shift_amount)*8+i];
                  end
                end
              end
            end
            //shlqbybi rt,ra,rb Shift Left Quadword by Bytes from Bit Shift Count	
            11'b00111001111: begin
              int bit_shift_count;
              bit_shift_count = src_reg_b[24:28];
              // Initialize delayed_rt_data[0] to avoid uninitialized elements
              for (int i = 0; i < 128; i++) begin
                delayed_rt_data[0][i] = 8'h00;
              end
              for (int b = 0; b < 16; b = b + 1) begin
                if (b + bit_shift_count < 16) begin
                  delayed_rt_data[0][b*8+:8] = src_reg_a[(b+bit_shift_count)*8+:8];
                end
              end
            end
            //rotqbyi rt, ra, imm7 Rotate Quadword by Bytes Immediate 
            11'b00111111100: begin
              int rotation_amount;
              rotation_amount = imm_value & 7'b0001111;
              // Initialize delayed_rt_data[0] to avoid uninitialized elements
              for (int i = 0; i < 128; i++) begin
                delayed_rt_data[0][i] = 0;
              end
              for (int b = 0; b < 16; b++) begin
                if (b + rotation_amount < 16) begin
                  for (int i = 0; i < 8; i++) begin
                    delayed_rt_data[0][b*8+i] = src_reg_a[(b+rotation_amount)*8+i];
                  end
                end else begin
                  for (int i = 0; i < 8; i++) begin
                    delayed_rt_data[0][b*8+i] = src_reg_a[(b+rotation_amount-16)*8+i];
                  end
                end
              end
            end
            //rotqbybi rt,ra,rb Rotate Quadword by Bytes from Bit Shift Count
            11'b00111001100: begin
              int bit_shift_count;
              bit_shift_count = src_reg_b[24:28];
              // Initialize delayed_rt_data[0] to avoid uninitialized elements
              for (int i = 0; i < 128; i++) begin
                delayed_rt_data[0][i] = 0;
              end
              for (int b = 0; b < 16; b = b + 1) begin
                if (b + bit_shift_count < 16) begin
                  delayed_rt_data[0][b*8+:8] = src_reg_a[(b+bit_shift_count)*8+:8];
                end else begin
                  delayed_rt_data[0][b*8+:8] = src_reg_a[(b+bit_shift_count-16)*8+:8];
                end
              end
            end
            default begin
              delayed_rt_data[0] = 0;
              delayed_rt_addr[0] = 0;
              delayed_enable_reg_write[0] = 0;
            end
          endcase
        end
      end
    end
  end
endmodule
