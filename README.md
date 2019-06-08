# RAInterface

This code is intended to be loaded into another repository as a submodule. An emulator should include RA_Interface.cpp in its build and link against winhttp.lib. Then, the emulator can be modified to call the hooks provided in RA_Interface.cpp at appropriate times to integrate with the RetroAchievements server via the RA_Integration.dll. See wiki for more details.

## Prerequisites

*This is to build the C++ dll as-is w/ Visual Studio 2017*

- MFC and ATL headers
- Visual Studio 2017 - Windows XP (v141_xp) w/ Windows 7.0 SDK
- git for windows: https://git-scm.com/download/win

Note: the `git` binary must be in the PATH environment variable (select "Use Git from the Windows Command Prompt" on installation).
