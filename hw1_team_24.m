%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% COMS W4733 Computational Aspects of Robotics 2015
%
% Homework 1
%
% Team number: 24
% Team leader: Chia-Jung Lin (cl3295)
% Team members: Cheng Zhang (cz2398), Ming-Ching Chu (mc4107)
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% main function
function hw1_team_24(serPort)
% Input:
% serPort - Serial port object, used for communicating over bluetooth
%
% ReadMe: Because the wall sensor on our iCreate is highly unstable,
% we only depend on bump sensor to trace the obstacle.
% If you wish to run the iCreate Robot, type in:
%    >> serPort = RoombaInit_mac ('ElementSerial-ElementSe');
%    >> hw1_team_24(serPort);

    % constants
    global found_obstacle;
    global start_velocity;
    global loop_pause_time;
    global is_simulation;
    p = properties(serPort);
    if size(p,1) == 0
        is_simulation = true;
        display('running simulation');
    else
        is_simulation = false;
        display('running on iCreate Robot');
    end
    init();
    pause(1);
    
    % Start moving ahead until bumping into obstacle
    while ~found_obstacle
        SetFwdVelAngVelCreate(serPort, start_velocity, 0.0)
        pause(0.01)
        [BumpRight BumpLeft WheDropRight WheDropLeft WheDropCaster ...
        BumpFront] = BumpsWheelDropsSensorsRoomba(serPort);
        if(isnan(BumpRight) || isnan(BumpLeft) || isnan(BumpFront))
            display('bad connection (getting broken signal)');
            display('    we recommand you to abort the program');
        else
            found_obstacle= BumpRight || BumpLeft || BumpFront;
        end
    end
    display('found obstacle!')
    % set start position
    DistanceSensorRoomba(serPort);
    AngleSensorRoomba(serPort);
   
    % Enter main loop
    while true
        display('=================loop===================')       
        %check if the robot is back to start position
        if checkLocation() == true
           display ('back to starting point - Stop!')
           break;
        end
        
        [BumpRight BumpLeft WheDropRight WheDropLeft WheDropCaster ...
        BumpFront] = BumpsWheelDropsSensorsRoomba(serPort);
        display([BumpFront, BumpLeft, BumpRight]);
       
        % always turn left to circle around the obstacle
        if BumpFront||BumpLeft
            while true
                [BumpRight BumpLeft WheDropRight WheDropLeft WheDropCaster ...
                BumpFront] = BumpsWheelDropsSensorsRoomba(serPort);
                bumped = BumpFront||BumpLeft||BumpRight;
                if ~bumped
                    break;
                end
                SetFwdVelAngVelCreate(serPort,0,0.3);
                display('bumped front or left')
                pause(loop_pause_time)
            end 

        elseif BumpRight
            display('Time to moveforward!');
            SetFwdVelRadiusRoomba(serPort, 0.1, inf);

        else
            display('Time to turn right!');
            SetFwdVelRadiusRoomba(serPort, 0.1, -0.1);

        end
        update_status (serPort);
        pause(loop_pause_time)
    end  
    
    % Stop robot motion
    SetFwdVelAngVelCreate(serPort, 0, 0);
end

% initialize constants
function init()
    global found_obstacle;
    global angle_left;
    global angle_right;
    global total_x_dist;
    global total_y_dist;
    global total_angle;
    global total_dist;
    global start_velocity;
    global is_simulation;
    global loop_pause_time;
    
    found_obstacle = false;
    total_dist     = 0;
    total_x_dist   = 0.0;
    total_y_dist   = 0.0;
    total_angle    = 0.0;
    angle_left     = 30;
    angle_right    = -15;
    start_velocity = 0.25;
    
    if is_simulation
        loop_pause_time = 0.1;
    else
        loop_pause_time = 0.01;
    end
        

end

% update current position
function update_status(serPort)

    global total_x_dist;
    global total_y_dist;
    global total_angle;
    global total_dist;

    dist = DistanceSensorRoomba(serPort);
    angle = AngleSensorRoomba(serPort);

    total_dist = total_dist + dist;
    total_angle = total_angle + angle;
    total_x_dist = total_x_dist + dist * cos(total_angle);
    total_y_dist = total_y_dist + dist * sin(total_angle);
end

% check if robot is back to the start point
function isDone = checkLocation()

    global total_x_dist;
    global total_y_dist;
    global total_dist;

    radius = sqrt(total_x_dist^2 + total_y_dist^2);

    display (sprintf ('current radius = %f', radius));
    display (sprintf ('current total_dist = %f', total_dist));

    if (total_dist > 1 && radius < 0.3)
        isDone = true;
    else
        isDone = false;
    end
end
