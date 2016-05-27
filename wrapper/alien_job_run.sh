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
	eval $CMD
	EXEC_RESULT=$?
	cd -
	#sqlite3 -init init.sql $DATABASE "UPDATE alien_jobs SET status='D', exec_code=$EXEC_RESULT, val_code=0 WHERE rank=$RANK"
	jalien_sqlite_q $DATABASE "UPDATE alien_jobs SET status='D', exec_code=$EXEC_RESULT, val_code=0 WHERE rank=$RANK"
	echo ===================== Job finished ====================
	#echo Rank $RANK now sleeping for $SLEEP
	sleep 60
done

