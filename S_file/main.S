.section .text
/////////////////////////////////////////////////////////////////////////////////////
// GPIO General Purpose I/0 Subroutine package                         0.91 AC
/////////////////////////////////////////////////////////////////////////////////////
.equ GPIOA,  0x40010800     // GPIOB Base address.
.equ GPIOB,  0x40010C00     // GPIOB Base address.
.equ CTR0,   0x00           // Port control register 0 offset
.equ ISTAT,  0x08           // Port input status register
.equ OCTL,   0x0C           // Port output control register
.equ BOP,    0x10           // Port bit operate register offset
.equ BC,     0x14           // Port bit clear register offset
.equ GPIO_AM, 0x0           // Mode: Input, Analog Mode
.equ GPIO_50, 0x3           // Mode: Output, max speed 50MHz
.equ GPIO_FI, 0x4           // Conf: (Input) Floating input
.equ GPIO_UD, 0x8           // Conf: (Input) Pull-up/-down
.equ GPIO_PP, 0x0           // Conf: (Output) Push-pull
.equ GPIO_OD, 0x4           // Conf: (Output) Open-drain

// GPIOI Initialize ////////////////////////////////////////////////// 1.0 / AC ////
// a0 Targeted GPIO-module
// a1 Configuration bits (<<2)
// a2 Mode bits
// a3 Targeted pin

gpioi:  mv t0, a0           // t0 points to GPIOX...
        mv t4, a3           //    t4 marks selected pin...
        li t1,0x8           //    Use port control register 0 or 1,
        blt t4,t1, 1f       //    thus is pin > 7?
        addi t0, t0, 4      //       Yes, adjust base address,
        addi t4,t4,-8       //            and adjust selected pin.

1:      slli t4,t4,2        //    Multiply pin nb by 4 to get steps to shift!
        li t1, 0xF          //    Create inverted configuration mask...
        sll t1, t1, t4      //    ...and move it into right position.
        not t1, t1          //    ...invert it back, then...
        mv t2, a1           //    Create configuration bits...
        or t2, t2, a2       //    
        sll t2, t2, t4      //    ...and move it into right position.

        lw t3,CTR0(t0)      //    retreive port control register 0(/1)...
        and t3,t3,t1        //    ...clear out selected pin's config/mode bits...
        or t3, t3, t2       //    ...configure new config/mode bits...
        sw t3,CTR0(t0)      //    ...and write it back.
        ret                 //  then go home!

// GPIOBO Bit Operations ///////////////////////////////////////////// 1.0 / AC ///
// a0 Targeted GPIO-module
// a1 Targeted pattern
// a2 Targeted pin(s)

gpiobo: and a1, a1, a2      // (Clear all pattern bits that are not target bits)
        xor a2, a2, a1      // Find zeros in targeted bits...
        slli a2, a2, 16     // ...position clear requests...
        or a1, a1, a2       // ...add set requests...
        sw a1, BOP(a0)      // ...then execute...
        ret                 // ...and return to caller!

// GPIBC Bit Clear /////////////////////////////////////////////////// 1.0 / AC ///
// a0 Targeted GPIO-module
// a1 Targeted pin(s)

gpiobc: sw a1, BC(a0)       // Execute request...
        ret                 // ...and return to caller!

// GPIOC Output Control ////////////////////////////////////////////// 1.0 / AC ///
// a0 Targeted GPIO-module
// a1 value

gpiooc: sw a1, OCTL(a0)     // Execute request...
        ret                 // ...and return to caller!

// GPIOIS Input Status //////////////////////////////////////////////// 1.0 / AC ///
// a0 Targeted GPIO-module
// a1 read value

gpiois: lw a1, ISTAT(a0)    // Execute request (return value ought to be in a0)...
        ret                 // ...and return to caller!

/////////////////////////////////////////////////////////////////////////////////////
// RCU Reset and Clock Unit Subroutine package                         0.91 AC
/////////////////////////////////////////////////////////////////////////////////////
.equ RCU,    0x40021000
.equ APB1EN, 0x1C
.equ T5EN,   0x10
.equ APB2EN, 0x18
.equ PAEN,   0x4
.equ PBEN,   0x8
// RCU1EN Enabel APB1 bus devices //////////////////////////////////// 1.0 / AC ///
rcu1en: li t0,RCU           // t0 points to RCU...
        lw t1,APB1EN(t0)    // ...retrieve current configuration...
        or t1,t1,a0         // ...and update the configuration...
        sw t1,APB1EN(t0)    // ...then save back the updated config...
        ret                 // and go home!
