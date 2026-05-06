/* 
Replace this file with your code. Put your source files in this directory and any libraries in the lib folder. 
If your main program should be assembly-language replace this file with main.S instead.

Libraries (other than vendor SDK and gcc libraries) must have .h-files in /lib/[library name]/include/ and .c-files in /lib/[library name]/src/ to be included automatically.
*/

#include "gd32vf103.h"
#define BITMASK 0xFFFFFFF8

int main(){
	uint32_t port = 0;
	uint32_t count = 0;
	rcu_periph_clock_enable(RCU_GPIOB);
	gpio_init(GPIOB, GPIO_MODE_OUT_PP, GPIO_OSPEED_50MHZ, GPIO_PIN_0 | GPIO_PIN_1 | GPIO_PIN_2);
	while(1){
		count += 1;
		port = gpio_input_port_get(GPIOB);
		gpio_port_write(GPIOB, (port & BITMASK) | (count & (~BITMASK)));
		for(volatile int i = 0; i < 1000000; i++);
	}

}
