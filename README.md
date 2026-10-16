# keil5-and-stm32f4xx

一个 Codex **skill**（技能）：把「Keil MDK5（μVision）+ STM32F4xx 标准外设库」这套开发方式里容易踩的坑
固化成可复用的操作手册，面向 XYD 智慧生活 / 智能锁开发板（STM32F405VGT6）。

> A Codex skill that captures build-and-debug know-how for Keil MDK5 (uVision) + STM32F4xx
> standard-peripheral-library projects on the XYD STM32F405VGT6 course board.

## 什么时候会用到

装上之后，出现下面这类情况会自动加载（也可以 `$keil5-and-stm32f4xx` 显式调用）：

- Keil 编译报错（头文件找不到、芯片型号/宏不匹配……）
- **编译 0 错误，但上电没反应**：屏幕全黑、电机不转、串口没输出
- 往课程工程里加一个外设驱动（GPIO / USART / TIM PWM / I2C / LCD / 传感器 / 语音）
- 想在命令行重建工程、批量验证编译结果

## 内容

| 文件 | 内容 |
|---|---|
| `SKILL.md` | 入口：环境事实、排障主线、硬性约定 |
| `references/troubleshooting.md` | **症状 → 病因 → 修法** 对照表（编译期 + 运行期） |
| `references/board-pinmap.md` | 板子引脚地图与各外设接法 |
| `references/module-recipes.md` | 各外设代码形状：GPIO、USART + printf 重定向、TIM PWM（舵机/风扇）、软件模拟 I2C、SHT30、MLX90614、ST7789 LCD（含取模与字模格式）、HLK-V20 语音 |
| `references/project-history.md` | 各作业工程用到什么、当前状态 |
| `scripts/build_uv4.ps1` | 命令行一键编译（`UV4 -b/-r` + 输出日志） |

## 安装

```powershell
git clone https://github.com/otiosumsage238/keil5-and-stm32f4xx.git "$env:USERPROFILE\.codex\skills\keil5-and-stm32f4xx"
```

装好后**下一轮对话生效**。

## 用法

```
$keil5-and-stm32f4xx 帮我看看这个工程为什么编译过但板子不动
```

命令行编译示例：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_uv4.ps1 `
    -Project "工作根目录\语音识别\PROJECT\voice.uvprojx" -Rebuild
```

## 路径占位符

为了能公开分享，文中路径都是占位符，按自己的环境替换即可：

- `工作根目录\` —— 课程工程的根目录
- `<KEIL>` —— Keil 安装目录
- `<课程资料>` —— 讲义与参考工程所在目录

本机的真实绝对路径建议放在同目录的 `LOCAL_PATHS.md`（本仓库的 `.gitignore` 已排除该文件，不会上传）。

## 硬件前提

- 开发板：XYD 智慧生活 / 智能锁开发板，**STM32F405VGT6（100 脚封装）**
- 外部晶振 25MHz → SYSCLK 168MHz；库里 `HSE_VALUE=25000000` + `PLL_M=25` 已是对的，不需要改
- 已在 Keil μVision 5（ARMCC V5.06）上验证

## 说明

内容来自真实课堂作业的调试过程（点灯 → 按键 → 串口 → PWM 舵机/风扇 → I2C 温湿度 → 红外测温 →
SPI LCD → 语音识别），里面每一条"坑"都是实际遇到并解决的。换成别的板子或库版本时，按实际情况调整。
