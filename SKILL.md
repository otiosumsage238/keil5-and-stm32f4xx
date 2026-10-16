---
name: keil5-and-stm32f4xx
description: Build and debug Keil MDK5 (uVision / UV4) projects for STM32F4xx with the ST standard peripheral library, especially the XYD STM32F405VGT6 course board and the local course project tree. Use when a Keil build fails, when code compiles but the board stays dead (blank screen, motor not moving, no serial output), when adding a peripheral driver to a course project, or when asked to create or rebuild such a project from the command line.
metadata:
  short-description: Keil5 + STM32F4xx 课程板编译与排障
---

# Keil5 + STM32F4xx（本机 / 本课程专用）

## 环境事实

- Keil：`<KEIL>\UV4\UV4.exe`（μVision 5.28 + ARMCC V5.06），工程里 Device 选 `STM32F405VGTx`
- 工程都在同一个「工作根目录」下的 `<作业名>\` 里，一个作业一个工程`r`n- 路径写法：文中 `工作根目录\` 指课程工程根目录、`<KEIL>` 指 Keil 安装目录，按自己的环境替换
- 板子：XYD 智慧生活 / 智能锁开发板，**STM32F405VGT6（100 脚）**，HSE 25MHz → SYSCLK 168MHz。
  库里 `HSE_VALUE=25000000` + `PLL_M=25` 已经是对的，不用改（别把它当 8MHz 板子）
- **命令行编译**（不用开 IDE）：
  `scripts/build_uv4.ps1 -Project <工程.uvprojx> [-Rebuild]`
  退出码 0 = 无错误无警告，日志会打印出来。启动 UV4 属于 GUI 程序，需要用户批准
- 源码编码：老师的文件**混用 GBK 与 UTF-8**。自己新建/改写文件按 **GBK** 写（中文注释在 Keil 里才正常）；
  读老师的文件若 GBK 读出乱码就改用 UTF-8
- 工程骨架有两代：扁平 `USER\`（早期）与 `APP\ + USER\inc|src`（后期，来自老师的 `<课程资料>\综合\02_new`）。
  新建工程时复制最近一版已编译通过的工程再改，比从头搭快也稳

## 排障主线（"编译过但硬件没反应"）

先分清**编译期**还是**运行期**：

1. 编译报 `cannot open source input file ...` → 头文件搜索路径缺项（见 troubleshooting 第 1 条）
2. 编译通过、上电全黑 / 全静 → 九成是**初始化漏东西**：外设时钟、GPIO 端口时钟、引脚复用、外设使能、
   高级定时器主输出（`TIM_CtrlPWMOutputs`）。老师给的驱动经常缺其中一两项，且**不报错**
3. 串口有打印但执行部件不动 → 问题已收敛到那一路：电源、接线、PWM 占空比、插错接口

症状 → 病因 → 修法对照表（含本课程真实踩过的每一个坑）：
**[references/troubleshooting.md](references/troubleshooting.md)**

## 板子引脚地图

LED / 按键 / 蜂鸣器 / 继电器 / 舵机 / 风扇 / I2C1 / USART1 / USART3 / LCD / 触摸：
**[references/board-pinmap.md](references/board-pinmap.md)**

## 各外设的代码形状

GPIO、USART（含 printf 重定向）、TIM PWM（舵机 / 风扇）、**软件模拟 I2C**、SHT30、MLX90614、
ST7789 LCD（含取模与字模）、HLK-V20 语音：**[references/module-recipes.md](references/module-recipes.md)**

## 各作业工程现状

`workwork` 下每个作业用到了什么、当前状态、以及还在进行中的语音识别项目：
**[references/project-history.md](references/project-history.md)**

## 硬性约定

- 改老师给的驱动文件：**先备份**，改动处加中文注释说明为什么改（便于对照和回退）
- 新增源文件必须同时登记进 `.uvprojx` 的组里（否则不参与编译）；`FilePath` 用相对路径，如 `..\USER\src\x.c`
- 结构体（`GPIO_InitTypeDef` / `TIM_TimeBaseInitTypeDef` 等）**每个成员都要赋值**：局部结构体不初始化
  就是栈上随机值，会被写进寄存器且**不报错**，是最隐蔽的一类 bug
- 别手动清理 `Objects\` / `Listings\`；命令行编译会自行重建
