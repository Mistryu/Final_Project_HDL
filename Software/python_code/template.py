# Jupiter notebook
from pynq import Overlay, MMIO
import os
import time

ol = Overlay("lab_12_axi_bram_bd.bit", download=True)

# find GPIO and BRAM
gpio_key = next(k for k in ol.ip_dict if "gpio" in k.lower())
bram_key = next(k for k in ol.mem_dict if "axi_bram_ctrl" in k.lower() or "bram" in k.lower())

gpio = MMIO(int(ol.ip_dict[gpio_key]["phys_addr"]), int(ol.ip_dict[gpio_key]["addr_range"]))

mi = ol.mem_dict[bram_key]
BRAM_BASE = int(mi.get("phys_addr", mi.get("base_address", mi.get("addr"))))
BRAM_SIZE = int(mi.get("addr_range", mi.get("range", mi.get("size"))))
bram = MMIO(BRAM_BASE, BRAM_SIZE)

print("GPIO:", gpio_key, hex(int(ol.ip_dict[gpio_key]["phys_addr"])), hex(int(ol.ip_dict[gpio_key]["addr_range"]))) # Expected: GPIO: axi_gpio_0 0x41200000 0x80
print("BRAM:", bram_key, hex(BRAM_BASE), hex(BRAM_SIZE)) # Expected: BRAM: axi_bram_ctrl_1 0x40000000 0x2000

# AXI GPIO CH1 regs
GPIO_DATA = 0x0
GPIO_TRI  = 0x4

# output + pulse low->high
gpio.write(GPIO_TRI, 0x0)
gpio.write(GPIO_DATA, 0x0); time.sleep(0.02)
gpio.write(GPIO_DATA, 0x1); time.sleep(0.02)

w0 = bram.read(0x0)
w1 = bram.read(0x4)
w1000 = bram.read(1000*4)

print("BRAM[0]   =", hex(w0))      # expected 0x0
print("BRAM[1]   =", hex(w1))      # expected 0x1
print("BRAM[1000]=", hex(w1000))   # expected 0x3e8

for i in range(8):
    v = bram.read(i*4)           # word i at byte offset i*4
    print(f"word[{i:2d}]  hex={v:#010x}  bin={format(v & 0xFFFFFFFF, '032b')}")
# Expected: 
word[ 0]  hex=0x00000000  bin=00000000000000000000000000000000
word[ 1]  hex=0x00000001  bin=00000000000000000000000000000001
word[ 2]  hex=0x00000002  bin=00000000000000000000000000000010
word[ 3]  hex=0x00000003  bin=00000000000000000000000000000011
word[ 4]  hex=0x00000004  bin=00000000000000000000000000000100
word[ 5]  hex=0x00000005  bin=00000000000000000000000000000101
word[ 6]  hex=0x00000006  bin=00000000000000000000000000000110
word[ 7]  hex=0x00000007  bin=00000000000000000000000000000111