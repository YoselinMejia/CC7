.section .text
.syntax unified
.code 32
.globl _start

// Exception Vector Table
// Must be aligned to 32 bytes (0x20)
.align 5
vector_table:
    b reset_handler      @ 0x00: Reset
    b undefined_handler  @ 0x04: Undefined Instruction
    b swi_handler        @ 0x08: Software Interrupt (SWI)
    b prefetch_handler   @ 0x0C: Prefetch Abort
    b data_handler       @ 0x10: Data Abort
    b .                  @ 0x14: Reserved
    b irq_handler        @ 0x18: IRQ (Interrupt Request)
    b fiq_handler        @ 0x1C: FIQ (Fast Interrupt Request)

reset_handler:
    // Set up stack pointer
    ldr sp, =_stack_top
    
    // Set up exception vector table base address (VBAR - Vector Base Address Register)
    ldr r0, =vector_table
    mcr p15, 0, r0, c12, c0, 0
    
    // Call main function
    bl main
    
    // If main returns, loop forever
hang:
    b hang

undefined_handler:
    b hang

swi_handler:
    b hang

prefetch_handler:
    b hang

data_handler:
    b hang

// TODO: Implement IRQ handler
// This handler should:
// 1. Save all registers (r0-r12, lr)
// 2. Call the timer_irq_handler() function in C
// 3. Restore all registers
// 4. Return from interrupt using: subs pc, lr, #4
irq_handler:
    // TODO: Implement IRQ handler
    b hang

fiq_handler:
    b hang

// Low-level memory access functions
.globl PUT32
PUT32:
    str r1, [r0]
    bx lr

.globl GET32
GET32:
    ldr r0, [r0]
    bx lr

// TODO: Implement enable_irq function
// This function should:
// 1. Read the current CPSR
// 2. Clear the I-bit (bit 7) to enable IRQ interrupts
// 3. Write back to CPSR
.globl enable_irq
enable_irq:
    // TODO: Implement enable_irq
    bx lr

// Stack space allocation
.section .bss
.align 4
_stack_bottom:
    .skip 0x2000  @ 8KB stack space
_stack_top:
