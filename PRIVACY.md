# Yabits privacy policy

Updated 21 September 2026. This policy covers the Yabits iPhone app and its widgets, developed by Yash Patel.

## Your habits

Yabits stores your habits, check-ins, notes and settings on your device. You can use it without an account. There are no ads, advertising identifiers or tracking SDKs. The analytics you see in the app are calculated on your device.

Yabits does not send your habit history to the developer. Sync is optional and sends the data described below only to the service you choose.

## Apple Health

Yabits asks for access only when you choose a Health source for a habit. It reads the requested type, such as steps, sleep or weight, to fill in that habit. It never writes to Apple Health.

Imported Health readings and the check-in values derived from them stay on the device. They are excluded from iCloud sync, self-hosted sync and shareable CSV or database exports. Local restore backups can contain them and stay inside the app’s storage. The habit database and these backups are excluded from iCloud device backup.

Habit names, targets, notes, manual check-ins and completion timestamps can sync or be exported. That includes anything you type about your health yourself. You can change Health access in the Health app or iOS Settings. Turning access off stops future reads; it does not erase values already stored in Yabits.

## Optional iCloud sync

If you enable iCloud sync, habit configuration, organization and manual tracking data are stored in your private CloudKit database under your Apple Account. The developer cannot browse that private database. Apple operates iCloud under its own privacy policy. Imported Health readings and sound files are not included.

## Optional self-hosted sync

If you connect a server, the app sends habit configuration, organization, manual check-ins, notes and completion timestamps to that server over HTTPS. The server also receives the information needed to authenticate your device and handle sync, including its device registration and network connection details.

The person running that server controls its database, backups and logs and can access the data it stores. Choose a server operator you trust. Yabits stores the app token in the iOS Keychain. Imported Health readings and sound files are not sent to the server.

## Permissions and files

Notifications are optional and scheduled on your device. Camera access is used only when you choose to scan a server enrollment QR code. Imported sounds stay on your device and play when your sound settings call for them.

Exporting opens the iOS share sheet. Only the app or person you choose receives the exported file. Opening an online guide, support page or privacy page sends a normal web request to its host, such as GitHub, whose privacy policy applies.

## Keeping and deleting data

Your local data stays until you delete it. You can delete habits in the app and remove backups in Settings → Data & backup → Backups & restore. Deleting a habit does not remove it from older backups or files you have already exported.

When sync is enabled, habit deletions are sent to the selected service. Sync services may retain deletion records, history or backups so devices can reconcile changes. Turning sync off or forgetting a server disconnects the app; it does not erase copies already stored remotely.

To remove remote data completely, use Apple’s iCloud storage controls or contact your server operator about its database, history and backups. Delete exported copies wherever you saved them. Deleting the app removes its local habit database and files. Saved credentials may remain in the iOS Keychain; revoke unused app tokens on your server. iCloud data, server data and exported files need to be managed separately.

## Diagnostics and support

Yabits has no built-in analytics or crash-reporting service. Apple may share diagnostics or TestFlight feedback with the developer according to your Apple settings and choices. If you contact support, the developer receives what you choose to send and uses it to respond and investigate the issue. Please leave out habit histories and Health data. Never send passwords, enrollment links or app tokens. You can ask for support correspondence to be deleted; public GitHub posts are also subject to GitHub’s retention rules.

## Questions and changes

For support or privacy questions, see [Help & support](https://github.com/DarkishLocket10/yabits-unraid/blob/main/SUPPORT.md). The date above changes when this policy is updated. Material changes to how the app handles data will be described in the release notes.
