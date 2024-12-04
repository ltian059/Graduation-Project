#include <stdint.h>
#include "TM4C123GH6PM.h"

void UART1_Init(void) {
    SYSCTL->RCGCUART |= 0x02;       // Enable UART1
    SYSCTL->RCGCGPIO |= 0x02;       // Enable port B
    UART1->CTL &= ~0x01;            // Disable UART1
    UART1->IBRD = 104;              // 16 MHz, 9600 baud rate
    UART1->FBRD = 11;
    UART1->LCRH = 0x70;             // 8-bit, no parity, 1-stop bit, FIFO enabled
    UART1->CTL |= 0x301;            // Enable UART1, TX, RX
    GPIOB->AFSEL |= 0x03;           // Enable alt function on PB0, PB1
    GPIOB->DEN |= 0x03;             // Enable digital on PB0, PB1
    GPIOB->PCTL = (GPIOB->PCTL & 0xFFFFFF00) + 0x00000011;  // Set PB0, PB1 as UART
}

void UART1_WriteChar(char data) {
    while ((UART1->FR & 0x20) != 0);  // Wait until TXFF is 0
    UART1->DR = data;
}

void UART1_WriteString(char* str) {
    while (*str) {
        UART1_WriteChar(*str++); // Send each character in the string
    }
}
void LED_Init(void) {
    SYSCTL->RCGCGPIO |= 0x20;        // Enable clock for Port F
    GPIOF->DIR |= 0x02;              // Set PF1 as output (red LED)
    GPIOF->DEN |= 0x02;              // Enable digital function on PF1
}

void LED_Toggle(void) {
    GPIOF->DATA ^= 0x02;             // Toggle PF1 (red LED)
}

void Delay(void) {
    volatile int i;
    for (i = 0; i < 200000; i++);    // Simple delay loop
}

int main(void) {
    UART1_Init();                    // Initialize UART1
    LED_Init();                      // Initialize LED

    while (1) {
        UART1_WriteString("A\n");  // Send "Hello world"
        LED_Toggle();                        // Toggle red LED
        Delay();                             // Delay to slow down toggling
    }
}
