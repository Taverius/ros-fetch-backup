# ros-fetch-backup

MikroTik RouterOS script to upload nearly all things that can be backed up to an SFTP remote.

Based on https://forum.mikrotik.com/viewtopic.php?t=159432 and https://forum.mikrotik.com/viewtopic.php?p=858564#p858564

Should work in both v6 and v7, but only v7 is tested.

The Dude and User-Manager backups are not tested.

Should also work in other `/fetch` modes with minor adjustments, but wanted to limit complexity for now.



## Known Issues:

* SSH Keys only get exported **after** the script ends, so they don't get backed up on first run and are always `interval` out of date. Help is appreciated.
