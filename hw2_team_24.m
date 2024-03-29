%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% COMS W4733 Computational Aspects of Robotics 2015
%
% Homework 2
%
% Team number: 24
% Team leader: Chia-Jung Lin (cl3295)
% Team members: Cheng Zhang (cz2398), Ming-Ching Chu (mc4107)
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% main function
function hw2_team_24(serPort)
% Input:
% serPort - Serial port object, used for communicating over bluetooth
%
% ReadMe: Please use cable to connect to the robot!!!
% If you wish to run the iCreate Robot, type in:
%    >> serPort = RoombaInit_mac ('usbserial');
%    >> hw1_team_24(serPort);
% The position of robot is indicated by a blue circle. The smaller red circle
% near the blue circle indicated the direction the robot is facing at the 
% moment. The plot updates very frequent so it might be hard to see the red
% circle clearly when running, but you can enlarge the plot to examine it
% afterwards.

    % constants
    global bumped_obstacle;
    global loop_pause_time;
    global bumped_dist_x; % coordinate x when first bumping into obstacle qi
    global bumped_dist_y; % coordinate y when first bumping into obstacle qi
    global total_x_dist;  % current coordinate x
    global total_y_dist;  % current coordinate y
    global reached_goal;
    global no_solution;
    global move_speed;
    global travel_dist_after_bump;
    global status;

    init();
    init_plot();
    pause(1);
    
    % reset distance and angle
    DistanceSensorRoomba(serPort);
    AngleSensorRoomba(serPort);
    
    % Start moving straight forward
    % main loop
    while true
        display('=================loop===================')       

        if reached_goal || checkLocation()
            display('reached goal - stop!');
            break;
        end
        
        if no_solution
            display('no solution found - stop!');
            break;
        end
        
        [BumpRight BumpLeft WheDropRight WheDropLeft WheDropCaster ...
        BumpFront] = BumpsWheelDropsSensorsRoomba(serPort);
        if(isnan(BumpRight) || isnan(BumpLeft) || isnan(BumpFront))
            display('bad connection (getting broken signal)');
            display('    we recommand you to abort the program');
        else
            bumped_obstacle = BumpRight || BumpLeft || BumpFront;
        end
         
        
        if bumped_obstacle
            display('trace broundary')
           
            % back off for a little bit
            travelDist (serPort, 0.025, -0.01);
            update_status (serPort);
            % reset travel dist (help determine 'back to mline')
            travel_dist_after_bump = 0.0;
            
            if(status == 0 || status == 2)
                bumped_dist_x = total_x_dist;
                bumped_dist_y = total_y_dist;
                display(bumped_dist_x);
            end
            
            % follow boundary
            trace_boundary(serPort);
            
        else % did not bump into any obstacle, keep moving forward
            SetFwdVelRadiusRoomba(serPort, move_speed, Inf);
            display ('moving forward');          
        end

        update_status(serPort);
        pause(loop_pause_time);
    end % end of main loop
    
    if (abs(total_y_dist) > 0.15)
        display('reposition!');
        reorient(serPort)
    end

    update_status(serPort);
    
    % Stop robot motion
    SetFwdVelAngVelCreate(serPort, 0, 0);
end

% initialize constants
function init()
    global angle_left;
    global angle_right;
    global angle_front;
    global total_x_dist;
    global total_y_dist;
    global total_angle;
    global total_dist;
    global loop_pause_time;
    global dist_to_goal;
    global reached_goal;
    global no_solution;
    global move_speed;
    global travel_dist_after_bump;
    global status;
    
    dist_to_goal   = 4.0; % distance to the target
    total_dist     = 0;
    total_x_dist   = 0.0;
    total_y_dist   = 0.0;
    total_angle    = 0.0;
    angle_left  = 60;
    angle_right = 15;
    angle_front = 45;
    reached_goal   = false;
    no_solution    = false;
    travel_dist_after_bump = 0.0;
    status = 0;
    
    loop_pause_time = 0.1;
    move_speed      = 0.05;

end

function init_plot()
    
    global fig_plotter;
    
    fig_plotter = figure;
    axis equal;
    xlabel ('Position in X-axis (m)');
    ylabel ('Position in Y-axis (m)');
    title  ('Position of iRobot');
end

