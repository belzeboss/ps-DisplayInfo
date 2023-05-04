function Decode-EDID([byte[]]$edidBytes)
{
	if ($edidBytes.Length -lt 255){
		Write-Error "Unexpected Length: $($edidBytes.Length) (expected 255)"
		return
	}
	$ob = [psobject]::new();

	$c1 = 65 + ($edidBytes[8] -shr 2)
	$c2 = 65 + (($edidBytes[8] -band 3) -shl 3) + ($edidBytes[9] -shr 5)
	$c3 = 65 + ($edidBytes[9] -band 0x1F)
	$man = [string]::new(($c1,$c2,$c3))
	$pc = [System.BitConverter]::ToUInt16($edidBytes, 10)
	$sn = [System.BitConverter]::ToUInt32($edidBytes, 12)
	$ob | Add-Member NoteProperty "Product" "$man-$pc-$sn"
	$ob | Add-Member NoteProperty "Year" "$($edidBytes[17] + 1990) (Week $($edidBytes[16]))"
	$ob | Add-Member NoteProperty "Version" ("{0}.{1}" -f $edidBytes[18],$edidBytes[19])

	$isDigital = ($edidBytes[20] -shr 7) -gt 0
	if ($isDigital){
		$d = (($edidBytes[20] -shr 4) -band 7)
		$bpc = ("undefined","6","8","10","12","14","16","reserved")[$d]
		$d = $edidBytes[20] -band 7
		$if = ("undefined","DVI","HDMIa","HDMIb","MDDI","DP")[$d]
		$ob | Add-Member NoteProperty "Digital" "$if (BPC: $bpc)"
	}
	else {
		$d = $edidBytes[20] -shr 6
		$wb = ("+0.7/-0.3V","+0.714/-0.286V","+1.0/-0.4V","+0.7/0V (EVC)")[$d]
		$flags = $d -band 0x1F
		$ob | Add-Member NoteProperty "Analog" "$wb ($flags)"
	}
	$hcm = $edidBytes[21]
	$vcm = $edidBytes[22]
	$ob | Add-Member NoteProperty "ScreenSize" "${hcm}cm x ${vcm}cm"
	$ob | Add-Member NoteProperty "Gamma" ($edidBytes[23] * 100 - 100)

	$dpmsStandby = ($edidBytes[24] -band 0x80) -gt 0
	$dpmsSuspend = ($edidBytes[24] -band 0x40) -gt 0
	$dpmsActiveOff = ($edidBytes[24] -band 0x20) -gt 0

	$ob | Add-Member NoteProperty "DPMS-StandBy" $dpmsStandby
	$ob | Add-Member NoteProperty "DPMS-Suspend" $dpmsSuspend
	$ob | Add-Member NoteProperty "DPMS-ActiveOff" $dpmsActiveOff

	$type = ($edidBytes[24] -band 0x18) -shr 3
	if ($isDigital){
		$f = "RGB 4:4:4"
		if ($type -eq 1 -or $type -eq 3) { $f = "$f + YCrCb 4:4:4"}
		if ($type -eq 2 -or $type -eq 3) { $f = "$f + YCrCb 4:2:2"}
		$ob | Add-Member NoteProperty "DisplayType" $f
	}
	else {
		$f = ("mono","RGB","non-RGB","undefined")[$type]
		$ob | Add-Member NoteProperty "DisplayType" $f
	}

	$sRgb = ($edidBytes[24] -band 4) -gt 0
	$firstIsPreferedTiming = ($edidBytes[24] -band 2) -gt 0
	$ctdTmg = if (($edidBytes[24] -band 1) -gt 0){"GTF"}else{"CVT"}

	$ob | Add-Member NoteProperty "sRGB-Mode" $sRgb
	$ob | Add-Member NoteProperty "PrefereFirstTiming" $firstIsPreferedTiming
	$ob | Add-Member NoteProperty "ContinuousTiming" $ctdTmg


	$ob | Add-Member NoteProperty "RedGreen" $edidBytes[25]
	$ob | Add-Member NoteProperty "BlueWhite" $edidBytes[26]
	$ob | Add-Member NoteProperty "Red" ([System.BitConverter]::ToUInt16($edidBytes,27))
	$ob | Add-Member NoteProperty "Green" ([System.BitConverter]::ToUInt16($edidBytes,29))
	$ob | Add-Member NoteProperty "Blue" ([System.BitConverter]::ToUInt16($edidBytes,31))
	$ob | Add-Member NoteProperty "White" ([System.BitConverter]::ToUInt16($edidBytes,33))

	$ob | Add-Member NoteProperty "Timings" $edidBytes[35..37]

	for ($i = 0; $i -lt 8; $i++){
		$d0 = $edidBytes[38+$i*2]
		$d1 = $edidBytes[39+$i*2]
		$px = (($d0+31)*8)
		$ar = ("16:10", "4:3", "5:4", "16:9")[$d1 -shr 6]
		$freq = ($d1 -band 0x3F)+60
		$ob | Add-Member NoteProperty "Timing_$i" "$ar $px ${freq}Hz"
	}
	Write-Output $ob
}
function Get-Monitor
{
	Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBasicDisplayParams | %{
		# get registry path
		$reg = "HKLM\SYSTEM\CurrentControlSet\Enum\" + $_.InstanceName
		if ($reg[-2] -eq "_") {
			$reg = $reg.SubString(0, $reg.Length - 2);
		}
		# load property
		$props = Get-ItemProperty "registry::$reg"
		# remove PS* fields from props
		$psFields = ($props | Get-Member -Name "PS*").Name
		foreach($psField in $psFields){
			$props.PSObject.Properties.Remove($psField)
		}
		# add EDID to props
		$devParam = Get-ItemProperty "registry::$reg\Device Parameters"
		$edid = Decode-EDID $devParam.EDID
		write-output $edid
		# return proprs
		#Write-Output $props
	}
}
function Get-Display([int]$Index=-1)
{
	if ($Index -lt 0)
	{
		$i=0
		while($ob=Get-Display $i){
			$ob
			$i++
		}
		return;
	}
	try {
		$dm = [WinLib.U32]::GetDisplayMode($Index)
		$isPrimary = ($dm.device.StateFlags -band 4) -gt 0
		$ob = [psobject]::new();
		$ob | Add-Member NoteProperty "Index" $Index
		$ob | Add-Member NoteProperty "Name" $dm.device.DeviceName
		$ob | Add-Member NoteProperty "Primary" $isPrimary
		$ob | Add-Member NoteProperty "X" $dm.dmPositionX
		$ob | Add-Member NoteProperty "Y" $dm.dmPositionY
		$ob | Add-Member NoteProperty "Width" $dm.dmPelsWidth
		$ob | Add-Member NoteProperty "Height" $dm.dmPelsHeight
		$ob | Add-Member NoteProperty "Frequency" $dm.dmDisplayFrequency
		$ob | Add-Member NoteProperty "_Mode" $dm
		Write-Output $ob
	} catch {
		Write-Output $null
	}
}
function TogglePrimaryMonitorFHD
{
	$p = Get-Display | ? -Property Primary
	if ($p.Height -eq 1440)
	{
		[WinLib.U32]::ChangeResolution($p.Index, 1920, 1080, $false)
	}
	elseif ($p.Height -eq 1080)
	{
		[WinLib.U32]::ChangeResolution($p.Index, 2560, 1440, $false)
	}
	# reset current wallpapers (only works for transcoded atm)
	SetWallpaper
}

