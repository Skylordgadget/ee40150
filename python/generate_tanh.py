from math import ceil, tanh
from numpy import linspace, append, flip, array, hstack
import matplotlib.pyplot as plt
import sys


rows = 64
int_bits = 8
frac_bits = 8
totalbits = int_bits + frac_bits
filename = "./tanh_lookup"

tanh_list = linspace(-4,3.875, rows)
tanh_list = hstack((tanh_list[rows//2:], tanh_list[0:rows//2]))

tanh_list_vals = tanh_list
tanh_strings = [""] * rows
for i in range(rows):
    if (i == rows-1):
        tanh_strings[i] = str(tanh(tanh_list[i])) 
    else:
        tanh_strings[i] = str(tanh(tanh_list[i])) + ", " 

with open(filename + ".csv", 'w') as file:
    file.writelines(tanh_strings)