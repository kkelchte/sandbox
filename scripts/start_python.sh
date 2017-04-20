#!/bin/bash
source ~/tensorflow2/bin/activate
export PYTHONPATH=:/home/klaas/tensorflow2/lib/python2.7:/home/klaas/tensorflow2/lib/python2.7/site-packages:/home/klaas/tensorflow2/examples:/home/klaas/bebop_ws/devel/lib/python2.7/dist-packages:/opt/ros/indigo/lib/python2.7/dist-packages:/home/klaas/sandbox_ws/devel/lib/python2.7/dist-packages
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda-8.0/lib64:/usr/local/cuda/lib64:
cd /home/klaas/tensorflow2/examples/pilot_online
echo "python main.py --launch_ros False $@"
#log="/home/klaas/.log_python/$(date +%F_%H%M).log"
# tee print input in file as well as putting it on the output
python main.py --launch_ros False $@  #&> $log &
#while [ 1=1 ] ; do tail $log; sleep 1 ; done