// RCU2EN Enabel APB2 bus devices //////////////////////////////////// 1.0 / AC ///
rcu2en: li t0,RCU           // t0 points to RCU...
        lw t1,APB2EN(t0)    // ...retrieve current configuration...
        or t1,t1,a0         // ...and update the configuration...
        sw t1,APB2EN(t0)    // ...then save back the updated config...
        ret                 // and go home!

/////////////////////////////////////////////////////////////////////////////////////
// Timer 5 Subroutine package                                          0.91 AC
/////////////////////////////////////////////////////////////////////////////////////
.equ TIMER5, 0x40001000
.equ T5CTR0, 0x00
.equ UPIF,   0x10
.equ PSC,    0x28
.equ CAR,    0x2C
.equ CNT,    0x24
// T5OMSI Initialize T5 to overflow each millisecond /////////////////// 1.0 / AC ///
.global t5omsi 
t5omsi: addi sp, sp, -4
        sw ra, 0(sp)

        li a0, T5EN         // Prepare to turn on Timer 5...
        call rcu1en         // ..do the set-up! 

        li t0, TIMER5       // Prepare to configur Timer 5...
        li t1, 0x06B        // ...set prescaler to
        sw t1,PSC(t0)       //    divide by 108, thus count 0..107...
        li t1, 0x3E7        // ...and then counter auto reload to
        sw t1, CAR(t0)      //    reload at 999 for a 1ms counter..
        sw zero,UPIF(t0)    // ...then clear the Interrupt Flag...
        li t1,0x01          // ...and start the counting!
        sw t1,T5CTR0(t0)

        lw ra, 0(sp)        // Restore return address...
        addi sp, sp, 4      // ...then the stack pointer...
        ret                 // ...and return to caller!   
.global t5expq
t5expq: li t0, TIMER5       // Prepare to, and then read, Timer 5... 
        lw a0, UPIF(t0)     // ...counter overflow flag...
        beqz a0, 1f         // ...done if not overflow...
        sw zero,UPIF(t0)    // ...else reset flag...
1:      ret                 // ...and return to caller!

/////////////////////////////////////////////////////////////////////////////////////
// Column hw driver Subroutine package                                   0.9 AC
// Needs: RCU & GPIO Package
/////////////////////////////////////////////////////////////////////////////////////
.section .data
column:  .word 7
.section .text
// ColInit Initialize the Column driver //////////////////////////////// 1.0 / AC ///
.global colinit
colinit:addi sp, sp, -4     // Make room on the stack...
        sw ra, 0(sp)        // ...for another return adress!
        
        li a0, PBEN         // Prepare to turn on GPIOB...
        call rcu2en         // ..do the set-up!  
        
        li a0, GPIOB        // Prepare to init GPIOB...
        li a1, GPIO_PP      // ...as Push-Pull Output...
        li a2, GPIO_50      // ...with max 50MHz rate...
        li a3, 0            // ...for pin 0...
        li a4, 3            // ...to pin 2...
1:      call gpioi          // ...do the set-up!
        addi a3,a3,1        // ...advance to next pin...
        bne a3,a4, 1b       // ...continue, if not done!

        lw ra, 0(sp)        // Restore return address...
        addi sp, sp, 4      // ...then the stack pointer...
        ret                 // ...and return to caller!

// Colget Return current column value ////////////////////////////////// 1.0 / AC ///
// a0 Return current active column
colget: la t0, column       // Prepare to read the column state...
        lb a0, 0(t0)        // ...do the read...
        ret                 // ...and return to caller!

// Colset Advance to "next" column (actually count down) /////////////// 1.0 / AC ///
// a0 Return "new" active column
.global colset
colset: addi sp, sp, -4     // Make room on the stack...
        sw ra, 0(sp)        // ...for another return adress!
        
        li a0, GPIOB        // Prepare to com with GPIOB0..2 attached hw
        la t0, column       // as well as to read the column state...
        lb a1, 0(t0)        // ...do the read...
        addi a1,a1,-1       // ...advance to next column...
        bgez a1, 1f         // ...modulo 8...
        li a1, 7            // ...fix wrap around...
