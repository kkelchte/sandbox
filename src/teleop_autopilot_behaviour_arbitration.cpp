
#include "BehaviourArbitration.h"

// ROS includes
#include <ros/ros.h>
#include <cv_bridge/cv_bridge.h>
#include <image_transport/image_transport.h>
#include <camera_calibration_parsers/parse.h>
#include <geometry_msgs/Twist.h>
#include <geometry_msgs/Quaternion.h>
#include <nav_msgs/Odometry.h>
#include <tf/transform_datatypes.h>
#include <std_msgs/Float32.h>

#include <std_msgs/Empty.h>

using namespace std;

//Check depth and provide target controls on supervised_vel node


bool discretized_twist = false;

int fsm_state = 0; //switch between 3 states [0: wait before take off, 1: takeoff and start positioning, 2: publish ready and start obstacle avoidance]
int FSM_COUNTER_THRESH=100;//wait for some time before taking off
int counter = 0;


float ADJUST_HEIGHT_MAX = 2.0; 
float ADJUST_HEIGHT_MIN = 0.2; // This is for the corridor world
double starting_height = 0.4;
float adjust_height = 0;
float CURRENT_YAW = 0;
double GOAL_ANGLE = 3*CV_PI/2;
float DYAW = 0, DPITCH = 0;

BehaviourArbitration * BAController = 0; // Will be initialized in main
ros::Publisher debugPub;

void updateController(cv::Mat depth_float_img) {
	// Scale whole image using a scalar. The anount is a parameter of the controller
	cv::Mat scaledImage = BAController->scaleDepthImage(depth_float_img);
	// cv::Mat_<float> scaledImage;
	// cv::exp(depth_float_img/255, scaledImage);
	// scaledImage -=1;
	double min, max;
	cv::minMaxLoc(depth_float_img, &min, &max, NULL, NULL);
// 	cout << "Min " << min << "Max " << max << endl;

	cv::minMaxLoc(scaledImage, &min, &max, NULL, NULL);
// 	cout << "Min " << min << "Max " << max << endl;

	float dYawObstacle = BAController->avoidObstacleHorizontal(scaledImage, CURRENT_YAW);
	float dYawGoal 	   = BAController->followGoal(GOAL_ANGLE, CURRENT_YAW);
	DYAW               = BAController->sumBehavioursHorz(dYawObstacle, dYawGoal);
	DPITCH             = BAController->avoidObstacleVertical(scaledImage, CURRENT_YAW);

	// DYAW = 0.5;
	std_msgs::Float32 msg;
	msg.data = CURRENT_YAW;
	debugPub.publish((msg));
// 	cout << "Angular velocity : " << DYAW << endl;
// 	cout << "DPitch: " << DPITCH << endl;
}

//Callback function for the estimated depth
void callbackDepthEstim(const sensor_msgs::ImageConstPtr& original_image) {
	cv_bridge::CvImagePtr cv_ptr;
	//Convert from the ROS image message to a CvImage suitable for working with OpenCV for processing
	try
	{
	  cv_ptr = cv_bridge::toCvCopy(original_image);
	}
	catch (cv_bridge::Exception& e)
	{
  		//if there is an error during conversion, display it
		ROS_ERROR("save_labelled_images_depth::main.cpp::cv_bridge exception: %s", e.what());
		return;
	}

	//Copy the image.data to imageBuf. Depth image is uint16 with depths in mm.
	cv::Mat depth_float_img = cv_ptr->image;

	// double min, max;
	// cv::minMaxLoc(depth_float_img, &min, &max, NULL, NULL);

	// cout << "Min: " << min << "max: " << max << endl;

	updateController(depth_float_img);
}

//general callback function for the depth map
void callbackWithoutCameraInfoWithDepth(const sensor_msgs::ImageConstPtr& original_image){
	cv_bridge::CvImagePtr cv_ptr;
	//Convert from the ROS image message to a CvImage suitable for working with OpenCV for processing
	try
	{
		//Always copy, returning a mutable CvImage
		//OpenCV expects color images to use BGR channel order.
		cv_ptr = cv_bridge::toCvCopy(original_image);
	}
	catch (cv_bridge::Exception& e)
	{
  		//if there is an error during conversion, display it
		ROS_ERROR("save_labelled_images_depth::main.cpp::cv_bridge exception: %s", e.what());
		return;
	}

	//Copy the image.data to imageBuf. Depth image is uint16 with depths in mm.
	cv::Mat depth_float_img = cv_ptr->image;

	for(int row = 0; row < depth_float_img.rows; row++) {
    	for(int col = 0; col < depth_float_img.cols; col++) {
      		if (isnan(depth_float_img.at<float>(row,col))) {
		        // Set to big enough number
		        // cout << "not a number" << endl;
		        depth_float_img.at<float>(row,col) = 5;
      		}
    	}
  	}
	updateController(depth_float_img);
}

