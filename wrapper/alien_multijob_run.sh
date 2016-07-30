#!/bin/bash

#DATABASE=alien.db

jalien_sqlite_q(){
	DATABASE=$1
	QUERY=$2
	Q_RESULT=-1
	sqlite3 -init init.sql $DATABASE "$QUERY"
	while [ $? -ne 0 ]; do
		sleep 5
		sqlite3 -init init.sql $DATABASE "$QUERY"
	done
}

get_resources(){
	if [ -z $1 ]; then
		echo No ALICE job PID specified for get_resources
		exit -1
	fi
	ALICE_JOB_PID=$1
	ALICE_QUEUE_ID=$2
	DATABASE="$3.monitoring"
	START_TIMESTAMP=$4

	CPUINFO=$(grep MHz /proc/cpuinfo | uniq -c)
	CPU_COUNT=$(echo $CPUINFO | awk '{print $1;}')
	CPU_FREQ=$(echo $CPUINFO | awk '{print $5;}' | sed  -r 's/cpu MHz\s*:\s//')
	CPU_FAMILY=$(grep family /proc/cpuinfo | tail -n 1 | awk '{print $4;}')
	MAX_VSZ=0
	MAX_RSZ=0
	LOOP_CNT=0
	ps aux

	# final String procinfo = String.format("%s %d %.2f %.2f %.2f %.2f %.2f %d %s %s %s %.2f %.2f 1000", RES_FRUNTIME, RES_RUNTIME, RES_CPUUSAGE, RES_MEMUSAGE, RES_CPUTIME, RES_RMEM, RES_VMEM,
	#                                  RES_NOCPUS, RES_CPUFAMILY, RES_CPUMHZ, RES_RESOURCEUSAGE, RES_RMEMMAX, RES_VMEMMAX);
	while true; do
		sleep 60
		CURRENT_TIMESTAMP=$(date +%s)
		RUNNING_LENGTH=$(echo $CURRENT_TIMESTAMP-$START_TIMESTAMP | bc)
		RUNLENGTH_STR=$(printf "%02d:%02d:%02d" $(echo $RUNNING_LENGTH/3600 | bc) $(echo $RUNNING_LENGTH/60%60 | bc) $(echo $RUNNING_LENGTH%60 | bc))
		#INFO=$(echo -n "$RUNLENGTH_STR $RUNNING_LENGTH "; du -sb ; ps h -p $ALICE_JOB_PID -o cputime,vsz,rss,pcpu,time,pmem ; echo -n " $CPU_FREQ 1000" )
		#INFO=$(echo -n "$RUNLENGTH_STR $RUNNING_LENGTH "; du -sb ; ps h -p $ALICE_JOB_PID -o "%cpu %mem cputime rsz vsz" ; echo -n " $CPU_COUNT $CPU_FAMILY $CPU_FREQ 1000" )
		PROCESS_INFO=$(ps --no-headers -o "user %cpu %mem cputime rsz vsz" | grep -e "^`id -u`" | awk '{cpu += $2; mem += $3; cputime += $4; rsz += $5; vsz += $6;} END {print cpu, mem, cputime, rsz, vsz}')
		RSZ=$(echo $PROCESS_INFO | awk '{print $4;}')
		VSZ=$(echo $PROCESS_INFO | awk '{print $5;}')
		if [ $VSZ -gt $MAX_VSZ ]; then MAX_VSZ=$VSZ; fi
		if [ $RSZ -gt $MAX_RSZ ]; then MAX_RSZ=$RSZ; fi
		INFO=$(echo -n "$RUNLENGTH_STR $RUNNING_LENGTH "; du -sb ; echo -n " $PROCESS_INFO"; echo -n " $CPU_COUNT $CPU_FAMILY $CPU_FREQ $MAX_RSZ $MAX_VSZ 1000" )
		#INFO="$RUNNING_LENGTH 93.52 3.8 6110.60 967556 2116900 16 6 2266.821 14528.06 793032 1919359 18915.4"
		#echo Consumption for ALICE_JOB_ID, pid:  $ALICE_JOB_PID : $INFO
		echo $INFO >> resources
		let "LOOP_CNT++"
		if [ $(echo $LOOP_CNT%10 | bc) -ne 0 ]; then continue; fi
		echo jalien_sqlite_q "$DATABASE" "INSERT INTO alien_jobs_monitoring VALUES ('$ALICE_QUEUE_ID', '$INFO')"
		jalien_sqlite_q "$DATABASE" "INSERT INTO alien_jobs_monitoring VALUES ('$ALICE_QUEUE_ID', '$INFO')"
	done
}


exec_element(){
	COMMAND=$1
	if [ -z "$COMMAND" ]; then 
		exit 254
	fi
	eval "(. environment; $COMMAND 1>>stdout 2>>stderr ; echo \$?>./fifo) &"
}