function SetWallpaper
{
	param(
		[Parameter(ValueFromPipeline=$true)][string]$FilePath = $null,
		[int]$Index = -1,
		[int]$X = -1,
		[int]$Y = -1
	)
	begin {
	$settingsPath = ([System.IO.Path]::GetTempPath() + "TranscodedImage.json")
	$settings = gc $settingsPath -ErrorAction SilentlyContinue | ConvertFrom-Json
	if ($null -eq $settings) {
		Write-Verbose "Create new Settings"
		$info = @{}
		$info.GridX = 1
		$info.GridY = 1
		$info.Path = ""
		$settings = $info,$info
	}

	$iterate = $Index -lt 0
	if ($iterate){
		$Index = 0
	}
	$Index = $Index % $settings.Count
	$validX = $X -ge 0
	$validY = $Y -ge 0

	function finalize {
		$newBitmapPath = ([System.IO.Path]::GetTempPath() + "TranscodedImage.bmp")
		TranscodeWallpaper $settings $newBitmapPath
		if (-not [WinLib.U32]::SetWallpaper($newBitmapPath, 3)){
			Write-Error "Can't save $newBitmapPath"
		}
		ConvertTo-Json -InputObject $settings | Out-file $settingsPath
	}

	}
	process {
		Write-Verbose "FilePath=$FilePath"
		if ($settings.Count -eq 0){
			Write-Verbose "No Settings"
			break
		}
		if ($validX) { $settings[$Index].GridX = $X }
		if ($validY) { $settings[$Index].GridY = $Y }
		if ("$FilePath".Length -gt 0){ $settings[$Index].Path = $FilePath }
		$Index++
		if ($Index -eq $settings.Count -or -not $iterate){
			Write-Verbose "Done processing pipeline"
			finalize
			break
		}
	}
	end {
		if ($iterate) {
			$n = $Index
			Write-Verbose "Iterate through $n starting at $Index/$($settings.Count)"
			for (;$Index -lt $settings.Count; ++$Index) {
				if ($validX) { $settings[$Index].GridX = $X }
				if ($validY) { $settings[$Index].GridY = $Y }
				if ("$FilePath".Length -gt 0 -and $Index -ge $n){
					$settings[$Index].Path = $settings[$Index % $n].Path
				}
			}
		}
		finalize
	}
}

