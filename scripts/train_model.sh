#!/bin/bash

LEARNING_RATE=0.00001 #"$1"
WEIGHT_DECAY=0.0001 #"$2"
echo "$(date +%F_%H:%M) Learning rate: $LEARNING_RATE, Weight decay: $WEIGHT_DECAY"

# Settings:
LAUNCHFILE="simulation_supervised_corridor.launch"
WORLD_DIR="esat_corridor"
MODELDIR="2017-02-14_23-45" #inception #"2017-03-01_1928_test" #
# if the distance to the starting point (0,0) is larger than this evaluation value, the simulation world is succeeded.
#EVA_DIS=(80 150 3300 3300)
EVA_DIS=(3300)

#LAUNCHFILE="simulation_supervised_sandbox.launch"
#WORLD_DIR="sandboxes"
#POS_OPTIONS=( "-6.5" "-3.5" "-0.5" "2.5" "5.5" )
#MODELDIR="2017-03-01_0008_test" #"2017-02-16_0709_ref"

NUMBER_OF_FLIGHTS=150 #1000
RENDER=false
RANDOM=125 #seed the random sequence

# Start python online training/evaluation
LOGDIR=esat_$(date +%F_%H%M)
COMMANDP="/home/klaas/sandbox_ws/src/sandbox/scripts/start_python.sh $LOGDIR $MODELDIR $LEARNING_RATE $WEIGHT_DECAY"
xterm -hold -e $COMMANDP &
pidpython=$!
echo "xterm started: $pidpython"
sleep 40 #wait some seconds for model to load otherwise you miss the start message

# Start ros with launch file
kill_combo(){
  echo "kill ros:"
  kill -9 $pidlaunch >/dev/null 2>&1 
  killall -9 roscore >/dev/null 2>&1 
  killall -9 rosmaster >/dev/null 2>&1
  killall -r /*rosout* >/dev/null 2>&1 
  killall -9 gzclient >/dev/null 2>&1
  kill -9 $pidros >/dev/null 2>&1
  while kill -0 $pidpython;
  do      
    kill $pidpython >/dev/null 2>&1
    sleep 0.05
  done
}
roscore &
pidros=$!
echo $pidros
sleep 3
for i in $(seq 0 $((NUMBER_OF_FLIGHTS-1)));
do
  # Clear gazebo log folder to overcome the impressive amount of log data
  rm -r /home/klaas/.gazebo/log/*

  echo "$(date +%H:%M) -----------------------> Started with run: $i"
  # check out how many worlds there are for this setting  
  nb_worlds=$(echo ../worlds/$WORLD_DIR/*.world | wc -w)
  NUM=$((i%$nb_worlds))
  world_name=$(printf %s/%010d%s $WORLD_DIR $NUM ".world")
  if [[ $LAUNCHFILE == *"corridor"* ]] ;then
    if [[ $NUM = 0 || $NUM = 2 ]] ; then   
      x=$(awk "BEGIN {print -1+2*$((RANDOM%=100))/100}")
      y=$(awk "BEGIN {print $((RANDOM%=100))/100}")   
      Y=$(awk "BEGIN {print 1.57-0.25+0.5*$((RANDOM%=100))/100}")
      z=$(awk "BEGIN {print 0.5+1.2*$((RANDOM%=100))/100}")
    else #corridor 1 is more tricky and does not allow much change
      x=0
      y=0
      Y=1.57
      z=$(awk "BEGIN {print 0.5+1.5*$((RANDOM%=100))/100}")
    fi
  else
    #x=${POS_OPTIONS[$RANDOM % ${#POS_OPTIONS[@]} ]}
	  #y=${POS_OPTIONS[$RANDOM % ${#POS_OPTIONS[@]} ]}		  
    Y=$(awk "BEGIN {print 2*3.14*$((RANDOM%=100))/100}")
    x=0
    y=0
    z=0.5
  fi  
  #printf $Y
  if [ ! -z $EVA_DIS ] ; then 
    dis=${EVA_DIS[NUM]} 
  else
    dis=-1
  fi
  COMMANDR="roslaunch sandbox $LAUNCHFILE Yspawned:=$Y x:=$x y:=$y \
           current_world:=$world_name eva_dis:=$dis starting_height:=$z"
	echo $COMMANDR
  START=$(date +%s)     
  xterm -hold -e $COMMANDR &
  pidlaunch=$!
  echo $pidlaunch > "/home/klaas/sandbox_ws/src/sandbox/.pid/rospid"
	echo "xterm started: $pidlaunch"
	if [ $RENDER = true ] ;
	then 
		echo "start client"
		gzclient &
		pidclient=$!
	fi
  while kill -0 $pidlaunch; 
  do 
    sleep 0.1
    END=$(date +%s)
    DIFF=$(( $END - $START ))
    #echo $DIFF
    if [ $DIFF -gt 360 ] ;
    then
      echo "WARNING ######### Something went wrong so killed ROS."
 			kill_combo
      echo "restart python:"
      if [ "$(ls /home/klaas/tensorflow2/log/$LOGDIR | wc -l)" -ge 7 ] ; then
      MODELDIR=$LOGDIR
      LOGDIR=$(date +%F_%H%M_test)
      else 
      rm -r /home/klaas/tensorflow2/log/$LOGDIR
      fi
      COMMANDP="/home/klaas/sandbox_ws/src/sandbox/scripts/start_python.sh $LOGDIR $MODELDIR"
      xterm -hold -e $COMMANDP &
      pidpython=$!
      echo "xterm started: $pidpython"
      sleep 40
      echo "restart ros:"
      roscore &
      pidros=$!
    fi
  done
	if [ $RENDER = true ] ;
	then
		echo "kill gzclient"
		killall -9 gzclient
	fi
	sleep 5
done
kill_combo