if [ -z $1 ]; then
	echo No MPI rank specified. Exiting.
	exit 255
fi

RANK=$1
WORKDIR=$2
echo My rank is: $RANK

# cd to working dir
# cd $WORKDIR/$PBS_JOBID

# sqlite3 

# DBLINKFILE=/lustre/atlas/scratch/psvirin/csc108/workdir/database.lnk
cd $WORKDIR
DATABASE=$PWD/jobagent.db

# try 10 times for exising database
# for i in `seq 1 10`; do
	# echo Doing $i th check for rank $RANK
	# echo DBLINKFILE is $DBLINKFILE
	# [ ! -f $DBLINKFILE ] && [ $i -eq 10 ] && echo No dblink file found && exit 2
    	# [ ! -f $DBLINKFILE ] && (echo No DBLINKFILE, sleeping ;  sleep 60 ; continue)
	# DATABASE=`cat $DBLINKFILE | sed s/jdbc:sqlite://`
	# echo Database is: $DATABASE
	# #[ ! -z $DATABASE ] && break
	# [ ! -f $DATABASE ] && [ $i -eq 10 ] && echo No database found && exit 1
	# [ ! -f $DATABASE ] && sleep 90
# done


echo We are entering main task fetch loop

#RANK=`./get_rank.py`
#RANK=0
for i in {1..20}; do
	#DATA=`sqlite3 -init init.sql $DATABASE "SELECT job_folder,executable FROM tasks_alien WHERE rank=$RANK AND status='Q'"`
	DATA=`sqlite3 -init init.sql $DATABASE "SELECT job_folder,executable, validation, environment, queue_id FROM alien_jobs WHERE rank=$RANK AND status='Q'"`
	echo Query result for rank $RANK : $?
	echo sqlite3 -init init.sql $DATABASE "SELECT job_folder,executable, validation, environment, queue_id FROM alien_jobs WHERE rank=$RANK AND status='Q'"
	[ -z "$DATA" ] &&  sleep 60 && continue
	echo ===================== Starting new job for rank $RANK ===========
	#echo $DATA
	CMD=`echo $DATA | awk -F"|" '{print $2;}'`
	VALIDATION=`echo $DATA | awk -F"|" '{print $3;}'`
	DIR=`echo $DATA | awk -F"|" '{print $1;}'`
	QUEUE_ID=`echo $DATA | awk -F"|" '{print $5;}'`

	#SLEEP=`echo $DATA | awk -F"|" '{print $2;}'`
	#echo $(date): Rank $RANK says: $MSG
	#cd `dirname $CMD`
	#eval $CMD
	#sqlite3 -init init.sql $DATABASE "UPDATE alien_jobs SET status='R' WHERE rank=$RANK"
	jalien_sqlite_q $DATABASE "UPDATE alien_jobs SET status='R' WHERE rank=$RANK"
	echo Rank $RANK: Job executable is: $CMD
	echo Rank $RANK: Job directory is: $DIR
	cd $DIR
	mkfifo ./fifo
	VALIDATION_RESULT=0
	#eval $CMD
	START_TIMESTAMP=$(date +%s)
	exec_element "$CMD"
	JOB_PID=$!
	get_resources "$JOB_PID" "$QUEUE_ID" "$DATABASE" "$START_TIMESTAMP" &
	MONITOR_PID=$!
	#EXEC_RESULT=$?
	#EXEC_RESULT=$(read ./fifo)
	read EXEC_RESULT < ./fifo
	if [ "$EXEC_RESULT" -ne "0" ]; then
		echo Failed
	fi
	kill $MONITOR_PID

	# do validation
	if [ ! -z $VALIDATION ]; then
		exec_element "$VALIDATION"
		JOB_PID=$!
		get_resources "$JOB_PID" "$QUEUE_ID" "$DATABASE" "$START_TIMESTAMP" &
		MONITOR_PID=$!
		#VALIDATION_RESULT=$(read ./fifo)
		read VALIDATION_RESULT < ./fifo
		kill $MONITOR_PID
	fi
	cd -
	#sqlite3 -init init.sql $DATABASE "UPDATE alien_jobs SET status='D', exec_code=$EXEC_RESULT, val_code=0 WHERE rank=$RANK"
	jalien_sqlite_q $DATABASE "UPDATE alien_jobs SET status='D', exec_code='$EXEC_RESULT', val_code='$VALIDATION_RESULT' WHERE rank=$RANK"
	echo "UPDATE alien_jobs SET status='D', exec_code='$EXEC_RESULT', val_code='$VALIDATION_RESULT' WHERE rank=$RANK"
	echo ===================== Job finished ====================
	#echo Rank $RANK now sleeping for $SLEEP
	sleep 60
done


