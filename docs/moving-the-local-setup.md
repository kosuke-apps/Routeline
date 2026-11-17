# Moving the local setup after the rename

The app was renamed from Headway to Routeline. The repository now uses the new name everywhere, but the setup on the Mac
that is not in Git (launchd jobs, the collector's configuration, the deployed Worker, installed copies of the app) still has
the old names, and some of it has the repository folder's path written into it. Nothing in the repository changes that setup;
this note lists what carries a name and how to move it, by hand, once, together with renaming the folder.

Until it is done, the hourly pull and the nightly punctuality job keep running under their old names from the old folder. Do not
rename the folder first and fix the jobs later: the recordings stay on the collector for 6 days only, and a job that points
to a folder that no longer exists fails silently (see "Check" below).

## What carries a name

| Where | Old name | New name | What breaks if only the folder is renamed |
|---|---|---|---|
| launchd job, hourly pull (`~/Library/LaunchAgents/` and the copy in `data/launchd/`) | label and file `dev.kosuke.headway.pull` | `dev.kosuke.routeline.pull` | the plist holds the folder's path in `ProgramArguments`, `WorkingDirectory`, `StandardOutPath` and `StandardErrorPath`: the job fails every hour and nothing is pulled |
| launchd job, nightly punctuality (04:30) | label and file `dev.kosuke.headway.punctuality` | `dev.kosuke.routeline.punctuality` | same paths (inside a `bash -c` command): the statistics stop being rebuilt |
| two plists that are not loaded (`recorder`, `report`; the recorder was stopped on 2026-10-04, the report ran once) | `dev.kosuke.headway.recorder`, `dev.kosuke.headway.report` | rename or delete them | nothing; they only document how the first recording was made |
| collector configuration `data/collector/config.json` | keys `url` and `token` carry no name; the `url` value is the address of the deployed Worker | unchanged until the Worker is migrated | nothing (it stays valid) |
| environment variables read by `tools/pull_feeds.py` (they override the file; no job sets them) | `HEADWAY_COLLECTOR_URL`, `HEADWAY_COLLECTOR_TOKEN` | `ROUTELINE_COLLECTOR_URL`, `ROUTELINE_COLLECTOR_TOKEN` | a shell profile that sets the old names is ignored |
| Cloudflare Worker and its D1 database (deployed 2026-10-04) | `headway-collector` (both) | `routeline-collector` in `collector/wrangler.toml` | **the deployed Worker keeps its old name.** `npm run deploy` from this branch would create a second Worker and an empty database beside it, and the old one would keep recording. Do not deploy until the migration (new Worker, new database, copy of what is kept) is planned |
| installed copies of the app (iPhone, iPad, a Mac running the iPad app, simulators) | bundle identifier `dev.kosuke.headway` | `dev.kosuke.routeline` (and `.watch`, `.tests`) | the new build is a different app to iOS: it installs beside the old one and starts with no settings, favourites or saved places. Delete the old copy when the new one runs. A free personal team registers the new identifier by itself on the first build |
| the Xcode project | `Headway.xcodeproj` (generated, not in Git) | `Routeline.xcodeproj` | `xcodegen generate` makes the new one; delete the old one and `build/` |
| log queries | `subsystem == "dev.kosuke.headway"` | `subsystem == "dev.kosuke.routeline"` | an old query shows nothing |

`Config/Local.xcconfig` holds only the team and needs no change.

## Steps

1. Commit and merge everything. Stop the two loaded jobs:

   ```bash
   launchctl bootout gui/$(id -u)/dev.kosuke.headway.pull
   launchctl bootout gui/$(id -u)/dev.kosuke.headway.punctuality
   ```

2. Rename the repository folder in Finder to the repository's name. `data/` is inside it and moves along (feeds, logs, the
   punctuality database, the collector configuration).
3. In the folder's `data/launchd/`, make the new plists from the old ones: rename the files to
   `dev.kosuke.routeline.pull.plist` and `dev.kosuke.routeline.punctuality.plist`, then in each set `Label` to the new
   label and replace the old folder path in `ProgramArguments`, `WorkingDirectory`, `StandardOutPath` and `StandardErrorPath`
   with the new one. Copy both into `~/Library/LaunchAgents/` (a job loaded straight from `data/launchd/` is forgotten at the
   next restart) and delete the old plists there.
4. Load them:

   ```bash
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.kosuke.routeline.pull.plist
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.kosuke.routeline.punctuality.plist
   ```

5. Generate the project again and remove the old generated files:

   ```bash
   xcodegen generate
   rm -rf Headway.xcodeproj build
   ```

## Check (do not call it done before these)

- `launchctl print gui/$(id -u)/dev.kosuke.routeline.pull | head -3` and the same for `.punctuality`: both loaded; the
  old labels are gone from `launchctl list`.
- Run the pull once with `launchctl kickstart gui/$(id -u)/dev.kosuke.routeline.pull`, then `python3 tools/pull_feeds.py --status`
  (the last run is recent, nothing is waiting for long) and look at the end of `data/logs/pull.out.log` and at the newest file in
  today's folder of `data/feeds/`.
- The day after, once 04:30 has passed: the end of `data/logs/punctuality.out.log` is new and `data/punctuality/punctuality.json`
  has a new modification time.
- After any restart of the Mac, check both again: a job that was not loaded from `~/Library/LaunchAgents` once cost four days
  of recordings.