1:      sb a1, 0(t0)        // ...and store the new value...
        li a2, 0x07         // ...then point out the relevant bits...
        call gpiobo         // ...and set/reset corresponing I/O bits...
        lb a0, 0(t0)        // ...read back the return value...

        lw ra, 0(sp)        // ...and return to caller!
        addi sp, sp, 4
        ret                 

/////////////////////////////////////////////////////////////////////////////////////
// 8*8LED hw driver Subroutine package                                   0.9 AC
/////////////////////////////////////////////////////////////////////////////////////
.section .data
l88mmat: .word l88mmap
l88mmap:
         .byte 0xF1, 0xE3, 0xC7, 0x87, 0xC3
         .byte 0xF3, 0xF8, 0xF1, 0xE3, 0xC7
         .byte 0xF1, 0xE3, 0xC7, 0x87, 0xC3
         .byte 0xF3, 0xF8, 0xF1, 0xE3, 0xC7
         .byte 0xF1, 0xE3, 0xC7, 0x87, 0xC3
         .byte 0xF3, 0xF8, 0xF1, 0xE3, 0xC7
         .byte 0xF1, 0xE3, 0xC7, 0x87, 0xC3
         .byte 0xF3, 0xF8, 0xF1, 0xE3, 0xC7
         .byte 0xF1, 0xE3, 0xC7, 0x87, 0xC3
         .byte 0xF3, 0xF8, 0xF1, 0xE3, 0xC7

l88mmap_end:


.section .text
// l88init Initialize the 8*8LED matrix row hw driver ////////////////// 1.0 / AC ///
// (The 8*8LED matrix column part is managed through the Column hw driver package)
.global l88init
l88init:addi sp, sp, -4
        sw ra, 0(sp)
        
        li a0, PBEN         // Prepare to turn on GPIOB...
        call rcu2en         // ..do the set-up!  

        li a0, GPIOB        // Prepare to init GPIOB...
        li a1, GPIO_PP      // ...as Push-Pull Output...
        li a2, GPIO_50      // ...with max 50MHz rate...
        li a3, 8            // ...for pin 08...
        li a4, 16           // ...to pin 15...
1:      call gpioi          // ...do the set-up!
        addi a3,a3,1        // ...advance to next pin...
        bne a3,a4, 1b       // ...continue, if not done! 

        lw ra, 0(sp)
        addi sp, sp, 4
        ret

// l88row Looks up row data and emits it on right GPIO pins //////////// 1.0 / AC ///
// a0 Active column (base address of l88mmap expected to be in l88mmat)
.global l88row
l88row: addi sp, sp, -4
        sw ra, 0(sp)
        
        la t0, l88mmat
        lw t0, 0(t0)
        add t0, t0, a0    
        lbu a1, 0(t0)         

        la t5, player
        lbu t2, 0(t5)    

        li   t3, 0
        bnez a0, skip_player 

        li   t4, 1
        sll  t4, t4, t2     
        or   a1, a1, t4    

skip_player:

        slli a1, a1, 8
        li   a0, GPIOB
        li   a2, 0x0FF00
        call gpiobo

        lw ra, 0(sp)
        addi sp, sp, 4
        ret
.global l88mem
l88mem: la t0, l88mmat      // Load memory map base address...
        lw t0, 0(t0)        // ...stored in l88mmat...
        add t0,t0,a0        // ...add offset to right row...
        sb a1,(t0)
        ret


/////////////////////////////////////////////////////////////////////////////////////
// 4*4KEY hw driver Subroutine package                                   0.9 AC
/////////////////////////////////////////////////////////////////////////////////////
.section .data
keytime: .word 0x200        // Key bounce/repeat/monky timeout

.section .text
// keyinit Initialize mcu to be able to read kbdkeyboard row data ////// 1.0 / AC ///
.global keyinit
keyinit:addi sp, sp, -4     // Push: Make room on the stack...
        sw ra, 0(sp)        // ...for another return address!

        li a0, PAEN         // Prepare to turn on GPIOA...
        call rcu2en         // ..do the set-up!

        li a0, GPIOA        // Prepare to init GPIOA...
        li a1, GPIO_AM      // ...in Analoge mode...
        li a2, GPIO_FI      // ...with High-Z...
        li a3, 5            // ...for pin 5...
        li a4, 9            // ...to pin 8...
