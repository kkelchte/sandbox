#!/usr/bin/env python
import rospy
# OpenCV2 for saving an image
from cv_bridge import CvBridge, CvBridgeError
import cv2
from geometry_msgs.msg import Twist
from sensor_msgs.msg import Image
from std_msgs.msg import Empty
from nav_msgs.msg import Odometry
import time
import sys, select, tty, os, os.path
import numpy as np
from subprocess import call

# Check groundtruth for height
# Log position
# Check depth images for bump 
# Check time for success
# write log when finished and shutdown

# Instantiate CvBridge
bridge = CvBridge()

flight_duration = 10 #amount of seconds drone should be flying, in case of no checking: use -1
delay_evaluation = 3
success=False
shuttingdown=False
ready=False
min_allowed_distance=0.5 #0.8
start_time = 0
saving_location = '/home/klaas/pilot_data/tmp'
log_file = saving_location+'/log'
pidfile="/home/klaas/sandbox_ws/src/sandbox/.pid"
finished_pub=None
current_pos=[0,0,0]
starting_height = 1
eva_dis=-1

def shutdown():
  global log_file
  finished_pub.publish(Empty())
  #import pdb; pdb.set_trace() #print("publish finised")
  try: 
    f=open(log_file, 'a')
    if success: 
      f.write('success\n')
    else: 
      f.write('bump\n')
    f.close()
    time.sleep(1)
  except :
    print('FAILED TO WRITE LOGFILE: ')
  #kill process
  if os.path.isfile(pidfile):
    with open(pidfile, 'r') as pf:
      pid=pf.read()[:-1]
    call("kill -9 "+pid, shell=True)
    

def time_check():
  global start_time, shuttingdown, success
  if (int(rospy.get_time()-start_time)) > flight_duration and not shuttingdown:
    print('time > eva_time----------success!')
    success=True
    shuttingdown=True
    shutdown()
    
def image_callback(msg):
  global shuttingdown, success, shuttingdown
  if shuttingdown or not ready or (rospy.get_time()-start_time)<delay_evaluation: return
  if flight_duration != -1: time_check()
  try:
    min_distance = np.nanmin(bridge.imgmsg_to_cv2(msg))
  except CvBridgeError, e:
    print(e)
  else:
    #print('min distance: ', min_distance)
    if min_distance < min_allowed_distance and not shuttingdown:
      print('bump')
      success=False
      shuttingdown=True
      shutdown()

def gt_callback(data):
  global current_pos, ready, success, shuttingdown
  current_pos=[data.pose.pose.position.x,
                  data.pose.pose.position.y,
                  data.pose.pose.position.z]
  if current_pos[2] > starting_height and not ready:
    #print('EVA: ready!')
    ready_pub.publish(Empty())
    ready = True
  #print 'dis: ',(current_pos[0]**2+current_pos[1]**2)
  # if (current_pos[0] > 52 or current_pos[1] > 30) and not shuttingdown:  
  if eva_dis!=-1 and (current_pos[0]**2+current_pos[1]**2) > eva_dis and not shuttingdown:
    print '-----------success!'
    success = True
    shuttingdown = True
    shutdown()


if __name__=="__main__":
  ## create necessary directories
  if rospy.has_param('pidfile'):
    pidfile=rospy.get_param('pidfile')
  if rospy.has_param('delay_evaluation'):
    delay_evaluation=rospy.get_param('delay_evaluation')
  if rospy.has_param('flight_duration'):
    flight_duration=rospy.get_param('flight_duration')
  if rospy.has_param('min_allowed_distance'):
    min_allowed_distance=rospy.get_param('min_allowed_distance')
  if rospy.has_param('starting_height'):
    starting_height=rospy.get_param('starting_height')
  if rospy.has_param('eva_dis'):
    eva_dis=rospy.get_param('eva_dis')
  print '-----------------------------EVALUATION: evadis= ',eva_dis
  if rospy.has_param('saving_location'):
    loc=rospy.get_param('saving_location')
    if loc[0]=='/':
      saving_location=loc
    else:
      saving_location='/home/klaas/pilot_data/'+loc
  if rospy.has_param('log_file'):
    log_file=rospy.get_param('log_file')
  else:
    log_file = saving_location+'/log'
  print 'set logfile: ', log_file
  rospy.init_node('evaluate', anonymous=True)
  
  rospy.Subscriber('/ardrone/kinect/depth/image_raw', Image, image_callback)
  #rospy.Subscriber('/ardrone/imu', Imu, imu_callback)
  #rospy.Subscriber('/ready', Empty, ready_callback)
  finished_pub = rospy.Publisher('/finished', Empty,  queue_size=10)
  ready_pub = rospy.Publisher('/ready', Empty,  queue_size=10)
  rospy.Subscriber('/ground_truth/state', Odometry, gt_callback)
  
  # spin() simply keeps python from exiting until this node is stopped	
  rospy.spin()
