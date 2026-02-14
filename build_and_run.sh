#!/bin/bash

# Build and Run Script for Interrupt Handler Lab
# BeagleBone Black Bare-Metal Application

# Exit immediately if a command exits with a non-zero status
set -e

# Run from script directory so paths work from anywhere
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Remove previous compiled objects and binaries
echo "Cleaning up previous build files..."
rm -f bin/*.o bin/program.elf bin/program.bin
mkdir -p bin

echo "Assembling OS/root.s..."
arm-none-eabi-as -o bin/root.o OS/root.s

echo "Compiling OS/os.c..."
arm-none-eabi-gcc -c -mcpu=cortex-a8 -mfpu=neon -mfloat-abi=hard \
    -I OS -Wall -O2 -nostdlib -nostartfiles -ffreestanding \
    -o bin/os.o OS/os.c

echo "Linking object files..."
arm-none-eabi-gcc -nostartfiles -T linker.ld \
    -mcpu=cortex-a8 -mfpu=neon -mfloat-abi=hard \
    -o bin/program.elf \
    bin/root.o bin/os.o

echo "Converting ELF to binary..."
arm-none-eabi-objcopy -O binary bin/program.elf bin/program.bin

echo "Running QEMU..."
qemu-system-arm -M beagle -nographic -kernel bin/program.elf
