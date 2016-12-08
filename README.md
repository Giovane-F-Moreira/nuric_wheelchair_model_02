## Smart Wheelchair - Estimator for Caster Wheel Orientation (Project in development)

#### Goal:
* Implement an Unscented Kalman FIlter (UKF) algorithm for accurate estimation of Caster Wheel Orientations (CWOs) and pose of a robotic wheelchair 
* Mentor: Prof. Brenna Argall
* Project is based in the assistive & rehabilitation robotics laboratory (argallab) located within the Rehabilitation Institute of Chicago (RIC)

#### Project Objectives:

* To study existing code structure and implement a wall-following behavior
* To design & simulate a 3D model of new wheelchair in ROS Gazebo and Rviz
* To research and implement a model in order to estimate wheelchair’s CWOs
* To implement an UKF algorithm for accurate estimation of CWOs and the pose of the wheelchair

#### Documentation Overview:

* This documentation explains the code structure and address the following 2 topics -

#####A. 3D model of new wheelchair

* The relevant files are present in 2 main directories, namely  `urdf` and `meshes`

* `urdf` : This directory contains the `xacro` files required to build the 3D model in simulation.
* Main highlights -
	* `joint_states` are published using the `gazebo_ros_control` plugin (particularly, `libgazebo_ros_joint_state_publisher.so` plugin)
	* The differential drive controller uses the `libgazebo_ros_diff_drive.so` plugin
	* The hokuyo laser controller uses `libgazebo_ros_laser.so` plugin to gather laser-scan data
	* The kinect camera controller uses `libgazebo_ros_openni_kinect.so` plugin to generate `rgb` and `depth` data

* `meshes` directory contain the collada `.dae` files of the wheelchair

* Raw SolidWorks files `.SLDPRT & .SLDASM` are available in the `3d_model_sw` directory
	* Blender software is used to convert the `.SLDPRT & .SLDASM` files into collada `.dae` files for URDF compatibility


#####B. UKF implementation for estimation of CWOs

* The UKF algorithm implementation consists of 3 main steps, as outlined below –

	(a) Initialize:
		* Initialize state and controls for the wheelchair (mean and covariance)

	(b) Predict:
		* Generate sigma points using Julier’s Scaled Sigma Point algorithm
		* Pass each sigma points through the dynamic motion model to from a new prior
		* Determine mean and covariance of new prior through unscented transform

	(c) Update:
		* Get odometry data (measurement of pose of wheelchair)
		* Convert the sigma points of prior into expected measurements (points corresponding to pose of wheelchair – x, y  and \theta  are chosen)
		* Compute mean and covariance of converted sigma points through unscented transform
		* Compute residual and Kalman gain
		* Determine new estimate for the state with new covariance


* The UKF code (Python) is produced below (Click on functions to look at its complete implementation): 

	* Frist, we create a function to represent dynamic motion model `f(x)` and the measurement function `h(x)`
	* The dynamic motion model is implemented using 4th-order Runge-Kutta method ([ode2], [rK7])
	* Measurement data for this implementation comes from wheelchair's odometry - hence, the measurement function returns the 3rd, 4th and 5th elements representing x, y and theta (pose of wheelchair)
	

		```
		import numpy as np

		def fx(x, dt):	
			sol = ode2(x)
			return np.array(sol)

		def hx(x):
			return np.array([x[3], x[2], normalize_angle(x[4])])

		```

	* Next, we create sigma points using the [Julier Scaled Sigma Point algorithm]. ([JulierSigmaPoints])


		```
		points = JulierSigmaPoints(n=7, kappa=-4., sqrt_method=None)
		```

	* The `[UKF]` class incorporates the UKF algorithm as follows -
	

		```
		class UKF(object):

		    def __init__(self, dim_x, dim_z, dt, hx, fx, points, sqrt_fn=None, 
		    				x_mean_fn=None, z_mean_fn=None, residual_z=None, residual_z=None):    
		``` 

	* `[predict]` function passes each of the sigma points through `fx` and calculate new set of sigma points
	* The mean (x) and covariance (P) are obtained via unscented transform as shown below -

		```
		    def predict(self, UT=None, fx_args=()):

		        dt = self._dt

		        if not isinstance(fx_args, tuple):
		            fx_args = (fx_args,)

		        if UT is None:
		            UT = unscented_transform

		        sigmas = self.points_fn.sigma_points(self.x, self.P)

		        for i in xrange(self._num_sigmas):
		            self.sigmas_f[i] = self.fx(sigmas[i], dt, *fx_args)
		        
		        self.x, self.P = UT(self.sigmas_f, self.Wm, self.Wc, self.Q, self.x_mean, self.residual_x)
		        # print self.x


	        def unscented_transform(sigmas, Wm, Wc, noise_cov=None, mean_fn=None, residual_fn=None):

			    kmax, n = sigmas.shape

			    x = mean_fn(sigmas, Wm)

			    P = np.zeros((n,n))
			    for k in xrange(kmax):
			        y = residual_fn(sigmas[k], x)
			        P += Wc[k] * np.outer(y, y)

			    if noise_cov is not None:
			        P += noise_cov

			    return (x, P)
	    ```

	    * The `[update]` function first generates sigma points from expected measurement data
	    * The measurement mean (zp) and covariance (Pz) is obtaine via unscented transform of the above generated sigma points
	    * Next, the Kalman gain (K) and residual gain (y) is calculated 
	    * Finally, the new mean (x) and covariance (P) is obtained, given K and y

	    ```
		    def update(self, z, R=None, UT=None, hx_args=()):

		        if z is None:
		            return

		        if not isinstance(hx_args, tuple):
		            hx_args = (hx_args,)

		        if UT is None:
		            UT = unscented_transform

		        R = self.R

		        for i in xrange(self._num_sigmas):
		            self.sigmas_h[i] = self.hx(self.sigmas_f[i], *hx_args)

		        zp, Pz = UT(self.sigmas_h, self.Wm, self.Wc, R, self.z_mean, self.residual_z)

		        Pxz = zeros((self._dim_x, self._dim_z))
		        for i in xrange(self._num_sigmas):
		            dx = self.residual_x(self.sigmas_f[i], self.x)
		            dz = self.residual_z(self.sigmas_h[i], zp)
		            Pxz += self.Wc[i] * outer(dx, dz)


		        self.K = dot(Pxz, inv(Pz))
		        self.y = self.residual_z(z, zp)

		        self.x = self.x + dot(self.K, self.y)
		        self.P = self.P - dot3(self.K, Pz, self.K.T)
		```

	* The above functions from UKF class are imported in the main file `ukf_wheelchair.py` and implemented as follows -

		```
		kf = UKF(dim_x=7, dim_z=3, dt, fx, hx, points, 
					sqrt_fn=None, x_mean_fn=state_mean, z_mean_fn=meas_mean, 
					residual_x, residual_z)

		x0 = np.array(self.ini_val)

		kf.x = x0
		kf.Q *= np.diag([.0001, .0001, .0001, .0001, .0001, .01, .01])
		kf.P *= 0.000001
		kf.R *= 0.0001

		move_time = 4.0
		start = rospy.get_time()

		while (rospy.get_time() - start < move_time) and not rospy.is_shutdown():	
			pub_twist.publish(wheel_cmd)

			z = np.array([odom_x, odom_y, odom_theta])
			zs.append(z)

			kf.predict()
			kf.update(z)

			xs.append(kf.x)
		```




