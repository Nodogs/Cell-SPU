/***********************************************************************************************************
 * Module: Single Precision
 * Author: Noah Merone
 *-----------------------------------------------------------------------------------------------------------
 * Description:
 *     This module implements a single precision unit. It performs various arithmetic 
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
 *   - temporary_register_c: Temporary register C
 *   - imm_value: Immediate value
 *   - enable_reg_write: Flag indicating register write operation
 *   - branch_is_taken: Flag indicating branch taken
 *-----------------------------------------------------------------------------------------------------------
 * Outputs:
 *   - wb_data: Data to be written back to the register file
 *   - wb_reg_addr: Address of the register to be written back
 *   - wb_enable_reg_write: Flag indicating register write operation in WB stage
 *   - int_data: Output data of the module
 *   - int_reg_addr: Destination register address for int_data
 *   - int_enable_reg_write: Flag indicating register write operation for int_data
 *-----------------------------------------------------------------------------------------------------------
 * Internal Signals:
 *   - delayed_rt_data: Delayed register data for forwarding
 *   - delayed_rt_addr: Delayed register address for forwarding
 *   - delayed_enable_reg_write: Delayed register write flag for forwarding
 *   - int_operation_flag: Flag indicating the type of operation
 ***********************************************************************************************************/

module Single_Precision (
    clock,
    reset,
    op_code,
    instr_format,
    dest_reg_addr,
    src_reg_a,
    src_reg_b,
    temporary_register_c,
    imm_value,
    enable_reg_write,
    wb_data,
    wb_reg_addr,
    wb_enable_reg_write,
    int_data,
    int_reg_addr,
    int_enable_reg_write,
    branch_is_taken,
    delayed_rt_addr,
    delayed_enable_reg_write,
    int_operation_flag
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
  input [0:127] src_reg_a, src_reg_b, temporary_register_c;
  // Immediate value, truncated based on instruction format
  input [0:17] imm_value;
  // Flag indicating if the current instruction will write to the Register Table
  input enable_reg_write;
  // Flag indicating if a branch was taken
  input branch_is_taken;

  //Write Back Stage
  // Output value of Stage 6
  output logic [0:127] wb_data;
  // Destination register for write back data
  output logic [0:6] wb_reg_addr;
  // Flag indicating if the write back data will be written to the Register Table	
  output logic wb_enable_reg_write;

  //Integer Stage
  // Output value of Stage 7
  output logic [0:127] int_data;
  // Destination register for write back data
  output logic [0:6] int_reg_addr;
  // Flag indicating if the write back data will be written to the Register Table
  output logic int_enable_reg_write;

  //Internal Signals
  // Staging register for calculated values
  logic [6:0][0:127] delayed_rt_data;
  // Destination register for write back data
  output logic [6:0][0:6] delayed_rt_addr;
  // Flag indicating if the write back data will be written to the Register Table
  output logic [6:0] delayed_enable_reg_write;
  // Flag indicating the type of operation
  output logic [6:0] int_operation_flag;

  always_comb begin
    // Check if the FP7 writeback is enabled for integer operations
    if (int_operation_flag[5] == 1) begin
      int_data = delayed_rt_data[5];
      int_reg_addr = delayed_rt_addr[5];
      int_enable_reg_write = delayed_enable_reg_write[5];
    end else begin
      int_data = 0;
      int_reg_addr = 0;
      int_enable_reg_write = 0;
    end
    // Check if the FP6 writeback is enabled for integer operations
    if (int_operation_flag[4] == 0) begin
      wb_data = delayed_rt_data[4];
      wb_reg_addr = delayed_rt_addr[4];
      wb_enable_reg_write = delayed_enable_reg_write[4];
    end else begin
      wb_data = 0;
      wb_reg_addr = 0;
      wb_enable_reg_write = 0;
    end
  end

  always_ff @(posedge clock) begin
    integer scale;
    shortreal tempfp;
    logic [0:15] temp16;
    if (reset == 1) begin
      delayed_rt_data[6] <= 0;
      delayed_rt_addr[6] <= 0;
      delayed_enable_reg_write[6] <= 0;
      int_operation_flag[6] <= 0;
      for (int i = 0; i < 6; i = i + 1) begin
        delayed_rt_data[i] <= 0;
        delayed_rt_addr[i] <= 0;
        delayed_enable_reg_write[i] <= 0;
        int_operation_flag[i] <= 0;
      end
    end else begin
      delayed_rt_data[6] <= delayed_rt_data[5];
      delayed_rt_addr[6] <= delayed_rt_addr[5];
      delayed_enable_reg_write[6] <= delayed_enable_reg_write[5];
      int_operation_flag[6] <= int_operation_flag[5];
      for (int i = 0; i < 5; i = i + 1) begin
        delayed_rt_data[i+1] <= delayed_rt_data[i];
        delayed_rt_addr[i+1] <= delayed_rt_addr[i];
        delayed_enable_reg_write[i+1] <= delayed_enable_reg_write[i];
        int_operation_flag[i+1] <= int_operation_flag[i];
      end
      //nop : No Operation (Execute)
      if (instr_format == 0 && op_code[0:9] == 0000000000) begin
        delayed_rt_data[0] <= 0;
        delayed_rt_addr[0] <= 0;
        delayed_enable_reg_write[0] <= 0;
        int_operation_flag[0] <= 0;
      end else begin
        delayed_rt_addr[0] <= dest_reg_addr;
        delayed_enable_reg_write[0] <= enable_reg_write;
        if (branch_is_taken) begin
          int_operation_flag[0] <= 0;
          delayed_rt_data[0] <= 0;
          delayed_rt_addr[0] <= 0;
          delayed_enable_reg_write[0] <= 0;
        end else if (instr_format == 0) begin
          case (op_code)
            //mpy : Multiply 
            11'b01111000100: begin
              int a;
              int b;
              int_operation_flag[0] <= 1;
              for (int i = 0; i < 4; i = i + 1) begin
                a = src_reg_a[(i*32)+31-:16];
                b = src_reg_b[(i*32)+31-:16];
                delayed_rt_data[0][(i*32)+:32] <= $signed(a) * $signed(b);
              end
            end
            //mpyu : Multiply Unsigned 
            11'b01111001100: begin
              int unsigned_a;
              int unsigned_b;
              int_operation_flag[0] <= 1;
              for (int i = 0; i < 4; i = i + 1) begin
                unsigned_a = src_reg_a[(i*32)+31-:16];
                unsigned_b = src_reg_b[(i*32)+31-:16];
                delayed_rt_data[0][(i*32)+:32] <= $unsigned(unsigned_a) * $unsigned(unsigned_b);
              end
            end
            //mpyh : Multiply High 			
            11'b01111000101: begin
              int signed_a;
              int signed_b;
              int_operation_flag[0] <= 1;
              for (int i = 0; i < 4; i = i + 1) begin
                signed_a = $signed(src_reg_a[(i*32)+:16]);
                signed_b = $signed(src_reg_b[(i*32)+16+:16]);
                delayed_rt_data[0][(i*32)+:32] <= (signed_a * signed_b) << 16;
              end
            end
            // mpyhh : Multiply High High	 				
            11'b01111000110: begin
              int signed_a;
              int signed_b;
              int_operation_flag[0] <= 1;
              for (int i = 0; i < 4; i = i + 1) begin
                signed_a = $signed(src_reg_a[(i*32)+:16]);
                signed_b = $signed(src_reg_b[(i*32)+:16]);
                delayed_rt_data[0][(i*32)+:32] <= (signed_a * signed_b) >> 32;
              end
            end
            // mpys : Multiply and Shift Right 
            11'b01111000111: begin
              int signed_a;
              int signed_b;
              int_operation_flag[0] <= 1;
              for (int i = 0; i < 4; i = i + 1) begin
                signed_a = $signed(src_reg_a[(i*32)+31-:16]);
                signed_b = $signed(src_reg_b[(i*32)+31-:16]);
                delayed_rt_data[0][(i*32)+:32] <= ($signed(signed_a * signed_b)) >> 1;
              end
            end
            //fa : Floating Add	 
            11'b01011000100: begin
              int_operation_flag[0] <= 0;
              for (int i = 0; i < 4; i = i + 1) begin
                real result;  // Declare result variable outside of the loop
                bit [31:0] src_a;
                bit [31:0] src_b;
                // Extract 32-bit long vectors
                src_a  = src_reg_a[(i*32)+:32];
                src_b  = src_reg_b[(i*32)+:32];
                // Perform the calculation
                result = ($bitstoshortreal(src_a) + $bitstoshortreal(src_b));
                // Perform the conditional assignment
                if (result >= $bitstoshortreal(32'h7F7FFFFF))
                  delayed_rt_data[0][(i*32)+:32] = 32'h7F7FFFFF;
                else if (result <= $bitstoshortreal(32'hFF7FFFFF))
                  delayed_rt_data[0][(i*32)+:32] = 32'hFF7FFFFF;
                else if (result <= $bitstoshortreal(32'h00000001) && result > 0)
                  delayed_rt_data[0][(i*32)+:32] = 32'h00000001;
                else if (result >= $bitstoshortreal(32'h80000001) && result < 0)
                  delayed_rt_data[0][(i*32)+:32] = 32'h80000001;
                else delayed_rt_data[0][(i*32)+:32] = $shortrealtobits(result);
              end
            end
            default: begin
              int_operation_flag[0] <= 0;
              delayed_rt_data[0] <= 0;
              delayed_rt_addr[0] <= 0;
              delayed_enable_reg_write[0] <= 0;
            end
            //fs : Floating Subtract  		
            11'b01011000101: begin
              int_operation_flag[0] <= 0;
              for (int i = 0; i < 4; i = i + 1) begin
                real result;  // Declare result variable outside of the loop
                bit [31:0] src_a;
                bit [31:0] src_b;
                // Extract 32-bit long vectors
                src_a  = src_reg_a[(i*32)+:32];
                src_b  = src_reg_b[(i*32)+:32];
                // Perform the calculation
                result = ($bitstoshortreal(src_a) - $bitstoshortreal(src_b));
                // Perform the conditional assignment
                if (result >= $bitstoshortreal(32'h7F7FFFFF))
                  delayed_rt_data[0][(i*32)+:32] = 32'h7F7FFFFF;
                else if (result <= $bitstoshortreal(32'hFF7FFFFF))
                  delayed_rt_data[0][(i*32)+:32] = 32'hFF7FFFFF;
                else if (result <= $bitstoshortreal(32'h00000001) && result > 0)
                  delayed_rt_data[0][(i*32)+:32] = 32'h00000001;
                else if (result >= $bitstoshortreal(32'h80000001) && result < 0)
                  delayed_rt_data[0][(i*32)+:32] = 32'h80000001;
                else delayed_rt_data[0][(i*32)+:32] = $shortrealtobits(result);
              end
            end
            //fm : Floating Multiply 			
            11'b01011000110: begin
              int_operation_flag[0] <= 0;
              for (int i = 0; i < 4; i = i + 1) begin
                real result;  // Declare result variable outside of the loop
                bit [31:0] src_a;
                bit [31:0] src_b;
                // Extract 32-bit long vectors
                src_a  = src_reg_a[(i*32)+:32];
                src_b  = src_reg_b[(i*32)+:32];
                // Perform the calculation
                result = ($bitstoshortreal(src_a) * $bitstoshortreal(src_b));
                // Perform the conditional assignment
                if (result >= $bitstoshortreal(32'h7F7FFFFF))
                  delayed_rt_data[0][(i*32)+:32] = 32'h7F7FFFFF;
                else if (result <= $bitstoshortreal(32'hFF7FFFFF))
                  delayed_rt_data[0][(i*32)+:32] = 32'hFF7FFFFF;
                else if (result <= $bitstoshortreal(32'h00000001) && result > 0)
                  delayed_rt_data[0][(i*32)+:32] = 32'h00000001;
                else if (result >= $bitstoshortreal(32'h80000001) && result < 0)
                  delayed_rt_data[0][(i*32)+:32] = 32'h80000001;
                else delayed_rt_data[0][(i*32)+:32] = $shortrealtobits(result);
              end
            end
          endcase
        end else if (instr_format == 1) begin
          case (op_code[7:10])
            //mpya : Multiply and Add  			
            4'b1100: begin
              int_operation_flag[0] <= 1;
              for (int i = 0; i < 4; i = i + 1)
                delayed_rt_data[0][(i*32)+:32] <= ($signed(
                    src_reg_a[(i*32)+16+:16]
                ) * $signed(
                    src_reg_b[(i*32)+16+:16]
                )) + $signed(
                    temporary_register_c[(i*32)+:32]
                );
            end
            //fma : Floating Multiply and Add  				
            4'b1110: begin
              int_operation_flag[0] <= 0;
              for (int i = 0; i < 4; i = i + 1) begin
                real result;  // Declare result variable outside of the loop
                bit [31:0] src_a;
                bit [31:0] src_b;
                bit [31:0] temp_c;
                // Extract 32-bit long vectors
                src_a = src_reg_a[(i*32)+:32];
                src_b = src_reg_b[(i*32)+:32];
                temp_c = temporary_register_c[(i*32)+:32];
                // Perform the calculation
                result = ($bitstoshortreal(src_a) * $bitstoshortreal(src_b)) +
                    $bitstoshortreal(temp_c);
                // Perform the conditional assignment
                if (result >= $bitstoshortreal(32'h7F7FFFFF))
                  delayed_rt_data[0][(i*32)+:32] = 32'h7F7FFFFF;
                else if (result <= $bitstoshortreal(32'hFF7FFFFF))
                  delayed_rt_data[0][(i*32)+:32] = 32'hFF7FFFFF;
                else if (result <= $bitstoshortreal(32'h00000001) && result > 0)
                  delayed_rt_data[0][(i*32)+:32] = 32'h00000001;
                else if (result >= $bitstoshortreal(32'h80000001) && result < 0)
                  delayed_rt_data[0][(i*32)+:32] = 32'h80000001;
                else delayed_rt_data[0][(i*32)+:32] = $shortrealtobits(result);
              end
            end
            //fms : Floating Multiply and Subtract 			
            4'b1111: begin
              int_operation_flag[0] <= 0;
              for (int i = 0; i < 4; i = i + 1) begin
                real result;  // Declare result variable outside of the loop
                bit [31:0] src_a;
                bit [31:0] src_b;
                bit [31:0] temp_c;
                // Extract 32-bit long vectors
                src_a = src_reg_a[(i*32)+:32];
                src_b = src_reg_b[(i*32)+:32];
                temp_c = temporary_register_c[(i*32)+:32];
                // Perform the calculation
                result = ($bitstoshortreal(src_a) * $bitstoshortreal(src_b)) -
                    $bitstoshortreal(temp_c);
                // Perform the conditional assignment
                if (result >= $bitstoshortreal(32'h7F7FFFFF))
                  delayed_rt_data[0][(i*32)+:32] = 32'h7F7FFFFF;
                else if (result <= $bitstoshortreal(32'hFF7FFFFF))
                  delayed_rt_data[0][(i*32)+:32] = 32'hFF7FFFFF;
                else if (result <= $bitstoshortreal(32'h00000001) && result > 0)
                  delayed_rt_data[0][(i*32)+:32] = 32'h00000001;
                else if (result >= $bitstoshortreal(32'h80000001) && result < 0)
                  delayed_rt_data[0][(i*32)+:32] = 32'h80000001;
                else delayed_rt_data[0][(i*32)+:32] = $shortrealtobits(result);
              end
            end
            // fnms : Floating Negative Multiply and Subtract  					
            4'b1101: begin
              int_operation_flag[0] <= 0;
              for (int i = 0; i < 4; i = i + 1) begin
                real result;  // Declare result variable outside of the loop
                bit [31:0] src_a;
                bit [31:0] src_b;
                bit [31:0] temp_c;
                // Extract 32-bit long vectors
                src_a = src_reg_a[(i*32)+:32];
                src_b = src_reg_b[(i*32)+:32];
                temp_c = temporary_register_c[(i*32)+:32];
                // Perform the calculation
                result = (-$bitstoshortreal(src_a) * $bitstoshortreal(src_b)) -
                    $bitstoshortreal(temp_c);
                // Perform the conditional assignment
                if (result >= $bitstoshortreal(32'h7F7FFFFF))
                  delayed_rt_data[0][(i*32)+:32] = 32'h7F7FFFFF;
                else if (result <= $bitstoshortreal(32'hFF7FFFFF))
                  delayed_rt_data[0][(i*32)+:32] = 32'hFF7FFFFF;
                else if (result <= $bitstoshortreal(32'h00000001) && result > 0)
                  delayed_rt_data[0][(i*32)+:32] = 32'h00000001;
                else if (result >= $bitstoshortreal(32'h80000001) && result < 0)
                  delayed_rt_data[0][(i*32)+:32] = 32'h80000001;
                else delayed_rt_data[0][(i*32)+:32] = $shortrealtobits(result);
              end
            end
            default begin
              int_operation_flag[0] <= 0;
              delayed_rt_data[0] <= 0;
              delayed_rt_addr[0] <= 0;
              delayed_enable_reg_write[0] <= 0;
            end
          endcase
        end else if (instr_format == 3) begin
          case (op_code[1:10])
            default begin
              int_operation_flag[0] <= 0;
              delayed_rt_data[0] <= 0;
              delayed_rt_addr[0] <= 0;
              delayed_enable_reg_write[0] <= 0;
            end
          endcase
        end else if (instr_format == 4) begin
          case (op_code[3:10])
            //mpyi : Multiply Immediate	 			
            8'b01110100: begin
              int_operation_flag[0] <= 1;
              for (int i = 0; i < 4; i = i + 1)
                delayed_rt_data[0][(i*32)+:32] <= $signed(
                    src_reg_a[(i*32)+16+:16]
                ) * $signed(
                    imm_value[8:17]
                );
            end
            //mpyui : Multiply Unsigned Immediate					
            8'b01110101: begin
              int_operation_flag[0] <= 1;
              temp16 = $signed(imm_value[8:17]);
              for (int i = 0; i < 4; i = i + 1)
                delayed_rt_data[0][(i*32)+:32] <= $unsigned(
                    src_reg_a[(i*32)+16+:16]
                ) * $unsigned(
                    temp16
                );
            end
            default begin
              int_operation_flag[0] <= 0;
              delayed_rt_data[0] <= 0;
              delayed_rt_addr[0] <= 0;
              delayed_enable_reg_write[0] <= 0;
            end
          endcase
        end
      end
    end
  end
endmodule
