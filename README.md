# Tiny11Builder ~ 24H2 Edition
A PowerShell script to build a trimmed-down Windows 11 24H2 image.

## About:

Originally, this fork was created because I wasn't satisfied with the ["November '24 release"](https://github.com/ntdevlabs/tiny11builder/releases/tag/11-17-24) of the original [tiny11builder script by ntdevlabs](https://github.com/ntdevlabs/tiny11builder); which was supposedly compatible with the version 24H2 of Windows 11, but performed terribly.

Recently, the ["September 2025 Release"](https://github.com/ntdevlabs/tiny11builder/releases/tag/06-09-25) was created, which fixed several of the issues I had with the previous version. However, I fell like there's still room for improvement, and that's why I'll keep maintaining my "alternative version".

A complete overhaul of `tiny11maker.ps1` was realized and a batch script that works as a launcher (`LAUNCH_TINY11.bat`) was created, to facilitate the process of starting the script.

Only version 24H2 of Windows 11 was tested in this fork, I don't know how this script will behave with older versions. Support for **tiny11 core** (`tiny11Coremaker.ps1`) was dropped, since I don't see usefulness in that version.

The script was created to automate the build of a streamlined Windows 11 24H2 image, similar to tiny11. The main goal is to use only Microsoft utilities like DISM, and no utilities from external sources. The only executable included is **oscdimg.exe**, which is provided in the Windows ADK and it is used to create bootable ISO images.

Also included is an unattended answer file, which is used to bypass the Microsoft Account on OOBE and to deploy the image with the `/compact` flag. It's open-source, **so feel free to add or remove anything you want!** Feedback is also much appreciated.

## Requirements:

+ A original ISO of *Windows 11* version **24H2** (older releases were *NOT* tested), either downloaded from Microsoft website or created with the *media creation tool*.

+ A tool to mount the original ISO on Windows Explorer. The free version of [DAEMON Tools Lite](https://www.daemon-tools.cc/por/products/dtLite) is already enough.

+ Windows PowerShell version **5.1**, *older* versions are **NOT** supported and *newer* versions were **NOT** tested.

+ Administrator rights.

## Instructions:

1. Either download or create a Windows 11 ISO with the *media creation tool*. Both can be obtained at (<https://www.microsoft.com/en-us/software-download/windows11>).

2. Mount the downloaded / created ISO image on Windows Explorer with your preferred tool.

3. Right click on `LAUNCH_TINY11.bat`, then select `Run as administrator`.

4. When requested, type the **drive letter** where the image is mounted.<br>
Note: Only type the **letter**, no colon (`:`).

5. When requested, type the **index number** of the edition (Home, Pro, etc.) you want to use for your image.<br>
Note: Only type the **number**, no colon (`:`).

6. Wait until the script finishes.

7. When the image is completed, you will see it in the same folder where the script is located, named as `tiny11.iso`.

## What is removed:

- Clipchamp
- News
- Weather
- Xbox
- GetHelp
- GetStarted
- Office Hub
- Solitaire
- PeopleApp
- PowerAutomate
- ToDo
- Alarms
- Mail and Calendar
- Feedback Hub
- Maps
- Sound Recorder
- Your Phone
- Media Player
- QuickAssist
- Internet Explorer
- Tablet PC Math
- Edge
- OneDrive
- Copilot
- Outlook
- Microsoft Teams

## Known issues:

1. Although Edge is removed, there are some remnants in the Settings. But the app in itself is deleted. You can install any browser using WinGet (after you update the app using Microsoft Store). If you want Edge, Copilot and Web Search back, simply install Edge using Winget: `winget install edge`.<br>
Note: You might have to update Winget before being able to install any apps, using Microsoft Store.

2. Outlook and Dev Home might reappear after some time.

3. If you are using this script on arm64, you might see a glimpse of an error while running the script. This is caused by the fact that the arm64 image doesn't have OneDriveSetup.exe included in the System32 folder.

4. When removing / disabling a package, program or feature, an error may show up. That's completely normal. Whenever that happens, it's because said resource either doesn't exist on the ISO, or there are multiple versions of it and only one of them can be removed.
