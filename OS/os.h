#ifndef OS_H
#define OS_H

// Low-level OS interface functions
void os_write(const char *s);
void os_read(char *buffer, int max_length);

// UART helper functions
void uart_putc(char c);
char uart_getc(void);
void uart_putnum(unsigned int num);

// Timer functions
void timer_init(void);
void timer_irq_handler(void);

// Interrupt control
void enable_irq(void);

// Low-level memory access functions (implemented in root.s)
void PUT32(unsigned int addr, unsigned int value);
unsigned int GET32(unsigned int addr);

#endif // OS_H
