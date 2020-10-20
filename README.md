# Cluster-based EGA Cryptor

This collection of shell scripts implements a part of EGA's [EgaCryptor](https://ega-archive.org/submission/tools/egacryptor)
Toolsuite, namely, the encryption and upload part. It does this in the form of
(mostly) portable shell scripts that can run in cluster setups, allowing one to
parallelize encryption of larger submissions.

# Input welcome! Questions Welcome!

These scripts are shared to make everyone's life easier when submitting to EGA.
They started out as small internal tools at the Omics IT & Datamanagement Core Facility at the German Cancer Research Centre (DKFZ), a publicly funded body.
They are made openly available under the MIT license under the philosophy of ["public money, public code"](https://publiccode.eu/).

Asking questions is a way to make this project better. If something is unclear,
please help us make the documentation better, by asking a question in the Issue
Tracker

# Steps

This implementation divides the  encryption process into three logical steps:

1. setup / preparation
2. encryption
3. upload

Each step has different requirements on environment, CPU-load and internet 
accessibility, so they are divided into three separate scripts to execute.

## setup: 0-generate-links.sh

This script will generate a working structure in the current directory. It
creates symlinks and a todo list.

As input it requires a two-column, tab-separated CSV file as input, the
"mapping file".
The mapping file allows you to rename all files to something that is suited for 
publication, e.g. hiding sensitive names/identifiers, or using a 
publication-specific numbering scheme.

```csv
# map-file.txt
# comments work, and are ignored for encryption

# empty lines are no problem either!

# a fastq file to encrypt
/absolute/path/to/file/to/encrypt.fastq name-that-will-be-public-on-EGA.fastq

# bam files too:
/more/files/fileA.bam   public-name-for-fileA.bam
/more/files/MaxMusterman_Tumor.bam   public-name-FileB.bam
/home/myStuff/EvaXample_germline.bam    public-name-FileC.bam
```

Call it as follows:

```sh
cd /path/to/work-dir
path/to/0-generate-links.sh your-mapping-file.csv
```

a local `files` subdirectory will be created with the generated symlink 
structure, as well as a `to-encrypt_<DATE>.txt` file as input for the next steps.

## encryption: 1-submit-encryption-jobs.sh

This script submits the actual encryption jobs to the cluster.
It supports both PBS/Torque clusters, as well as LSF clusters
(though the switch is currently hardcoded in the script, edit to your needs).


Encryption is GPG-based, using 
[EGA's public key](https://ega-archive.org/submission/public_keys).
The submission script will check if GPG and this key are available.
For convenience purposes, a copy of EGA's key (as of 2020-03-12) is included: `submission_2020_public.gpg.asc`.
The paranoid will of course verify that this key matches that published by EGA itself.

call it as follows:
```sh
cd /path/to/work-dir
path/to/1-submit-encryption-jobs.sh [to-encrypt_<DATE>.txt]
```

if no to-encrypt filelist is explicitly provided, it will try to find the most recently
modified `to-encrypt*` and use that instead.
Basic attempts to not restart already-running jobs are made (looking for partial
or finished results in the `files` working directory), but please try not to
rely on this too much. If the check overlooks something, corrupted output
will be produced (two concurrent jobs writing to the same result file).

Walltime requests are tuned to each individual filesize to be encrypted,
assuming a very conservative encryption speed.
The `BYTES_PER_MINUTE` value probably needs tuning for each individual cluster

Output is written to the `files` working directory, and consists of the
encrypted file (`filename.gpg`), and md5 checksums for both encrypted and 
unencrypted versions of said file (`filename.md5` and `filename.gpg.md5`).
This trio is suitable for upload directly to EGA's submission inbox via Aspera or FTP.

### Job management

Jobs are all named 'egacrypt-{something}' for easy identification.

On the LSF system, they're also submitted into a single jobgroup (`/$USER/egacrypt`), for batch-management, e.g.
  - `bjobs -g /$USER/egacrypt` to inspect
  - `bkill -g /$USER/egacrypt 0` to kill all ega-cluster-cryptor jobs.

## upload: 2-aspera-upload.sh

This script will upload the encrypted results of a filelist to EGA's submission
inbox. It requires Aspera's `ascp` to be installed and in path, and takes its
login details from environment variables. (see `aspera-env.conf.template`).

depending on internet weather and your local outgoing connection, you probably
want to impose an upload speed limit by setting environment variable
`$SPEED_LIMIT`. EGA recommends a maximum of 300M (Mbit/second), our 
battle-tested default is `SPEED_LIMIT=100M`.
In our (limited) personal experience, "bursty" or "stuttering" upload behaviour
can usually be solved by setting a lower speed limit. Uploads that stutter and 
stall at 101M can be rock-solid at 100M if certain firewalls are present along
the path.


call it as follows:
```sh
cd /path/to/work-dir
source your-egalogin-aspera.conf
SPEED_LIMIT=99M path/to/2-aspera-upload.sh to-encrypt_<DATE>.txt
```

If no filelist is specified, it will automatically try to use the
most-recently modified `to-encrypt*`.

Since upload can easily take multiple days, we recommend doing this in `nohup`,
`screen` or `tmux` sessions.

## upload: ega22-aspera-retry.sh

This script wraps `2-aspera-upload` with retries, in case bad network conditions keep aborting your upload.

Call it as follows:
```sh
cd /path/to/work-dir
source your-egalogin-aspera.conf
# optional:  export SPEED_LIMIT=99M
UPLOADER=e.mail@example.com ega22-upload-retries [to-encrypt_<DATE>.txt] [ N ]
```

if no `to-encrypt-file.txt` is specified, `2-aspera-upload` will default to autodetection as above.
`N` is the number of retries (default 10).

If the upload-server has a sanely configured `mail`-program, you will receive an email notifying you of status (successful or errors)
once the script stops retrying (either because of success, or because the maximum number of retries was reached).
