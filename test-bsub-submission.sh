set -eu

MY_DIR="$HOME/lsf-cryptor"
WORKDIR="$MY_DIR/files"
JOBLOGDIR="$MY_DIR/cluster-logs"
SHORTNAME="a.txt"
FULL_FILE="$WORKDIR/$SHORTNAME"
#REQ_WALLTIME="00:19:59"
REQ_WALLTIME="00:09"
SCRIPT="JOB-ega-encryption.sh"
SUBMITLOG="$MY_DIR/submit.log"

    bsub \
        -env "FULL_FILE=$FULL_FILE, WORKDIR=$WORKDIR" \
        -J "egacrypt-$SHORTNAME" \
        -Jd "encrypting $SHORTNAME ($FULL_FILE) for the EGA archive" \
        -e "$JOBLOGDIR/%J.err" \
        -o "$JOBLOGDIR/%J.out" \
        -W $REQ_WALLTIME \
        < "$SCRIPT" | tee -a "$SUBMITLOG"
