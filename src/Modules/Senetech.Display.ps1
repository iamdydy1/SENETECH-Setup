# SENETECH V1.6 - responsive display helper
# ASCII-only source for Windows PowerShell 5.1 compatibility.

$script:SenetechDisplayMode = ''
$script:SenetechDisplayInitialized = $false

function Get-SenetechDisplayMetrics {
    $work = [System.Windows.SystemParameters]::WorkArea
    $dpiX = 96.0
    $dpiY = 96.0

    try {
        $source = [System.Windows.PresentationSource]::FromVisual($window)
        if ($source -and $source.CompositionTarget) {
            $matrix = $source.CompositionTarget.TransformToDevice
            $dpiX = 96.0 * [double]$matrix.M11
            $dpiY = 96.0 * [double]$matrix.M22
        }
    } catch { }

    $scaleX = $dpiX / 96.0
    $scaleY = $dpiY / 96.0

    return [pscustomobject]@{
        WorkWidth = [double]$work.Width
        WorkHeight = [double]$work.Height
        PixelWidth = [int][Math]::Round($work.Width * $scaleX)
        PixelHeight = [int][Math]::Round($work.Height * $scaleY)
        DpiX = [int][Math]::Round($dpiX)
        DpiY = [int][Math]::Round($dpiY)
        ScalePercent = [int][Math]::Round($scaleX * 100)
    }
}

function Set-SenetechResponsiveDisplay {
    param([switch]$Silent)

    if ($null -eq $window) { return }

    $metrics = Get-SenetechDisplayMetrics
    $w = [double]$metrics.WorkWidth
    $h = [double]$metrics.WorkHeight

    $mode = 'Large'
    if ($w -le 1450 -or $h -le 820) {
        $mode = 'Compact'
    } elseif ($w -le 2100 -or $h -le 1200) {
        $mode = 'Standard'
    }

    try {
        $window.SizeToContent = [System.Windows.SizeToContent]::Manual
        $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $window.UseLayoutRounding = $true
        $window.SnapsToDevicePixels = $true

        if ($mode -eq 'Compact') {
            # 1366x768 / small laptops: use all available work area instead of
            # shrinking the whole interface. Internal panels keep their scrollbars.
            $window.MinWidth = [Math]::Min(900.0, [Math]::Max(720.0, $w * 0.70))
            $window.MinHeight = [Math]::Min(580.0, [Math]::Max(500.0, $h * 0.68))
            $window.MaxWidth = $w
            $window.MaxHeight = $h
            $window.WindowState = [System.Windows.WindowState]::Maximized
        } elseif ($mode -eq 'Standard') {
            $window.MinWidth = [Math]::Min(1080.0, $w * 0.78)
            $window.MinHeight = [Math]::Min(680.0, $h * 0.72)
            $window.MaxWidth = $w
            $window.MaxHeight = $h

            if ($window.WindowState -ne [System.Windows.WindowState]::Maximized) {
                $targetW = [Math]::Min(1600.0, $w * 0.96)
                $targetH = [Math]::Min(940.0, $h * 0.94)
                if ($window.Width -gt $targetW -or [double]::IsNaN($window.Width)) { $window.Width = $targetW }
                if ($window.Height -gt $targetH -or [double]::IsNaN($window.Height)) { $window.Height = $targetH }
            }
        } else {
            $window.MinWidth = 1100.0
            $window.MinHeight = 700.0
            $window.MaxWidth = $w
            $window.MaxHeight = $h

            if ($window.WindowState -ne [System.Windows.WindowState]::Maximized) {
                $targetW = [Math]::Min(1760.0, $w * 0.90)
                $targetH = [Math]::Min(1040.0, $h * 0.90)
                if ($window.Width -gt $targetW -or [double]::IsNaN($window.Width)) { $window.Width = $targetW }
                if ($window.Height -gt $targetH -or [double]::IsNaN($window.Height)) { $window.Height = $targetH }
            }
        }

        # Keep the application readable if Windows uses an unusual scaling value.
        # WPF remains DPI-aware; we do not change the user's Windows resolution.
        if ($window.FontSize -lt 12.0) { $window.FontSize = 12.0 }

        if (-not $Silent -and $script:SenetechDisplayMode -ne $mode) {
            Write-Log (('Affichage adapte : {0}x{1}px, DPI {2} ({3}%), mode {4}.' -f $metrics.PixelWidth,$metrics.PixelHeight,$metrics.DpiX,$metrics.ScalePercent,$mode)) 'OK'
            Add-SenetechHistory 'Affichage adapte' 'OK' (('{0}x{1}px - {2}% - {3}' -f $metrics.PixelWidth,$metrics.PixelHeight,$metrics.ScalePercent,$mode))
        }

        $script:SenetechDisplayMode = $mode
        try { $window.UpdateLayout() } catch { }
    } catch {
        if (-not $Silent) { Write-Log (('Adaptation affichage impossible : {0}' -f $_.Exception.Message)) 'ATTENTION' }
    }
}

function Initialize-SenetechResponsiveDisplay {
    if ($script:SenetechDisplayInitialized) { return }
    $script:SenetechDisplayInitialized = $true

    # First pass before display, then a second pass once WPF knows the real DPI.
    Set-SenetechResponsiveDisplay -Silent
    $window.Add_Loaded({ Set-SenetechResponsiveDisplay })
}