double getYaw(geometry_msgs::Quaternion orientation) {
	double yaw = tf::getYaw(orientation);
	return yaw;
}

void callbackGt(const nav_msgs::Odometry& msg)
{
	if (msg.pose.pose.position.z > ADJUST_HEIGHT_MAX){
		adjust_height=-1;
	}else if (msg.pose.pose.position.z < ADJUST_HEIGHT_MIN){ // Was 0.5
		adjust_height=1;
	}else if (fsm_state == 1 && msg.pose.pose.position.z < starting_height){
		adjust_height=1;
	}else{
		adjust_height=0;
	}
	
// 	cout << "adjust_height: " << adjust_height <<"; current height: " << msg.pose.pose.position.z << "starting_height"<< starting_height<< endl;
	CURRENT_YAW = getYaw(msg.pose.pose.orientation) + CV_PI;
// 	cout << "GOAL_ANGLE: " << GOAL_ANGLE << endl;
}

void callbackGoalAngle(const std_msgs::Float32& msg) {
	GOAL_ANGLE = (double) msg.data;
// 	cout << "Adjusting goal" << endl;
}

/*
 * Returns the discretized value "value_cont". disc_factor is the amount of available discrete values between -1 and 1.
 */
float discretize_value(float value_cont, int disc_factor) {
	float b = 2.0/(disc_factor-1);
	float a = -1.0;
		cout << b << endl;

	while (abs(a-value_cont) >= b/2 && a <= 1) {
		// Keep adding b until the closest discrete value is found.
		a += b;
	}
	cout << "Continuous " << value_cont << " Discrete " << a << " Discretizing factor " << disc_factor << endl;
	return a;
}

geometry_msgs::Twist get_twist() {
	//take off after FSM counter greater than the threshold
	geometry_msgs::Twist twist;
	
	switch(fsm_state){
	  case 0: //wait before take off
	    twist.linear.x = 0.0;
	    twist.linear.y = 0.0;
	    twist.linear.z = 0.0;
	    twist.angular.x = 0.0;
	    twist.angular.y = 0.0;
	    twist.angular.z = 0.0;
	    counter=counter+1;
	    if(counter > FSM_COUNTER_THRESH) fsm_state = 1;
	    return twist;
	  case 1: //position drone on certain height set by rosparam
	    twist.linear.x = 0.0;
	    twist.linear.y = 0.0;
	    twist.linear.z = adjust_height;
	    twist.angular.x = 0.0;
	    twist.angular.y = 0.0;
	    twist.angular.z = 0.0;
	    if(adjust_height == 0) fsm_state = 2;
	    return twist;
	  case 2: //Do obstacle avoidance
	    DYAW = std::max(-1.0f, std::min(DYAW, 1.0f));
	    // DPITCH = std::max(-1.0f, std::min(DPITCH, 1.0f));
	    if(!discretized_twist) {
		    // twist.linear.x = 1 - abs(DYAW);
		    twist.linear.x = 0.8;
		    twist.linear.y = 0.0;
		    twist.linear.z = DPITCH + adjust_height;
		    twist.angular.x = 0.0;
		    twist.angular.y = 0.0;
		    twist.angular.z = DYAW;
		    counter=counter+1;
		    return twist;
	    }
	    else {//discretized control
		    twist.linear.x = 0.8;
		    twist.linear.y = 0.0;
		    twist.linear.z = 0.0;
		    twist.angular.x = 0.0;
		    twist.angular.y = 0.0;
		    twist.angular.z = 0.0;
		    // Choose to rotate or to go up or down
		    if (abs(DYAW) > abs(DPITCH)) {	
			    // Discretize rotation values
			    twist.angular.z = discretize_value(DYAW, 21);
		    }
		    else {
			    // Discretize altitude values
			    twist.linear.z = discretize_value(DPITCH, 21);
		    }
		    counter++;
		    // Return twist
		    return twist;
	    }
	    break;
	}
}

