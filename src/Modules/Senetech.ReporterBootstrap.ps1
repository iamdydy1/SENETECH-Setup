# SENETECH V1.6.0.18 - Reporter bootstrap
# ASCII-only for Windows PowerShell 5.1.

$reporterModule = Join-Path $script:EngineDir 'Modules\Senetech.Reporter.ps1'
if (-not (Test-Path -LiteralPath $reporterModule)) {
    throw 'Module SENETECH Reporter V1.6.0.18 introuvable.'
}
. $reporterModule

# Build 18 is intentionally delivered as an overlay-only DEV build to avoid
# adding another nested patch to the already long V1.6 patch chain.
$script:AppVersion = '1.6.0.18'
$script:DisplayVersion = '1.6.0 DEV - build 18'

function Update-SenetechReporterBuildVisual {
    param($Node)
    if ($null -eq $Node) { return }
    try {
        if ($Node -is [System.Windows.Controls.TextBlock]) {
            $text = [string]$Node.Text
            if ($text -match '^VERSION 1\.6\.0 DEV - BUILD [0-9]+$') {
                $Node.Text = 'VERSION 1.6.0 DEV - BUILD 18'
            }
        }
        $count = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Node)
        for ($i = 0; $i -lt $count; $i++) {
            Update-SenetechReporterBuildVisual ([System.Windows.Media.VisualTreeHelper]::GetChild($Node,$i))
        }
    } catch { }
}

function Set-SenetechReporterBuildUi {
    try { if ($window) { $window.Title = 'SENETECH Setup V1.6.0 DEV - build 18' } } catch { }
    try { Update-SenetechReporterBuildVisual $window } catch { }
}

# Reporter must start only after the normal V1.6 and Delivery UIs have been
# created. Wrapping the existing initializer keeps sections ordered 6, 7, 8.
if (Get-Command Initialize-SenetechDeliveryFeatures -ErrorAction SilentlyContinue) {
    $script:ReporterOriginalDeliveryInitializer = ${function:Initialize-SenetechDeliveryFeatures}
    function Initialize-SenetechDeliveryFeatures {
        & $script:ReporterOriginalDeliveryInitializer
        try {
            Set-SenetechReporterBuildUi
            Initialize-SenetechReporter
        } catch {
            try { Write-Log ('Reporter initialization warning: ' + $_.Exception.Message) 'ATTENTION' } catch { }
        }
    }
}
