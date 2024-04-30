import argparse

# Type this in terminal: python3.11 assembler.py input1.asm memory_contents.txt

class Assembler:
    def __init__(self, instruction_list_name, source_file, destination_file, debug):
        self.instruction_to_opcode_dict = {}
        self.source_file = source_file
        self.destination_file = destination_file
        self.log_severity = debug
        self.import_map(instruction_list_name)

    def import_map(self, instruction_list_name):
        with open(instruction_list_name, 'r') as instruction_list:
            for text_line in instruction_list:
                operation, operation_code = text_line.strip().split("\t")
                mnemonic = operation.split(" ")[0]
                operation_code = operation_code.strip()
                self.instruction_to_opcode_dict[mnemonic] = operation_code

    def interpret_line(self, text_line):
        return text_line.strip().split("//")[0].strip().split(" ")

    def interpret_input(self):
        with open(self.source_file, 'r') as instruction_list, \
                open(self.destination_file, 'w') as output_file, \
                open("debug.out", 'w') as data_object:
            for text_line in instruction_list:
                operation = self.interpret_line(text_line)
                mnemonic = operation[0]
                if "stop" in mnemonic:
                    break
                operation_code = self.instruction_to_opcode_dict.get(mnemonic, '00000000000')
                binary = self.calculate(operation_code, operation)
                output_file.write(binary + "\n")
                if self.log_severity == 2:
                    o_hex = '0x{0:0{1}X}'.format(int(binary, 2), 8)
                    data_object.write(str(binary) + "\t" + o_hex + "\t" + text_line)
                else:
                    data_object.write(str(binary) + "\t" + text_line)

    def calculate(self, operation_code, operation):
        instruction_binary = operation_code
        for op in operation[1:]:
            if '(' in op and ')' in op:
                reg_offset = op.split('(')[0]
                offset = op.split('(')[1].rstrip(')')
                reg_binary = self.populate(bin(int(reg_offset)).replace("0b", ""), 7)
                offset_binary = self.populate(bin(int(offset)).replace("0b", ""), 7)
                instruction_binary += reg_binary + offset_binary
            else:
                op_binary = self.populate(bin(int(op)).replace("0b", ""), 7)
                instruction_binary += op_binary
        return instruction_binary.zfill(32)


    def populate(self, sequence, span):
        sequence = sequence.lstrip('-').zfill(span)
        return '1' + sequence[1:] if sequence.startswith('-') else sequence
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Assembler script')
    parser.add_argument('source_file', help='Input file path')
    parser.add_argument('destination_file', help='Output file path')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    parser.add_argument('--instruction_list_name', default='instruction_list.txt', help='Instruction list file path')
    args = parser.parse_args()
    assembler = Assembler(args.instruction_list_name, args.source_file, args.destination_file, args.debug)
    assembler.interpret_input()