1:      call gpioi          // ...do the set-up!
        addi a3,a3,1        // ...advance to next pin...
        bne a3,a4, 1b       // ...continue, if not done! 

        lw ra, 0(sp)        // Pop: Read back last stored return address...
        addi sp, sp, 4      // ...and reclame used stack space...
        ret                 // ...then return to caller!  
// keyscan Analyze row feedb. from act. col. to check for key pressed / 1.0 / AC ///  
// a0 returns key code if a key is pressed else -1       
.global keyscan
keyscan:addi sp, sp, -4     // Push: Make room on the stack...
        sw ra, 0(sp)        // ...for another return address!

        li t3,-1            // Most likely nothing to report!
        la t4,keytime       // Count down bounce/repeat/monky counter...
        lw t1,0(t4)         // (if code updated, check t4 preserved.)
        addi t2, t1, -1
        sw t2,0(t4)        
        bnez t2, 1f         // ...not ready until zero, skip!
        sw t1,0(t4)         // ...Ready, back-up counter to 1...

        li a0, GPIOA        // Prepare to read GPIOA...
        call gpiois         // ...and get the value!
        srli a1,a1,5        // ...shift it down 5 steps...
        andi a1,a1,0x0F     // ...mask out 3 lsb...
        beqz a1,1f          // ...if it is zero, then done!
                            //    (Key pressed!)
        srli a1,a1,1        // ...Row is 0010?
        snez a0,a1
        add t1,zero,a0
        srli a1,a1,1        // ...0100?
        snez a0,a1
        add t1,t1,a0
        srli a1,a1,1        // ...1000?        
        snez a0,a1
        add t1,t1,a0        // (else it must have been 0001)

        call colget         // Get active column (must be 0..3)
        slli a0,a0,2        // ...move it up 2 bits...
        or t3,t1,a0         // ...and combind it with row data!

        li t1,0x200         // Reload repeat counter...
        sw t1,0(t4)         // ...with max value.

1:      mv a0,t3            // Get the return value, -1 or key.

        lw ra, 0(sp)        // Pop: Read back last stored return address...
        addi sp, sp, 4      // ...and reclame used stack space...
        ret                 // ...then return to caller!       
/// END //////////////////////////////////////////////////////////////////// 

/////////////////////////////////////////////////////////////////////////////////////
// BCD 4 Digits Counter Subroutine package                                   0.9 AC
/////////////////////////////////////////////////////////////////////////////////////
.section .data
bcd4dc: .half 0xFFFF        // Counter (uninitialized)
.section .text
// bcd4dc_reset //////////////////////////////////////////////////////// 1.0 / AC ///
bcd4dc_reset:
        la t0,bcd4dc        // t0 points to counter...
        sh zero, 0(t0)      // ...clear counter...
        ret                 // ...and go home!

// bcd4dc_tick ///////////////////////////////////////////////////////// 1.0 / AC ///
bcd4dc_tick:
        la t0,bcd4dc        // t0 points to counter...
        lhu t1, 0(t0)       // ...read counter...
        li t2, 0x9          // ...overflow constant...

        addi t1, t1, 1      // ...add 1 (tick)

        andi t3, t1, 0xF    // ...mask out one's...
        ble t3, t2, 1f      // ...done if one's didn't overflow?
        addi t1, t1, 0x6    // ...they did, add 0x6...

        srli t3, t1, 4      // ...position the ten's...
        andi t3, t3, 0xF    // ...mask out ten's...
        ble t3, t2, 1f      // ...done if ten's didn't overflow?
        addi t1, t1, 0x60   // ...they did, add 0x60...

        srli t3, t1, 8      // ...position the 100's...
        andi t3, t3, 0xF    // ...mask out 100's...
        ble t3, t2, 1f      // ...done if 100's didn't overflow?
        addi t1, t1, 0x600  // ...they did, add 0x600...

        srli t3, t1, 12     // ...position the 1000's...
        ble t3, t2, 1f      // ...done if 1000's didn't overflow?
        li t1, 0            // ...they did, reset the counter!

1:      sh t1,0(t0)         // ...save the new value...
        ret                 // ...and go home!

