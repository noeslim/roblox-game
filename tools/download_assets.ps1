# Downloads the free (CC0) assets listed in docs/ASSETS.md into assets/incoming/, ready to push.
# Run from the repo root in PowerShell (not cmd):
#   powershell -ExecutionPolicy Bypass -File tools\download_assets.ps1
# Re-runnable: what is already downloaded is skipped. Anything that fails is listed at the end with
# its page, to download by hand.

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # Invoke-WebRequest is very slow with the progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = Split-Path $PSScriptRoot -Parent
$Incoming = Join-Path $Root "assets\incoming"
$UserAgent = "BlackMarketRobloxGame-AssetFetch/1.0"
$Failed = New-Object System.Collections.ArrayList
$Today = Get-Date -Format "yyyy-MM-dd"

# --- what to download -------------------------------------------------------------------------

# Poly Haven textures (id -> resolution)
$Textures = [ordered]@{
    "asphalt_02" = "2k"; "asphalt_01" = "1k"; "asphalt_03" = "1k"
    "brick_wall_02" = "2k"; "brick_wall_001" = "1k"; "red_brick_03" = "1k"
    "brick_wall_09" = "1k"; "painted_brick" = "1k"; "painted_worn_brick" = "1k"
    "concrete_wall_007" = "1k"; "concrete_wall_005" = "1k"; "concrete_brick_wall_001" = "1k"
    "damaged_plaster" = "1k"; "worn_plaster_wall" = "1k"; "rough_plaster_broken" = "1k"
    "checkered_pavement_tiles" = "1k"; "concrete_pavement_02" = "1k"
    "cobblestone_05" = "1k"; "cobblestone_pavement" = "1k"
    "rusty_corrugated_iron" = "1k"; "corrugated_iron" = "1k"; "rusty_painted_metal" = "1k"
    "rusty_metal_04" = "1k"; "rusty_metal_sheet" = "1k"
    "old_wood_floor" = "1k"; "wood_floor_worn" = "1k"; "plywood" = "1k"
    "tarred_gravel" = "1k"; "roof_07" = "1k"
    "rusty_metal_shutter" = "1k"; "metal_grate_rusty" = "1k"
    "dirty_tiles" = "1k"; "worn_tile_floor" = "1k"
    "broken_brick_wall" = "1k"
}

# Poly Haven models (glTF 1k) -> folder
$AlleyModels = @(
    "modular_fire_escape", "exterior_aircon_unit", "modular_metal_gutter", "rollershutter_door",
    "rollershutter_window_01", "rollershutter_window_02", "rollershutter_window_03",
    "security_camera_01", "security_light", "metal_trash_can", "utility_box_01", "utility_box_02",
    "water_manhole_cover", "fire_hydrant", "modular_chainlink_fence", "large_iron_gate",
    "street_lamp_02", "barrel_stove", "Barrel_01", "Barrel_02", "barrel_03", "cardboard_box_01",
    "wooden_crate_01", "wooden_crate_02", "covered_car", "old_tyre", "rusted_wheel_rim_01",
    "rusted_wheel_rim_02", "concrete_road_barrier_02", "modular_wooden_pier", "lateral_sea_marker"
)
$ShedModels = @(
    "Sofa_01", "sofa_02", "ArmChair_01", "plastic_monobloc_chair_01", "steel_frame_shelves_01",
    "steel_frame_shelves_02", "wooden_bookshelf_worn", "Television_01", "CashRegister_01",
    "pull_chain_light_socket", "lightbulb_01", "caged_hanging_light", "mounted_fluorescent_lights",
    "portable_generator", "propane_tank", "bench_vice_01", "metal_tool_chest", "crowbar_01",
    "pipe_wrench", "ratchet_wrench", "Drill_01", "bolt_cutters_01", "spray_paint_bottles"
)

# ambientCG materials and decals (1K)
$AmbientCG = @(
    "GraffitiSet001", "AsphaltDamageSet001", "RoadLines006", "Leaking005", "Fence006",
    "PaintedMetal006", "Sticker001", "Asphalt025C", "Asphalt024C"
)

# --- helpers ----------------------------------------------------------------------------------

function Save-Url($Url, $Path) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Invoke-WebRequest -Uri $Url -OutFile $Path -UserAgent $UserAgent -UseBasicParsing
}

function Write-Source($Dir, $Page, $Author) {
    $text = "Source: $Page`r`nAuthor: $Author`r`nLicense: CC0 1.0 (public domain)`r`nDownloaded: $Today`r`n"
    Set-Content -Path (Join-Path $Dir "SOURCE.txt") -Value $text -Encoding UTF8
}

# the entry of a Poly Haven files listing whose name matches (e.g. "Diffuse" / "diff")
function Find-Map($Files, $Pattern) {
    foreach ($p in $Files.PSObject.Properties) {
        if ($p.Name -match $Pattern) { return $p.Value }
    }
    return $null
}