int main(int argc, char** argv)
{
	ros::init(argc, argv, "teleop_autopilot", ros::init_options::AnonymousName);
	ros::NodeHandle nh;
	image_transport::ImageTransport it(nh);
	//std::string topic = nh.resolveName("image");
	std::string topic_depth = "/ardrone/kinect/depth/image_raw";
	std::string topic_estim_depth = "/autopilot/depth_estim";

	image_transport::Subscriber sub_image_depth;
	// Use kinect by default
	bool use_depth_estim = false;
	nh.getParam("use_depth_estim", use_depth_estim);
	if (use_depth_estim) {
		cout << "Using depth estimation" << endl;
		sub_image_depth = it.subscribe(topic_estim_depth, 1, callbackDepthEstim);
	}
	else {
		cout << "Using kinect data" << endl;
		sub_image_depth = it.subscribe(
			topic_depth, 1, callbackWithoutCameraInfoWithDepth);
	}
	// Get the goal angle from the launch file
	if(!nh.getParam("goal_angle", GOAL_ANGLE)) {
		cout << "Using default angle: " << GOAL_ANGLE << endl;
	}
	if(!nh.getParam("starting_height", starting_height)){
	  	cout << "Using default starting_height: " << starting_height << endl;
	}
	cout << "starting_height: " << starting_height << endl;

	// Make subscriber to ground_truth in order to get the position.
	//ros::Subscriber subControl = nh.subscribe("/ground_truth/state/pose/pose/position",1,&Callbacks::callbackGt, &callbacks);
	ros::Subscriber subControl = nh.subscribe("/ground_truth/state",1,callbackGt);
	ros::Subscriber subGoalAngle = nh.subscribe("/autopilot/goal_angle",1,callbackGoalAngle);


	// Make subscriber to cmd_vel in order to set the name.
	ros::Publisher pubControl;
	ros::Publisher pubTakeoffControl;
	bool online_control = false;
	//nh.getParam("online_control", online_control);
	
	bool supervision = false;
	cout << "Behaviour Arbitration supervision: "<< supervision << endl;
	nh.getParam("supervision", supervision);
	if (!supervision) {
		pubControl = nh.advertise<geometry_msgs::Twist>("/cmd_vel", 1000);
		cout << "Behaviour Arbitration is controlling the drone" << endl;
	}
	else {
		pubControl = nh.advertise<geometry_msgs::Twist>("/supervised_vel", 1000);
		cout << "Behaviour Arbitration is publishing on /supervised_vel" << endl;
		pubTakeoffControl = nh.advertise<geometry_msgs::Twist>("/cmd_vel", 1000);
	}
	
	// Make Publisher to cmd_vel in order to set the velocity.
	ros::Publisher pubTakeoff = nh.advertise<std_msgs::Empty>("/ardrone/takeoff", 1);
  
	// Make Publisher to ready in order to start saving the images
	//ros::Publisher pubReady = nh.advertise<std_msgs::Empty>("/ready", 1);
  
	
	ros::Rate loop_rate(20);
	//ros::Rate loop_rate(10);

	debugPub = nh.advertise<std_msgs::Float32>("debug_autopilot", 1000);

	geometry_msgs::Twist twist;

	std::string BA_parameters_path;
	if(nh.getParam("BA_parameters_path", BA_parameters_path)) {
		BAController = new BehaviourArbitration(BA_parameters_path);
	}
	else {
		cout << "Using default BA paremeters" << endl;
		BAController = new BehaviourArbitration();
	}
	cout << "Goal angle: " << GOAL_ANGLE << endl;

	nh.getParam("discretized_twist", discretized_twist);
	
	while(ros::ok()){
		if(! online_control) cout << "BA state: " << fsm_state << ", "<< twist<< endl;
		twist = get_twist();

		pubControl.publish(twist);
		//Supervisor let drone take off
		if(fsm_state == 1){
		      std_msgs::Empty msg;
		      pubTakeoff.publish(msg);
          if (supervision){pubTakeoffControl.publish(twist);}
		}
		if(fsm_state == 2){
          //the first time fsm reaches state 2 it should publish supervision one more time.
          if( twist.linear.x == 0 && supervision ){
            pubTakeoffControl.publish(twist);
          }
		      //std_msgs::Empty msg;
		      //pubReady.publish(msg);
		}
		loop_rate.sleep();
		ros::spinOnce();
	}
} 
