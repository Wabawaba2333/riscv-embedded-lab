#include "gd32vf103.h"
#include "drivers.h"
#include "pwm.h"
#include "alarm.h"


int main(void)
{
    int ms = 0, s = 0, pKey = -1, c = 0, idle = 0, adcr, tmpr;
    char lookUpTbl[16] = {
        '1','4','7','*', // 0-3
        '2','5','8','0', // 4-7
        '3','6','9','#', // 8-11
        'A','B','C','D'  // 12-15
    };

    T1powerUpInitPWM(0x3);    // 同时初始化 A0(CH0) 和 A1(CH1)
    T1setPWMch2(0);           // A0 初始关闭
    aSet(15999);              // A1 初始点亮
    int Coordinate_code = 0;
    int light = 0;
    int procent_light = 0;

    int secret = 0;
    int lockstate = 0;

    /* 新增变量：用于控制平滑过渡 */
    int target_pwm = 0;   // 期望最终达到的亮度值
    int current_pwm = 0;  // 当前硬件正在输出的亮度值
    int step = 160;       // 16000 的 1% 为 160

    int a0_on = 0;         // 独立状态：A0 是否亮着

    t5omsi();                                     // Initialize timer5 1kHz
    colinit();                                     // Initialize column toolbox
    l88init();                                    // Initialize 8*8 led toolbox
    keyinit();                                    // Initialize keyboard toolbox

    while (1)
    {
        idle++;                                   // Manage Async events
        if (t5expq()) 
        {                                           // Manage periodic tasks
            l88row(colset());                     // ...8*8LED and Keyboard

            ms++;                                 // ...One second heart beat
            
            /* 每当 ms 经过 20ms 的整数倍时，调整一次亮度 */
            if (ms % 20 == 0)
            {
                if (current_pwm < target_pwm)
                {
                    current_pwm += step;
                    if (current_pwm > target_pwm)
                    {
                        current_pwm = target_pwm;
                    }
                    T1setPWMch2(current_pwm);
                }
                else if (current_pwm > target_pwm)
                {
                    current_pwm -= step;
                    if (current_pwm < target_pwm)
                    {
                        current_pwm = target_pwm;
                    }
                    T1setPWMch2(current_pwm);
                }

                /* 独立判断：基于 current_pwm 更新 a0_on，联动 A1 */
                if (current_pwm > 0 && a0_on == 0)
                {
                    a0_on = 1;
                    aSet(0);       // A0 亮 → A1 灭
                }
                else if (current_pwm == 0 && a0_on == 1)
                {
                    a0_on = 0;
                    aSet(15999);   // A0 灭 → A1 亮
                }
            }

            if (ms==1000)
            {
                ms=0;
                l88mem(0,s++);
            }

            if ((Coordinate_code=keyscan())>=0)  // ...Any key pressed?
            {   
                int Keyboard_code = lookUpTbl[Coordinate_code];

                if(pKey!=Coordinate_code)
                {
                    if (Keyboard_code == 'C') 
                    {
                        if (secret == 72) 
                        {
                            lockstate = !lockstate;   // 密码正确，切换锁状态
                        }

                        secret = 0;
                        light = 0; 
                    } 
                    else if (lockstate == 0)
                    {
                        switch(Keyboard_code)
                        {
                            case '0': case '1': case '2': case '3': case '4':
                            case '5': case '6': case '7': case '8': case '9':

                                light = (light * 10) + Keyboard_code - '0';
                                if (light > 100)
                                {
                                    light = 100;
                                }

                                secret = (secret % 10) * 10 + (Keyboard_code - '0');
                                break;

                            case '*': 
                                light = light / 10;
                                secret = 0;
                                break;

                            case '#':  
                                light = 0;
                                secret = 0;
                                break;

                            case 'A':
                                light = 100;
                                target_pwm = 16000;
                                break;

                            case 'B':
                                light = 0;
                                target_pwm = 0;
                                break;
                                
                            case 'D':
                                procent_light = (light * 16000)/100;
                                if(procent_light > 16000)
                                {
                                    procent_light = 16000;
                                }
                                target_pwm = procent_light;
                                light = 0;
                                break;
                        }
                    }
                    else 
                    {
                        if (Keyboard_code >= '0' && Keyboard_code <= '9')   
                        {
                            secret = (secret % 10) * 10 + (Keyboard_code - '0');
                        } 
                        else if (Keyboard_code == '#') 
                        {
                            secret = 0;
                        }
                    }

                    pKey = Coordinate_code;
                    c = 0;
                } 
                else 
                {
                    c++;
                }
                
                l88mem(1, Keyboard_code + (c << 4));
                l88mem(4, light); 
                l88mem(5, lockstate);
            } 
            else 
            {
                pKey = -1;
            }
            
            l88mem(2,idle>>8);                    
            l88mem(3,idle); idle=0;
        }
    }
}