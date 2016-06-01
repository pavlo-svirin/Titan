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
	du -sb ; ps h -p $ALICE_JOB_PID -o cputime,vsz,rss,pcpu,time,pmem ; cat /proc/cpuinfo | grep "cpu MHz" | tail -n 1 | sed  -r 's/cpu MHz\s*:\s//'
}


exec_element(){
	COMMAND=$1
	if [ -z "$COMMAND" ]; then 
		exit 254
	fi
	eval "(. environment; $COMMAND ; echo \$?>./fifo) &"
}


if [ -z $1 ]; then
	echo No MPI rank specified. Exiting.
	exit 255
fi

RANK=$1
echo My rank is: $RANK

DBLINKFILE=/lustre/atlas/scratch/psvirin/csc108/workdir/database.lnk
DATABASE=

# try 10 times for exising database
for i in `seq 1 10`; do
	echo Doing $i th check for rank $RANK
	echo DBLINKFILE is $DBLINKFILE
	[ ! -f $DBLINKFILE ] && [ $i -eq 10 ] && echo No dblink file found && exit 2
    	[ ! -f $DBLINKFILE ] && (echo No DBLINKFILE, sleeping ;  sleep 60 ; continue)
	DATABASE=`cat $DBLINKFILE | sed s/jdbc:sqlite://`
	echo Database is: $DATABASE
	#[ ! -z $DATABASE ] && break
	[ ! -f $DATABASE ] && [ $i -eq 10 ] && echo No database found && exit 1
	[ ! -f $DATABASE ] && sleep 90
done

echo We are entering main task fetch loop

#RANK=`./get_rank.py`
#RANK=0
for i in {1..20}; do
	#DATA=`sqlite3 -init init.sql $DATABASE "SELECT job_folder,executable FROM tasks_alien WHERE rank=$RANK AND status='Q'"`
	DATA=`sqlite3 -init init.sql $DATABASE "SELECT job_folder,executable, validation, environment FROM alien_jobs WHERE rank=$RANK AND status='Q'"`
	echo Query result for rank $RANK : $?
	echo sqlite3 -init init.sql $DATABASE "SELECT job_folder,executable, validation, environment FROM alien_jobs WHERE rank=$RANK AND status='Q'"
	[ -z $DATA ] &&  sleep 60 && continue
	echo ===================== Starting new job for rank $RANK ===========
	#echo $DATA
	CMD=`echo $DATA | awk -F"|" '{print $2;}'`
	VALIDATION=`echo $DATA | awk -F"|" '{print $3;}'`
	DIR=`echo $DATA | awk -F"|" '{print $1;}'`
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
	exec_element "$CMD"
	JOB_PID=$!
	get_resources "$JOB_PID" &
	MONITOR_PID=$!
	#EXEC_RESULT=$?
	EXEC_RESULT=$(read ./fifo)
	if [ "$EXEC_RESULT" -ne "0" ]; then
		echo Failed
	fi
	kill $MONITOR_PID

	# do validation
	exec_element "$VALIDATION"
	JOB_PID=$!
	get_resources "$JOB_PID" &
	MONITOR_PID=$!
	VALIDATION_RESULT=$(read ./fifo)
	kill $MONITOR_PID
	cd -
	#sqlite3 -init init.sql $DATABASE "UPDATE alien_jobs SET status='D', exec_code=$EXEC_RESULT, val_code=0 WHERE rank=$RANK"
	jalien_sqlite_q $DATABASE "UPDATE alien_jobs SET status='D', exec_code=$EXEC_RESULT, val_code=$VALIDATION_RESULT WHERE rank=$RANK"
	echo ===================== Job finished ====================
	#echo Rank $RANK now sleeping for $SLEEP
	sleep 60
done


