# 各外设的代码形状（本课程实际用过的写法）

共同套路：**激活时钟 → 填结构体（每个成员都填）→ Init → Cmd 使能**。
下面只写容易踩错的关键点。

## GPIO

输出：`GPIO_Mode_OUT` + `GPIO_OType_PP` + `GPIO_PuPd_NOPULL` + `GPIO_Speed_Low/Medium`。
输入：`GPIO_Mode_IN`，上下拉按外部电路定（外部已有上拉/下拉就 `NOPULL`）。
同一结构体可连续 `GPIO_Init` 多个端口，只改 `GPIO_Pin`，其余成员会沿用。

## USART + printf 重定向

1. 引脚配 `GPIO_Mode_AF` + `GPIO_PinAFConfig(端口, GPIO_PinSourceX, GPIO_AF_USARTn)`
2. `USART_Init`：115200 / 8b / 1 停止位 / 无校验 / 无硬件流控 / Rx|Tx
3. 重定向：自己写 `int fputc(int ch, FILE *f){ uart_sendbyte(ch); return ch; }`
   （`#include <stdio.h>`）。用 MicroLIB 时这样就够；不用 MicroLIB 最好再加
   `#pragma import(__use_no_semihosting)` + `_sys_exit` + `_ttywrch`
4. 要收整串数据：开 RXNE（收字节）+ IDLE（判定一帧结束）中断，**必须写 `USARTx_IRQHandler`**
   - 固定长度帧：数够 N 字节置标志（简单，够用）
   - 变长帧：IDLE 中断里读 SR 再读 DR 清标志，把缓冲补 `'\0'` 并置"收完"标志

## TIM → PWM（舵机 / 风扇）

```c
TIM_TimeBaseInitStruct.TIM_Prescaler = psc - 1;
TIM_TimeBaseInitStruct.TIM_Period    = arr - 1;   /* counter_clock = fTIM / psc, PWM 频率 = counter_clock / arr */
TIM_CounterMode_Up / TIM_CKD_DIV1
TIM_OCInitStruct.TIM_OCMode = TIM_OCMode_PWM1;  TIM_OCPolarity_High;  TIM_OutputState_Enable;  TIM_Pulse = 0;
TIM_OCxInit(TIMx, &TIM_OCInitStruct);            /* x 要和通道号一致 */
TIM_OCxPreloadConfig(TIMx, TIM_OCPreload_Enable);
TIM_Cmd(TIMx, ENABLE);
if (TIMx == TIM1 || TIMx == TIM8) TIM_CtrlPWMOutputs(TIMx, ENABLE);   /* 高级定时器必须加这句 */
```

- **舵机**：50Hz（20ms 周期），0.5~2.5ms 脉宽对应 0~180°。
  用 `TIM2 + psc=840, arr=2000`（84MHz → 100kHz 计数，1 个计数 = 10µs）→ CCR 写 50~250。
  角度换算：`pulse = 50 + angle * 100 / 90`，角度限幅 5~175°。
- **风扇**：`TIM8 + psc=840, arr=100` → 计数时钟 168MHz/840 = 200kHz，PWM ≈ 2kHz；
  占空比 = `CCR3 / (arr+1)`，所以 `CCR = speed`（0~100 直接当百分比用）。
  小电机低速可能推不动，测试时直接用 100%。

## 软件模拟 I2C（本节课程用它接 SHT30 / MLX90614）

标准库那套硬件 I2C 在这门课里没用——用的都是 GPIO 模拟：

```
起始：SCL=1, SDA=1, 延时, SDA=0, 延时, SCL=0
停止：SCL=0, SDA=0, 延时, SCL=1, 延时, SDA=1
写字节：8 位，高位先出；SCL=0 时准备数据，SCL=1 期间数据必须稳定；结束时释放 SDA 让从机应答
等应答：SCL 拉高读 SDA，0=ACK，1=NACK
读字节：主机释放 SDA，SCL 拉高期间读 SDA；读完主机回 ACK（继续读）或 NACK（最后一字节）
```

- 引脚配**开漏输出**（`GPIO_OType_OD`），靠板上上拉电阻拉高；两个信号线各保持 1~5µs 延时
- 读 SDA 直接读 IDR（输出模式下也有效）；要更保险就切"带上拉的输入模式"
- 老师文档里的框架函数名：`iic_start/stop/sendbyte/receivebyte/sendack/receiveack`

## SHT30（温湿度）

- 地址 0x44（8 位：0x88 写 / 0x89 读）
- 命令 `0x24 0x0B`（非时钟延伸、中等重复性）→ 等 2ms → 读 6 字节：
  `T_MSB T_LSB T_CRC RH_MSB RH_LSB RH_CRC`（每 2 字节后跟 1 字节 CRC8）
- 换算：`T = -45 + 175 * S / 65535`；`RH = 100 * S / 65535`
- CRC8：多项式 0x31、初值 0xFF（测试数据 `0xBE 0xEF` 应得 `0x92`）

## MLX90614（红外测温）

- 地址 0x5A（8 位：0xB4 写 / 0xB5 读），读 RAM **0x07**（物体温度）
- 先写命令 → 重新发起始条件转读地址 → 连读 3 字节（低、高、PEC）
- 换算：`T = (高<<8 | 低) * 0.02 - 273.15`（1 LSB = 0.02K）

## LCD（ST7789VW，4 线 SPI）

- 引脚同 board-pinmap；`lcd_send_cmd()` 拉低 DC、`lcd_send_data()` 拉高 DC，每次传输前后动 CS
- 核心命令：`0x2A` 设列范围、`0x2B` 设行范围、`0x2C` 写像素；初始化序列 `0x11`(sleep out) → `0x36`(MADCTL)
  → `0x3A=0x05`(16 位色) → 一堆电源/Gamma 参数 → `0x21` → `0x29`
- 分辨率 240×240，但显存 240×320 → **画图时 y 要 +25**
- **图片取模**：C 数组、水平扫描、16 位真彩色(RGB565)、**高位在前**、包含 8 字节图像头。
  头格式：`00 10 00 W 00 H 00 00`；显示时 `w=pic[3]; h=pic[5];` 再跳过 8 字节，每 2 字节一个像素（高字节在前）
- **汉字字模**：32×32、**逐行式**、每行 4 字节、高位在左；一个字 128 字节
  代码按 **GB2312/GBK 双字节编码**在字库里查表：`hz_zk` 是索引串（每字 2 字节），`hz_zm32` 按同样顺序拼接字模
- 想在字库加新字：在 `hz_zk` 字符串末尾追加汉字，在 `hz_zm32` 末尾追加对应字模（**注意每个字节后要有逗号**）

## HLK-V20 语音模块

- 接 USART3（PD8/PD9，115200）；命令帧是 4 字节，形如 `4F 00 XX F4`，**第 3 字节区分动作**
- 匹配用整帧比较（`HLK_Cmd_Check(0x4F,0x00,0x02,0xF4)`），避免唤醒词等其它报文误触发
- 网站上可配 9 条命令 + 每条的 4 字节参数；命令词支持批量填（`actionN=命令词@回复语` 多行）
- 每条的"控制参数"要单独加：控制功能=UART1_TX、动作=发送、数据=16 进制；
  **"空占比/周期/次数"必须一起填**（50/1000/1），否则保存被静默拦截
