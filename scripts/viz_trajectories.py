import sys
import os.path
import os
import cv2
import numpy as np

def transp(x,y):
    # Transpose for bended corridor
    #x=50*x+100
    #y=50*-y+350
    # Transpose for esat corridor
    x=10*x+50
    y=10*-y+450
    return x,y


root_dir='/home/klaas/tensorflow2/log'
#run_name='2017-03-08_1641_same_startpos_' #sys.argv[1]
save=False
if len(sys.argv) >= 2:
  run_name=sys.argv[1]
if len(sys.argv) >= 3:
  save=sys.argv[2]
run_dir=root_dir+'/'+run_name
print run_dir

if save and not os.path.isdir(os.path.join(run_dir,'runs')):
  os.mkdir(os.path.join(run_dir,'runs'))
if not os.path.isfile(os.path.join(run_dir,'runs.txt')): 
  print('no runs.txt file found.')
  sys.exit(0)
posfile=open(os.path.join(run_dir,'runs.txt'), 'r')
poslines=posfile.readlines()
posfile.close()

max_runs=int(poslines[-1].split()[0])
#max_runs=100

count=0
img = np.zeros((480,640,3), np.uint8)
img = img+255
font = cv2.FONT_HERSHEY_SIMPLEX

image_name="Run: "+str(max_runs) #run_name
if len(run_name)>26: image_name=image_name[:25]
cv2.putText(img,image_name,(10,40), font, 1,(0,0,0),2)
color=(255,0,0)
xprev=0
yprev=0
cprev=0
show=False
for pos in poslines:
  count=int(pos.split()[0])
  #print('count: ', count)
  if count != cprev:
    #print('run: ',count)
    color=(int(255-count*255./max_runs),0,int(count*255./max_runs))
    xprev=0
    yprev=0
    #if count%10==0:
    #cv2.imshow('runs', img)
    #cv2.waitKey(0)
    #img = np.zeros((480,640,3), np.uint8)
    #import pdb; pdb.set_trace()
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
  if count>max_runs: break  

#count = count+1
if save:
  cv2.imwrite(os.path.join(run_dir, 'runs', '{0:05d}.jpg'.format(max_runs)), img)
#cv2.imshow('image',img)
#cv2.waitKey(0)
cv2.destroyAllWindows()


        
