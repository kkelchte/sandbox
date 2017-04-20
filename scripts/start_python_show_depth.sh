#!/bin/bash
source ~/tensorflow2/bin/activate
export PYTHONPATH=:/home/klaas/tensorflow2/lib/python2.7:/home/klaas/tensorflow2/lib/python2.7/site-packages:/home/klaas/tensorflow2/examples:/home/klaas/bebop_ws/devel/lib/python2.7/dist-packages:/opt/ros/indigo/lib/python2.7/dist-packages:/home/klaas/sandbox_ws/devel/lib/python2.7/dist-packages
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda-8.0/lib64:/usr/local/cuda/lib64:
cd /home/klaas/sandbox_ws/src/sandbox/python/
echo "python show_depth_prediction.py"
python show_depth_prediction.py
