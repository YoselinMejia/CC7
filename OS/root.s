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
    cps #18             @ Cambiar a modo IRQ (binario 10010)
    ldr sp, =0x40300000 @ Le damos el mismo tope (o un poco menos)
    
    cps #19             @ Cambiar a modo Supervisor (binario 10011)
    ldr sp, =0x402F8000 @ Le damos un espacio diferente para que no choquen
    
    ldr r0, =vector_table
    mcr p15, 0, r0, c12, c0, 0
    
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
    sub lr, lr, #4          @ Ajustar LR para volver a la instrucción correcta
    stmdb sp!, {r0-r3, r12, lr} @ Guardar registros que C usa
    
    bl timer_irq_handler    @ Llamar a tu función en os.c
    
    ldmia sp!, {r0-r3, r12, pc}^ @ Restaurar y volver (el ^ restaura el CPSR)
    
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

.globl enable_irq
enable_irq:
    mrs r0, cpsr
    bic r0, r0, #0x80    @ Limpiar bit I para habilitar IRQ
    msr cpsr, r0
    bx lr

// Stack space allocation
.section .bss
.align 4
_stack_bottom:
    .skip 0x2000  @ 8KB stack space
_stack_top:
