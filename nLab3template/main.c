#include "gd32vf103.h"
#include "drivers.h"
#include "pwm.h"

int main(void){
    int ms=0, s=0, key, pKey=-1, c=0, idle=0, adcr, tmpr;
    int lookUpTbl[16]={1,4,7,14,2,5,8,0,3,6,9,15,10,11,12,13};

    t5omsi();                                     // Initialize timer5 1kHz
    colinit();                                    // Initialize column toolbox
    l88init();                                    // Initialize 8*8 led toolbox
    keyinit();                                    // Initialize keyboard toolbox
    //T1powerUpInitPWM(0x4);                      // Timer #1, Ch #2 PWM
    //T1powerUpInitPWM(0xC);                      // Timer #1, Ch #2 & 3 PWM

    while (1) {
        idle++;                                   // Manage Async events
 
        if (t5expq()) {                           // Manage periodic tasks
            l88row(colset());                     // ...8*8LED and Keyboard

            ms++;                                 // ...One second heart beat
            if (ms==1000){
              ms=0;
              l88mem(0,s++);
            }

            if ((key=keyscan())>=0) {             // ...Any key pressed?
              if (pKey==key) c++; else {c=0; pKey=key;}
              l88mem(1,lookUpTbl[key]+(c<<4));
            }
            
            l88mem(2,idle>>8);                    // ...Performance monitor
            l88mem(3,idle); idle=0;
        }
    }
}