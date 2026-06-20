# ============================================================
# Job Radar — Actualização automática + alerta de email
# Jefferson Santos · SAP Analytics & Data Architect
# Corre 2x/dia via Windows Task Scheduler
# ============================================================

$LogDir  = "$PSScriptRoot\logs"
$LogFile = "$LogDir\$(Get-Date -Format 'yyyy-MM-dd').log"

function Write-Log {
    param([string]$Msg)
    $line = "$(Get-Date -Format 'HH:mm:ss') $Msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

Write-Log "=== Job Radar — Início da actualização ==="

# ── Prompt completo para o Claude CLI ──────────────────────
$Prompt = @'
Actualização automática do Job Radar — Jefferson Santos.

PERFIL:
- Nome: Jefferson Santos · Email: jefferstos@gmail.com
- Stack: SAP BW, SAP BW/4HANA, SAP Datasphere, SAP Analytics Cloud (SAC), SAP BDC, SAP HANA, ABAP, Databricks, Data Lake, CDS Views
- Regiões alvo: DACH (Alemanha/Áustria/Suíça), União Europeia, Brasil
- Regime preferido: Remoto; aceita híbrido com viagem 1x/mês
- Línguas: Português 100%, Inglês 95%, Espanhol 70%, Alemão 0%
- Localização: Montijo, Portugal · EU Passport

PASSO 1 — Ler vagas existentes:
Ler o ficheiro "C:\Users\jssantos\Documents\CLAUDE CODE\Primeiro Projeto\JobRadar\data\jobs.json" e guardar todos os IDs existentes no campo "id" de cada job. Não adicionar duplicados.

PASSO 2 — Pesquisar novas vagas (usar WebSearch para CADA um destes termos):
- "SAP BW consultant remote Europe 2026"
- "SAP BW4HANA consultant remote 2026"
- "SAP Datasphere consultant remote Europe 2026"
- "SAP Analytics Cloud SAC consultant remote 2026"
- "SAP BDC Business Data Cloud consultant remote 2026"
- "consultor SAP BW remoto Brasil 2026"
- "consultor SAP BW4HANA remoto Brasil 2026"
- "consultor SAP Datasphere remoto Brasil 2026"
Sites a pesquisar: LinkedIn, RemoteRocketship, Remotive, StepStone, FreelancerMap, Duerenhoff, Ratbacher, Gupy, Nerdin, Jobgether, Glassdoor, Indeed, XING, WomenTechNetwork

PASSO 3 — Filtrar e avaliar:
Para cada vaga nova encontrada (ID não duplicado):
- EXCLUIR obrigatoriamente vagas fora de DACH/EU/Brasil (ex: Índia, APAC, US, China)
- Calcular match_score = (score_lingua * 0.40) + (score_tecnico * 0.55) + (score_regime * 0.05)
  - Scores de língua: Português=100, Inglês=95, Espanhol=70, Alemão=20, Francês=15, Outro=10
  - Score técnico: baseado no alinhamento com SAP BW/BW4HANA/Datasphere/SAC/BDC/HANA/ABAP/Databricks
  - Score regime: Remoto=100, Híbrido=75, Onsite=30
- Gerar ID único em formato "empresa-stack-localidade" (ex: "sap-bw-consultant-germany")
- Definir is_new: true, date_found: data de hoje (formato YYYY-MM-DD)

PASSO 4 — Se houver vagas novas:
a) Adicionar as vagas novas ao ficheiro "C:\Users\jssantos\Documents\CLAUDE CODE\Primeiro Projeto\JobRadar\data\jobs.json" — manter todas as vagas existentes, apenas append das novas no array "jobs", actualizar "last_updated" no meta.
b) Actualizar o JOBS_DATA inline no ficheiro "C:\Users\jssantos\Documents\CLAUDE CODE\Primeiro Projeto\JobRadar\index.html" — substituir o objecto JOBS_DATA completo com os dados actualizados (incluindo vagas antigas + novas). Actualizar também "last_updated" e "sources_searched" se necessário.
c) Enviar email para jefferstos@gmail.com usando o Gmail MCP (ferramenta Gmail disponível) com:
   - Assunto: "🎯 Job Radar — [N] novas vagas SAP · [data de hoje]"
   - Corpo: lista formatada com título, empresa, país, match%, regime, língua exigida e link directo para cada vaga nova; mencionar total de vagas no dashboard.

PASSO 5 — Se NÃO houver vagas novas:
Não enviar email. Apenas terminar silenciosamente.

REGRAS IMPORTANTES:
- Nunca remover vagas existentes do jobs.json
- Nunca adicionar vagas com localização fora de DACH/EU/Brasil
- Vagas com alemão obrigatório podem ser incluídas mas com match_score baixo (score_lingua=20)
- O ficheiro index.html usa JOBS_DATA como const inline — actualizar apenas o objecto JSON dentro da const, não alterar o HTML/CSS/JS circundante
'@

# ── Executar Claude CLI ────────────────────────────────────
Write-Log "A chamar Claude CLI..."

$ClaudeExe = "$env:USERPROFILE\.local\bin\claude.exe"

if (-not (Test-Path $ClaudeExe)) {
    Write-Log "ERRO: claude.exe não encontrado em $ClaudeExe"
    exit 1
}

try {
    $Output = & $ClaudeExe --print $Prompt 2>&1
    Write-Log "Claude concluído."
    Add-Content -Path $LogFile -Value $Output -Encoding UTF8
} catch {
    Write-Log "ERRO ao executar Claude: $_"
    exit 1
}

Write-Log "=== Job Radar — Claude concluído ==="

# ── Git commit + push ──────────────────────────────────────
Write-Log "A fazer git commit e push..."
try {
    $GitDir = $PSScriptRoot
    git -C $GitDir add -A 2>&1 | ForEach-Object { Write-Log "git: $_" }
    $CommitMsg = "Job Radar auto-update $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    $commitOut = git -C $GitDir commit -m $CommitMsg 2>&1
    $commitOut | ForEach-Object { Write-Log "git: $_" }
    if ($LASTEXITCODE -eq 0) {
        git -C $GitDir push 2>&1 | ForEach-Object { Write-Log "git: $_" }
        Write-Log "Push para GitHub concluído."
    } else {
        Write-Log "Nada para commitar (sem alterações)."
    }
} catch {
    Write-Log "AVISO git: $_"
}

# ── Redeploy Netlify via zip ───────────────────────────────
Write-Log "A fazer redeploy no Netlify..."
try {
    $NetlifyToken = "nfp_R5gY2Wa8bcKtQTcKzMrWukrdDbFj9fCR61d1"
    $SiteId       = "1223b23e-deca-4325-a328-440ab10ba805"
    $ZipPath      = "$env:TEMP\jobradar-deploy.zip"

    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    Compress-Archive -Path "$PSScriptRoot\*" -DestinationPath $ZipPath -Force

    $deployResult = curl.exe -s -X POST "https://api.netlify.com/api/v1/sites/$SiteId/deploys" `
        -H "Authorization: Bearer $NetlifyToken" `
        -H "Content-Type: application/zip" `
        --data-binary "@$ZipPath"

    $deployJson = $deployResult | ConvertFrom-Json
    Write-Log "Netlify deploy state: $($deployJson.state) · id: $($deployJson.id)"
} catch {
    Write-Log "AVISO Netlify: $_"
}

Write-Log "=== Job Radar — Actualização concluída ==="
