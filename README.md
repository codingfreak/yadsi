# yadsi

Yet Another Desired State Implementation. Bring your dev-box to your personal working configuration with minor effort using freely available tools and platforms.

## Summary

On often underestimated task for a developer is to keep control over the dev environment. In order to target this (for myself in the first place) I decided to
try to automate this for Windows as far as possible. There are solutions to this already (PowerShell Desired State, Group Policies, Intune, ...) but all of them
are kind of enterprise-related. This is why I wanted to use simple scripting in combination with some configuration and reliance on publicly available cost-free
tools. This is what yadsi tries to accomplish.

In it's technical core it is a simple PowerShell (posh) script which reads desired state from a JSON file and tries hard to achieve the state including often
needed reboots and other complicated stuff. So instead of me sitting in front of my computer and hammering commands and then waiting for them to finish I try to
have a single command which does everything automated until my state is reached.

## Preconditions

- Fresh Windows 11 installation.
- All current updates are installed.
- Windows Terminal is default terminal.
- Administrative Windows Terminal is used to execute the script.

## Current State

- Windows Only
- Choco
- Winget
- Win Features
- Custom PowerShell
- Reboots
- Cleanup

## Known Issues

- Drivers
- Not idempotent currently

## Plans for the future

- git clone task
- progress store for idempotency
- nicer output
- JSON schema
- config editor
- more system preps:
	- terminal settings override from public link
	- terminal configuration (oh-my-posh ...)
	- default browser
	- background image
	- login screen image
	- color preset
	- taskbar layout
	- vscode extensions
	- Visual Studio installer
	- log
	- font installer without choco/winget
	- winget fixing
- Porting to MAC/Linux