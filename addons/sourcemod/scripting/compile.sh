#!/bin/bash -e
cd "$(dirname "$0")"

test -e ../plugins || mkdir ../plugins

if [[ $# -ne 0 ]]; then
	for sourcefile in "$@"
	do
		smxfile="`echo $sourcefile | sed -e 's/\.sp$/\.smx/'`"
		echo -e "\nCompiling $sourcefile..."
		/home/clague/Documents/Program/SourcePawn/SM/spcomp $sourcefile -i./include -o../plugins/$smxfile
	done
else
	for sourcefile in *.sp
	do
		smxfile="`echo $sourcefile | sed -e 's/\.sp$/\.smx/'`"
		echo -e "\nCompiling $sourcefile ..."
		/home/clague/Documents/Program/SourcePawn/SM/spcomp $sourcefile -i./include -o../plugins/$smxfile
	done
fi
