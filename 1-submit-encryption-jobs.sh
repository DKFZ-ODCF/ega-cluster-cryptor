#!/bin/bash

# INFO: if you want to restart the encryption for a file, delete all the corresponding *.md5 and *.gpg files
#
# This script will automatically find the most-recent "to-encrypt*.txt" file and process files therein.
# If you wish to use a different to-encrypt list, you can specify this as a command line argument:
#   1-submit-encryption-jobs.sh your-filelist.txt

# Check if required EGA public key is known.
gpg --no-tty --batch --list-keys 'European Genome-Phenome Archive (EGA)' >/dev/null 2>&1;
if [ $? != 0 ]; then
  >&2 echo "ERROR: EGA public key not present in GPG keyring on this submission host
  -> Worker nodes probably cannot encrypt with EGA as recipient.
  Please import the EGA key!

Public key should be obtained from EGA: https://ega-archive.org/submission/public_keys .
  (those who believe this author is trustworthy, can used the copy included with this script)
  Import the obtained key with: \`gpg --import submission_2020_public.gpg.asc\`
"

exit 17
fi

CLUSTER_SYSTEM='LSF'
#CLUSTER_SYSTEM='PBS'

echo "using cluster system: $CLUSTER_SYSTEM"

# find wherever this script is, and load the util library next to it
#   even when hidden behind symlinks
OUR_DIR="$(dirname "$(readlink -f "$0")")"
source "${OUR_DIR}/util.sh"

# Get default, latest input file, OR whatever the user wants
OVERRIDE_FILE="$1"
TO_ENCRYPT_LIST=$(get_default_or_override_to_encrypt_list "$OVERRIDE_FILE");
verify_to_encrypt_list "$TO_ENCRYPT_LIST"

echo "using file-list: $TO_ENCRYPT_LIST"


WORKDIR="$(pwd)/files/"
SUBMITLOG="$(pwd)/_submitted_jobs_"$(date +%Y-%m-%d_%H:%M:%S)
JOBLOGDIR="$(pwd)/cluster-logs"
if [ ! -d "$JOBLOGDIR" ]; then
  mkdir "$JOBLOGDIR"
fi


# Get files from to-encrypt list that DON'T have a corresponding .gpg file
# first input is the to-encrypt filelist, using `sed` to normalise for either absolute paths or relative paths in WORKDIR
# second input is the contents of WORKDIR: all finished or partial encryption output, massaged with `sed` to match the original filename.
toEncryptFiles=( $( cut -f2 "$TO_ENCRYPT_LIST" \
      | sed -E -e 's#^.+/##' -e 's/ /\\ /g' \
      | sort
))
workdirFiles=( $( find "$WORKDIR" -type f \( -name '*.gpg' -or -name '*.gpg.partial' \) \
      | sed -E -e 's#^.+/##' -e 's/\.gpg(.partial)?$//' -e 's/ /\\ /g' \
      | sort
))

OLD_IFS="$IFS"
IFS='' # to preserve spaces in filenames in the 'printf $array' calls
unencryptedFiles=( $( comm -23 \
  <( printf -- '%s\n' "${toEncryptFiles[@]}" ) \
  <( printf -- '%s\n' "${workdirFiles[@]}" ) \
) )
alreadyEncryptedFiles=( $( comm -12 \
  <( printf -- '%s\n' "${toEncryptFiles[@]}" ) \
  <( printf -- '%s\n' "${workdirFiles[@]}" ) \
) )
IFS="$OLD_IFS"
echo "found ${#alreadyEncryptedFiles[*]} encrypted and/or in-progress files. Submitting ${#unencryptedFiles[*]} new encryption jobs:"

if [ ${#unencryptedFiles[*]} -ge 1 ]; then
  echo -e "FILE                        \tWTIME\tSUBMISSION_FEEDBACK" | tee -a "$SUBMITLOG"
fi
for SHORTNAME in ${unencryptedFiles[*]}; do
  FULL_FILE="$WORKDIR/$SHORTNAME"
  if [ ! -e "$FULL_FILE" ]; then
    echo "WARNING: File not found: $FULL_FILE" | tee -a "$SUBMITLOG"
  else
    # Request a sensible amount of walltime, and let the queue runlimits sort out which queue we get
    FILESIZE=$(stat -c '%s' "$(readlink -f "$FULL_FILE")") # in bytes

    # Be VERY pessimistic about encryption speed: 200 MByte/minute ~ 3 MByte/second.
    #   under good conditions, we can easily do five times that, but bad "I/O weather"
    #   can easily kill throughput.
    # By underestimating our speed, we'll probably request too much walltime, but that's
    #   better than being walltime-killed 80% of the way (with no way to resume later)
    BYTES_PER_MINUTE=200000000

    MINUTES="$(( FILESIZE / BYTES_PER_MINUTE ))"
    HOURS="$(( MINUTES / 60 ))"
    MINUTES="$(( MINUTES - ( 60 * HOURS ) + 1 ))" # +1 to avoid requesting "0" for tiny files, and as margin

    # prepend filename before job-id output (intentionally no newline!)
    printf "%-29s\t%dh%02dm\t" "$SHORTNAME" "$HOURS" "$MINUTES" | tee -a "$SUBMITLOG"

    # actual job submission, prints job-id
    if [ $CLUSTER_SYSTEM == "PBS" ]; then
      2>&1 qsub \
          -v "FULL_FILE=$FULL_FILE,WORKDIR=$WORKDIR" \
          -N "egacrypt-$SHORTNAME" \
          -e "$JOBLOGDIR" \
          -o "$JOBLOGDIR" \
          -l "walltime=$( printf '%2d:%20d:00' $HOURS $MINUTES )" \
          < "${OUR_DIR}/JOB-ega-encryption.sh" | tee -a "$SUBMITLOG"
    elif [ $CLUSTER_SYSTEM == "LSF" ]; then
      2>&1 bsub \
          -env "FULL_FILE=$FULL_FILE, WORKDIR=$WORKDIR" \
          -J "egacrypt-$SHORTNAME" \
          -Jd "encrypting $SHORTNAME ($FULL_FILE) for the EGA archive" \
          -e "$JOBLOGDIR/%J-$SHORTNAME.err" \
          -o "$JOBLOGDIR/%J-$SHORTNAME.out" \
          -W "$( printf '%2d:%02d' $HOURS $MINUTES )" \
          < "${OUR_DIR}/JOB-ega-encryption.sh" | tee -a "$SUBMITLOG"
    else
      echo "ERROR: specified unknown cluster system '$CLUSTER_SYSTEM'; no jobs submitted" | tee -a "$SUBMITLOG"
      exit 42
    fi
  fi
done
