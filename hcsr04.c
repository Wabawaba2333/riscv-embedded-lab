#include "hcsr04.h"
#include "gd32vf103.h"

#define MTIME_LO (*(volatile uint32_t*)0xD1000008)
#define TICK_PER_MS (27000)
#define TIME_OUT_30MS (810000)

typedef enum status
{
    STATE_IDLE,
    STATE_TRIG,
    STATE_ECHO_HIGH,
    STATE_ECHO_LOW,
    STATE_ERROR
} hcsr04state;

static hcsr04state current_state = STATE_IDLE;
static uint32_t start_time = 0;
static uint32_t end_time = 0;
static int32_t distance= 0;
static uint32_t error_count = 0;

static uint32_t last_trig_time = 0;

void hcsr04_init(void)
{
    rcu_periph_clock_enable(RCU_GPIOA);

    gpio_init(GPIOA, GPIO_MODE_OUT_PP, GPIO_OSPEED_50MHZ, GPIO_PIN_0);
    gpio_init(GPIOA, GPIO_MODE_IN_FLOATING, GPIO_OSPEED_50MHZ, GPIO_PIN_1);
}

int32_t hcsr04_get_distance(void)  {return distance;}

void hcsr04_tick(void)
{
    switch(current_state)
    {
        case STATE_IDLE:
        if(MTIME_LO - last_trig_time >= 2700000) //wait for 100ms
        {current_state = STATE_TRIG;}
        break;

        case STATE_TRIG:
        gpio_bit_set(GPIOA, GPIO_PIN_0);
        uint32_t t = MTIME_LO;
        while(MTIME_LO - t < 270);  // 270 tick = 10µs @ 27MH

        gpio_bit_reset(GPIOA, GPIO_PIN_0);
        last_trig_time = MTIME_LO;
        current_state = STATE_ECHO_HIGH;
        break;

        case STATE_ECHO_HIGH:
        if(gpio_input_bit_get(GPIOA,GPIO_PIN_1) == SET)
        {
            start_time = MTIME_LO;
            current_state = STATE_ECHO_LOW;
        }

        else if(MTIME_LO - last_trig_time > TIME_OUT_30MS) //1s = 2700 0000 tck, 1ms = 27000 tck
        {current_state = STATE_ERROR;}
        break;

        case STATE_ECHO_LOW:
        if(gpio_input_bit_get(GPIOA,GPIO_PIN_1) == RESET)
        {
            end_time = MTIME_LO;
            distance = ((end_time - start_time) * 10 / 27) / 58; // Distance conversion constant based on laboratory room temperature
            error_count = 0;
            current_state = STATE_IDLE;
        }

        else if(MTIME_LO - start_time > TIME_OUT_30MS)
        {current_state = STATE_ERROR;}
        break;
        
        case STATE_ERROR:
        error_count++;

        if(error_count > 3)
        {distance = -1;}

        current_state = STATE_IDLE;
        last_trig_time = MTIME_LO;
        break;

        default:
        current_state = STATE_IDLE;
        break;

    }
}