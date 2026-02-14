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

// Implement IRQ handler
// Saves CPU state, calls C handler, and restores state
irq_handler:
    @ Save all registers to stack
    sub sp, sp, #60          @ Reserve space for 15 registers
    stmia sp, {r0-r12, lr}   @ Save r0-r12, lr
    
    @ Call the timer interrupt handler in C
    bl timer_irq_handler
    
    @ Restore all registers from stack
    ldmia sp, {r0-r12, lr}   @ Restore r0-r12, lr
    add sp, sp, #60          @ Release stack space
    
    @ Return from interrupt (pc = lr - 4)
    subs pc, lr, #4

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

// Implement enable_irq function
// Enables IRQ interrupts by clearing the I-bit in CPSR
.globl enable_irq
enable_irq:
    @ Read current CPSR into r0
    mrs r0, cpsr
    
    @ Clear bit 7 (I-bit) to enable IRQ interrupts
    bic r0, r0, #0x80
    
    @ Write back to CPSR
    msr cpsr, r0
    
    @ Return
    bx lr

// Stack space allocation
.section .bss
.align 4
_stack_bottom:
    .skip 0x2000  @ 8KB stack space
_stack_top:
