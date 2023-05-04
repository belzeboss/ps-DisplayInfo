Get information of your display like resolution, manufacturer, refreshrate etc. Used to change the resolution of the primary display before and after playing some video games to avoid rescaling render targets especially when actively using multiple monitors and Alt-tabbing.

### Get-Monitor
Uses `Get-CimInstance` on class `WmiMonitorBasicDisplayParams` to get the instance name of each connected display. This is then used to query the `Device Parameters` from the registry containing the EDID information. The function `Decode-EDID` takes the EDID information as byte[]-paramter and parses it into a ps-object. Mostly copied from WikiPedia.

### Get-Display
Uses Windows API call `GetDisplayMode` and converts it into a ps-object.

### TogglePrimaryMonitorFHD
Toggles between 1440p and 1080p, using Windows API `ChangeResolution`. This was the motivation for the functions above and may only act as an example in this instance.