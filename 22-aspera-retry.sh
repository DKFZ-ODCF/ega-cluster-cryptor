#!/bin/bash

# input check: we should know who to notify
if [ -z ${UPLOADER} ]; then
   >&2 echo "ERROR: please specify \$UPLOADER"
   >&2 echo "Usage: UPLOADER=e.mail@example.com ega22-upload-retries [to-encrypt-file.txt] [ N ]"
   >&2 echo "  where N = number of retries (default 10);"
   >&2 echo "  $UPLOADER will receive mail noting success/fail when last retry finishes."
   exit 22
fi


# Keep trying until N retries, with early exit on Aspera-success.
RETRIES=$2 # take from 2nd CLI arg
: ${RETRIES:=10}  # set default value, in case empty from CLI-args; cannot do this directly because cannot assign to $2

for i in $(seq $RETRIES); do
   echo " ===== $(date '+%F %T'): upload attempt $i for $UPLOADER ======";
   ega2-aspera-upload $1
   ASP_EXIT=$?
   if [ $ASP_EXIT -eq 0 ]; then
     break;
   fi
   
   # Give user a couple of seconds to hit Ctrl+C to escape out of this script
   # rather than having to repeatedly kill Aspera $RETRIES times
   USER_GRACE_PERIOD=5
   echo "hit Ctrl+C in the next $USER_GRACE_PERIOD seconds to break out of the retry-loop."
   sleep $USER_GRACE_PERIOD
done

# we finished retrying, check if upload finished successfully or not
if [ $ASP_EXIT -eq 0 ]; then
  EXIT_STATUS="successfully"
else
  EXIT_STATUS="with errors"
fi

# notify $UPLOADER about result
EXIT_MSG="Aspera upload in folder $PWD finished $EXIT_STATUS on $(date '+%F %T')"
SUBJECT="Aspera for $(basename $PWD) finished $EXIT_STATUS"
echo "$EXIT_MSG" | mail -s "$SUBJECT" "$UPLOADER"

# Pass on the Aspera-result, for potentially even more layers of scripting
exit $ASP_EXIT
