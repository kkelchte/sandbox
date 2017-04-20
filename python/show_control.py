#!/usr/bin/env python
import rospy
# OpenCV2 for saving an image
from cv_bridge import CvBridge, CvBridgeError
import cv2
from geometry_msgs.msg import Twist
from sensor_msgs.msg import Image
from std_msgs.msg import Empty
import time
import sys, select, tty, os, os.path
import numpy as np
from subprocess import call

# Instantiate CvBridge
bridge = CvBridge()

# Graphical User Interface that shows current view of drone and cmd_vels but does not receive any input

start_time = None
end_time = None
saving_location = ''
current_control = 0
current_trg_control = 0
neural_control=False
font = cv2.FONT_HERSHEY_SIMPLEX
count=0
recording=False
save_images=False
real=False

def print_dur(start_time, end_time):
  duration = (end_time-start_time)
  m, s = divmod(duration, 60)
  h, m = divmod(m, 60)
  return "%02dm:%02ds" % (m, s)

def image_callback(msg):
  global end_time, count
  try:
    # Convert your ROS Image message to OpenCV2
    img = bridge.imgmsg_to_cv2(msg,'bgr8')
  except CvBridgeError, e:
    print(e)
  else:
    # Draw control
    xs=int(img.shape[1]/2)
    ys=int(img.shape[0]/2)
    #print('size: ',xs,ys)
    cv2.line(img, (xs, ys), (int(xs-200*current_control),ys),(240,200,0), 5)
    if current_trg_control != 0:
      cv2.line(img, (xs, ys+10), (int(xs-200*current_trg_control),ys+10),(240,0,200), 5)
    # Draw time
    if neural_control: 
      end_time = rospy.get_time()
    if start_time and end_time:
      cv2.putText(img,print_dur(start_time, end_time),(10,40), font, 1,(240,200,200),2)
         
    if neural_control:
      cv2.putText(img,"Control on",(xs+139,40), font, 1,(0,255,0),2)
    else:
      cv2.putText(img,"Control off",(xs+137,40), font, 1,(0,0,255),2)
    
    cv2.putText(img,"Online",(img.shape[1]-105,img.shape[0]-55), font, 1,(240,200,0),2)
    cv2.putText(img,"Supervised",(img.shape[1]-180,img.shape[0]-15), font, 1,(240,0,200),2)  
    
    if recording:
      cv2.circle(img,(30,40), 20, (0,0,255), -1)
    
    cv2.imshow('Control',img)
    cv2.waitKey(2)
    if recording :
      cv2.imwrite(saving_location+'/'+'{0:010d}.jpg'.format(count),img)
      count+=1
    
def ready_callback(msg):
  global neural_control, start_time
  if not neural_control:
    neural_control=True
    start_time = rospy.get_time()
    
def overtake_callback(data):
  global neural_control
  if neural_control:
    neural_control = False
  
def recon_callback(msg):
  global recording
  if not recording: recording=True
    
def recoff_callback(data):
  global recording
  if recording: recording=False
     
def control_callback(data):
  global current_control
  #if not ready: return
  #else:
  current_control = data.angular.z
  
def trgt_control_callback(data):
  global current_trg_control
  #if not ready: return
  #else:
  current_trg_control = data.angular.z

    

if __name__=="__main__":
  if rospy.has_param('saving_location'):
    loc=rospy.get_param('saving_location')
    if loc[0]=='/':
      saving_location=loc
    else:
      saving_location='/home/klaas/pilot_data/flights/'+loc
  else:
    flight_moment="{0}-{1}-{2}_{3:2d}-{4:2d}".format(*list(time.localtime()))
    saving_location='/home/klaas/pilot_data/flights/'+flight_moment
  if not os.path.isdir(saving_location):
    os.mkdir(saving_location)
    #print(saving_location)
  if rospy.has_param('save_images'):
    save_images=bool(rospy.get_param('save_images')!='False')
  else:
    save_images=False
  if rospy.has_param('real'):
    real=bool(rospy.get_param('real')!='False')
  else:
    real=False
  if rospy.has_param('supervision'):
    supervision=bool(rospy.get_param('supervision')!='false')
  else:
    supervision=False
  #print('--------------------------------real: ',real)
  
  rospy.init_node('show_control', anonymous=True)
  if real:
    rospy.Subscriber('/bebop/ready', Empty, ready_callback)
    rospy.Subscriber('/bebop/image_raw', Image, image_callback)
    rospy.Subscriber('/bebop/overtake', Empty, overtake_callback)  
    rospy.Subscriber('/bebop/cmd_vel', Twist, control_callback)
    if save_images:
      rospy.Subscriber('/bebop/rec_on', Empty, recon_callback) 
      rospy.Subscriber('/bebop/rec_off', Empty, recoff_callback) 
  else:
    rospy.Subscriber('/ready', Empty, ready_callback)
    rospy.Subscriber('/ardrone/image_raw', Image, image_callback)
    rospy.Subscriber('/overtake', Empty, overtake_callback)  
    rospy.Subscriber('/cmd_vel', Twist, control_callback)
    if save_images:
      rospy.Subscriber('/rec_on', Empty, recon_callback) 
      rospy.Subscriber('/rec_off', Empty, recoff_callback)
    if supervision:
      rospy.Subscriber('/supervised_vel', Twist, trgt_control_callback)
      
    
  rospy.spin()
