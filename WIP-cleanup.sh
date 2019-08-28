#!/bin/bash

# Cleans up EGA-cluster-cryptor work-dirs
#  * condenses per-file MD5 sums into one overall list.
#  * removes files that have no value anymore after succesful EGA archiving.
#    If EGA archiving (and thus checksum verification) worked, everything in-between MUST have gone correctly.
#    * the (often huge) encrypted files themselves
#    * encryption cluster logs
#    * aspera transfer logs
#  * remove linking scripts, they contain no useful info over the map-files.


for EGA_DIR in "$@"; do
	# condense per-file MD5 sums into one overall check-file
	WORKDIR="$EGA_DIR"/files

	# sanity check: before we start deleting stuff, does this folder look like an EGA-cluster-cryptor dir?
	if [ ! -d "$WORKDIR" \
			-o ! -d "$EGA_DIR/cluster-logs" \
			-o ! -e "$EGA_DIR/aspera-scp-transfer.log" ]; then
		2>&1 echo "ERROR: '${EGA_DIR}' doesn't look like it's  an EGA-cluster cryptor working dir. Aborting, rather than deleting your stuff!"
		2>&1 echo "(Better safe than sorry)"
		exit 42
	fi


	# DANGER ZONE: start force deleting stuff!

	CONDENSED_OUTPUT="$EGA_DIR/all_md5sums.md5"
# ToDo: I'm waffling if this check is a good idea; it's extremely harsh on resuming after Ctrl+C, but would be a good "oops I overwrote my archived data" check...
#	if [ -e "$CONDENSED_OUTPUT" ]; then
#		2>&1 echo "ERROR: output file '$CONDENSED_OUTPUT' already exists, ABORTING!"
#		2>&1 echo "  (delete or rename it first if you want to continue)"
#		exit 1
#	fi
	for MD5_FILE in "$WORKDIR"/*.md5; do
		cat "$MD5_FILE" >> "$CONDENSED_OUTPUT"
		rm "$MD5_FILE"
	done

	# encrypted data (Only EGA can read it anyway):
	rm -f "$WORKDIR"/*.gpg

	# linking scripts and the links they produced
	# the result is still documented by the map-files we keep.
	rm -f "$EGA_DIR"/_create_links-*.sh
	find "$WORKDIR" -type l -delete

	# The above steps SHOULD have left the workdir empty: remove it as well.
	# If not, let the rmdir 'not empty' message do the warning for us.
	rmdir "$WORKDIR"

	# Clusterlogs and their submission job IDs
	# Once the files are permanently archived, we couldn't possibly have an interest in how they are produced
	rm -r "$EGA_DIR"/cluster-logs
	rm -f "$EGA_DIR"/_submitted_jobs_*

	# aspera formatted todo file, and resulting transfer logs
	rm -f  "$EGA_DIR"/_aspera-upload_*.txt
	rm -f  "$EGA_DIR"/aspera-scp-transfer*.log
done

