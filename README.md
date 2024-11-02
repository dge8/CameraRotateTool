# CameraRotateTool

## What is CameraRotateTool?
CameraRotateTool is an unimaginatively named interactive PowerShell script for rotating UVC video feeds on Windows 10. It works by setting keys in the registry that tell the Windows UVC camera pipeline to rotate the camera feed, and so should work for most modern Windows apps using without requiring any running software in the background.

## How do I use it?
Download the latest release file on the right, and Right-Click > Run with PowerShell. It should automatically request escalation to admin privileges.

## Will it work for me?
Maybe. Some apps (especially older ones) ignore rotation information provided by Windows with the camera feed and/or use different Windows APIs for video and/or just do their own thing.

It's been tested with the Windows Camera app and Zoom on Windows 10 2004 and 20H2 64-bit and the following cameras:
- Logitech BRIO 4K
- Logitech Rally
- Microsoft Surface front & rear cameras

If it doesn't work for you, feel free to create a new issue. I will probably not be able to help you, but someone else may have a similar issue and be able to help. Perhaps there are KSCATEGORYs that are used by different cameras/software that have been missed.

## How does it work? Can I rotate my camera without using this script?
Yes, you need to create one or more FSSensorOrientation registry keys as per [this Microsoft doc](https://docs.microsoft.com/en-us/windows-hardware/drivers/stream/camera-device-orientation). The FSSensorOrientation registry key is a DWORD value with decimal 0, 90, 180, or 270 corresponding to the camera correction. Deleting the key also corresponds to 0 degrees.

Start by navigating to HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceClasses\ in the Registry Editor. Look inside the following keys in turn (your camera may not appear in all of them):
- `{6994AD05-93EF-11D0-A3CC-00A0C9223196}` (corresponding to KSCATEGORY_VIDEO)
- `{E5323777-F976-4f5b-9B55-B94699C46E44}` (corresponding to KSCATEGORY_VIDEO_CAMERA)
- `{24E552D7-6523-47F7-A647-D3465BF1F5CA}` (corresponding to KSCATEGORY_SENSOR_CAMERA, this will only be if your camera has a sensor/IR array, e.g. for Windows Hello)
- `{65E8773D-8F56-11D0-A3B9-00A0C9223196}` (corresponding to KSCATEGORY_CAPTURE)      

Look through subkeys (two levels) of these to find the 'Device Parameters' key containing a FriendlyName with your camera name. If you have multiple subkeys with the same FriendlyName you can instead match the path to the InstanceID of your camera in the Device Manager. Create the FSSensorOrientation key adjacent to the FriendlyName key. Then repeat for the other KSCATEGORY keys above.

## Roadmap and Contributions
CameraRotateTool is already essentially feature-complete, but if you know of other registry keys that cause Windows to do useful things to the camera pipeline please feel free to suggest them in an issue or via email.

## License
CameraRotateTool is released under the MIT license, see LICENSE.
