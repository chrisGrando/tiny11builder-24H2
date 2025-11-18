# Tiny11 Maker ~ Reforged Edition
(Formerly known as `Tiny11Builder ~ 24H2 Edition`)

## About:

Originally, this fork was created because I wasn't satisfied with the ["November '24 release"](https://github.com/ntdevlabs/tiny11builder/releases/tag/11-17-24) of the original [tiny11builder script by ntdevlabs](https://github.com/ntdevlabs/tiny11builder); which was supposedly compatible with the version 24H2 of Windows 11, but performed terribly.

Recently, the ["September 2025 Release"](https://github.com/ntdevlabs/tiny11builder/releases/tag/06-09-25) was created, which fixed several of the issues I had with the previous version, along with adding support for version 25H2. However, I fell like there's still room for improvement, and that's why I'll keep maintaining my "alternative version".

A complete overhaul of `tiny11maker.ps1` was realized and a batch script that works as a launcher (`LAUNCH_TINY11.bat`) was created, to facilitate the process of starting the script. Now it also has a GUI for user interaction (command prompt is now used exclusively for log output).

Since the release of version `2025.11.17`, this script is designed and tested for editions **24H2** and **25H2** of Windows 11, I don't know how older editions will behave here. Support for **tiny11 core** (`tiny11Coremaker.ps1`) was dropped, since I don't see usefulness in that version.

The script was created to automate the build of a custom streamlined Windows 11 image, similar to tiny11. The main goal is to use only Microsoft utilities like DISM, and no utilities from external sources. The only executable included is **oscdimg.exe**, which is provided in the Windows ADK and it is used to create bootable ISO images.

Also included is an unattended answer file, which is used to bypass the Microsoft Account on OOBE and to deploy the image with the `/compact` flag. It's open-source, **so feel free to add or remove anything you want!** Feedback is also much appreciated.

## Requirements:

+ A original ISO of *Windows 11* with either version **24H2** *OR* **25H2** (older releases were *NOT* tested), either downloaded from Microsoft website or created with the *media creation tool*.

+ Windows PowerShell version **5.1**, *older* versions are **NOT** supported and *newer* versions were **NOT** tested.

+ Administrator rights.

## Instructions:

1. Either download or create a Windows 11 ISO with the *media creation tool*. Both can be obtained at (<https://www.microsoft.com/en-us/software-download/windows11>).

2. Right click on `LAUNCH_TINY11.bat`, then select `Run as administrator`.

3. Choose between mounting an ISO or using a already mounted drive.

	3.1. If mounting a ISO, then provide the full path to the file.
	
	3.2. If using a already mounted drive, then select the drive letter.

4. Select the Windows edition you want to use (Home, Education, Pro, etc.).

5. Wait until the script finishes.

6. If you mounted a ISO file, choose to either unmount it or keep it mounted.

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
