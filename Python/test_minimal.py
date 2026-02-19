from pynq import Overlay, MMIO
import time
import random
import struct

BITSTREAM_PATH = "risc_v_wrapper.bit"
PROGRAM_HEX = "minimal.hex"  # ← Changed to minimal test

# Expected addresses (for verification)
EXPECTED_INSTR_BASE = 0x42000000
EXPECTED_DATA_BASE = 0x40000000
BRAM_SIZE = 0x2000

STATUS_FLAG_OFFSET = 0x1FFC

MAGIC_SUCCESS = 0xCAFEBABE
MAGIC_FAILURE = 0xDEADBEAF

ARRAY_SIZE = 32          
ARRAY_MIN = 1
ARRAY_MAX = 100
POLL_TIMEOUT = 5.0  # Reduced for minimal test

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


def write_instructions(instr_bram, instructions, base_addr):
    print(f"\nWriting {len(instructions)} instructions to I-MEM at {hex(base_addr)}")
    
    for i, instr in enumerate(instructions):
        addr = i * 4
        instr_bram.write(addr, instr)
        
    print(f"Instructions written successfully")

def write_data_array(data_bram, data, base_addr):
    print(f"\nWriting {len(data)} test values to D-MEM at {hex(base_addr)}")

    for i, value in enumerate(data):
        addr = i * 4
        unsigned_val = value & 0xFFFFFFFF
        data_bram.write(addr, unsigned_val)
        
    print(f"Test data written successfully")

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
            print(f"✓ SUCCESS flag detected after {elapsed:.3f}s ({poll_count} polls)")
            return True, status, elapsed
        
        elif status == MAGIC_FAILURE:
            elapsed = time.time() - start_time
            print(f"✗ FAILURE flag detected after {elapsed:.3f}s ({poll_count} polls)")
            return False, status, elapsed
        
        elapsed = time.time() - start_time
        if elapsed > POLL_TIMEOUT:
            print(f"✗ TIMEOUT after {elapsed:.3f}s ({poll_count} polls)")
            return False, status, elapsed
        
        # Show progress every 100 polls for minimal test
        if poll_count % 100 == 0:
            print(f"  Poll {poll_count}: status = {hex(status)}")
        
        time.sleep(0.001)  # Faster polling for minimal test

