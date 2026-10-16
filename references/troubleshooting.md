# 症状 → 病因 → 修法

按"先编译期、再运行期"的顺序查。运行期的问题几乎都是**初始化漏项**或**接线**，
共同特征是"编译 0 错误、上电没反应"。

## 一、编译期

### 1. `cannot open source input file "core_cm4.h"`（或任何 CMSIS 头文件）

`IncludePath` 写的是 `..\CMSIS`，但头文件其实在更深一层：

| 文件 | 实际位置 |
|---|---|
| `core_cm4.h` | `..\CMSIS\Include\` |
| `stm32f4xx.h` | `..\CMSIS\Device\ST\STM32F4xx\Include\` |

两个都要加进 Include Paths。注意：**修好路径后会立刻报下一个错**——工程里通常还缺
`USER\stm32f4xx_conf.h`（`USE_STDPERIPH_DRIVER` 会去 include 它），从标准库模板复制一份即可。

报错信息里出现的路径若像 `AppData\Local\Arm\Packs\Keil\STM32F4xx_DFP\...`，说明编译器
退而用了 Keil 设备包里的另一套头文件，那不是工程自带的库——根子还是 Include Path 缺项。

### 2. 芯片宏与实物不符

- 板子是 F405，宏却写 `STM32F401xx` → 应该用 **`STM32F40_41xxx`**。
  **不会报错**，但选的是 F401 的外设子集与中断表。
- Device 下拉里选 `STM32F405RGTx`（64 脚）而实物是 **`STM32F405VGTx`**（100 脚）。

## 二、运行期（编译 0 错误但不工作）

| 症状 | 病因 | 修法 |
|---|---|---|
| 屏全黑，**连背光都不亮**，但串口有打印 | `lcd_pin_init()` 没开 **GPIOD 时钟** → DC(PD3)/背光(PD4) 的配置全写不进去 | 补 `RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOB \| RCC_AHB1Periph_GPIOD, ENABLE)` |
| 程序卡死（串口打印到一半就没了） | `LCD_Init()` 没调 `spi1_init()` → SPI1 没使能，`spi1_send_recv()` 里 `while(RXNE==RESET)` 死等 | 在 `LCD_Init()` 开头调 `spi1_init()` |
| 电脑一发数据，板子就彻底僵死（只能复位） | 开了 RXNE/IDLE 中断却没写 `USARTx_IRQHandler` → 跳进启动文件里的弱定义 `B .` | 写中断服务函数；或先注掉 `USART_ITConfig` + NVIC 那段 |
| 画面整体上移约 25 行（顶边被切、底部一条空白） | 240×240 面板装在 240×320 显存的屏里 | `lcd_set_area()` 里 `ys/ye += 25`（参考工程叫 `LCD_Y_OFFSET`）。注意整屏清屏要改成清 240 行，否则越界 |
| 风扇 / 舵机不转 | ① 结构体成员没赋全（可能被配成开漏）② 小电机低速扭矩不足 ③ 插错座 / 没 5V | 补全结构体；占空比改成 **100%** 复测；确认插的是"直流电机/MOTOR"座、5V 有电 |
| 蜂鸣器 / 继电器单独调用不工作，跟 LED 一起初始化就正常 | 该端口时钟只在别的 `Init()` 里开过（LED 和 BEEP 同在 GPIOD 就是这种情况） | 每个 `xxx_Init()` 自己开自己端口的时钟 |
| 串口收到完全规律的重复乱码 | 波特率不匹配（时钟算错），或收到的根本不是这台设备的数据 | 先确认 SYSCLK=168MHz；再确认选对了串口（见下） |
| 能发不能收 / 收不到命令 | TXD-RXD 没交叉，或没共地 | 模块 TXD→MCU RX、模块 RXD→MCU TX，GND 对接 |

## 三、本机已知事实（省得重复排查）

**串口**：板载 CH340 当前是 **COM4**（换 USB 口编号会变）。查询：
`Get-ItemProperty 'HKLM:\HARDWARE\DEVICEMAP\SERIALCOMM'`。
**COM5 / COM6 是蓝牙虚拟口**——串口工具里报"打开串口失败"属正常，忽略即可；
烧录/调试前要关掉占用 COM4 的程序（串口助手 xcom 等）。

**定时器时钟**：APB1 分频 4 → TIM2/3/5 时钟 **84MHz**；APB2 分频 2 → TIM1/TIM8 时钟 **168MHz**
（`psc=840, arr=100` 在 TIM8 上约 2kHz，不是 1kHz——容易算错一倍）。

**位带**：STM32F4 **支持**位带（参考手册 2.3.3 位段），`PBout(n)` / `PBin(n)` 可用
（Cortex-M7 才移除）。

**printf**：工程用 MicroLIB；`%f` **可用**（链接器会自动选带浮点的 `printfa` 变体）。
重定向靠自定义 `fputc`；若同时要 `__use_no_semihosting`，需一起提供 `_sys_exit` / `_ttywrch`。

**软件模拟 I2C**：两个脚配成**开漏输出**，读 SDA 时直接读 IDR（输出模式下 IDR 仍反映引脚电平）。
若担心个别芯片/端口行为，可读的时候切成"带上拉的输入模式"再切回，功能等价、更保险。