function Get-PolyHavenTexture($Id, $Res) {
    $dir = Join-Path $Incoming "polyhaven_textures\$Id"
    if (Test-Path (Join-Path $dir "SOURCE.txt")) { Write-Host "  = $Id (already there)"; return }
    $files = Invoke-RestMethod -Uri "https://api.polyhaven.com/files/$Id" -UserAgent $UserAgent
    $maps = @{ "diff" = "^(Diffuse|diff)$"; "nor_gl" = "^nor_gl$"; "rough" = "^(Rough|rough)$"; "metal" = "^(Metal|metal)$" }
    $got = 0
    foreach ($name in $maps.Keys) {
        $map = Find-Map $files $maps[$name]
        if ($null -eq $map) { continue }
        $size = $map.$Res
        if ($null -eq $size) { $size = $map."1k" }
        if ($null -eq $size -or $null -eq $size.jpg) { continue }
        $url = $size.jpg.url
        Save-Url $url (Join-Path $dir ([IO.Path]::GetFileName($url)))
        $got++
    }
    if ($got -eq 0) { throw "no color/normal/roughness map found" }
    Write-Source $dir "https://polyhaven.com/a/$Id" "Poly Haven"
    Write-Host "  + $Id ($got maps, $Res)"
}

function Get-PolyHavenModel($Id, $Folder) {
    $dir = Join-Path $Incoming "$Folder\$Id"
    if (Test-Path (Join-Path $dir "SOURCE.txt")) { Write-Host "  = $Id (already there)"; return }
    $files = Invoke-RestMethod -Uri "https://api.polyhaven.com/files/$Id" -UserAgent $UserAgent
    $entry = $files.gltf."1k".gltf
    if ($null -eq $entry) { throw "no glTF 1k download" }
    Save-Url $entry.url (Join-Path $dir ([IO.Path]::GetFileName($entry.url)))
    if ($entry.include) {
        foreach ($inc in $entry.include.PSObject.Properties) {
            # include keys are relative paths like "textures/x_diff_1k.jpg"
            Save-Url $inc.Value.url (Join-Path $dir ($inc.Name -replace "/", "\"))
        }
    }
    Write-Source $dir "https://polyhaven.com/a/$Id" "Poly Haven"
    Write-Host "  + $Id"
}

function Get-AmbientCG($Id) {
    $dir = Join-Path $Incoming "ambientcg\$Id"
    if (Test-Path (Join-Path $dir "SOURCE.txt")) { Write-Host "  = $Id (already there)"; return }
    $zip = Join-Path $env:TEMP "$Id.zip"
    $ok = $false
    foreach ($variant in @("1K-JPG", "1K-PNG")) {
        try {
            Save-Url "https://ambientcg.com/get?file=${Id}_$variant.zip" $zip
            $ok = $true
            break
        } catch { }
    }
    if (-not $ok) { throw "no 1K-JPG / 1K-PNG zip" }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Expand-Archive -Path $zip -DestinationPath $dir -Force
    Remove-Item $zip
    # keep what Roblox uses: color, OpenGL normal, roughness, metalness, opacity
    Get-ChildItem $dir -File | Where-Object {
        $_.Name -match "(_NormalDX|_Displacement|_AmbientOcclusion|\.usda|\.usdc|\.mtlx|\.tres)" -or
        $_.Extension -eq ".blend"
    } | Remove-Item
    Write-Source $dir "https://ambientcg.com/view?id=$Id" "ambientCG (Lennart Demes)"
    Write-Host "  + $Id"
}

function Try-Step($What, $Page, [scriptblock]$Action) {
    try { & $Action } catch {
        Write-Host "  ! $What : $($_.Exception.Message)" -ForegroundColor Yellow
        [void]$Failed.Add("$What -> $Page")
    }
}

# --- run --------------------------------------------------------------------------------------

Write-Host "Poly Haven textures -> assets\incoming\polyhaven_textures"
foreach ($id in $Textures.Keys) {
    $res = $Textures[$id]
    Try-Step $id "https://polyhaven.com/a/$id" { Get-PolyHavenTexture $id $res }
}

Write-Host "ambientCG -> assets\incoming\ambientcg"
foreach ($id in $AmbientCG) {
    Try-Step $id "https://ambientcg.com/view?id=$id" { Get-AmbientCG $id }
}

Write-Host "Poly Haven street props -> assets\incoming\polyhaven_hidden_alley"
foreach ($id in $AlleyModels) {
    Try-Step $id "https://polyhaven.com/a/$id" { Get-PolyHavenModel $id "polyhaven_hidden_alley" }
}

Write-Host "Poly Haven hideout props -> assets\incoming\polyhaven_shed"
foreach ($id in $ShedModels) {
    Try-Step $id "https://polyhaven.com/a/$id" { Get-PolyHavenModel $id "polyhaven_shed" }
}

Write-Host ""
if ($Failed.Count -gt 0) {
    Write-Host "Not downloaded ($($Failed.Count)) - open the page and grab it by hand (or skip it):" -ForegroundColor Yellow
    $Failed | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "Everything downloaded." -ForegroundColor Green
}
Write-Host ""
Write-Host "Then push:  git add assets/incoming  ;  git commit -m ""Add CC0 assets""  ;  git push"
Write-Host "Still by hand (see docs/ASSETS.md): itch.io packs, Sketchfab models, Roblox kits in Studio."
