#!/usr/bin/zsh
setopt shwordsplit
PID_ARRAY=`pgrep srcds_linux`
for PID in $PID_ARRAY; do

	MASK=`taskset -pc $PID|grep -oP "current affinity list:[[:blank:]]\K([[:alnum:]]|,)*"`
	IFS=','
	CORES=(${MASK})
	IFS=''

	if [[ ${#CORES} -eq 1 ]]; then

		if [[ ${CORES[1]} -gt 0 ]]; then
			CORES=( $((CORES[1]-1)) ${CORES[1]} )
		else
			CORES=( ${CORES[1]} $((CORES[1]+1)) )
		fi
	fi

	echo "Affinity set for pid: $PID"
	echo $CORES

	TASKS=`ls /proc/$PID/task/|xargs`
	for TASK_ID in ${(s: :)TASKS}; do

		if [ $PID -eq $TASK_ID ]; then
			continue
		fi
		taskset -pc ${CORES[1]} $TASK_ID > /dev/null
	done
	taskset -pc ${CORES[-1]} $PID > /dev/null
done

