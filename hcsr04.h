#ifndef HCSR04_H
#define HCSR04_H

#include <stdint.h> 

void hcsr04_init(void);
void hcsr04_tick(void);
int32_t hcsr04_get_distance(void);

#endif /* HCSR04_H */