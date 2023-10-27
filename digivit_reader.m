function [] = digivit_reader(dv_ip, host_ip, t_incr, n_samples)
%DIGIVIT_READER Reads the position from a Kaman digiVIT sensor over
%Ethernet.
%
% Reads position sensor data from a Kaman digiVIT sensor module over
% an Ethernet connection via UDP. Call as:
%
%  digivit_reader(dv_ip, host_ip, t_incr, n_samples)
%
% where
%
%  dv_ip: the IP address of the digiVIT sensor (normally 192.168.0.145),
%  host_ip: the IP address of the host machine this script is running
%  on, which should be on the same subnet as the sensor,
%  t_incr: the interval between sensor samples in seconds,
%  n_samples: the total number of sensor samples to take.
%
% Captured position data will be written to an output .CSV file in the 
% same directory as the script. The written file will be named
% 'logged_digiVIT_data_' followed by the date and time of creation.
%
% The .CSV data file will contain four columns:
%
% Column 1: Sample count
% Column 2: Log time (seconds since start of acquisition)
% Column 3: Position value in counts from digiVIT (nom. 0 to 100,000)
% Column 4: Position value in millimetres (calculated from Column 3)

% Revision History
% ----------------
%
% 8th September 2023: V1.0: Initial release
%
% 9th September 2023: V1.1: Used regex to parse digiVIT output string
%
% 5th October 2023: V1.2: Changed to assume all inputs are strings rather
% than string/numeric mixed. Necessary to compiled version of script under
% Windows/DOS.
%
% 11th October 2023: V1.3: Changed the way(s) data is written to the log
% file depending upon the requested sampling interval. Now, in all cases,
% the filename time-stamp corresponds to the time at which the script was
% run, rather than when the file was last written to.
%
% 15th October 2023: V1.4: Added try/catch error handling. Changed UDP read
% timeout to 60 seconds from the variable '0.9 * t_incr'.
%
% 18th October 2023: V1.5: Added 'x of y' count progress reporting; changed
% datetime format in filename. Fixed loss of two decimal places in position
% data.

% Initial setup

clc

% V1.2: START: Added to fix 'strings as numbers' for compiled version w.
% Matlab runtime

t_incr = str2num(t_incr);
n_samples = str2num(n_samples);

% V1.2: END

udp_timeout = 60;   % V1.4
read_error_flag = false;    % V1.4

% Generate a unique filename for the logged data

fname = ['logged_digiVIT_data_' char(datetime('now','TimeZone','local','Format','d-MMM-y_HH_mm_ss')) '.csv'];  % V1.3

% Set flag 'incremental_write' if the sampling interval ('t_incr' in
% seconds) is greater than or equal to '5'. Later, this will be used to
% determine how the logged data is written to file (incrementally as
% gathered, or once at the end of the session).

incremental_write = (t_incr >= 5);          % V1.3
write_msg = {'Incremental';'One-time'};     % V1.3
n = 2;      % V1.3: Default to 'One-time' write mode

if incremental_write
    n = 1;  % V1.3: If incremental_write is TRUE then set message 'Incremental (every sample)'
else
    n = 2;  % V1.3: If incremental_write is FALSE then set message 'One-time (post gather)'
end

% Report initial status to user

fprintf("\n")
fprintf("digiVIT sensor IP address: %s\n",dv_ip)
fprintf("Host IP address: %s\n",host_ip)
fprintf("Position read interval (seconds): %3.2f\n",t_incr)
fprintf("No. of position samples to take: %i\n",n_samples)
fprintf("Logfile write mode: %s\n", string(write_msg(n)))   % V1.3

% Variables

time = 0;

sample_count = 1;

v_range = 4.0;
count_range = 100000;

% First column: Sample count
% First column: Log time (seconds since start)
% Second column: Position value in counts from digiVIT (nom. 0 to 100,000)
% Third column: Position value in millimetres

data_to_write = zeros(1,4);

% Create a udpport object for this session

