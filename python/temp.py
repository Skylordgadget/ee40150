a = 0

for i in range(2):
    a = a + 2**i

b = 0

for i in range(3):
    b = b + 1/(2**(i+1))

print(a+b)
