import sys
import os.path
import os
import cv2
import numpy as np

def transp(x,y):
    x=50*x+100
    y=50*-y+350
    return x,y


root_dir='/home/klaas/tensorflow2/log'
run_name='2017-02-14_12-26' #sys.argv[1]
#run_name='2017-02-14_23-45' #sys.argv[1]
run_dir=root_dir+'/'+run_name
print run_dir


posfile=open(os.path.join(run_dir,'runs.txt'), 'r')

count=0
img = np.zeros((640,480,3), np.uint8)
img = img+255
font = cv2.FONT_HERSHEY_SIMPLEX

image_name=run_name
if len(run_name)>26: image_name=image_name[:25]
cv2.putText(img,image_name,(10,40), font, 1,(0,0,0),2)
max_runs=269
color=(255,0,255)
xprev=0
yprev=0
cprev=0
show=False
for pos in posfile.readlines():
  count=int(pos.split()[0])
  if count!= cprev:
    print('run: ',count)
    color=(int(255-count*255/max_runs),0,int(count*255/max_runs))
    xprev=0
    yprev=0
    if count%50==0:
      cv2.imshow('runs', img)
      cv2.waitKey(0)
      cv2.waitKey(0)
      
      
  if xprev ==0 and yprev ==0:
    xprev = float(pos.split()[1])
    yprev = float(pos.split()[2])
    xprev, yprev = transp(xprev,yprev)
  else:
    x = float(pos.split()[1])
    y = float(pos.split()[2])
    x,y = transp(x,y)
    cv2.line(img, (int(xprev), int(yprev)), (int(x),int(y)),color, 5)
    xprev = x
    yprev = y
  cprev = count
    

#count = count+1
#cv2.imwrite(run_dir+'/runs.jpg', img)
cv2.destroyAllWindows()
posfile.close


        