function TranscodeWallpaper($settings, $newBitmapPath)
{
	# get display size information
	$union = [System.Drawing.Rectangle]::new(0,0,0,0)
	$displays = Get-Display | sort X | % {
		$r = [System.Drawing.Rectangle]::new([int]$_.X,[int]$_.Y,[int]$_.Width,[int]$_.Height)
		$union = [System.Drawing.Rectangle]::Union($r, $union)
		$r
	}
	$displays | %{ $_.X -= $union.X; $_.Y -= $union.Y; }

	# open target bitmap
	try{
		$fs = [System.IO.File]::OpenRead($newBitmapPath)
		$newBitmap = [System.Drawing.Image]::FromStream($fs)
		$fs.Close()
		$fs.Dispose()
		if ($newBitmap.Size -ne $union.Size) {
			throw "existing bitmap has wrong size"
		}
	} catch {
		$newBitmap = [System.Drawing.Bitmap]::new(
			$union.Width,
			$union.Height,
			[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
	}
	$g = [System.Drawing.Graphics]::FromImage($newBitmap)
	function updateDisplay($displayIndex){
		if ($displayIndex -lt 0 -or $displayIndex -ge $settings.Count){
			return $false
		}
		Write-Verbose "Display$displayIndex"
		$display = $displays[$displayIndex]
		Write-Verbose "Display$displayIndex = $display"
		$g.SetClip($display, [System.Drawing.Drawing2D.CombineMode]::Replace)

		$filePathInternal = $settings[$displayIndex].Path
		$X = $settings[$displayIndex].GridX
		$Y = $settings[$displayIndex].GridY

		# open image
		try {
			$fullPath = Resolve-Path -LiteralPath "$filePathInternal" -ErrorAction SilentlyContinue
			$image = [System.Drawing.Image]::FromFile($fullPath)
			Write-Verbose "Loaded $filePathInternal"
		}
		catch {
			Write-Error "Can't load $filePathInternal"
			return $false
		}

		if ($X -gt 0 -and $Y -gt 0) {
			$w = $display.Width / $X
			$h = $display.Height / $Y
		}
		elseif ($X -gt 0) {
			$w = [math]::Floor($display.Width / $X)
			$h = [math]::Floor($image.Height / $image.Width * $w)
		}
		elseif ($Y -gt 0) {
			$h = [math]::Floor($display.Height / $Y)
			$w = [math]::Floor($image.Width / $image.Height * $h)
		}
		else
		{
			$w = $image.Width
			$h = $image.Height
		}

		$tile = [System.Drawing.Bitmap]::new($image, $w, $h)
		$image.Dispose()

		Write-Verbose "TileSize= $($tile.Size)"

		$yy = $display.Y
		while($yy -lt $display.Bottom) {
			$xx = $display.X
			$mirrorAgain = $true
			while($xx -lt $display.Right){
				$g.DrawImage($tile, $xx, $yy, $tile.Width, $tile.Height)
				$tile.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipY)
				$xx += $w
				$mirrorAgain = -not $mirrorAgain
			}
			if ($mirrorAgain){
				$tile.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipY)
			}
			$tile.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone)
			$yy += $h
		}
		$tile.Dispose()
		return $true
	}
	for ($di=0; $di -lt $settings.Count; ++$di){
		$null = updateDisplay $di
	}
	$null = $g.Save()
	$g.Dispose()
	# save bitmap
	$newBitmap.Save($newBitmapPath);
	$newBitmap.Dispose()
}