function trace_boundary(serPort)
    global no_solution;
    global reached_goal;
    global move_speed;
    global loop_pause_time;
    global angle_right;
    global angle_front;
    global angle_left;
    global travel_dist_after_bump;
    global status;
    
    status = 1;
    
    while true
        update_status(serPort);

        [BumpRight BumpLeft WheDropRight WheDropLeft WheDropCaster ...
        BumpFront] = BumpsWheelDropsSensorsRoomba(serPort);
        bumped= BumpRight || BumpLeft || BumpFront;
        wallSensor = WallSensorReadRoomba (serPort);
%         display(wallSensor);

        if bumped
            if BumpRight
              display('bump right');
              turnAngle (serPort, 0.2, angle_right);
              pause(0.05)
            elseif BumpLeft
              display('bump left');
              turnAngle (serPort, 0.2, angle_left);
              pause(0.05)
            elseif BumpFront
              display('bump front');
              turnAngle (serPort, 0.2, angle_front);
              pause(0.05)
            end

        elseif ~wallSensor %need to turn back to obstacle
%             display ('differntial turn');
            SetFwdVelRadiusRoomba (serPort, move_speed, -0.2);

        else %move forward              
            SetFwdVelRadiusRoomba(serPort, move_speed, Inf);                                       
        end
        update_status (serPort);

        % check break loop conditions
        if is_in_mline() && travel_dist_after_bump > 0.5
            display(travel_dist_after_bump);
            display('back to mline');
            
            if back_to_bumped_point()
                no_solution = true;
                return;
            end
            
            if checkLocation()
                reached_goal = true;
                return;
            end
            
            if is_closer_to_goal()
                travel_dist_after_bump = 0;
                display('is closer to goal - now try to leave obstacle');
                success = try_leave_obstacle(serPort); 
                
                if (success)
                    % keep going
                    status = 2;                  
                    return;
                end
            end
        end
        pause(loop_pause_time);       
    end % end of tracing boundary loop
end

% this is sketchy
function success = try_leave_obstacle(serPort)
    global total_x_dist;
    global dist_to_goal;
    global total_angle;
    global move_speed;
    global loop_pause_time;
    display('try to leave obstable')
    
    success = true;
    
    alpha = 0.6; % the arbitrary parameter we set to compensate the 
                 % 'over-turning' by the physical machine
    if (total_x_dist > dist_to_goal)
        % at the other side, need to turn back, turn to 180 degree
        % -2*pi < total_angle < 2*pi
        while (abs(abs(total_angle)- pi ) * 180 / pi > 2)
            if total_angle < -pi || (total_angle < pi && total_angle > 0)
                turnAngle (serPort, 0.2, abs(pi - abs(total_angle)) * 180 * alpha / pi);
            else
                turnAngle (serPort, 0.2, (-1) * abs(pi - abs(total_angle)) * 180 * alpha / pi);
            end
            update_status (serPort);
            display('turning')            
        end
    else
        while (abs(total_angle) * 180 / pi > 2) % turn to 0 degree
            turnAngle (serPort, 0.2, (-1)* total_angle * 180 * alpha / pi);
            update_status (serPort);
            display('turning')
        end
    end

    % try moving
    bumped_obstacle = false;
    N = 0;
    % try move foward for 10 runs
    while ~bumped_obstacle && N < 10
        % try slightly moving forward
        travelDist (serPort, move_speed, 0.01);

        [BumpRight BumpLeft WheDropRight WheDropLeft WheDropCaster ...
            BumpFront] = BumpsWheelDropsSensorsRoomba(serPort);
        if(isnan(BumpRight) || isnan(BumpLeft) || isnan(BumpFront))
            display('bad connection (getting broken signal)');
            display('    we recommand you to abort the program');
        else
            bumped_obstacle = BumpRight || BumpLeft || BumpFront;
        end
        update_status (serPort);
        N = N + 1;
        pause(loop_pause_time);
    end
        
    if bumped_obstacle
        display('leaving obstacle not succesful - keep tracing boundary');

        % back off for a little bit
        travelDist (serPort, 0.025, -0.01);

        update_status (serPort);
        success = false;
        return;
    else
        display('leaving obstacle successfully');
        update_status(serPort);
    end
    
    
end

function isTrue = back_to_bumped_point()
    global bumped_dist_x;
    global bumped_dist_y;
    global total_x_dist;
    global total_y_dist;
    display(bumped_dist_x);
    display(bumped_dist_y);
    isTrue = false;
    
    dist = sqrt((total_x_dist - bumped_dist_x)^2 + (total_y_dist - bumped_dist_y)^2);
    
    if (dist < 0.2)
        isTrue = true;
    end
    
end

