from math import ceil

def float_to_fixed(num, int_bits, frac_bits):
    total_bits = int_bits + frac_bits
    scale_factor = 1 << frac_bits  # equivalent to 2^frac_bits

    # Scale the floating point number
    scaled_num = round(num * scale_factor)

    # Handle the case where the number is out of bounds for the given bit size
    min_val = -(1 << (total_bits - 1))
    max_val = (1 << (total_bits - 1)) - 1
    if scaled_num < min_val or scaled_num > max_val:
        raise ValueError(f"The number {num} is out of bounds for the given fixed point configuration")

    # Convert to two's complement representation if the number is negative
    if scaled_num < 0:
        scaled_num = (1 << total_bits) + scaled_num
    
    # Return the fixed-point number as an integer
    return scaled_num

def fixed_to_float(fixed_num, int_bits, frac_bits):
    total_bits = int_bits + frac_bits
    scale_factor = 1 << frac_bits  # equivalent to 2^frac_bits

    # Check if the number is negative (most significant bit is 1)
    if fixed_num & (1 << (total_bits - 1)):
        # Convert from two's complement representation
        fixed_num -= (1 << total_bits)
    
    # Convert back to floating point by dividing by the scale factor
    float_num = fixed_num / scale_factor
    return float_num

def int_to_hex(int_in, nibbles_per_int):
    
    line = ""

    el_hex_str = str(hex(int_in))[2:]
    if (len(el_hex_str) < nibbles_per_int):
        el_hex_str = ("0" * (nibbles_per_int - len(el_hex_str))) + el_hex_str
    
    line = line + el_hex_str + "\n"

    return line

int_bits = 11
frac_bits = 7
totalbits = int_bits + frac_bits
filename = "../verilog/top/new_mr_train"

lines = []
with open(filename + ".txt", 'r') as file:
    # Iterate over each line in the file
    for line in file:
        # Strip leading/trailing whitespace and append the line to the list
        lines.append(line.strip())

hex_lines = []
for line in lines:
    hex_lines.append(int_to_hex(float_to_fixed(float(line),int_bits,frac_bits,),ceil(totalbits/4)))

with open(filename + ".hex", 'w') as file:
    file.writelines(hex_lines)