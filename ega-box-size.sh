#!/bin/bash

# Script to check how full an EGA upload-area is.
# The EGA-archive has a per-submitter-account quotum of ~10 TB, after which uploads will start failing
# (out of disk-space)
# It is only polite to check how close we are to this limit before starting to upload things.
#
# Usage:
#   ega-box-size.sh [ega-box-NNNN]
#
# Script will first check if an aspera-upload config is loaded in the environment
#   (as used by 2-aspera-upload, source source-<some-account>-aspera-env.conf)
# If not, it will ask for the box (if not already specified as command line parameter), and
# read the password from STDIN (to avoid passwords from showing up in shell command history)




# Which box to use?
# First, see if a box-config for upload is already loaded:
# Check for the env-vars used by 2-aspera-upload.sh / aspera ascp
if [[ ! -z "$ASPERA_USER" && ! -z "$ASPERA_SCP_PASS" ]]; then
  echo "using EGA credentials from loaded ASPERA-environment for $ASPERA_USER"
  EGA_BOX="$ASPERA_USER"
  EGA_PASS="$ASPERA_SCP_PASS"

elif [[ $1 =~ ega-box ]]; then
  # Second, if no env preloaded, assume a command line param:
  EGA_BOX="$1"
  # ask the password with `read`, instead of as argument-2/$2, to prevent passwords from showing up in shell history
  read -p "password for $EGA_BOX? (ctrl+shift+v to paste) " -s EGA_PASS
elif [[ -z $1 ]]; then
  # Third: if nothing specified at all, ask both user+pas explicitly
  read -p "From which box do you wish to download? ega-box-" BOX_NR
  EGA_BOX="ega-box-$BOX_NR"
  read -p "password for $EGA_BOX? (ctrl+shift+v to paste) " -s EGA_PASS
else
  >&2 echo "ERROR: don't know which EGA box to query.
  either source an upload config ('source source-<some-account>-aspera-env.conf') or
  use 'ega-box-size-sh ega-box-NNNN'"
  exit 42
fi

# hardcoded: EGA's FTP server
EGA_FTP_SERVER=ftp.ega.ebi.ac.uk


# access EGA upload area via FTP
# using LFTP because it has a nice `du` (disk-usage) built-in that we can use
# - -u user,password: login credentials
# - -e: commands to run after establishing connection
# - ssl:verify-certificate/ftp.ega.ebi.ac.uk no
#   This is moderately INSECURE: without verification, ANYONE can claim to be EGA,
#   including Evil-mc-hacker-face, and we will believe them :-(
#   We limit the risk by:
#   - only disabling verification for this session (instead of in a lftp-config file), and
#   - only for the EGA FTP server, and
#   - praying that no-one will comprise the DNS-result for ftp.ega.ebi.ac.uk
#     (praying/hope is an EXCELLENT security primitive, widely used in the industry! /s)
#   First: The 'proper' solution would be to get LFTP to use the system certificate store to verify EGA's identity.
#   LFTP CA-certs seem to be misconfigured on all servers I have access to (OpenSuse, CentOS, Debian, Ubuntu)
#   I did not get this working after several hours :-(
#   Second: It seems a critical intermediate certificate from QuoVadis (EGA's cert provider) is missing in Linux CA-lists
#   EGA's suggested workaround of downloading the QuoVadis certs manually, and providing them as a ca-file doesn't work
#   because QuoVadis stopped providing the PEM-version of the EV (extended-validation) cert they use,
#   and manual conversion with openSSL errors out with some kind of parsing error in the DER-file they do provide.
#   in short: AAAAAAAAAAAAAAAAARGH
#
#   see also:
#   - https://ega-archive.org/submission/tools/ftp-aspera#FTPTLS
#   - https://www.quovadisglobal.com/download-roots-crl/
#   - https://serverfault.com/questions/411970/how-to-avoid-lftp-certificate-verification-error
#   - https://stackoverflow.com/questions/23900071/how-do-i-get-lftp-to-use-ssl-tls-security-mechanism-from-the-command-line
#   - https://stackoverflow.com/questions/12790572/openssl-unable-to-get-local-issuer-certificate
#   - https://www.versatilewebsolutions.com/blog/2014/04/lftp-ftps-and-certificate-verification.html
#   - https://unix.stackexchange.com/questions/97244/list-all-available-ssl-ca-certificates
#   - https://cheapsslsecurity.com/p/convert-a-certificate-to-pem-crt-to-pem-cer-to-pem-der-to-pem/
#
# - du: get disk-usage by recursively summing all filesizes (lftp-specific extension, not a normal FTP command)
#   -h for human readable output (GB/TB), instead of loooooong byte numbers.
# - exit: leave server, otherwise lftp keeps connection open for interactive input.
lftp "$EGA_FTP_SERVER" \
  -u $EGA_BOX,$EGA_PASS \
  -e 'set ssl:verify-certificate/ftp.ega.ebi.ac.uk no ; du -h . ; exit'