% update current position
function update_status(serPort)

    global total_x_dist;
    global total_y_dist;
    global total_angle;
    global total_dist;
    global travel_dist_after_bump;
    
    dist = DistanceSensorRoomba(serPort);
    angle = AngleSensorRoomba(serPort);
  
    total_dist = total_dist + dist;
    total_angle = total_angle + angle;
    
    % keep total_angle between -2*pi and 2*pi
    if total_angle >= 2*pi
        total_angle = total_angle - 2*pi;
    elseif total_angle < -2*pi
        total_angle = total_angle + 2*pi;
    end
    display(total_angle);
    
    x = dist * cos (total_angle);
    y = dist * sin (total_angle);

    total_x_dist = total_x_dist + x;
    total_y_dist = total_y_dist + y;
    travel_dist_after_bump = travel_dist_after_bump + abs(dist);
    
    % plotting
    global fig_plotter;
    
    xlabel ('Position in X-axis (m)');
    ylabel ('Position in Y-axis (m)');
    title  ('Position of iRobot');
    figure (fig_plotter);
    plot (total_x_dist, total_y_dist, 'o', 'MarkerEdgeColor','b', 'MarkerSize', 9);
    dir_x = 0.001 * cos (total_angle);
    dir_y = 0.001 * sin (total_angle);
    plot (total_x_dist + dir_x, total_y_dist + dir_y, 'o', 'MarkerEdgeColor','r', 'MarkerSize', 4);
    axis equal
    hold on;

end

% check if robot is back to the start point
function isDone = checkLocation()

    global total_x_dist;
    global total_y_dist;
    global dist_to_goal;

    % this function is called only when robot is in m-line
    % so let's not let error in y-direction distract us
    radius = abs(total_x_dist - dist_to_goal); 

    if (radius < 0.15)
        isDone = true;
        display (sprintf ('current y dist = %f', total_y_dist));
        display (sprintf ('current x dist = %f', total_x_dist));
        display (sprintf ('current radius = %f', radius));
    else
        isDone = false;
    end
end

function isCloser = is_closer_to_goal()

    global total_x_dist;
    global bumped_dist_x;
    global dist_to_goal;    

    display (sprintf ('current x dist = %f', total_x_dist));
    display (sprintf ('last bumped x dist = %f', bumped_dist_x));

    if ( abs (dist_to_goal - total_x_dist) < abs (dist_to_goal - bumped_dist_x) )
        isCloser = true;
    else
        isCloser = false;
    end
end

function in_mline = is_in_mline()

    global total_y_dist;

    display (sprintf ('current total_y_dist = %f', total_y_dist));

    if (abs(total_y_dist) < 0.1)
        in_mline = true;
    else
        in_mline = false;
    end
end

% this function is for fine tuning y position 
% now only called after reaching target
function reorient (serPort)
    
    global total_x_dist;
    global total_y_dist;
    global dist_to_goal;
    global total_angle;
    
    global move_speed;
    turn_speed = 0.2;
    
    % re-orient to zero
    delta_x = dist_to_goal - total_x_dist;
    delta_y = total_y_dist;
    
%     checkLocation();
    
    display (sprintf ('re-orienting... x = %f, delta_x = %f', total_x_dist, delta_x));
    SetFwdVelRadiusRoomba(serPort, 0, 0);
    turnAngle (serPort, turn_speed, (-1.0) * total_angle);
    pause(1);
    update_status(serPort);
    
%     checkLocation();
    
    % re-orient to 90
    display (sprintf ('re-positioning... y = %f, delta_y = %f', total_y_dist, delta_y));
    if (total_y_dist > 0)
        angle = -90.0;
    else
        angle = 90.0;
    end
    turnAngle (serPort, turn_speed, angle);
    pause(2);
    
    update_status(serPort);
    
    travelDist (serPort, move_speed/2, delta_y);
    % plot the gap (not plotted in update_status)
    y = linspace(total_y_dist,total_y_dist + delta_y * angle / 90.0, 10);
    x = ones(1, 10) * total_x_dist;
    global fig_plotter;
    
    xlabel ('Position in X-axis (m)');
    ylabel ('Position in Y-axis (m)');
    title  ('Position of iRobot');
    figure (fig_plotter);
    plot (x, y, 'x');
    hold on;
    
    update_status (serPort);
    
    checkLocation();
    
    turnAngle (serPort, turn_speed, -angle);
    update_status (serPort);
    
    display ('end of re-orienting');
    
end
