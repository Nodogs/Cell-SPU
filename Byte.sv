/***********************************************************************************************************
 * Module: Byte
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module simulates the execution of byte-level instructions, providing calculated results 
 *     to the Write Back stage.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Decoded opcode truncated based on format
 *   - instr_format: Format of the instruction, used with op_code and imm_value
 *   - dest_reg_addr: Destination register address
 *   - src_reg_a: Value of source register A
 *   - src_reg_b: Value of source register B
 *   - imm_value: Immediate value truncated based on format
 *   - enable_reg_write: Flag indicating whether current instruction writes to RegTable
 *   - branch_is_taken: Was branch taken?
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Output value of Stage 3
 *   - wb_reg_addr: Destination register for wb_data
 *   - wb_enable_reg_write: Will wb_data write to RegTable
 *   - delayed_rt_addr: Destination register for wb_data, delayed by one clock cycle
 *   - delayed_enable_reg_write: Will wb_data write to RegTable, delayed by one clock cycle
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - delayed_rt_data: Staging register for calculated values, delayed by one clock cycle
 ***********************************************************************************************************/

module Byte (
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

  // Temporary variable used as an incrementing counter
  logic [3:0] temporary_variable;

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
      for (int i = 0; i < 3; i = i + 1) begin
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
            //cntb : Count Ones in Bytes
            11'b01010110100: begin
              automatic int i;
              for (i = 0; i < 16; i = i + 1) begin
                automatic int temporary_variable = 0;
                automatic int j;
                for (j = 0; j < 8; j = j + 1) begin
                  if (src_reg_a[(i*8)+j] == 1'b1) temporary_variable = temporary_variable + 1;
                end
                delayed_rt_data[0][(i*8)+:8] <= temporary_variable;
              end
            end
            //avgb : Average Bytes
            11'b00011010011: begin
              automatic int i = 0;
              while (i < 16) begin
                automatic logic [9:0] temp_a = {2'b00, src_reg_a[(i*8)+:8]};
                automatic logic [9:0] temp_b = {2'b00, src_reg_b[(i*8)+:8]};
                delayed_rt_data[0][(i*8)+:8] <= (temp_a + temp_b + 1) >> 1;
                i = i + 1;
              end
            end
            //absdb : Absolute Differences of Bytes
            11'b00001010011: begin
              automatic int i = 0;
              while (i < 16) begin
                automatic logic [7:0] temp_a = src_reg_a[(i*8)+:8];
                automatic logic [7:0] temp_b = src_reg_b[(i*8)+:8];
                delayed_rt_data[0][(i*8) +: 8] <= (temp_a > temp_b) ? (temp_a - temp_b) : (temp_b - temp_a);
                i = i + 1;
              end
            end
            //sumb : Sum Bytes into Halfwords
            11'b01001010011: begin
              automatic int i = 0;
              while (i < 4) begin
                automatic int sum_b = 0;
                automatic int sum_a = 0;
                automatic int j = 0;
                while (j < 4) begin
                  sum_b += $signed(src_reg_b[(i*32)+(j*8)+:8]);
                  sum_a += $signed(src_reg_a[(i*32)+(j*8)+:8]);
                  j = j + 1;
                end
                delayed_rt_data[0][(i*32)+:16] <= sum_b;
                delayed_rt_data[0][(i*32)+16+:16] <= sum_a;
                i = i + 1;
              end
            end
            default begin
              delayed_rt_data[0] <= 0;
              delayed_rt_addr[0] <= 0;
              delayed_enable_reg_write[0] <= 0;
            end
          endcase
        end else begin
          delayed_rt_data[0] <= 0;
          delayed_rt_addr[0] <= 0;
          delayed_enable_reg_write[0] <= 0;
        end
      end
    end
  end
endmodule
