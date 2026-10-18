# llama.cpp (SYCL) + Qwen3.6-35B-A3B launcher for Intel Arc Pro B70.
# Everything is resolved relative to this script:
#   .\Llama\llama-server.exe                        - llama.cpp SYCL build (see README)
#   .\Model\Qwen3.6-35B-A3B-UD-Q4_K_M.gguf          - the model (see README)
#   .\Cache\...                                     - generated at runtime (gitignored)

# --- Paths ---
$ScriptDir  = $PSScriptRoot
$ServerExe  = Join-Path $ScriptDir "Llama\llama-server.exe"
$ModelPath  = Join-Path $ScriptDir "Model\Qwen3.6-35B-A3B-UD-Q4_K_M.gguf"
$SlotsDir   = Join-Path $ScriptDir "Cache\llama-slots"
$SyclCache  = Join-Path $ScriptDir "Cache\sycl"

# --- Port and address ---
$HostAddr = "127.0.0.1"
$Port     = 8010
$Context  = 131072

# --- Checks ---
if (-not (Test-Path $ServerExe)) {
    Write-Error "llama-server.exe not found at $ServerExe - download the SYCL build and put it into .\Llama (see README.md)"; exit 1
}
if (-not (Test-Path $ModelPath)) {
    Write-Error "Model not found at $ModelPath - download the GGUF and put it into .\Model (see README.md)"; exit 1
}

# --- Port ---
# A leftover process from a previous run of this script is stopped by the script itself:
# when it runs in a service session it is allowed to kill its own former process, while from
# a regular session such a process is unreachable (Access denied). Ports owned by others are left alone.
$portPattern = "--port\s+$Port" + '(\s|$)'

$existing = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($existing) {
    foreach ($ownerPid in @($existing | Select-Object -ExpandProperty OwningProcess -Unique)) {
        $proc = Get-Process -Id $ownerPid -ErrorAction SilentlyContinue
        if ($proc -and $proc.ProcessName -eq 'llama-server') {
            Write-Host "Port $Port held by stale llama-server pid $ownerPid - stopping it"
            Stop-Process -Id $ownerPid -Force -ErrorAction SilentlyContinue
        }
    }
}

# The server may not have bound the port yet (the model takes ~25 s to load) - also check by name.
foreach ($proc in @(Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue)) {
    $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue).CommandLine
    if ($cmd -and $cmd -notmatch $portPattern) {
        Write-Host "Keeping llama-server pid $($proc.Id) - it serves another port"
        continue
    }
    Write-Host "Stopping leftover llama-server pid $($proc.Id)"
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
}

if ($existing) {
    for ($i = 0; $i -lt 30; $i++) {
        if (-not (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Seconds 1
    }
    $still = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($still) {
        Write-Warning "Port $Port is still in use (PID $($still[0].OwningProcess))"; exit 1
    }
}

# --- SYCL environment ---
New-Item -ItemType Directory -Force -Path $SlotsDir  | Out-Null
New-Item -ItemType Directory -Force -Path $SyclCache | Out-Null

# Level Zero only: skip the OpenCL adapter of the same GPU.
$env:ONEAPI_DEVICE_SELECTOR = "level_zero:gpu"
$env:ZES_ENABLE_SYSMAN      = "1"
# Keep compiled SYCL kernels between runs, otherwise the first tokens are slow.
$env:SYCL_CACHE_PERSISTENT  = "1"
$env:SYCL_CACHE_DIR         = $SyclCache

# --- Start ---
Write-Host "Starting llama-server on $HostAddr`:$Port" -ForegroundColor Cyan
Write-Host "  Model:                  $ModelPath" -ForegroundColor DarkGray
Write-Host "  Alias:                  qwen3.6-35b-a3b" -ForegroundColor DarkGray
Write-Host "  Context:                $Context" -ForegroundColor DarkGray
Write-Host "  Reasoning preserve:     disabled" -ForegroundColor DarkGray
Write-Host "  SYCL_CACHE_PERSISTENT:  $env:SYCL_CACHE_PERSISTENT" -ForegroundColor DarkGray

& $ServerExe `
    -m $ModelPath `
    -a qwen3.6-35b-a3b `
    --host $HostAddr --port $Port `
    -ngl 99 -c $Context `
    -ctk q8_0 -ctv q8_0 -fa on `
    -b 8192 -ub 4096 `
    -t 8 --parallel 1 `
    --jinja --no-warmup --no-reasoning-preserve `
    --slot-save-path $SlotsDir `
    --metrics
