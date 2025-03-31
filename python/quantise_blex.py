import csv
import argparse


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


def int_to_intel_hex(ints, nibbles_per_int, iteration):
    
    it_hex_str = str(hex(iteration))[2:]
    if (len(it_hex_str) < 4):
        it_hex_str = ("0" * (4 - len(it_hex_str))) + it_hex_str
    byte_count = (nibbles_per_int//2) * len(ints)
    bc_hex_str = str(hex(byte_count))[2:]
    if (len(bc_hex_str) < 2):
        bc_hex_str = ("0" * (2 - len(bc_hex_str))) + bc_hex_str

    line = bc_hex_str + it_hex_str + "00"
    for element in ints:
        el_hex_str = str(element)
        if (len(el_hex_str) < nibbles_per_int):
            el_hex_str = ("0" * (nibbles_per_int - len(el_hex_str))) + el_hex_str
        
        line = line + el_hex_str

    sum = 0
    for i in range(0,len(line),2):
        sum = sum + int(line[i:i+2],16)
    cs_hex_str = str(hex(0x100 - (sum % 0x100)))[2:]
    if (len(cs_hex_str) < 2):
        cs_hex_str = ("0" * (2 - len(cs_hex_str))) + cs_hex_str
    checksum = cs_hex_str[-2:]

    return ":" + line + checksum + "\n"


parser = argparse.ArgumentParser(description="Quantises floating-point data from a .csv to signed fixed point two's compliment in Intel HEX format.")
parser.add_argument('--int_bits', type=int, nargs=1, default=8, help='integer bits')
parser.add_argument('--frac_bits', type=int, nargs=1, default=0, help='fractional bits')
parser.add_argument('--in_filepath', metavar='I', type=str, nargs=1, default="../weights/temp/", help='input file path')
parser.add_argument('--out_filepath', metavar='O', type=str, nargs=1, default="../verilog/test/weights/", help='output file path')
parser.add_argument('--filenames', metavar='F', type=str, nargs='+', default=["config_file"], help='file names to be converted')

args = parser.parse_args()
int_bits = args.int_bits
frac_bits = args.frac_bits

for filename in args.filenames:
    with open(args.in_filepath + filename + ".csv", newline='') as file:
        reader = csv.reader(file)
        res = list(map(tuple, reader))



    totalbits = int_bits + frac_bits

    intel_hex = []

    for i in range(len(res[0])):
        # floats = []
        ints = []
        for j in range(len(res)):
            ints.append(res[j][i])

        # for f in floats:
        #     ints.append(float_to_fixed(float(f),int_bits,frac_bits))

        intel_hex.append(int_to_intel_hex(ints,totalbits//4,i))
    intel_hex.append(":00000001FF")

    with open(args.out_filepath + filename + "_{0}I{1}F".format(int_bits, frac_bits) + ".hex", 'w') as file:
        file.writelines(intel_hex)

 
