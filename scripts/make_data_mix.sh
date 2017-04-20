LAUNCHFILE="create_data.launch"
WORLD_DIR="mix" #"sandboxes_big"
WORLDFILES="/home/klaas/sandbox_ws/src/sandbox/worlds/$WORLD_DIR"
EVA_DIS=(60 120 3300 3100 60 60 60 60 3100)
# EVA_DIS=(3100)

#DATA_DIR="/media/klaas/d4afcfac-17c9-40cd-876f-fc814f5458c4/home/klaas_14/pilot_data"
DATA_DIR="/home/klaas/pilot_data"
NUMBER_OF_FLIGHTS=100
i=0

SET_NAME="mix"
if [ -z "$SET_NAME" ]
then
	echo "Give name of saving location"
	exit
fi
rm -r $DATA_DIR/$SET_NAME
mkdir $DATA_DIR/$SET_NAME

# Start ros with launch file
convertsecs() {
	((h=${1}/3600))
	((m=(${1}%3600)/60))
	((s=${1}%60))
	printf "%02d hours %02d min %02d sec\n" $h $m $s
}
start_time=$(date +%s)
while [ $i -lt $NUMBER_OF_FLIGHTS ] ;
do
	# Clear gazebo log folder to overcome the impressive amount of log data
  if [ $((i%50)) = 0 ] ; then rm -r /home/klaas/.gazebo/log/* ; fi
  # check out how many worlds there are for this setting  
  nb_worlds=$(echo ../worlds/$WORLD_DIR/*.world | wc -w)
  NUM=$((i%$nb_worlds))
  world_name=$(printf %s/%010d%s $WORLD_DIR $NUM ".world")
	x=$(awk "BEGIN {print -0.5+$((RANDOM%=100))/100}")
  if [[ $NUM = 1 ]] ; then
    x=0
  fi

  y=$(awk "BEGIN {print $((RANDOM%=100))/100}")   
  Y=$(awk "BEGIN {print 1.57-0.25+0.5*$((RANDOM%=100))/100}")
  if [[ $NUM = 4  || $NUM = 5 || $NUM = 6 || $NUM = 7 ]] ; then
    Y=$(awk "BEGIN {print 3.14*$((RANDOM%=100))/100}")
  fi
  z=$(awk "BEGIN {print 0.5+1.2*$((RANDOM%=100))/100}")
  LLOC="$DATA_DIR/$SET_NAME/log"
	SLOC="$DATA_DIR/$SET_NAME/${SET_NAME}_$(printf %010d $i)"
  if [ ! -z $EVA_DIS ] ; then 
    dis=${EVA_DIS[NUM]} 
  else
    dis=-1
  fi
	COMMAND="roslaunch sandbox $LAUNCHFILE\
    saving_location:=$SLOC current_world:='$world_name'\
    log_file:=$LLOC x:=$x y:=$y Yspawned:=$Y eva_dis:=$dis starting_height:=$z"
		
	if [[ -e $DATA_DIR/$SET_NAME/${SET_NAME}_$(printf %010d $i)/RGB && \
		$(tail -1 $LLOC) == 'success' ]] ; then
		i=$((i+1))
		continue
	fi		
	echo "$(date +%H:%M) -----------------------> Started with run: $i"
  echo $COMMAND
  START=$(date +%s)     
  xterm -hold -e $COMMAND&
  pidlaunch=$!
  echo $pidlaunch > "/home/klaas/sandbox_ws/src/sandbox/.pid/rospid"
  while kill -0 $pidlaunch; 
  do 
    sleep 0.5
    END=$(date +%s)
    DIFF=$(( $END - $START ))
    if [ $DIFF -gt 360 ] ;
    then
			echo "Something went wrong so killed ROS."
			kill $pidlaunch
			if [ -e $SLOC ] ; then
				rm -r $SLOC/*
			fi
    fi
  done
		
	sleep 15
	END=$(date +%s)
	DIFF=$((END - START))
  TODO=$(( NUMBER_OF_FLIGHTS - i ))
	TODOTIME=$(( TODO * DIFF ))
	echo "Run $((i)) duration: $( convertsecs $DIFF ). estimated rest time: $( convertsecs $TODOTIME )"
done

