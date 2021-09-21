#!/bin/bash
rosparam get use_sim_time

rosparam set use_sim_time false

roslaunch rosbridge_server rosbridge_websocket.launch
