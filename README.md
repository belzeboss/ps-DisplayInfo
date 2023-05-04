# DisplayInfo
Simple functions for retrieving information from cim-instances/registtry/edid. 
Also setting wallpapers using the dimensions of the monitors, when using multiple monitors.
## Requirements
Add the code from `cs-WinLibCode` as member information to your current session. Using these libs:
```
$libs = "System.Drawing.Primitives.dll", "System.Drawing.Common.dll", "Microsoft.Win32.Registry.dll", "System.Console.dll"
```
and the code from the repository: 
```
$winLibCode = "$(gc ...\winLibCode.cs -Raw)"
```
then add the type to your session as follows:
```
Add-Type -MemberDefinition $winLibCode -Name "U32" -Namespace WinLib -ReferencedAssemblies $libs
```
This will expose the code in the `WinLib.U32` class, which is how it is used in this project.
## Functions
Get information of your display like resolution, manufacturer, refreshrate etc. Used to change the resolution of the primary display before and after playing some video games to avoid rescaling render targets especially when actively using multiple monitors and Alt-tabbing.

Also allows for transcoding images in dynamic and mirrored Tile-style into a bitmap spanning all monitors.

### Get-Monitor
Uses `Get-CimInstance` on class `WmiMonitorBasicDisplayParams` to get the instance name of each connected display. This is then used to query the `Device Parameters` from the registry containing the EDID information. The function `Decode-EDID` takes the EDID information as byte[]-paramter and parses it into a ps-object. Mostly copied from WikiPedia.

### Get-Display
Uses Windows API call `GetDisplayMode` and converts it into a ps-object.

### TogglePrimaryMonitorFHD
Toggles between 1440p and 1080p, using Windows API `ChangeResolution`. This was the motivation for the functions above and may only act as an example in this instance.

### TranscodeWallpaper
This function will use a given `settings` object, containing file-path and tiling settings for each display, to create a single image that can be used as wallpaper across multiple monitors. Using the helper functions above to determine the dimensions of the displays. It also allows the user to specify a tiling. Parameters are `Path`, `GridX` and `GridY`. For example GridX and GridY set to 1 will stretch the image across the given monitor. Change GridX for example to 2, to have the image at the given Path repeat twice horizontally. If either value is set to 0, the aspect ratio of the original image is maintained. Also **each repetition is mirrored, creating a seamless tiling effect**. The transcoded bitmap can then be used as a wallpaper in the Span or Tile Mode.

### SetWallpaper
This function will populate a settings-object to be consumed by the `TranscodeWallpaper` function. This will save the transcoded wallpaper and the current options, used to create it in the temporary directory. Then the wallpaper will be applied using the `SetWallpaper` Windows API.