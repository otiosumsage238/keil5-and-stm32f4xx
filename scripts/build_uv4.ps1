# 用 Keil 的命令行批量编译（不用打开 IDE）
#
#   scripts/build_uv4.ps1 -Project "工作根目录\语音识别\PROJECT\voice.uvprojx" -Rebuild
#
# 退出码 0 表示无错误无警告；日志内容会打印出来。
# 注意：这会启动 UV4.exe（GUI 程序），在受限环境下需要用户先批准。
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [string]$Keil = '<KEIL>\UV4\UV4.exe',
    [switch]$Rebuild,
    [int]$TimeoutSec = 300
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Project)) { throw "工程不存在: $Project" }
if (-not (Test-Path -LiteralPath $Keil)) { throw "UV4.exe 不存在: $Keil" }

$proj = (Resolve-Path -LiteralPath $Project).Path
$log = Join-Path $env:TEMP ("uv4_" + [IO.Path]::GetFileNameWithoutExtension($proj) + ".log")
if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }

$argList = @()
$argList += if ($Rebuild) { '-r' } else { '-b' }
$argList += '"' + $proj + '"'
$argList += '-o'
$argList += '"' + $log + '"'
$argList += '-j0'                      # 批处理模式，构建完自动退出

$p = Start-Process -FilePath $Keil -ArgumentList $argList -Wait -PassThru -WindowStyle Hidden
Write-Output ("UV4 exit code: {0}   (0 = 0 error 0 warning)" -f $p.ExitCode)

if (Test-Path -LiteralPath $log) {
    Get-Content -LiteralPath $log
} else {
    Write-Output '没有生成日志文件，检查工程路径是否正确'
}