u = udpport("datagram","IPV4","LocalHost",host_ip,...
    "LocalPort",55555,"EnablePortSharing",true, "Timeout", 60);

% Define the ASCII command sequence we will eventually send to the sensor

seq_char = 'u';     % 'Sequence character'
dv_command = 'MD';  % Command to send to the digiVIT module
pseq = [seq_char dv_command];

% Compute checksum of the digiVIT command sequence

chksumd = bitcmp(bitand(sum(double(pseq)),255),'uint8');
chksumh = dec2hex(chksumd);

% Build the payload to be sent to the digiVIT

command = ['$' pseq '#' chksumh];

% Gather the position data from the digiVIT

regex = '[a-z][\s]+(\-?[0-9]+)#';   % Finds position data in returned string

while (sample_count <= n_samples)

    write(u,command,"uint8",dv_ip,55556);

    % V1.4 START
    try
        % Attempt to read data from the digiVIT

        dvdata = read(u,1,"uint8");
        position_counts = char(dvdata.Data);
        [mat,tok] = regexp(position_counts,regex,'match','tokens');
        position_counts = str2double(tok{1});
    catch
        % Catch this if it fails and carry on.
        % If the read fails, we set the position count value for this read
        % to be NaN and continue.

        read_error_flag = true;
        position_counts = NaN;
    end
    % V1.4 END

    data_to_write(sample_count,1) = sample_count;
    data_to_write(sample_count,2) = time;
    data_to_write(sample_count,3) = position_counts;
    data_to_write(sample_count,4) = position_counts * ...
        (v_range / count_range);

    fprintf("\nSample No. %i of %i; Time: %3.2f second(s); Position: %i counts (%3.5f mm)",...
        data_to_write(sample_count,1),...
        n_samples,...                       % V1.5
        data_to_write(sample_count,2),...
        data_to_write(sample_count,3),...
        data_to_write(sample_count,4));

    % V1.3: New 'incremental' write-to-file block

    if incremental_write == true

        % Open log file for read/appended write

        fID = fopen(fname,'at+','native','UTF-8');

        % Data is comma-separated
        % Item 1: Sample count (integer, starting at 1)
        % Item 2: Time (sample time, starting from zero seconds)
        % Item 3: Position in counts from the digiVIT sensor
        % Item 4: Position in millimetres (converted from counts, Item 3)

        % Write line of data

        fprintf(fID,"%i,%3.2f,%i,%3.5f\n",...
        data_to_write(sample_count,1),...
        data_to_write(sample_count,2),...
        data_to_write(sample_count,3),...
        data_to_write(sample_count,4));

        % Close log file

        fclose(fID);

    end

    % V1.3: End of 'incremental' write-to-file code block

    time = time + t_incr;
    sample_count = sample_count + 1;
    pause(t_incr);

end

if incremental_write == false
    
    % Write the log file
    
    writematrix(data_to_write,fname);
end

% Calculate some useful statistics

ave_counts = mean(data_to_write(:,3));
ave_mm = mean(data_to_write(:,4));

std_counts = std(data_to_write(:,3));
std_mm = std(data_to_write(:,4));

% Display some helpful statistics for the user

fprintf("\n\n Summary\n -------\n")
fprintf(" * Sampling interval: %3.2f second(s)\n", t_incr);
fprintf(" * No. of samples recorded: %i\n", sample_count - 1);
fprintf(" * Mean (average) of position data: %3.0f counts (%3.5f mm)\n",...
    ave_counts, ave_mm)
fprintf(" * Standard deviation of position data: %3.0f counts (%3.5f mm)\n",...
    std_counts, std_mm)

% V1.4 START
if read_error_flag
    fprintf(" * Warning: Logged data suffered one or more acquisition time-out errors, and will contain NaN entries!\n")
else
    fprintf(" * All samples were read successfully.\n")
end
% V1.4 END
fprintf(" * Logged data written to: %s", fname)
fprintf("\n\n")

% Close the UDP session

clear u;

end