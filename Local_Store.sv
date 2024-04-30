/***********************************************************************************************************
 * Module: Local Store
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module handles the local memory operations such as loading and storing quadwords. It manages the
 *     write-back stage, delayed register data, and enables register write based on the instruction format and
 *     opcode.
 *-----------------------------------------------------------------------------------------------------------
 * Inputs:
 *   - clock: Clock signal
 *   - reset: Reset signal
 *   - op_code: Decoded opcode truncated based on instr_format
 *   - instr_format: Format of the instruction, used with op_code and imm_value
 *   - dest_reg_addr: Destination register address
 *   - src_reg_a: Value of source register A
 *   - src_reg_b: Value of source register B
 *   - store_reg: Value to be stored in memory
 *   - imm_value: Immediate value truncated based on instr_format
 *   - enable_reg_write: Flag indicating whether the current instruction writes to the register table
 *   - branch_is_taken: Signal indicating if a branch was taken
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Output value of Stage 3
 *   - wb_reg_addr: Destination register for wb_data
 *   - wb_enable_reg_write: Will wb_data write to the register table
 *   - delayed_rt_addr: Destination register for wb_data, delayed by one clock cycle
 *   - delayed_enable_reg_write: Will wb_data write to the register table, delayed by one clock cycle
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - delayed_rt_data: Staging register for calculated values, delayed by one clock cycle
 *   - local_mem: 32KB local memory for storing quadwords
 *   - program_counter: Current program counter value
 ***********************************************************************************************************/

module Local_Store (
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

  // Register File/Forwarding Stage
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
  logic [5:0][0:127] delayed_rt_data;
  // Destination register for write back data
  output logic [5:0][0:6] delayed_rt_addr;
  // Flag indicating if the write back data will be written to the Register Table
  output logic [5:0] delayed_enable_reg_write;
  // 32KB local memory
  logic [0:127] local_mem[0:2047];
  // Program Counter
  logic [31:0] program_counter;

  always_comb begin
    wb_data = delayed_rt_data[4];
    wb_reg_addr = delayed_rt_addr[4];
    wb_enable_reg_write = delayed_enable_reg_write[4];
  end

  always_ff @(posedge clock) begin
    if (reset == 1) begin
      delayed_rt_data[5] <= 0;
      delayed_rt_addr[5] <= 0;
      delayed_enable_reg_write[5] <= 0;
      for (int i = 0; i < 5; i = i + 1) begin
        delayed_rt_data[i] <= 0;
        delayed_rt_addr[i] <= 0;
        delayed_enable_reg_write[i] <= 0;
      end
      for (logic [0:11] i = 0; i < 2048; i = i + 1) begin
        //mem[i] <= 0;
        local_mem[i] <= {i * 4, (i * 4 + 1), (i * 4 + 2), (i * 4 + 3)};
      end
    end else begin
      // Increment the program counter by 4, assuming each instruction is 4 bytes long
      program_counter <= program_counter + 4;
      delayed_rt_data[5] <= delayed_rt_data[4];
      delayed_rt_addr[5] <= delayed_rt_addr[4];
      delayed_enable_reg_write[5] <= delayed_enable_reg_write[4];
      for (int i = 0; i < 4; i = i + 1) begin
        delayed_rt_data[i+1] <= delayed_rt_data[i];
        delayed_rt_addr[i+1] <= delayed_rt_addr[i];
        delayed_enable_reg_write[i+1] <= delayed_enable_reg_write[i];
      end
      //nop : No Operation (Load)
      if (instr_format == 0 && op_code == 0) begin
        delayed_rt_data[0] <= 0;
        delayed_rt_addr[0] <= 0;
        delayed_enable_reg_write[0] <= 0;
      end else begin
        delayed_rt_addr[0] <= dest_reg_addr;
        delayed_enable_reg_write[0] <= enable_reg_write;
        // If a branch was taken in the last cycle, cancel the last instruction
        if (branch_is_taken) begin
          delayed_rt_data[0] <= 0;
          delayed_rt_addr[0] <= 0;
          delayed_enable_reg_write[0] <= 0;
        end else if (instr_format == 0) begin
          case (op_code)
            //lqx : Load Quadword (x-form)
            11'b00111000100: begin
              int addr_sum;
              addr_sum = $signed(src_reg_a[0:31]) + $signed(src_reg_b[0:31]);
              delayed_rt_data[0] <= local_mem[addr_sum];
            end
            //stqx : Store Quadword (x-form)
            11'b00101000100: begin
              int addr_sum;
              addr_sum = $signed(src_reg_a[0:31]) + $signed(src_reg_b[0:31]);
              local_mem[addr_sum] <= store_reg;
              delayed_enable_reg_write[0] <= 0;
            end
            default begin
              delayed_rt_data[0] <= 0;
              delayed_rt_addr[0] <= 0;
              delayed_enable_reg_write[0] <= 0;
            end
          endcase
        end else if (instr_format == 4) begin
          case (op_code[3:10])
            //lqd : Load Quadword (d-form)
            8'b00110100: begin
              int addr_sum;
              addr_sum = $signed(src_reg_a[0:31]) + $signed(imm_value[8:17]);
              delayed_rt_data[0] <= local_mem[addr_sum];
            end
            //stqd : Store Quadword (d-form)
            8'b00100100: begin
              int addr_sum;
              addr_sum = $signed(src_reg_a[0:31]) + $signed(imm_value[8:17]);
              local_mem[addr_sum] <= store_reg;
              delayed_enable_reg_write[0] <= 0;
            end
            default begin
              delayed_rt_data[0] <= 0;
              delayed_rt_addr[0] <= 0;
              delayed_enable_reg_write[0] <= 0;
            end
          endcase
        end else if (instr_format == 5) begin
          case (op_code[2:10])
            //lqa : Load Quadword (a-form)
            9'b001100001: begin
              int addr;
              addr = $signed(imm_value[2:17]);
              delayed_rt_data[0] <= local_mem[addr];
            end
            //stqa : Store Quadword (a-form)
            9'b001000001: begin
              int addr;
              addr = $signed(imm_value[2:17]);
              local_mem[addr] <= store_reg;
              delayed_enable_reg_write[0] <= 0;
            end
            //lqr: Load Quadword Instruction Relative (a-form)
            9'b001100111: begin
              //Calculate Load Store Address (LSA)
              reg [31:0] LSA;
              LSA = (({$signed(imm_value[15]), imm_value[2:15], 2'b00}) + program_counter) &
                  32'hFFFFFFF0;
              //Load value from Local Memory using LSA
              delayed_rt_data[0] <= local_mem[LSA[31:2]];
            end
            //stqr: Store Quadword Instruction Relative (a-form)
            9'b001000111: begin
              //Calculate Load Store Address (LSA)
              reg [31:0] LSA;
              LSA = (({$signed(imm_value[15]), imm_value[2:15], 2'b00}) + program_counter) &
                  32'hFFFFFFF0;
              //Store value to Local Memory using LSA
              local_mem[LSA[31:2]] <= store_reg;
              //No need to set delayed_enable_reg_write[0] as it's a store operation
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
