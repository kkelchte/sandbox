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

# import scipy.misc as sm
# import matplotlib.pyplot as plt
from rospy.numpy_msg import numpy_msg
from rospy_tutorials.msg import Floats

# Instantiate CvBridge
bridge = CvBridge()

# Graphical User Interface that shows current view of drone and cmd_vels but does not receive any input

target_depth = np.zeros((64))
predicted_depth = np.zeros((64))
real=False
ready=False
finished=False
disp_depth_im=False #display depth image instead of array
window_name='Depth Prediction'  
  
def ready_callback(msg):
  global ready, finished
  if not ready:
    print('ready')
    ready = True
    finished = False

def finished_callback(msg):
  global finished, ready
  if not finished:
    print('finished')
    finished = True
    ready = False
    # window is not destroyed...
    cv2.destroyWindow(window_name)

def target_callback(data):
  global target_depth
  if not ready: return
  try:
    # Convert your ROS Image message to OpenCV2
    im = bridge.imgmsg_to_cv2(data, desired_encoding='passthrough')#gets float of 32FC1 depth image
  except CvBridgeError as e:
    print(e)
  else:
    # crop image to get 1 line in the middle
    # row = int(im.shape[0]/2.)
    # step_colums = int(im.shape[1]/64.)
    # arr = im[row, ::step_colums]
    # arr_clean = [e if not np.isnan(e) else 5 for e in arr]
    # arr_clean = np.array(arr_clean)
    # arr_clean = arr_clean*1/5.-0.5
    # # target_depth = arr_clean #(64,)
    im = im[::3,::3]
    shp = im.shape
    im=np.asarray([ e*1.0 if not np.isnan(e) else 0. for e in im.flatten()]).reshape(shp)
    showim = im*1/5.
    # Show float image in range 0 to 1
    cv2.imshow('target depth',showim)
    cv2.waitKey(1)
  
  #show()

def predicted_callback(data):
  global predicted_depth, disp_depth_im
  print('received depth prediction')
  if not ready: return
  predicted_depth = data.data
  if predicted_depth.shape[0] > 64:
    disp_depth_im=True
  img = predicted_depth.reshape(55,74)
  img = img*1/5.
  n=2
  img = np.kron(img, np.ones((n,n)))
  print('max: ',np.amax(img),'min: ', np.amin(img))
  cv2.imshow('predicted depth',img)
  cv2.waitKey(1) 
  #print predicted_depth.shape
  # show()

def show():
  if predicted_depth.sum()==0 or target_depth.sum()==0: return
  if disp_depth_im:
    img = predicted_depth.reshape(55,74)
    n=2
    img = np.kron(img, np.ones((n,n)))
    print('max: ',np.amax(img),'min: ', np.amin(img))
    # img = sm.imresize(img,(300, 400, 3),'nearest')  
  else:
    img = np.zeros((480,640,3), np.uint8)
    img = img+255
    font = cv2.FONT_HERSHEY_SIMPLEX
    cv2.putText(img,'Depth Prediction',(10,40), font, 1,(0,0,0),2)
    bottom = 400
    space = 8
    for x,y in enumerate(target_depth):
      cv2.line(img, (20+space*x, bottom), (20+space*x,int(bottom-400*y)),(255,0,0), 2)
    for x,y in enumerate(predicted_depth):
      cv2.line(img, (24+space*x, bottom), (24+space*x,int(bottom-400*y)),(0,255,0), 4)
    cv2.putText(img,"target_depth",(img.shape[1]/2,40), font, 1,(255,0,0),2)
    cv2.putText(img,"predicted_depth",(img.shape[1]/2,80), font, 1,(0,255,0),2)
  cv2.namedWindow(window_name)#WINDOW_AUTOSIZE
  cv2.imshow(window_name,img)
  cv2.waitKey(2)  


if __name__=="__main__":
  if rospy.has_param('real'):
    real=bool(rospy.get_param('real')!='False')
  else:
    real=False
  rospy.init_node('show_depth', anonymous=True)
  if not real:
    rospy.Subscriber('/ready', Empty, ready_callback)
    rospy.Subscriber('/finished', Empty, finished_callback)
    rospy.Subscriber('/ardrone/kinect/depth/image_raw', Image, target_callback)
    rospy.Subscriber('/depth_prediction', numpy_msg(Floats), predicted_callback, queue_size = 10)
  rospy.spin()
