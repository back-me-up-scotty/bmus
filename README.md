1. What is BmuS?


BmuS (https://www.back-me-up-scotty.com) is a powerful free backup program for the automated backup 
of files, directories, and MySQL databases from a Linux / Raspberry Pi system 
to a NAS or network drive. It features encryption, deduplication, and much more.

For a short demo see here:

https://www.youtube.com/watch?v=OmTRMqfe7oM

BmuS was developed with low-resource systems in mind, enabling single-board 
computers such as Raspberry Pi to run it efficiently.

One of the key features that has received special attention (or is it called “Love”?) 
is the dashboard. The pro version of the dashboard does not only provide simple status 
information, but also includes trend analyses (such as size growth, duration 
and more) and displays the backup history of the last 30 days.

2. Key Features

- Rsync-based: Efficient transfer, only changed files are copied.

- Deduplication: Uses hardlinks to save storage space. You have access 
  to full snapshots at any time without using up storage space for unchanged files.

- Automatic verification of data integrity

Encryption:

- File system encryption with gocryptfs (filenames & contents encrypted).
- GPG encryption for SQL database dumps.
- Restore: Built-in restore mode for individual files or entire backups (including from encrypted sources).
- Layer 1: gocryptfs for file system encryption
- Layer 2: GPG for additional archive encryption
- Layer 3: SMB3 encryption for network transmission

Dashboard & Reporting:

- In the Pro version, BmuS generates an HTML5 dashboard with charts (Chart.js) for analyzing memory usage, trends and errors.
- 10+ visualization types
- Email notification with log file and dashboard attached.

Backup History

- CSV-based long-term history (365+ days)
- Automatic rotation of old entries
- Trend analysis with 7-day average
- Success rate tracking over months/years

Databases

- Automatic dump of MySQL/MariaDB databases.
- Single transaction dumps (InnoDB optimized)
- Automatic fallback for MyISAM
- Multi-database support (array-based)
- Optional GPG encryption of SQL dumps

Resilience

- Automatic network resets in case of freeze or connection problems.
- Batch processing to conserve memory (RAM).
- Dry-Run mode for safe testing.
- Adjustable pauses for system stabilization

Intelligent structure recognition

- Flat structures (Flat)
- Date folders (YYYY-MM-DD)
- Nested deduplication structures
- Mixed structures

Specialization in resource-constrained systems

- Intelligent RAM-Management
- Auto-Reset network interface
- Freeze-Protection

Multilingual languages available

-  Your own language files can be added easily


3. What is the design difference between tools such as Borg or Restic?

While tools like BorgBackup and Restic are powerful industry standards for block-level 
deduplication, BmuS (Back Me Up Scotty) follows a different philosophy: The KISS 
Principle (Keep It Simple, Stupid).

Here is the different approach taken by BmuS.

a. Zero Lock-in & 100% Transparency

This is the biggest differentiator. Borg and Restic store your data in proprietary 
“repositories” (chunked data blobs). To read or restore a single file, you must have 
the tool installed and working.

BmuS Approach: Your backup is just a standard file system. You can plug your backup 
drive into any Linux machine and browse your files with a standard file manager 
(Explorer/Finder).

The Benefit: If BmuS stops existing tomorrow, your data is still fully accessible. 
You don’t need BmuS to restore your data.

b. Visual Reporting Out-of-the-Box

Borg and Restic are Command-Line Interface (CLI) tools. They output text logs. 
If you want charts or a dashboard, you have to set up complex external monitoring 
stacks (like Prometheus/Grafana) or use third-party wrappers.

BmuS Approach: BmuS generates a beautiful, standalone HTML Dashboard after every 
run. It visualizes your data growth, file types, and performance trends instantly, 
without any additional software.

c. Minimal Dependencies

To run Borg or Restic, you need to download and maintain their specific binaries 
on every machine.

BmuS Approach: BmuS relies on rsync and bash—tools that are pre-installed on 
virtually every Linux distribution (from Raspberry Pi to Enterprise Servers). 
It is lightweight and native to the system.

d. “Time Machine” Style Browsing

Because BmuS uses Hardlinks (like macOS Time Machine), every backup snapshot 
looks like a full backup directory.

The Benefit: You can verify your backup simply by looking at it. You don’t need 
to mount a FUSE filesystem or run a mount command just to check if a file is there.

e. Hackability & Customization

Borg and Restic are compiled programs (Go/Python/C). If you want to change how 
they work, you need to be a software engineer.

BmuS Approach: It is a transparent Bash script. If you want to add a custom 
notification, change the logging format, or tweak the logic, you can do it yourself in minutes.
