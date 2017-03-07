LAUNCHFILE="simulation_supervised.launch"
WORLDFILE="bended_corridor.world"
DATA_DIR="/home/klaas/pilot_data"
NUMBER_OF_WORLDS=3
roscore&
sleep 
for i in $(seq 0 $((NUMBER_OF_WORLDS-1)));
do
SLOC="$DATA_DIR/$(date +%F)/$i"
mkdir $SLOC
x=2
y=-3
Y=1.57
COMMAND="roslaunch sandbox $LAUNCHFILE\
	    saving_location:=$SLOC current_world:=$WORLDFILE\
	    log_file:=$SLOC/log x:=$x y:=$y Y:=$Y"
echo $COMMAND
    START=$(date +%s)     
    xterm -hold -e $COMMAND&    
    pidlaunch=$!
    echo $pidlaunch > "/home/klaas/sandbox_ws/src/sandbox/.pid"
    #gzclient &    
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
        exit
      fi
    done
    #killall -9 gzclient
done
killall -9 roscore
killall -9 rosmaster

