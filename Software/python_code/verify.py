from pynq import Overlay, MMIO
import time
import random
import struct

BITSTREAM_PATH = "risc_v_wrapper.bit"
PROGRAM_HEX = "Bubble_sort.hex"

BRAM_SIZE = 0x2000

STATUS_FLAG_OFFSET = 0x1FFC

MAGIC_SUCCESS = 0xCAFEBABE
MAGIC_FAILURE = 0xDEADBEAF

ARRAY_SIZE = 32          
ARRAY_MIN = 1
ARRAY_MAX = 100
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


def write_instructions(instr_bram, instructions):
    for i, instr in enumerate(instructions):
        addr = i * 4
        instr_bram.write(addr, instr)
        
    print(f"Instructions written successfully")

def write_data_array(data_bram, data):
    for i, value in enumerate(data):
        addr = i * 4
        unsigned_val = value & 0xFFFFFFFF
        data_bram.write(addr, unsigned_val)
        
    print(f"Test array written successfully")

def read_data_array(data_bram, size):
    result = []
    for i in range(size):
        addr = i * 4
        unsigned_val = data_bram.read(addr)
        signed_val = struct.unpack('i', struct.pack('I', unsigned_val))[0]
        result.append(signed_val)
    return result

def poll_status_flag(data_bram):
    print(f"\nPolling status flag at offset {hex(STATUS_FLAG_OFFSET)} in D-MEM")
    start_time = time.time()
    poll_count = 0
    
    while True:
        status = data_bram.read(STATUS_FLAG_OFFSET)
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
    print("RISC-V Sorting Core Verification\n")
    
    ol = Overlay(BITSTREAM_PATH, download=True)
    
    bram_controllers = {}
    for key, info in ol.mem_dict.items():
        if "axi_bram_ctrl" in key.lower() or "bram" in key.lower():
            addr = int(info.get('phys_addr', info.get('base_address', info.get('addr'))))
            size = int(info.get('addr_range', info.get('range', info.get('size'))))
            bram_controllers[key] = {
                'addr': addr,
                'size': size
            }
    
    if len(bram_controllers) < 2:
        raise RuntimeError(f"ERROR: Expected 2 BRAM controllers, found {len(bram_controllers)}")
    
    # Setup GPIO
    gpio_key = next(k for k in ol.ip_dict if "gpio" in k.lower())
    gpio = MMIO(int(ol.ip_dict[gpio_key]["phys_addr"]), int(ol.ip_dict[gpio_key]["addr_range"]))
    
    # Sorting the brams to ensure they are correctly identified
    sorted_brams = sorted(bram_controllers.items(), key=lambda x: x[1]['addr'])
    
    # Lower address = Data BRAM (0x40000000)
    # Higher address = Instruction BRAM (0x42000000)
    data_info = sorted_brams[0][1]
    instr_info = sorted_brams[1][1]
    
    DATA_BRAM_BASE = data_info['addr']
    DATA_BRAM_SIZE = data_info['size']
    INSTR_BRAM_BASE = instr_info['addr']
    INSTR_BRAM_SIZE = instr_info['size']
    
    instr_bram = MMIO(INSTR_BRAM_BASE, INSTR_BRAM_SIZE)
    data_bram = MMIO(DATA_BRAM_BASE, DATA_BRAM_SIZE)
    
    
    print(f"GPIO at {hex(int(ol.ip_dict[gpio_key]['phys_addr']))}")
    print(f"I-MEM at {hex(INSTR_BRAM_BASE)}")
    print(f"D-MEM at {hex(DATA_BRAM_BASE)}\n")
    
    
    print("\nPHASE 1: INITIALIZATION ")
    
    # Hold in reset
    gpio.write(GPIO_TRI, 0x0)
    gpio.write(GPIO_DATA, 0x0)
    
    time.sleep(0.02)
    print("RISC-V core held in reset")
    
    gpio_val = gpio.read(GPIO_DATA)
    print(f"GPIO readback (should be 0): {gpio_val}")
    
    instructions = load_hex_file(PROGRAM_HEX)
    write_instructions(instr_bram, instructions)
    
    print("\nVerifying instruction write:")
    for i in range(min(5, len(instructions))):
        addr = i * 4
        written = instructions[i]
        readback = instr_bram.read(addr)
        match = "Good" if written == readback else "Bad"
        print(f"  instr[{i}] addr: {hex(addr)}: wrote {hex(written)}, read {hex(readback)} {match}")
    
    # Write data to DATA BRAM
    test_array = [random.randint(ARRAY_MIN, ARRAY_MAX) for _ in range(ARRAY_SIZE)]
    write_data_array(data_bram, test_array)
    
    # Reset status flag
    data_bram.write(STATUS_FLAG_OFFSET, 0x0)
    
    golden_result = sorted(test_array)
    
    print("\nVerifying data write:")
    for i in range(min(5, ARRAY_SIZE)):
        addr = i * 4
        val = data_bram.read(addr)
        signed_val = struct.unpack('i', struct.pack('I', val))[0]
        print(f"  data[{i}] addr: {hex(addr)}: {signed_val} ({hex(val)})")
    
    print("\nPHASE 2: EXECUTION")
    
    # Release reset
    gpio.write(GPIO_DATA, 0x1)
    time.sleep(0.1)
    
    gpio_val = gpio.read(GPIO_DATA)
    
    success, magic, exec_time = poll_status_flag(data_bram)
    
    print("\nReading data after execution:")
    for i in range(min(5, ARRAY_SIZE)):
        addr = i * 4
        val = data_bram.read(addr)
        signed_val = struct.unpack('i', struct.pack('I', val))[0]
        print(f"  data[{i}] addr: {hex(addr)}: {signed_val} ({hex(val)})")
    
    print(f"\nStatus flag addr: {hex(STATUS_FLAG_OFFSET)}: {hex(data_bram.read(STATUS_FLAG_OFFSET))}")
    
    print("\nPHASE 3: VERIFICATION")
    
    if not success:
        if magic == MAGIC_FAILURE:
            print("\n HARDWARE REPORTED FAILURE")
        else:
            print(f"\n TIMEOUT or UNKNOWN STATUS: {hex(magic)}")
        return False
    
    hw_result = read_data_array(data_bram, ARRAY_SIZE)
    
    mismatches = []
    for i in range(ARRAY_SIZE):
        if hw_result[i] != golden_result[i]:
            mismatches.append((i, golden_result[i], hw_result[i]))
    
    print(f"\nExecution time: {exec_time:.3f}s")
    
    if mismatches:
        print(f"\n FAILURE: {len(mismatches)} mismatches found!")
        for idx, expected, actual in mismatches[:10]:
            print(f"  Index {idx}: Expected {expected}, Got {actual}")
        return False
    else:
        print("\n SUCCESS: All values match!")
        print(f"Sorted values: {hw_result[:31]}...")
        return True

if __name__ == "__main__":
    
    try:
        success = main()
        exit(0 if success else 1)
    except Exception as e:
        print(f"\n ERROR: {e}")
        import traceback
        traceback.print_exc()
        exit(1)
        
        