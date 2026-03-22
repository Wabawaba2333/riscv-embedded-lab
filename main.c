#include "gd32vf103.h"
#include "drivers.h"
#include "adc.h"
#include "lcd.h"
#include "usart.h"
#define EI 1
#define DI 0


void rtcInit(void){
   // enable power managemenet unit - perhaps enabled by default
   rcu_periph_clock_enable(RCU_PMU);
   // enable write access to the registers in the backup domain
   pmu_backup_write_enable();
   // enable backup domain
   rcu_periph_clock_enable(RCU_BKPI);
   // reset backup domain registers
   bkp_deinit();
   
   bkp_rtc_calibration_value_set(0);

   // setup RTC
   // enable external low speed XO (32.768 kHz)
   // rcu_osci_on(RCU_LXTAL);
   if (rcu_osci_stab_wait(RCU_LXTAL)) {
     // use external low speed oscillator, i.e. 32.768 kHz
     rcu_rtc_clock_config(RCU_RTCSRC_LXTAL);
     rcu_periph_clock_enable(RCU_RTC);
     // wait until shadow registers are synced from the backup domain
     // over the APB bus
     rtc_register_sync_wait();
     // wait until shadow register changes are synced over APB
     // to the backup domain
     rtc_lwoff_wait();
     // prescale to 1 second: 32768 Hz / 32768 = 1 Hz
     rtc_prescaler_set(32767);
     rtc_lwoff_wait();
     rtc_flag_clear(RTC_INT_FLAG_SECOND);
    rtc_interrupt_enable(RTC_INT_SECOND);
     rtc_lwoff_wait();
   }
}

int main(void){
    int ms=0, s=0, key, pKey=-1, c=0, idle=0;
    int lookUpTbl[16]={1,4,7,14,2,5,8,0,3,6,9,15,10,11,12,13};
    int adcr, tmpr;
    int hexState=0, firstNibble=0, txByte;    // Hex input state machine
    char rx;
    int curX=80, curY=40;                     // Drawing pen position (screen centre)
    int drawDir=0, drawSteps=0, stepMs=0;     // Drawing state machine
    int cmdBuf[7], cmdBufLen=0;               // Stored command buffer (max 7)
    int cmdBufIdx=0, playing=0;               // Playback state

    t5omsi();                               // Initialize timer5 1kHz
    colinit();                              // Initialize column toolbox
    l88init();                              // Initialize 8*8 led toolbox
    keyinit();                              // Initialize keyboard toolbox
    ADC3powerUpInit(1);                     // Initialize ADC0, Ch3
    Lcd_SetType(LCD_NORMAL);                // or use LCD_INVERTED!
    Lcd_Init();
    LCD_Clear(RED);
    LCD_ShowStr(10, 10, "Lab #5", WHITE, TRANSPARENT);
    rtcInit();                              // Initialize RTC
    rtc_counter_set(3600+60+1);
    u0init(EI);                             // Initialize USART0 toolbox
    LCD_DrawPoint(80, 40, WHITE);           // Draw starting dot at screen centre

    eclic_global_interrupt_enable();        // !!! INTERRUPT ENABLED !!!

    while (1) 
    {
        idle++;                             // Manage Async events
        LCD_WR_Queue();                     // Manage LCD com queue!
        u0_TX_Queue();                      // Manage U(S)ART TX Queue!

        if (adc_flag_get(ADC0,ADC_FLAG_EOC)==SET)  // ...ADC done?
        {

          if (adc_flag_get(ADC0,ADC_FLAG_EOIC)==SET) 
          {
            tmpr = adc_inserted_data_read(ADC0, ADC_INSERTED_CHANNEL_0);
            l88mem(7,((0x680-tmpr)/5)+25);              // Temperature on row 7
            adc_flag_clear(ADC0, ADC_FLAG_EOC); 
            adc_flag_clear(ADC0, ADC_FLAG_EOIC); 
          }
          
          else 
          {
            adcr = adc_regular_data_read(ADC0); // ......get data
            l88mem(4,adcr>>8);                  // ......move data
            l88mem(5,adcr);                     // ......(view each ms)
            adc_flag_clear(ADC0, ADC_FLAG_EOC); // ......clear IF
          }
        }

        //RX

        if (usart_flag_get(USART0,USART_FLAG_RBNE)) 
        {
          rx = (char)usart_data_receive(USART0);        // Read once into rx
          l88mem(6, rx);                                // Display on 8x8 LED row 6
        }

        if (t5expq()) 
        {                     // Manage periodic tasks
            l88row(colset());               // ...8*8LED and Keyboard
            ms++;                           // ...One second heart beat
            if (ms==1000)
            {
              ms=0;
              l88mem(0,s++);
            }

            // Drawing step: one pixel per second
            if (drawSteps > 0 && ++stepMs >= 100) {
              stepMs = 0;
              if      (drawDir==2) curY--;  // up
              else if (drawDir==4) curX--;  // left
              else if (drawDir==6) curX++;  // right
              else if (drawDir==8) curY++;  // down
              LCD_DrawPoint(curX, curY, WHITE);
              
              if (--drawSteps == 0 && playing) 

              {
                if (cmdBufIdx < cmdBufLen) 
                {
                  int cmd = cmdBuf[cmdBufIdx++];
                  drawDir = (cmd>>4) & 0x0F;
                  drawSteps = cmd & 0x0F;
                } 

                else
                { playing=0; cmdBufLen=0; cmdBufIdx=0; }  // done: clear buffer
              }
            }


            if ((key=keyscan())>=0)        // ...Any key pressed?
            {

              if (pKey==key) c++; 
              
              else {c=0; pKey=key;}

              l88mem(1,lookUpTbl[key]+(c<<4));

              if (c==0)                 // New key press (debounced)
              {   

                int hexDigit = lookUpTbl[key]; // 0-15 (* -> E, # -> F)

                if (hexDigit==13 && hexState==0) 
                
                {
                  //D
                  if (cmdBufLen > 0) 
                  {
                    cmdBufIdx = 0; playing = 1;
                    int cmd = cmdBuf[cmdBufIdx++];
                    drawDir=(cmd>>4)&0x0F; drawSteps=cmd&0x0F; stepMs=0;
                  }

                } 
                
                else if (!playing) 
                {
                  if (hexState==0) 
                  {
                    // FSM state 0: waiting for first hex nibble
                    firstNibble = hexDigit;
                    hexState = 1;
                  } 
                  
                  else 
                  {
                    // FSM state 1: store drawing command in buffer
                    txByte = (firstNibble<<4) | hexDigit;

                    { int _m = (txByte>>4)&0x0F;

                      if ((_m==2||_m==4||_m==6||_m==8) && (txByte&0x0F)>=1 && cmdBufLen<7)
                        cmdBuf[cmdBufLen++] = txByte;  // store, do not execute yet
                    }
                    hexState = 0;
                  }
                }
              }
            } 

            else
             {
              // Key released: re-arm debounce so same key can be entered again
              pKey = -1;
              c = 0;
            }
            l88mem(2,idle>>8);              // ...Performance monitor
            l88mem(3,idle); idle=0;
            adc_software_trigger_enable(ADC0, //Trigger another ADC conversion!
                                        ADC_REGULAR_CHANNEL);
        }
    }
}