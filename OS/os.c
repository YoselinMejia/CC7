#include "os.h"

// BeagleBone Black UART0 base address
#define UART0_BASE     0x44E09000
#define UART_THR       (UART0_BASE + 0x00)  // Transmit Holding Register
#define UART_LSR       (UART0_BASE + 0x14)  // Line Status Register
#define UART_LSR_THRE  0x20                  // Transmit Holding Register Empty
#define UART_LSR_RXFE  0x10                  // Receive FIFO Empty

// BeagleBone Black DMTIMER2 base address
#define DMTIMER2_BASE    0x48040000
#define TCLR             (DMTIMER2_BASE + 0x38)  // Timer Control Register
#define TCRR             (DMTIMER2_BASE + 0x3C)  // Timer Counter Register
#define TISR             (DMTIMER2_BASE + 0x28)  // Timer Interrupt Status Register
#define TIER             (DMTIMER2_BASE + 0x2C)  // Timer Interrupt Enable Register
#define TLDR             (DMTIMER2_BASE + 0x40)  // Timer Load Register

// BeagleBone Black Interrupt Controller (INTCPS) base address
#define INTCPS_BASE      0x48200000
#define INTC_MIR_CLEAR2  (INTCPS_BASE + 0xC8)    // Interrupt Mask Clear Register 2
#define INTC_CONTROL     (INTCPS_BASE + 0x48)    // Interrupt Controller Control
#define INTC_ILR68       (INTCPS_BASE + 0x110)   // Interrupt Line Register 68

// Clock Manager base address
#define CM_PER_BASE      0x44E00000
#define CM_PER_TIMER2_CLKCTRL (CM_PER_BASE + 0x80)  // Timer2 Clock Control
#define CM_PER_GPIO1_CLKCTRL  (CM_PER_BASE + 0xAC)  // GPIO1 Clock Control

// GPIO1 (user LEDs) base and registers (AM335x)
#define GPIO1_BASE       0x4804C000
#define GPIO_OE          (GPIO1_BASE + 0x134)
#define GPIO_DATAOUT     (GPIO1_BASE + 0x13C)

// User LEDs are on GPIO1_21..GPIO1_24
#define USER_LED_MASK    ((1<<21) | (1<<22) | (1<<23) | (1<<24))

// ============================================================================
// UART Functions
// ============================================================================

// Function to send a single character via UART
void uart_putc(char c) {
    // Wait until Transmit Holding Register is empty
    while ((GET32(UART_LSR) & UART_LSR_THRE) == 0);
    PUT32(UART_THR, c);
}

// Function to receive a single character via UART
char uart_getc(void) {
    // Wait until data is available
    while ((GET32(UART_LSR) & UART_LSR_RXFE) != 0);
    return (char)(GET32(UART_THR) & 0xFF);
}

// Function to send a string via UART
void os_write(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

// Function to receive a line of input via UART
void os_read(char *buffer, int max_length) {
    int i = 0;
    char c;
    while (i < max_length - 1) { // Leave space for null terminator
        c = uart_getc();
        if (c == '\n' || c == '\r') {
            uart_putc('\n'); // Echo newline
            break;
        }
        uart_putc(c); // Echo character
        buffer[i++] = c;
    }
    buffer[i] = '\0'; // Null terminate the string
}

// Helper function to print an unsigned integer
void uart_putnum(unsigned int num) {
    char buf[10];
    int i = 0;
    if (num == 0) {
        uart_putc('0');
        uart_putc('\n');
        return;
    }
    do {
        buf[i++] = (num % 10) + '0';
        num /= 10;
    } while (num > 0 && i < 10);
    while (i > 0) {
        uart_putc(buf[--i]);
    }
    uart_putc('\n');
}

// ============================================================================
// Timer Functions
// ============================================================================

// Implement timer initialization
// This function configures DMTIMER2 for a 2-second periodic interrupt
void timer_init(void) {
    // 1. Enable the timer clock
    PUT32(CM_PER_GPIO1_CLKCTRL, 0x40002);

    // Enable clock (BMTIMER2)
    PUT32(CM_PER_TIMER2_CLKCTRL, 0x2);    


    //LEds como salida
    unsigned int val = GET32(GPIO_OE);
    val &= ~USER_LED_MASK; 
    PUT32(GPIO_OE, val);

    // Encendemos los LEDs inmediatamente para verificar que el código arrancó
    PUT32(GPIO_DATAOUT, USER_LED_MASK);

    // 2. Unmask IRQ 68 (Timer2) in the interrupt controller
    PUT32(INTC_MIR_CLEAR2, 0x10);  // Bit 4 = 2^4 = IRQ 68 (64+4)
    
    // 3. Configure interrupt priority and mode (IRQ mode, priority 0)
    PUT32(INTC_ILR68, 0x0);
    
    // 4. Stop the timer
    PUT32(TCLR, 0x0);
    
    // 5. Clear any pending interrupts
    PUT32(TISR, 0x7);
    
    // 6. Set the timer load value for ~2 seconds at 24MHz
    PUT32(TLDR, 0xFE91CA00);
    
    // 7. Set counter to the same value
    PUT32(TCRR, 0xFE91CA00);
    
    // 8. Enable overflow interrupt
    PUT32(TIER, 0x2);
    
    // 9. Start timer in auto-reload mode (AR=1, ST=1)
    PUT32(TCLR, 0x3);
    
    os_write("Timer initialized\n");

    // Configure user LEDs GPIO pins as outputs and turn them off
    // Eliminada la redeclaración de 'val' para evitar error de compilación
    val = GET32(GPIO_OE);
    val &= ~USER_LED_MASK;    // set as outputs (OE bit = 0 => output)
    PUT32(GPIO_OE, val);

    // Ensure LEDs start off (El timer los encenderá en el primer tick)
    PUT32(GPIO_DATAOUT, 0);
}

// Implement timer interrupt handler
// Called from the IRQ exception handler to service timer interrupts
void timer_irq_handler(void) {
    // 1. Clear the timer overflow interrupt flag
    PUT32(TISR, 0x2);
    
    // 2. Acknowledge the interrupt to the controller
    PUT32(INTC_CONTROL, 0x1);
    
    // 3. Print tick message
    os_write("Tick\n");

    // Toggle user LEDs to provide visual tick
    unsigned int dout = GET32(GPIO_DATAOUT);
    dout ^= USER_LED_MASK;
    PUT32(GPIO_DATAOUT, dout);
}

// ============================================================================
// Main Program
// ============================================================================

// Simple random number generator (Linear Congruential Generator)
static unsigned int seed = 12345;

unsigned int rand(void) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed;
}

int main(void) {
    // Print initialization message
    os_write("Starting...\n");
    
    // Initialize the timer
    timer_init();
    
    // Print message before enabling interrupts
    os_write("Enabling interrupts...\n");
    
    // Enable interrupts
    enable_irq();
    
    // Main loop: continuously print random numbers
    while (1) {
        unsigned int random_num = rand() % 1000;
        uart_putnum(random_num);
        
        // Small delay to prevent overwhelming UART
        for (volatile int i = 0; i < 1000000; i++);
    }
    
    return 0;
}