def main():
    print("="*70)
    print("RISC-V MINIMAL CORE TEST")
    print("Testing: Write magic number 0xCAFEBABE to status flag")
    print("="*70)
    
    ol = Overlay(BITSTREAM_PATH, download=True)
    print("\n✓ Bitstream loaded successfully")
    
    # ================================================================
    # DISCOVER ALL BRAM CONTROLLERS
    # ================================================================
    print("\n" + "="*70)
    print("DISCOVERING MEMORY BLOCKS")
    print("="*70)
    
    # Find all BRAM controllers
    bram_controllers = {}
    for key, info in ol.mem_dict.items():
        if "axi_bram_ctrl" in key.lower() or "bram" in key.lower():
            addr = int(info.get('phys_addr', info.get('base_address', info.get('addr', '0'))))
            size = int(info.get('addr_range', info.get('range', info.get('size', '0'))))
            bram_controllers[key] = {
                'addr': addr,
                'size': size
            }
            print(f"\nFound: {key}")
            print(f"  Address: {hex(addr)}")
            print(f"  Size: {hex(size)}")
    
    if len(bram_controllers) < 2:
        raise RuntimeError(f"ERROR: Expected 2 BRAM controllers, found {len(bram_controllers)}")
    
    # Sort by address to identify which is which
    sorted_brams = sorted(bram_controllers.items(), key=lambda x: x[1]['addr'])
    
    # Lower address = Data BRAM (0x40000000)
    # Higher address = Instruction BRAM (0x42000000)
    data_bram_key, data_info = sorted_brams[0]
    instr_bram_key, instr_info = sorted_brams[1]
    
    DATA_BRAM_BASE = data_info['addr']
    DATA_BRAM_SIZE = data_info['size']
    INSTR_BRAM_BASE = instr_info['addr']
    INSTR_BRAM_SIZE = instr_info['size']
    
    print("\n" + "="*70)
    print("MEMORY MAP")
    print("="*70)
    
    print(f"\nData BRAM: {data_bram_key}")
    print(f"  Discovered Address: {hex(DATA_BRAM_BASE)}")
    print(f"  Expected Address:   {hex(EXPECTED_DATA_BASE)}")
    print(f"  Match: {'✓ YES' if DATA_BRAM_BASE == EXPECTED_DATA_BASE else '✗ NO - MISMATCH!'}")
    print(f"  Size: {hex(DATA_BRAM_SIZE)}")
    
    print(f"\nInstruction BRAM: {instr_bram_key}")
    print(f"  Discovered Address: {hex(INSTR_BRAM_BASE)}")
    print(f"  Expected Address:   {hex(EXPECTED_INSTR_BASE)}")
    print(f"  Match: {'✓ YES' if INSTR_BRAM_BASE == EXPECTED_INSTR_BASE else '✗ NO - MISMATCH!'}")
    print(f"  Size: {hex(INSTR_BRAM_SIZE)}")
    
    # Verify addresses match expectations
    if DATA_BRAM_BASE != EXPECTED_DATA_BASE:
        print(f"\n⚠️  WARNING: Data BRAM address mismatch!")
        print(f"   Using discovered address: {hex(DATA_BRAM_BASE)}")
    
    if INSTR_BRAM_BASE != EXPECTED_INSTR_BASE:
        print(f"\n⚠️  WARNING: Instruction BRAM address mismatch!")
        print(f"   Using discovered address: {hex(INSTR_BRAM_BASE)}")
    
    # Create MMIO objects for both BRAMs
    instr_bram = MMIO(INSTR_BRAM_BASE, INSTR_BRAM_SIZE)
    data_bram = MMIO(DATA_BRAM_BASE, DATA_BRAM_SIZE)
    
    # Setup GPIO
    gpio_key = next(k for k in ol.ip_dict if "gpio" in k.lower())
    gpio = MMIO(int(ol.ip_dict[gpio_key]["phys_addr"]), 
                int(ol.ip_dict[gpio_key]["addr_range"]))
    
    print(f"\nGPIO: {gpio_key}")
    print(f"  Address: {hex(int(ol.ip_dict[gpio_key]['phys_addr']))}")
    
    # ================================================================
    # PHASE 1: INITIALIZATION & INJECTION
    # ================================================================
    print("\n" + "="*70)
    print("PHASE 1: INITIALIZATION")
    print("="*70)
    
    # Hold in reset
    gpio.write(GPIO_TRI, 0x0)
    gpio.write(GPIO_DATA, 0x0)
    time.sleep(0.02)
    
    gpio_val = gpio.read(GPIO_DATA)
    print(f"\n✓ RISC-V core held in reset")
    print(f"  GPIO readback: {hex(gpio_val)} (expected: 0x0) {'✓' if gpio_val == 0 else '✗'}")
    
    # Load and write minimal test instructions
    instructions = load_hex_file(PROGRAM_HEX)
    write_instructions(instr_bram, instructions, INSTR_BRAM_BASE)
    
    # Verify instruction write
    print("\nVerifying instruction write:")
    errors = 0
    for i in range(len(instructions)):
        addr = i * 4
        written = instructions[i]
        readback = instr_bram.read(addr)
        match = "✓" if written == readback else "✗"
        print(f"  instr[{i}] @ {hex(addr)}: {hex(written)} -> {hex(readback)} {match}")
        if written != readback:
            errors += 1
    
    if errors > 0:
        print(f"\n⚠️  WARNING: {errors} instruction verification errors!")
    else:
        print(f"✓ All {len(instructions)} instructions verified")
    
    # Write some test data (optional for minimal test, but keeps functionality)
    test_array = [random.randint(ARRAY_MIN, ARRAY_MAX) for _ in range(ARRAY_SIZE)]
    write_data_array(data_bram, test_array, DATA_BRAM_BASE)
    
    # Reset status flag
    data_bram.write(STATUS_FLAG_OFFSET, 0x0)
    status_check = data_bram.read(STATUS_FLAG_OFFSET)
    print(f"\n✓ Status flag reset at offset {hex(STATUS_FLAG_OFFSET)}")
    print(f"  Readback: {hex(status_check)} (expected: 0x0) {'✓' if status_check == 0 else '✗'}")
    
    # Verify first few data writes
    print("\nVerifying data write (first 5):")
    for i in range(min(5, ARRAY_SIZE)):
        addr = i * 4
        val = data_bram.read(addr)
        signed_val = struct.unpack('i', struct.pack('I', val))[0]
        match = "✓" if signed_val == test_array[i] else "✗"
        print(f"  data[{i}] @ {hex(addr)}: wrote {test_array[i]}, read {signed_val} {match}")
    
    # ================================================================
    # PHASE 2: EXECUTION
    # ================================================================
    print("\n" + "="*70)
    print("PHASE 2: EXECUTION")
    print("="*70)
    
    print(f"\nGPIO before release: {hex(gpio.read(GPIO_DATA))}")
    
    # Release reset
    gpio.write(GPIO_DATA, 0x1)
    time.sleep(0.1)
    
    gpio_val = gpio.read(GPIO_DATA)
    print(f"GPIO after release: {hex(gpio_val)} (expected: 0x1) {'✓' if gpio_val == 1 else '✗'}")
    
    if gpio_val != 1:
        print("⚠️  WARNING: GPIO did not change to 1 - reset may not be released!")
    
    # Verify first instruction is still there
    first_instr = instr_bram.read(0x0)
    print(f"\nFirst instruction in I-MEM: {hex(first_instr)}")
    print(f"Expected: {hex(instructions[0])} {'✓' if first_instr == instructions[0] else '✗'}")
    
    # Poll for completion
    print("\n" + "-"*70)
    success, magic, exec_time = poll_status_flag(data_bram)
    print("-"*70)
    
    # ================================================================
    # PHASE 3: RESULTS & DIAGNOSIS
    # ================================================================
    print("\n" + "="*70)
    print("PHASE 3: RESULTS")
    print("="*70)
    
    # Read status flag
    status_val = data_bram.read(STATUS_FLAG_OFFSET)
    print(f"\nStatus flag @ {hex(STATUS_FLAG_OFFSET)}: {hex(status_val)}")
    print(f"Expected: {hex(MAGIC_SUCCESS)}")
    print(f"Match: {'✓ YES' if status_val == MAGIC_SUCCESS else '✗ NO'}")
    
    # Read data array to check if anything changed
    print("\nData memory after execution (first 10):")
    hw_result = read_data_array(data_bram, min(10, ARRAY_SIZE))
    for i in range(min(10, ARRAY_SIZE)):
        before = test_array[i]
        after = hw_result[i]
        changed = "→" if before != after else "="
        print(f"  data[{i}]: {before} {changed} {after}")
    
    # Diagnosis
    print("\n" + "="*70)
    print("DIAGNOSIS")
    print("="*70)
    
    if success and status_val == MAGIC_SUCCESS:
        print("\n✅ SUCCESS: Core is running correctly!")
        print(f"   Execution time: {exec_time:.3f}s")
        print("\nCore successfully:")
        print("  1. Fetched instructions from I-MEM")
        print("  2. Executed minimal program")
        print("  3. Wrote magic number to D-MEM")
        print("\n → Your RISC-V core is WORKING! Ready for full bubble sort test.")
        return True
    
    elif status_val == MAGIC_SUCCESS:
        print("\n⚠️  Status flag set, but took too long")
        print(f"   This might still indicate the core is working")
        return True
    
    else:
        print("\n❌ FAILURE: Core did not execute")
        print(f"   Final status: {hex(status_val)} (expected {hex(MAGIC_SUCCESS)})")
        
        # Check if data changed
        data_changed = any(test_array[i] != hw_result[i] for i in range(min(10, ARRAY_SIZE)))
        
        if data_changed:
            print("\n⚠️  Data memory changed, but no status flag")
            print("   Possible issues:")
            print("   - Core running but crashed before status write")
            print("   - Wrong status flag address calculation")
        else:
            print("\n❌ Data memory unchanged - core NOT running at all!")
            print("\nCritical hardware issues to check:")
            print("  1. RISC-V core dmem/imem ports NOT connected to BRAM PORTB")
            print("  2. Reset signal not connected or wrong polarity")
            print("  3. Clock not connected to core")
            print("  4. Core optimized away during synthesis")
            print("\n→ CHECK VIVADO BLOCK DESIGN CONNECTIONS!")
        
        return False

if __name__ == "__main__":
    try:
        success = main()
        print("\n" + "="*70)
        if success:
            print("FINAL RESULT: MINIMAL TEST PASSED ✅")
            print("\nNext steps:")
            print("  1. Change PROGRAM_HEX to 'Bubble_sort.hex'")
            print("  2. Increase POLL_TIMEOUT to 30.0")
            print("  3. Run full sorting test")
        else:
            print("FINAL RESULT: MINIMAL TEST FAILED ❌")
            print("\nFix Vivado connections before proceeding!")
        print("="*70)
        exit(0 if success else 1)
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        exit(1)