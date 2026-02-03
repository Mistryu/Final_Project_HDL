from pynq import Overlay, MMIO
import time
import random
import struct

BITSTREAM_PATH = "RISCV_final.bit"
PROGRAM_HEX = "Bubble_sort.hex"

# Our memory layout
INSTRUCTION_BASE = 0x0000
DATA_RAM_BASE = 0x1000
STATUS_FLAG_OFFSET = 0x1FFC   # Position of the status flag

MAGIC_SUCCESS = 0xCAFEBABE
MAGIC_FAILURE = 0xDEADBEAF

ARRAY_SIZE = 32          
ARRAY_MIN = 1000         # Minimum signed 32-bit value (-2^31 = -2147483648) TODO for testing change to like a 1000 to make it easier
ARRAY_MAX = 1000         # Maximum signed 32-bit value (2^31 - 1 = 2147483647)
POLL_TIMEOUT = 30.0

# AXI GPIO CH1 regs
GPIO_DATA = 0x0
GPIO_TRI = 0x4

# Helper Functions
def load_hex_file(filename):
    instructions = []
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            
            if '//' in line:
                line = line.split('//')[0].strip()

            if line and not line.startswith('#'):
                instr = int(line, 16)    
                instructions.append(instr)
                
    print(f"Loaded {len(instructions)} instructions from {filename}")
    return instructions


def write_instructions(bram, instructions):
    print(f"\n Writing {len(instructions)} instructions to I-ROM at offset {hex(INSTRUCTION_BASE)}")
    
    for i, instr in enumerate(instructions):
        addr = INSTRUCTION_BASE + (i * 4)
        bram.write(addr, instr)
        
    print(f"Instructions written successfully :)")

def write_data_array(bram, data):
    print(f"\n Writing {len(data)} integers to D-RAM at offset {hex(DATA_RAM_BASE)}")

    for i, value in enumerate(data):
        addr = DATA_RAM_BASE + (i * 4)
        unsigned_val = value & 0xFFFFFFFF    # In case of python doing weird large int or some unpredictable behavior
        bram.write(addr, unsigned_val)
        
    print(f"Test array written successfully")

def read_data_array(bram, size):

    result = []
    for i in range(size):
        addr = DATA_RAM_BASE + (i * 4)
        unsigned_val = bram.read(addr)
        signed_val = struct.unpack('i', struct.pack('I', unsigned_val))[0]
        result.append(signed_val)
    return result

# This function just check for the status flag in a loop with timeout. The timeout exists in case the RISC-V core hangs
def poll_status_flag(bram):
    print(f"\nPolling status flag at {hex(STATUS_FLAG_OFFSET)} with timeout {POLL_TIMEOUT}s")
    start_time = time.time()
    poll_count = 0
    
    while True:
        status = bram.read(STATUS_FLAG_OFFSET)
        poll_count += 1
        
        if status == MAGIC_SUCCESS:
            elapsed = time.time() - start_time
            print(f"SUCCESS flag detected after {elapsed:.3f}s ({poll_count} polls)")
            return True, status, elapsed
        
        elif status == MAGIC_FAILURE:
            elapsed = time.time() - start_time
            print(f"FAILURE flag detected after {elapsed:.3f}s ({poll_count} polls)")
            return False, status, elapsed
        
        elapsed = time.time() - start_time
        if elapsed > POLL_TIMEOUT:
            print(f"TIMEOUT after {elapsed:.3f}s ({poll_count} polls)")
            return False, status, elapsed
        
        time.sleep(0.01)

def main():
    print("RISC-V Sorting Core Verification Script")    
    
    ol = Overlay(BITSTREAM_PATH, download=True)
    print("Bitstream loaded successfully")
    
    gpio_key = next(k for k in ol.ip_dict if "gpio" in k.lower())
    bram_key = next(k for k in ol.mem_dict if "axi_bram_ctrl" in k.lower() or "bram" in k.lower())
    
    gpio = MMIO(int(ol.ip_dict[gpio_key]["phys_addr"]), int(ol.ip_dict[gpio_key]["addr_range"]))
    
    mi = ol.mem_dict[bram_key]
    BRAM_BASE = int(mi.get("phys_addr", mi.get("base_address", mi.get("addr"))))
    BRAM_SIZE = int(mi.get("addr_range", mi.get("range", mi.get("size"))))
    bram = MMIO(BRAM_BASE, BRAM_SIZE)
    
    print(f"GPIO: {gpio_key} at {hex(int(ol.ip_dict[gpio_key]['phys_addr']))}")
    print(f"BRAM: {bram_key} at {hex(BRAM_BASE)}, size {hex(BRAM_SIZE)}")
    
    
    
    print("PHASE 1: INITIALIZATION & INJECTION")
    
    gpio.write(GPIO_TRI, 0x0)
    gpio.write(GPIO_DATA, 0x0); time.sleep(0.02)
    print("RISC-V core held in reset")
    
    instructions = load_hex_file(PROGRAM_HEX)
    write_instructions(bram, instructions)
    
    test_array = [random.randint(ARRAY_MIN, ARRAY_MAX) for _ in range(ARRAY_SIZE)]
    write_data_array(bram, test_array)
    
    # Reset status flag in case of previous runs
    bram.write(STATUS_FLAG_OFFSET, 0x0)
    
    golden_result = sorted(test_array)
    
    
    print("PHASE 2: EXECUTION")

    gpio.write(GPIO_DATA, 0x1)
    time.sleep(0.01)
    success, magic, exec_time = poll_status_flag(bram)
    

    print("PHASE 3: VERIFICATION")
    
    if not success:
        if magic == MAGIC_FAILURE:
            print("\n HARDWARE REPORTED FAILURE")
        else:
            print(f"\n TIMEOUT or UNKNOWN STATUS: {hex(magic)}")
        return False
    
    hw_result = read_data_array(bram, ARRAY_SIZE)
    
    mismatches = []
    for i in range(ARRAY_SIZE):
        if hw_result[i] != golden_result[i]:
            mismatches.append((i, golden_result[i], hw_result[i]))
    
    print(f"\nExecution time: {exec_time:.3f}s")
    print(f"Array size: {ARRAY_SIZE}")
    
    if mismatches:
        print(f"\nFAILURE: {len(mismatches)} mismatches found!")
        print("\nMismatches:")
        
        for i, (idx, expected, actual) in enumerate(mismatches[:31]):
            print(f"  Index {idx}: Expected {expected}, Got {actual}")
        return False
    else:
        print("\nSUCCESS: All values match!")
        print(f"Sorted values: {hw_result[:31]}")
        return True

# Entry Point
if __name__ == "__main__":
    try:
        success = main()
        exit(0 if success else 1)
    except Exception as e:
        print(f"\n ERROR: {e}")
        import traceback
        traceback.print_exc()
        exit(1)