echo NOTIFICATION: have you updated ega-aspera-upload.sh to include the ega-box pass? If not, you can kill the job with the following command 'qdel jobId'


WORKDIR=$(pwd)
LOG_BACK_UP_DIR=log-back-up

if [ -e $LOG_BACK_UP_DIR ]
then
  rm -r $LOG_BACK_UP_DIR
fi

if [ -e aspera-scp-transfer.log ]
then
  mkdir -p $LOG_BACK_UP_DIR
  mv aspera-scp-transfer* $LOG_BACK_UP_DIR
fi

qsub -v WORKDIR=$WORKDIR ega-aspera-upload.sh
