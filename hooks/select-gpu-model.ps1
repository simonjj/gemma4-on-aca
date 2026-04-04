param()

# ─── GPU Profile Selection ───
if (-not $env:GPU_PROFILE_TYPE) {
    Write-Host ""
    Write-Host "Select GPU profile:"
    Write-Host "  1) T4  (16 GB VRAM) - good for smaller Gemma4 models (e2b, e4b)"
    Write-Host "  2) A100 (80 GB VRAM) - supports all Gemma4 models including 26b and 31b"
    Write-Host ""
    $gpuChoice = Read-Host "Enter choice [1/2] (default: 1)"
    if ([string]::IsNullOrWhiteSpace($gpuChoice)) { $gpuChoice = "1" }

    switch ($gpuChoice) {
        "2" { $gpuProfile = "Consumption-GPU-NC24-A100" }
        default { $gpuProfile = "Consumption-GPU-NC8as-T4" }
    }

    azd env set GPU_PROFILE_TYPE $gpuProfile | Out-Null
    azd env config set infra.parameters.gpuProfileType $gpuProfile 2>$null
    $env:GPU_PROFILE_TYPE = $gpuProfile
}

# ─── Model Selection (based on GPU) ───
if (-not $env:OLLAMA_MODEL) {
    Write-Host ""
    if ($env:GPU_PROFILE_TYPE -eq "Consumption-GPU-NC24-A100") {
        Write-Host "Select Gemma 4 model for A100:"
        Write-Host "  1) gemma4:e4b   - 4B params, fast, multimodal (text+image+audio)"
        Write-Host "  2) gemma4:26b   - 26B MoE, strong reasoning, 256K context"
        Write-Host "  3) gemma4:31b   - 31B dense, highest quality, 256K context"
        Write-Host "  4) gemma4:e2b   - 2B params, ultra-fast, multimodal"
        Write-Host ""
        $modelChoice = Read-Host "Enter choice [1-4] (default: 2)"
        if ([string]::IsNullOrWhiteSpace($modelChoice)) { $modelChoice = "2" }

        switch ($modelChoice) {
            "1" { $model = "gemma4:e4b" }
            "3" { $model = "gemma4:31b" }
            "4" { $model = "gemma4:e2b" }
            default { $model = "gemma4:26b" }
        }
    }
    else {
        Write-Host "Select Gemma 4 model for T4:"
        Write-Host "  1) gemma4:e4b   - 4B params, good balance of speed and quality"
        Write-Host "  2) gemma4:e2b   - 2B params, fastest, best for simple tasks"
        Write-Host ""
        $modelChoice = Read-Host "Enter choice [1/2] (default: 1)"
        if ([string]::IsNullOrWhiteSpace($modelChoice)) { $modelChoice = "1" }

        switch ($modelChoice) {
            "2" { $model = "gemma4:e2b" }
            default { $model = "gemma4:e4b" }
        }
    }

    azd env set OLLAMA_MODEL $model | Out-Null
    $env:OLLAMA_MODEL = $model
}

Write-Host ""
Write-Host "Configuration:"
Write-Host "  GPU Profile : $env:GPU_PROFILE_TYPE"
Write-Host "  Model       : $env:OLLAMA_MODEL"
Write-Host ""