// bcd4dc_read ///////////////////////////////////////////////////////// 1.0 / AC ///
bcd4dc_read:
        la t0,bcd4dc        // t0 points to counter...
        lhu a0, 0(t0)       // ...read counter...
        ret                 // ...and go home!
/// END ///////////////////////////////////////////////////////////////////////////// 

.section .data
fcounter:.word 0x00008F     // Change Frame Buffer each 0x8E ms!
speed:   .word 0x000006FF  

.section .text
flow:
        la   t0, run_flag
        lw   t1, 0(t0)
        beqz t1, 9f

        # t4 = &fcounter (DO NOT overwrite t4 later)
        la   t4, fcounter
        lw   t1, 0(t4)
        addi t1, t1, -1
        bnez t1, 8f
        
        la  t5, speed
        lw  t1, 0(t5)

        li  t0, 0xC
        bge  t0, t1, 4f
        addi t1, t1, -1
        sw  t1, 0(t5)

        # t2 = &l88mmat, t3 = current window pointer
4:      la   t2, l88mmat
        lw   t3, 0(t2)

        # t5 = last valid window start = l88mmap_end - 8
        la   t5, l88mmap_end
        addi t5, t5, -8

        bgeu t3, t5, 1f
        addi t3, t3, 1
        j    2f
1:      la   t3, l88mmap
2:      sw   t3, 0(t2)

8:      sw   t1, 0(t4)      # write back to fcounter ONLY
9:      ret

.section .data
index:  .word 0x7

.section .data
run_flag: .word 1      # 1 表示滚动，0 表示停止

player: .byte 0x04

.section .text
.global main
main:   call t5omsi         // Initialize timer 5 to count milliseconds!
        call colinit        // Initialize the Column driver!
        call l88init        // Initialize the 8*8 LED matrix driver!
        call keyinit        // Initialize the 4*4 keyboard driver! 

1:      nop           
        call t5expq         # 检查定时器
        beqz a0, 1b         # 时间未到则循环
        
        call flow           # 处理滚动逻辑
        call colset         # 刷新LED列
        call l88row         # 刷新LED行
        call keyscan        # 获取按键状态

    # 无按键检查 
        bltz a0, 1b         # a0 < 0 (无按键)，直接回到 1
        andi a0, a0, 0x0F

        li   t2, 5
        beq  a0, t2, handle_toggle 

        li  t2, 1
        beq a0, t2, move_left

        li t2, 9
        beq a0, t2, move_right

        j 1b

move_left:
        la t0, player
        lb t1, 0(t0)
        addi t1, t1, -1
        andi t1, t1, 0x7
        sb t1, 0(t0)
        j wait_release

move_right:
        la t0, player
        lb t1, 0(t0)
        addi t1, t1, +1
        andi t1, t1, 0x7
        sb t1, 0(t0)
        j wait_release

        la   t0, index
        lw   t1, 0(t0)
        addi t2, t1, -1
        bgez t2, 2f
        li   t2, 7
2:      sw   t2, 0(t0)
        la   t0, l88mmap
        add  t0, t0, t1
        sb   a0, 0(t0)
        j    1b             # 处理完普通按键，跳回 1

# --- 4. 暂停处理逻辑 (独立出来) ---
handle_toggle:
        la   t0, run_flag
        lw   t1, 0(t0)
        xori t1, t1, 1      # 翻转 run_flag (1 -> 0 或 0 -> 1)
        sw   t1, 0(t0)

wait_release:
        # 即使在等待松手，也要维持显示扫描
        call colset         
        call l88row         
        
        # 延时，控制 keyscan 内部计数器的衰减
        li   t6, 0x2000      
delay:  addi t6, t6, -1
        bnez t6, delay
        
        call keyscan        # 再次检查按键
        li   t3, -1
        bne  a0, t3, wait_release  # 只要不是 -1 (还在按着)，就继续等
        j    1b                    # 松手了，回到主循环

8:      # 其他按键：保持你原本的 trace 写入逻辑
        la   t0, index
        lw   t1, 0(t0)
        addi t2, t1, -1
        bgez t2, 2f
        li   t2, 7
2:      sw   t2, 0(t0)
        la   t0, l88mmap
        add  t0, t0, t1
        sb   a0, 0(t0)
        j    1b             // ...again, forever!
.end