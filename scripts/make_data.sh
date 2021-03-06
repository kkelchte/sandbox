LAUNCHFILE="test.launch"
WORLD_DIR="sandboxes_depth"
WORLDFILES="/home/klaas/sandbox_ws/src/sandbox/worlds/$WORLD_DIR"
#DATA_DIR="/media/klaas/d4afcfac-17c9-40cd-876f-fc814f5458c4/home/klaas_14/pilot_data"
DATA_DIR="/home/klaas/pilot_data"
NUMBER_OF_FLIGHTS=10
NUMBER_OF_WORLDS=100
START_I=0
GENERATE_NEW_WORLDS=false
POS_OPTIONS=( "-15.5" "-12.5" "-9.5" "-6.5" "-3.5" "-0.5" "2.5" "5.5" "8.5" "11.5" "14.5" "17.5")
STUCK=false

SET_NAME="$1"
if [ -z "$SET_NAME" ]
then
	echo "Give name of saving location"
	exit
fi
convertsecs() {
	((h=${1}/3600))
	((m=(${1}%3600)/60))
	((s=${1}%60))
	printf "%02d hours %02d min %02d sec\n" $h $m $s
}
start_time=$(date +%s)
for i in $(seq $START_I $((NUMBER_OF_WORLDS-1)));
do
	s_time=$(date +%s)
	echo "world: $i"
	WORLD=$(printf %010d $i)
	world_name=$(printf %s/%s%s $WORLD_DIR $WORLD ".world")
	# generate world:
	if [ $GENERATE_NEW_WORLDS=true ] ;
	then	
		python world_generator.py $world_name >> generator_log
	fi	
	# start gazebo to fly several times in this world
	j=0	
	while [ $j -lt $NUMBER_OF_FLIGHTS ] ;
	do
		s_run=$(date +%s)
		echo "run: $j"
		x=${POS_OPTIONS[$RANDOM % ${#POS_OPTIONS[@]} ]}
		y=${POS_OPTIONS[$RANDOM % ${#POS_OPTIONS[@]} ]}
		Y=$(awk "BEGIN {print 2*3.14*$((RANDOM%=100))/100}")
		LLOC="$DATA_DIR/$SET_NAME/log"
		SLOC="$DATA_DIR/$SET_NAME/${SET_NAME}_${WORLD}_$j"
		COMMAND="roslaunch sandbox $LAUNCHFILE\
	    saving_location:=$SLOC current_world:='$world_name'\
	    log_file:=$LLOC x:=$x y:=$y Y:=$Y"
		
		if [[ -e $DATA_DIR/$SET_NAME/${SET_NAME}_${WORLD}_$j/RGB && \
			$(tail -1 $LLOC) == 'success' && \
			$(ls -l $DATA_DIR/$SET_NAME/${SET_NAME}_${WORLD}_$j/RGB | wc -l) -gt 80 ]] ; then
			j=$((j+1))
			continue
		fi		
		#echo $COMMAND
    START=$(date +%s)     
    xterm -hold -e $COMMAND&
    pidlaunch=$!
    echo $pidlaunch > "/home/klaas/sandbox_ws/src/sandbox/.pid"
    while kill -0 $pidlaunch; 
    do 
      sleep 0.5
      END=$(date +%s)
      DIFF=$(( $END - $START ))
      if [ $DIFF -gt 200 ] ;
      then
				echo "Something went wrong so killed ROS."
				kill $pidlaunch
				if [ -e $SLOC ] ; then
					rm -r $SLOC/*
 				fi
				STUCK=true
      fi
    done
		if [[ $STUCK=false && $(tail -1 $LLOC) == 'success' ]] ; then
			echo 'success!'
			j=$((j+1))
		else
			echo "stuck: $STUCK, log: $(tail -1 $LLOC)"
			STUCK=false		
		fi
			
		sleep 15
		e_run=$(date +%s)
		d_run=$((e_run - s_run))
		echo "last run: $( convertsecs $d_run )."
	done
	
	end_time=$(date +%s)
	dif=$(( end_time - s_time ))
	todo=$(( NUMBER_OF_WORLDS - i ))
	todotime=$(( todo * dif ))
	echo "end_time: $end_time, dif: $dif, todo: $todo, todotime: $todotime"
	echo "duration last world: $( convertsecs $dif ). estimated rest time: $( convertsecs $todotime )"

done
