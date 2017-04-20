#!/bin/bash



# Settings:
LAUNCHFILE="simulation_supervised_corridor.launch"
WORLD_DIR="esat_corridor"
MODELDIR="2017-03-31_1340_esat_noisy" #"2017-03-20_1250_esat"
# if the distance to the starting point (0,0) is larger than this evaluation value, the simulation world is succeeded.
#EVA_DIS=(80 150 3300 3300)
EVA_DIS=(3100)

NUMBER_OF_FLIGHTS=100
RENDER=false
RANDOM=125 #seed the random sequence

# Start python online training/evaluation
TAG="train_off_noisy" #"wd_$WEIGHT_DECAY-bs_$BUFFER_SIZE"
mkdir -p /home/klaas/tensorflow2/log/$TAG
LOGDIR="$TAG/$(date +%F_%H%M)"
# Depth input with fc control:
# Normal network:
# PARAMS="--owr True --epsilon 0.001 --alpha 0.0001 --dropout_keep_prob 0.9 --auxiliary_depth True"
PARAMS="--owr True --epsilon 0.001 --alpha 0.0001 --dropout_keep_prob 0.9"
ARGUMENTS="--log_tag $LOGDIR --model_path $MODELDIR $PARAMS" # --continue_training True --checkpoint_path offline_aux/2017-03-23_1727
COMMANDP="/home/klaas/sandbox_ws/src/sandbox/scripts/start_python.sh $ARGUMENTS"
echo $COMMANDP
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
crash_number=0
for i in $(seq 0 $((NUMBER_OF_FLIGHTS-1))) ;
do
  crashed=false
  # Clear gazebo log folder to overcome the impressive amount of log data
  if [ $((i%50)) = 0 ] ; then rm -r /home/klaas/.gazebo/log/* ; fi

  echo "$(date +%H:%M) -----------------------> Started with run: $i crash_number: $crash_number"
  # check out how many worlds there are for this setting  
  nb_worlds=$(echo ../worlds/$WORLD_DIR/*.world | wc -w)
  NUM=$((i%$nb_worlds))
  world_name=$(printf %s/%010d%s $WORLD_DIR $NUM ".world")
  if [[ $LAUNCHFILE == *"corridor"* ]] ;then
    if [[ $NUM = 0 || $NUM = 2 ]] ; then   
      # x=$(awk "BEGIN {print -1+2*$((RANDOM%=100))/100}")
      # y=$(awk "BEGIN {print $((RANDOM%=100))/100}")   
      # Y=$(awk "BEGIN {print 1.57-0.25+0.5*$((RANDOM%=100))/100}")
      # z=$(awk "BEGIN {print 0.5+1.*$((RANDOM%=100))/100}")
      x=0
      y=0
      z=1
      Y=1.57
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
  LLOC="/home/klaas/tensorflow2/log/$LOGDIR/log"
  COMMANDR="roslaunch sandbox $LAUNCHFILE Yspawned:=$Y x:=$x y:=$y \
           current_world:=$world_name eva_dis:=$dis starting_height:=$z \
            log_file:=$LLOC"
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
    if [ $DIFF -gt 300 ] ;
    then
      if [ $crash_number -ge 3 ] ; then 
        echo "$(date +%H:%M)########################### KILLED ROSCORE" >> "/home/klaas/tensorflow2/log/$LOGDIR/crash"       
        kill_combo
        crash_number=0
        echo "restart python:"
        if [ "$(ls /home/klaas/tensorflow2/log/$LOGDIR | wc -l)" -ge 7 ] ; then
          MODELDIR="$LOGDIR"
          LOGDIR="$TAG/$(date +%F_%H%M)"
          ARGUMENTS="--continue_training True --reloaded_by_ros True --log_tag $LOGDIR --checkpoint_path $MODELDIR $PARAMS"
        else 
          rm -r /home/klaas/tensorflow2/log/$LOGDIR
          ARGUMENTS="--continue_training True --reloaded_by_ros True --log_tag $LOGDIR --checkpoint_path $MODELDIR $PARAMS "
        fi
        COMMANDP="/home/klaas/sandbox_ws/src/sandbox/scripts/start_python.sh $ARGUMENTS"
        echo $COMMANDP      
        xterm -hold -e $COMMANDP &
        pidpython=$!
        echo "xterm started: $pidpython"
        sleep 40
        echo "restart ros:"
        roscore &
        pidros=$!
      else
        echo "$(date +%H:%M)####______________________ KILLED ROSLAUNCH: $crash_number" >> "/home/klaas/tensorflow2/log/$LOGDIR/crash" 
        kill -9 $pidlaunch >/dev/null 2>&1
        sleep 2
        crash_number=$((crash_number+1))
        crashed=true
      fi
    fi
  done
  if [ $DIFF -lt 300 ] ; then
    crash_number=0
  fi
	if [ $RENDER = true ] ;
	then
		echo "kill gzclient"
		killall -9 gzclient
	fi
  if [[ $((i%5)) = 0 && $crashed = false ]] ; then
    python viz_trajectories.py $LOGDIR  True&
  fi  
  #else
  #  python viz_trajectories.py $LOGDIR  False&
  #fi
	sleep 15
done
kill_combo




