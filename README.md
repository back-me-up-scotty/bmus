<img width="1000" height="545" alt="Image" src="https://github.com/user-attachments/assets/9068281f-0c29-4a20-818b-d199a43bf372" />

**What is BmuS?**

BmuS is a powerful free backup program for the automated backup of files, directories, and MySQL databases from a 
Linux / Raspberry Pi system to a NAS or network drive. You can also sync two NAS (i.e. Synology to Synology 
or UGREEN etc. and vice versa). 

BmuS can be installed directly on the source system (just run install_dependencies.sh) or via a Docker repository, which is also available. 
With Docker, you can easily use BmuS on different operating systems, such as a **Mac** or **Windows**. 

**For a short demo see here:**

[![BmuS on Youtube](https://img.youtube.com/vi/OmTRMqfe7oM/0.jpg)](https://www.youtube.com/watch?v=OmTRMqfe7oM)


**Installation, Configuration & Use**

To learn how to configure and use BmuS, please visit the user manual at: 
https://www.back-me-up-scotty.com/docs/what-is-bmus/

**Native install**

1. Download BmuS either from our [Website](https://www.back-me-up-scotty.com/docs/what-is-bmus/download/)  and unzip 

**OR** via GitHub

`git clone https://github.com/back-me-up-scotty/bmus.git`

2. `cd bmus/`
3. `chmod +x install_dependencies.sh`
4. `sudo bash install_dependencies.sh`
5. Configure [bmus_credentials](https://www.back-me-up-scotty.com/docs/configuration/bmus_credentials-sh-password-file/)
6. Configure [bmus.conf](https://www.back-me-up-scotty.com/docs/configuration/main-configuration/)
7. Give proper rights (install_dependencies.sh does that for you)

**Docker install**

Visit the [Quick Start Guide](https://www.back-me-up-scotty.com/docs/quick-start-guide-native-mac-win-docker/) and 
the FAQ on our Website to learn how to install Docker and Bmus on a [Mac](https://www.back-me-up-scotty.com/faq/can-i-backup-my-mac/) or [Windows](https://www.back-me-up-scotty.com/faq/can-i-backup-windows/).

**Tutorial video click here:**

In this video, you learn how to use BmuS to back up a Synology folder to a Ugreen NAS. The configuration is similar 
for other sources or destinations. So it doesn't matter whether you're backing up from a Mac to a NAS or from a 
Windows system to a NAS.

[![BmuS on Youtube](https://img.youtube.com/vi/ksfYJlpqfCw/0.jpg)](https://www.youtube.com/watch?v=ksfYJlpqfCw)

**Features**

- BmuS features encryption, Grandfather-Father-Son (GFS) Backup, deduplication, cloud storage / backup and much more.

- BmuS can be installed directly on the source system or via a Docker repository, which is also available.

- BmuS was developed with low-resource systems in mind, enabling even single-board computers such as 
Raspberry Pi to run it efficiently.

- One of the key features that has received special attention (or is it called “Love”?) is the dashboard, which is 
probably the most unique feature of BmuS, apart from the fact that only a few backup tools can back up files 
AND MySQL/MariaDB databases at the same time.

- The [pro version](https://www.back-me-up-scotty.com/dashboards/bmus_dashboard.html) of the dashboard does not only provide simple status information, but also includes trend analyses 
(such as size growth, duration and more) and displays the backup history of the last 30 days.

**Dashboard Standard Version (included)**

<img width="950" height="1257" alt="Image" src="https://github.com/user-attachments/assets/6cdfa626-ec66-4f2c-8182-69bc58988d6a" />


**Dashboard Pro Version (One time fee of $10 to support dev)**

<img width="950" height="507" alt="Image" src="https://github.com/user-attachments/assets/1231a593-8364-414d-9a2f-f6512722a4e9" />
<img width="950" height="370" alt="Image" src="https://github.com/user-attachments/assets/1763b624-805e-48c6-8d4c-602174afa7fc" />
<img width="950" height="606" alt="Image" src="https://github.com/user-attachments/assets/0c77fb98-13a3-4dbc-a3f6-6a4fa7826855" />
<img width="950" height="331" alt="Image" src="https://github.com/user-attachments/assets/1ffd8cc6-4a3a-45d2-a3d9-a17f9c98c17a" />
<img width="950" height="310" alt="Image" src="https://github.com/user-attachments/assets/63e8a266-2968-4d63-b5b1-9af0e7c22b20" />
<img width="950" height="269" alt="Image" src="https://github.com/user-attachments/assets/e2cb6417-e1d1-4a00-8b9b-36ceda5c78bf" />
<img width="950" height="283" alt="Image" src="https://github.com/user-attachments/assets/0342c79c-a91d-4c8f-9ea8-f74ee1ba477a" />
<img width="950" height="285" alt="Image" src="https://github.com/user-attachments/assets/03999f3e-4508-4322-8444-7f217976a8ce" />
<img width="950" height="276" alt="Image" src="https://github.com/user-attachments/assets/6c4fbb18-1d47-4fe4-a71b-f5b516333843" />
<img width="950" height="258" alt="Image" src="https://github.com/user-attachments/assets/b05e2815-ad7f-49b7-bf03-3b0c4dcc88a7" />
<img width="950" height="335" alt="Image" src="https://github.com/user-attachments/assets/f84ffc4f-6333-4931-b64a-0f7538183726" />
<img width="950" height="174" alt="Image" src="https://github.com/user-attachments/assets/51f0409b-2dad-4634-9726-259549dd40c2" />
<img width="950" height="450" alt="Image" src="https://github.com/user-attachments/assets/3f4e44a2-dbed-4a4c-9f93-582883b13187" />
<img width="950" height="630" alt="Image" src="https://github.com/user-attachments/assets/879a5dbf-3f69-4be3-a2e2-999988635142" />


For more on Pro Version:  [https://www.back-me-up-scotty.com/docs/what-is-bmus/buy-pro-dashboard/](https://www.back-me-up-scotty.com/docs/what-is-bmus/buy-pro-dashboard/)

**Key Features**

- Rsync-based: Efficient transfer, only changed files are copied.
- Deduplication: Uses hardlinks to save storage space. You have access 
  to full snapshots at any time without using up storage space for unchanged files.
- Automatic verification of data integrity
- Docker version available

Cloud Services

BmuS uses rclone and supports following cloud services: 

1Fichier, Akamai NetStorage, Amazon Drive, Amazon S3 Compliant Storage Providers including AWS, Alibaba, Ceph, China Mobile, Cloudflare, ArvanCloud, Digital Ocean, Dreamhost, Huawei OBS, IBM COS, IDrive e2, IONOS Cloud, Lyve Cloud, Minio, Netease, RackCorp, Scaleway, SeaweedFS, StackPath, Storj, Tencent COS, Qiniu and Wasabi, Backblaze B2, Better checksums for other remotes, Box, Cache a remote, Citrix Sharefile, Combine several remotes into one, Compress a remote, Dropbox, Encrypt/Decrypt a remote, Enterprise File Fabric, FTP, Google Cloud Storage (this is not Google Drive), Google Drive, Google Photos, Hadoop distributed file system, HiDrive, HTTP, In memory object storage system, Internet Archive, Jottacloud, Koofr, Digi Storage and other Koofr-compatible storage providers, Local Disk, Mail.ru Cloud, Microsoft Azure Blob Storage, Microsoft OneDrive, OpenDrive, OpenStack Swift (Rackspace Cloud Files, Memset Memstore, OVH), Pcloud, premiumize.me, Put.io, seafile, Sia Decentralized Cloud, SMB / CIFS, SSH / SFTP, Sugarsync, Uptobox, WebDAV, Yandex Disk, Zoho

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

------------------------------------------------------------------------------------

**What is the design difference between tools such as Borg or Restic?**

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

---

## 📜 Credits


This project uses several open-source tools to do the heavy lifting.
Special thanks to the developers of:

* **Rsync** (GPL) - for local file synchronization.
* **Rclone** (MIT) - for cloud storage connectivity.
* **Gocryptfs** (MIT) - for encryption.
* **MariaDB Client** (GPL) - for database dumps.
* **Docker** (Apache 2.0) - for containerization.

The Docker image is based on **Debian Bookworm Slim**.
