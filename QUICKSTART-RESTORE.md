# Docker quickstart restore validation

Requires server **1.0.5 or newer**. Version 1.0.4 cannot start a restored database;
update before attempting recovery. The 1.0.5 candidate passed fresh setup, backup,
restore, restart, sign-in, new app enrollment and two-way native sync on
21 September 2026. See `scripts/test-quickstart-live.py`.

### Restore the Docker quickstart

Use a backup made with the server command, and keep the original `.env`. This
procedure preserves your current account security where possible and reconnects
apps safely. Don't replace a running database or copy old WAL/SHM files over it.

1. From `yabits-home`, stop the serving container with `docker compose stop yabits`.
2. Copy your backup into its volume. Replace the filename below with your backup:

   ```sh
   docker compose cp backups/yabits-backup.sqlite yabits:/data/restore-source.sqlite
   docker run --rm --network none --volumes-from "$(docker compose ps -aq yabits)" busybox:1.37 chown 99:100 /data/restore-source.sqlite
   docker run --rm --network none --volumes-from "$(docker compose ps -aq yabits)" busybox:1.37 chmod 600 /data/yabits.sqlite /data/restore-source.sqlite
   ```

   The helper gives Yabits permission to read the copied backup and makes both
   database files private, as required by restore. It doesn't edit their contents
   or start the server. Keep this step when using Docker copy or restoring an older database.

3. Prepare a separate restored database. The current database is unchanged:

   ```sh
   docker compose run --rm --no-deps yabits restore --from /data/restore-source.sqlite --prepare /data/yabits.restore.sqlite
   ```

4. If preparation lists users needing a password reset, run each printed
   `auth reset-user` command through `docker compose run --rm --no-deps yabits`,
   using the prepared database and that user's ID. Run this in an interactive
   terminal and follow the confirmations. Do not skip a required reset.
5. Complete the restore even if no resets were required:

   ```sh
   docker compose run --rm --no-deps yabits auth complete-restore --database /data/yabits.restore.sqlite
   ```

6. Activate only after completion succeeds, then start:

   ```sh
   docker compose run --rm --no-deps yabits restore --activate /data/yabits.restore.sqlite --database /data/yabits.sqlite &&
     docker compose up -d --wait
   ```

If any step fails, stop there and keep the original volume, prepared database,
backup and `.env`. Do not start a second server on that volume. The detailed
[operations guide](https://github.com/DarkishLocket10/yabits-unraid#backup-and-restore)
covers interrupted recovery and the special case where the current database is
missing or corrupt. After a successful restore, sign in again and create a fresh
app token for each phone. Test this process on a separate installation before
you need it for real.
