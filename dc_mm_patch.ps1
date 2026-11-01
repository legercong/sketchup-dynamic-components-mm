[CmdletBinding()]
param(
  [switch]$Restore,
  [switch]$ExtraOnly,
  [string[]]$Extra = @()
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$backupDirName = '_backup_dc_mm'

# 毫米尺子图标（40x21 GIF，按原 units.gif 像素风格绘制）
$gifBase64 = 'R0lGODlhKAAVAIcAAP//45eXh9jYwtfXwcnJtZWVhv//59nZxMrKt9zcyM7Ou8zMuaCgkf//6dzcydDQvs3Nu56ekP//6t3dy9LSwf//7NTUxKysn+Pj0+Hh0f//7tbWx9DQwqurn9nZy///8Nzcz9PTxru7sOfn2v//8unp3d7e0rq6sOHh1v//9OTk2u3t4+Pj2svLw///9u/v5ufn3urq4srKw///+Obm3/Pz7e/v6Z+fm///+vX18PHx7Nra1f//+/n59fT08L29uvr69/n59vb28/X18urq5+np5v///ff39dnZ1////v7+/f39/Pz8+/r6+fb29cHArsTDssLBsMnIuMvKu9rZzt3c0kA/OFBPSGdmYYOCfe3s5/Dv60JBQe/u7v////7+/vn5+fLy8vHx8enp6eHh4eDg4NbW1svLy7+/v7S0tLOzs6enp5qampmZmY2NjX9/f3Nzc3JycmZmZmVlZVhYWEtLSz8/PzQ0NDMzMykpKR8fHx4eHhYWFhUVFQ0NDQYGBgAAAP///wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAIEALAAAAAAoABUAQAj/AAMJHEiwoMGDCAl6SWKEB44ZLlKQ+KChggQDADJq3Mix40ZAXr4saQKkh48cNX68WKGixAgQGDJYmJAAwgEBVgYMIKCT586eOgElHEp06MKGDyNOrNgAY0dAGaECgCq1qkaQYMSMKWPmDBo1a9q4eRNHDp06dvDk0cPHzx9AcOPKnculqN27gY46hCiRYoWmHgMLnqo3aV+mTjlancq4sVTCDPcq9Qt4sOWrIZd0KYkEpcoVN1xmiYmF5pWbOQekXq0ztVC8sGPLtusFTJgxZLqiSbOGzVg4c87auZNnTx+3c5PL9VKY79K/iS8PBhnZ8PPKiuFOrapdO+bqzilHe78atfzix9SRhq940eN5x+WjelHCpEkQIT502PgRA4YKFCaA4MEGFlDwgAILIGAFAQw26KCDIInkRElEeLZSCy6JENMFEzjAAGo6BRDiiAOIOABI9DlxxBBFbKHFDjSwIEMVVJwQAgcdTCFFBFBEUcATT/wYJJBCCglIQAA7'

function Get-Targets {
  $roots = New-Object System.Collections.Generic.List[string]

  if (-not $ExtraOnly) {
    foreach ($base in @($env:APPDATA, $env:PROGRAMDATA)) {
      $suRoot = Join-Path $base 'SketchUp'
      if (Test-Path $suRoot) {
        Get-ChildItem $suRoot -Directory | ForEach-Object {
          [void]$roots.Add((Join-Path $_.FullName 'SketchUp\Plugins'))
          [void]$roots.Add((Join-Path $_.FullName 'SketchUp\ShippedExtensions'))
        }
      }
    }

    $hives = @(
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($hive in $hives) {
      Get-ItemProperty $hive -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'SketchUp*' -and $_.InstallLocation } |
        ForEach-Object {
          $il = $_.InstallLocation.TrimEnd('\')
          if ($il) {
            [void]$roots.Add((Join-Path $il 'ShippedExtensions'))
            [void]$roots.Add((Join-Path $il 'Plugins'))
            [void]$roots.Add((Join-Path (Split-Path $il -Parent) 'ShippedExtensions'))
            [void]$roots.Add($il)
          }
        }
    }
  }

  foreach ($e in $Extra) { [void]$roots.Add($e.TrimEnd('\')) }

  $targets = New-Object System.Collections.Generic.List[string]
  foreach ($r in $roots) {
    if (-not (Test-Path $r)) { continue }
    $direct = Join-Path $r 'su_dynamiccomponents'
    if (Test-Path (Join-Path $direct 'js\components.js')) {
      if ($targets -notcontains $direct) { [void]$targets.Add($direct) }
      continue
    }
    Get-ChildItem $r -Recurse -Directory -Filter 'su_dynamiccomponents' -ErrorAction SilentlyContinue |
      ForEach-Object {
        if ((Test-Path (Join-Path $_.FullName 'js\components.js')) -and ($targets -notcontains $_.FullName)) {
          [void]$targets.Add($_.FullName)
        }
      }
  }
  return $targets
}

function Read-Text($path) { return [System.IO.File]::ReadAllText($path) }
function Write-Text($path, $text) { [System.IO.File]::WriteAllText($path, $text, $utf8) }
function Sub-Text($text, $old, $new) { if ($text.Contains($old)) { return $text.Replace($old, $new) } return $text }

function Test-Patched($dir) {
  $path = Join-Path $dir 'js\components.js'
  if (-not (Test-Path $path)) { return $false }
  return (Read-Text $path).Contains("'_lengthunits_user'")
}

function Test-Anchor($dir) {
  $path = Join-Path $dir 'js\components.js'
  if (-not (Test-Path $path)) { return $false }
  $text = Read-Text $path
  return $text.Contains("'_lengthunits_user'") -or
         $text.Contains("su.ifEmpty(lengthUnits, 'MILLIMETERS');") -or
         $text.Contains("lengthUnits = su.ifEmpty(lengthUnits, 'INCHES');")
}

function Back-Up($dir, $alreadyPatched) {
  $bk = Join-Path $dir $backupDirName
  if (Test-Path $bk) { return $bk }
  if ($alreadyPatched) { return $null }
  New-Item -ItemType Directory -Path (Join-Path $bk 'js') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $bk 'css') -Force | Out-Null
  foreach ($rel in @('js\components.js', 'js\manager.js', 'css\manager.css')) {
    $src = Join-Path $dir $rel
    $dst = Join-Path $bk $rel
    if (Test-Path $src) { Copy-Item $src $dst }
  }
  return $bk
}

function Patch-Components($dir) {
  $path = Join-Path $dir 'js\components.js'
  $text = Read-Text $path
  if ($text.Contains("'_lengthunits_user'")) { return 'already' }
  $pattern = '(?s)comp\.lengthUnits = function\(entity\) \{.*?\};'
  $match = [regex]::Match($text, $pattern)
  if (-not $match.Success) { return 'MISSING' }
  $replacement = @(
    'comp.lengthUnits = function(entity) {',
    '  // Only the unit picked with the units button is honoured. Anything',
    '  // authored into the component (inches or centimeters) shows as millimeters.',
    "  var chosenUnits = comp.getAttributeValue(entity, '_lengthunits_user');",
    "  if (chosenUnits == 'CENTIMETERS' || chosenUnits == 'MILLIMETERS') {",
    '    return chosenUnits;',
    '  }',
    "  return 'MILLIMETERS';",
    '};'
  ) -join "`r`n"
  $text = $text.Remove($match.Index, $match.Length).Insert($match.Index, $replacement)
  $text = Sub-Text $text " * Returns the lengthUnits attached to a given entity, defaulting to INCHES." " * Returns the lengthUnits attached to a given entity, defaulting to`r`n * MILLIMETERS."
  $text = Sub-Text $text ' * @return {string} The units string, such as INCHES or CENTIMETERS.' ' * @return {string} The units string, such as MILLIMETERS or CENTIMETERS.'
  Write-Text $path $text
  return 'patched'
}

function Patch-Manager($dir) {
  $path = Join-Path $dir 'js\manager.js'
  $text = Read-Text $path
  $report = @()

  # 尺子按钮：原版在英寸/厘米之间跳，改成厘米/毫米，并把这次选择记下来
  $togglePattern = @(
    '(?s)var newUnits;',
    "if\s*\(lengthUnits == '(?:INCHES|CENTIMETERS)'\)",
    '\{',
    "newUnits = '(?:CENTIMETERS|MILLIMETERS)';",
    '\}',
    'else',
    '\{',
    "newUnits = '(?:INCHES|CENTIMETERS)';",
    '\}',
    "\$\('units-button'\)\.className = 'units-button-' \+ newUnits\.toLowerCase\(\);",
    "comp\.setAttributeValue\(entity, '_lengthunits', newUnits\);"
  ) -join '\s*'
  $toggleReplacement = @(
    'var newUnits;',
    "  if (lengthUnits == 'CENTIMETERS') {",
    "    newUnits = 'MILLIMETERS';",
    '  } else {',
    "    newUnits = 'CENTIMETERS';",
    '  }',
    "  `$('units-button').className = 'units-button-' + newUnits.toLowerCase();",
    "  comp.setAttributeValue(entity, '_lengthunits', newUnits);",
    '  // The stored unit of a component is often centimeters already, so the',
    "  // panel remembers an explicit choice separately in '_lengthunits_user'.",
    "  comp.setAttributeValue(entity, '_lengthunits_user', newUnits);"
  ) -join "`r`n"
  $match = [regex]::Match($text, $togglePattern)
  if ($match.Success) {
    $text = $text.Remove($match.Index, $match.Length).Insert($match.Index, $toggleReplacement)
    $report += 'toggle=patched'
  } elseif ($text.Contains("comp.setAttributeValue(entity, '_lengthunits_user', newUnits);")) {
    $report += 'toggle=already'
  } else {
    $report += 'toggle=MISSING'
  }

  # 新增的键也要推给 Ruby 侧，否则重新选组件后记忆会丢
  $pushPattern = "comp\.pushAttribute\(entity, '_lengthunits', 'mgr\.redraw'\);"
  $pushReplacement = @(
    "comp.pushAttribute(entity, '_lengthunits_user');",
    "  comp.pushAttribute(entity, '_lengthunits', 'mgr.redraw');"
  ) -join "`r`n"
  $match = [regex]::Match($text, $pushPattern)
  if ($match.Success) {
    $text = $text.Remove($match.Index, $match.Length).Insert($match.Index, $pushReplacement)
    $report += 'push=patched'
  } elseif ($text.Contains("comp.pushAttribute(entity, '_lengthunits_user');")) {
    $report += 'push=already'
  } else {
    $report += 'push=MISSING'
  }

  # 点尺子时的确认框：直接放行
  $confirmPattern = "(?s)mgr\.confirmUnitsChange = function\(\)\s*\{.*?\};"
  $confirmReplacement = "mgr.confirmUnitsChange = function() {`r`n  return true;`r`n};"
  if ([regex]::IsMatch($text, "(?s)mgr\.confirmUnitsChange = function\(\)\s*\{\s*return true;\s*\};")) {
    $report += 'confirm=already'
  } else {
    $match = [regex]::Match($text, $confirmPattern)
    if ($match.Success) {
      $text = $text.Remove($match.Index, $match.Length).Insert($match.Index, $confirmReplacement)
      $report += 'confirm=patched'
    } else {
      $report += 'confirm=MISSING'
    }
  }

  $text = Sub-Text $text '// Get our length units for this entity, defaulting to inches.' '// Get our length units for this entity, defaulting to millimeters.'
  Write-Text $path $text
  return ($report -join ', ')
}

function Patch-Css($dir) {
  $path = Join-Path $dir 'css\manager.css'
  $text = Read-Text $path
  if ($text -match 'units-button-millimeters') { return 'already' }
  $block = @(
    '',
    '',
    '.units-button-millimeters {',
    '  padding: 4px 41px 2px 0;',
    '  background-image: url("../images/units_mm.gif");',
    '  background-position: 0px 0px;',
    '  background-repeat: no-repeat;',
    '  cursor: pointer;',
    '  display: inline-block;',
    '}'
  ) -join "`r`n"
  $anchor = [regex]::Match($text, "(?s)\.units-button-centimeters \{[^}]*\}")
  if ($anchor.Success) {
    $text = $text.Insert($anchor.Index + $anchor.Length, $block)
  } else {
    $text = $text + $block.TrimStart() + "`r`n"
  }
  Write-Text $path $text
  return 'patched'
}

function Install-Gif($dir) {
  $bytes = [Convert]::FromBase64String($gifBase64)
  $path = Join-Path $dir 'images\units_mm.gif'
  if (-not (Test-Path (Split-Path $path))) { New-Item -ItemType Directory -Path (Split-Path $path) | Out-Null }
  [IO.File]::WriteAllBytes($path, $bytes)
  return $bytes.Length
}

function Restore-One($dir) {
  $bk = Join-Path $dir $backupDirName
  if (-not (Test-Path $bk)) { Write-Host "  没有备份，跳过：$dir" -ForegroundColor Yellow; return }
  $probe = Join-Path $bk 'js\components.js'
  if ((Test-Path $probe) -and ((Read-Text $probe).Contains("'_lengthunits_user'") -or
      (Read-Text $probe).Contains("su.ifEmpty(lengthUnits, 'MILLIMETERS');"))) {
    Write-Host "  备份不可用：里面的文件已经带毫米补丁，还原它没有意义。" -ForegroundColor Red
    Write-Host "  位置：$bk" -ForegroundColor Red
    Write-Host '  要恢复原厂状态，请重新安装动态组件扩展（或重装 SketchUp）。' -ForegroundColor Yellow
    return
  }
  foreach ($rel in @('js\components.js', 'js\manager.js', 'css\manager.css')) {
    $src = Join-Path $bk $rel
    if (Test-Path $src) { Copy-Item $src (Join-Path $dir $rel) -Force }
  }
  $gif = Join-Path $dir 'images\units_mm.gif'
  if (Test-Path $gif) { Remove-Item $gif -Force }
  Write-Host "  已还原：$dir" -ForegroundColor Green
}

Write-Host ''
Write-Host '动态组件单位补丁（厘米 / 毫米）' -ForegroundColor Cyan
Write-Host '请先退出 SketchUp。' -ForegroundColor Yellow
Write-Host ''

$targets = Get-Targets
if ($targets.Count -eq 0) {
  Write-Host '没有找到动态组件扩展目录。如果 SketchUp 装在非常规位置，把扩展文件夹路径发给作者，或用 -Extra "安装目录\ShippedExtensions" 再跑一次。' -ForegroundColor Red
  exit 1
}

$needAdmin = $false

foreach ($dir in $targets) {
  Write-Host "目标：$dir"
  if ($Restore) { Restore-One $dir; continue }
  try {
    if (-not (Test-Anchor $dir)) {
      Write-Host '  这个版本的代码结构和本机不一样，为避免改坏，本目录一个字节都没动、也没建备份。' -ForegroundColor Yellow
      Write-Host '  请把该目录下的 js\components.js 发给作者，我再适配。' -ForegroundColor Yellow
      continue
    }
    $bk = Back-Up $dir (Test-Patched $dir)
    if ($null -eq $bk) {
      Write-Host '  这里之前已经改过了、又没有原始备份，本次不再做备份（否则会把改过的当成原版）。' -ForegroundColor Yellow
    } else {
      Write-Host "  原件备份在：$bk" -ForegroundColor DarkGray
    }
    $c = Patch-Components $dir
    if ($c -eq 'MISSING') {
      $m = 'skipped'; $s = 'skipped'; $g = 0
    } else {
      $m = Patch-Manager $dir
      $s = Patch-Css $dir
      $g = Install-Gif $dir
    }
    Write-Host "  components.js=$c  manager.js[$m]  manager.css=$s  units_mm.gif=${g}字节" -ForegroundColor Green
    if ($c -eq 'MISSING') {
      Write-Host '  这个版本的代码结构和本机不一样，为避免改坏，本目录一个字节都没动。' -ForegroundColor Yellow
      Write-Host '  请把该目录下的 js\components.js 发给作者，我再适配。' -ForegroundColor Yellow
    }
  } catch {
    Write-Host "  失败：$($_.Exception.Message)" -ForegroundColor Red
    if ("$($_.Exception)" -match 'UnauthorizedAccess|Access to the path|拒绝访问|被拒绝') {
      $needAdmin = $true
      Write-Host '  这是没有写入权限（SketchUp 装在 Program Files 之类的位置）。' -ForegroundColor Yellow
    } else {
      Write-Host '  如果提示的是权限问题，请关掉本窗口，右键"以管理员身份运行"那个安装 bat 再来一次。' -ForegroundColor Yellow
    }
  }
  Write-Host ''
}

if (-not $Restore) {
  Write-Host '完成后启动 SketchUp。若某处显示 MISSING，说明该版本的代码结构不同，把对应的 js 文件发给我再看。' -ForegroundColor Cyan
}
Write-Host ''
if ($needAdmin) { exit 2 }
