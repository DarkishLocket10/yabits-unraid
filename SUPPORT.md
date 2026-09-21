# Help with Yabits

## Something isn’t working

Check that you’re using the latest version of Yabits. When reporting a problem, include the app version from Settings → About, your iOS version, what you expected and what happened. A screenshot can help; hide any personal information first.

You can [report a bug on GitHub](https://github.com/DarkishLocket10/yabits-unraid/issues). GitHub issues are public. Do not post habit histories, Health data, passwords, enrollment links or app tokens.

## Sync

Open Settings → Data & backup and check the selected sync service and its status. For iCloud, use the same Apple Account on each device and make sure iCloud is available. For a self-hosted server, use the same server account with a separate app token for each device, then tap Sync now.

The [server setup guide](https://github.com/DarkishLocket10/yabits-unraid/blob/main/SETUP.md) covers installation, connecting your phone, updates and connection problems. Imported Health readings and sound settings stay on each device, so they will not appear through sync.

## Health isn’t filling in a habit

Check the habit’s Health source and whether the Health app contains data for that day. Review Yabits access in the Health app or iOS Settings. Apple does not tell apps whether read access was denied, so an empty result can mean either no data or no access. Manual entries are kept when Health refreshes.

## Reminders and sounds

Use Settings → Notifications to check iOS permission and your reminder schedules. Focus modes and iOS notification settings can silence delivery. Check Settings → Sounds for the main sound setting and any habit or check-in-state overrides. Check-in sounds respect the silent switch.

## Backups and your data

Use Settings → Data & backup → Backups & restore to make or restore a local backup. Restoring replaces the current local data and first makes a safety backup. Local backups stay on that device, so they are not a replacement for protecting the device itself. CSV and database exports let you keep a separate copy of your manual tracking data; imported Health readings are excluded.

For privacy details and deletion options, read the [Privacy policy](https://github.com/DarkishLocket10/yabits-unraid/blob/main/PRIVACY.md).
