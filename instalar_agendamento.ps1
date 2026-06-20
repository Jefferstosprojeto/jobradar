# Job Radar - Instalar tarefas no Windows Task Scheduler
# Usa Register-ScheduledTask sem privilegios de administrador

$ScriptPath = 'C:\Users\jssantos\Documents\CLAUDE CODE\Primeiro Projeto\JobRadar\update_jobs.ps1'

$Action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$ScriptPath"""

$TriggerManha = New-ScheduledTaskTrigger -Daily -At '08:30AM'
$TriggerTarde = New-ScheduledTaskTrigger -Daily -At '03:15PM'

$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew

# RunLevel Limited nao requer administrador
$Principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERDOMAIN\$env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

# ── Tarefa da manha ──────────────────────────────────────
Get-ScheduledTask -TaskName 'JobRadar_Manha' -ErrorAction SilentlyContinue |
    Unregister-ScheduledTask -Confirm:$false

try {
    Register-ScheduledTask `
        -TaskName 'JobRadar_Manha' `
        -Description 'Job Radar SAP - Actualizacao matinal 08h30' `
        -Action $Action `
        -Trigger $TriggerManha `
        -Settings $Settings `
        -Principal $Principal | Out-Null
    Write-Host 'OK  JobRadar_Manha criada - todos os dias as 08:30'
} catch {
    Write-Host "ERRO JobRadar_Manha: $_"
}

# ── Tarefa da tarde ───────────────────────────────────────
Get-ScheduledTask -TaskName 'JobRadar_Tarde' -ErrorAction SilentlyContinue |
    Unregister-ScheduledTask -Confirm:$false

try {
    Register-ScheduledTask `
        -TaskName 'JobRadar_Tarde' `
        -Description 'Job Radar SAP - Actualizacao da tarde 15h15' `
        -Action $Action `
        -Trigger $TriggerTarde `
        -Settings $Settings `
        -Principal $Principal | Out-Null
    Write-Host 'OK  JobRadar_Tarde criada - todos os dias as 15:15'
} catch {
    Write-Host "ERRO JobRadar_Tarde: $_"
}

Write-Host ''
Write-Host 'Agendamento instalado! Sem expiracao, sem necessidade de renovar.'
Write-Host "Script : $ScriptPath"
Write-Host "Logs   : $(Split-Path $ScriptPath)\logs\"
