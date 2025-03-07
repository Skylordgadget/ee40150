from math import cos, sin, pi

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
    
    line = line + el_hex_str

    return line

int_bits = 5
frac_bits = 11
totalbits = int_bits + frac_bits
fft_points = 8
num_twiddles = fft_points // 2
twiddles = [[0 for x in range(2)] for y in range(num_twiddles)]
filename = "twiddles{0}".format(num_twiddles)

for r in range(num_twiddles):
    twiddles[r][0] = cos(2*pi*(r/fft_points)) # real
    twiddles[r][1] = -sin(2*pi*(r/fft_points)) # imaginary

hex_lines = []
for tw in twiddles:
    re = int_to_hex(float_to_fixed(float(tw[0]),int_bits,frac_bits,),totalbits//4)
    im = int_to_hex(float_to_fixed(float(tw[1]),int_bits,frac_bits,),totalbits//4)

    debug_string = "real float: {0} fixed: {1} | imag float: {2} fixed: {3}".format(tw[0], fixed_to_float(int(re,16),int_bits,frac_bits), tw[1], fixed_to_float(int(im,16),int_bits,frac_bits))
    print(debug_string)
    hex_lines.append(re + ", " + im + "\n")

with open(filename + ".hex", 'w') as file:
    file.writelines(hex_lines)