=== Cluster-based EGA Cryptor ===

This collection of shell scripts implements a part of EGA's [EgaCryptor](https://ega-archive.org/submission/tools/egacryptor)
Toolsuite, namely, the encryption and upload part.

==== 0-generate-links.sh ====

This script will generate a working structure in the current directory. It
creates symlinks and a todo list.

As input it requires a two-column, tab-separated CSV file as input, the
"mapping file".
The mapping file allows you to rename all files to something that is suited for 
publication, e.g. hiding sensitive names/identifiers, or using a 
publication-specific numbering scheme.

```csv
# comments work, and are ignored for encryption

# so are empty lines

# a fastq file to encrypt
/absolute/path/to/file/to/encrypt.fastq name-that-will-be-public-on-EGA.fastq

# a bam file
/more/files/fileA.bam   public-name-for-fileA.bam
/more/files/MaxMusterman_Tumor.bam   public-name-FileB.bam
/home/myStuff/EvaXample_germline.bam    public-name-FileC.bam
```

allowing you to rename the files before 
encryption, so

call it as follows:

```sh
cd /path/to/work-dir
path/to/0-generate-links.sh your-mapping-file.csv
```

a local `files` subdirectory will be created with the generated symlink 
structure, as well as a filelist-<DATE>.txt file as input for the next steps.

==== 1-submit-encryption-jobs.sh ====

This script submits the actual encryption jobs to the cluster.
Currently it only supports PBS-based clusters using `qsub`.

Encryption is GPG-based, using 
[EGA's public key](https://ega-archive.org/submission/EGA_public_key).
The submission script will check if GPG and this key are available.

call it as follows:
```sh
cd /path/to/work-dir
path/to/1-submit-encryption-jobs.sh filelist-<DATE>.txt
```

if no filelist is explicitly provided, it will try to find the most recently
modified `file-list*` and use that instead.
Basic attempts to not restart already-running jobs are made (looking for partial
or finished results in the `files` working directory), but please try not to
rely on this too much, in case this check overlooks something, corrupted output
will be produced (two concurrent jobs writing to the same result file).

The script can submit differently-sized input files to different queues based on
walltime limits. These limits will likely need to be tuned to your local cluster
situation.

Output is written to the `files` working directory, and consists of the
encrypted file (`filename.gpg`), and md5 checksums for both encrypted and 
unencrypted versions of said file (`filename.md5` and `filename.gpg.md5`).
All three are suitable for upload directly to EGA's submission inbox.

==== 2-aspera-upload.sh ====

This script will upload the encrypted results of a filelist to EGA's submission
inbox. It requires Aspera's `ascp` to be installed and in path, and takes its
login details from environment variables. (see `aspera-env.conf.template`).

depending on internet weather and your local outgoing connection, you probably
want to impose an upload speed limit by setting environment variable
`$SPEED_LIMIT`, default is `SPEED_LIMIT=100M`.
in our (limited) personal experience, "bursty" or "stuttering" upload behaviour
can usually be solved by setting a lower speed limit. Uploads that stutter and 
stall at 101M can be rock-solid at 100M if certain firewalls are present along
the path.


call it as follows:
```sh
cd /path/to/work-dir
source your-egalogin-aspera.conf
SPEED_LIMIT=99M path/to/2-aspera-upload.sh filelist-<DATE>.txt
```

If no filelist is specified, it will automatically try to use the
most-recently modified `filelist*`.

Since upload can take a long time, we recommend doing this in `nohup`, `screen`
or `tmux` sessions.