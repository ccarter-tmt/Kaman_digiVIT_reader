DIGIVIT_READER reads position sensor data from a Kaman digiVIT sensor module over
an Ethernet connection via UDP. Call as:

 digivit_reader(dv_ip, host_ip, t_incr, n_samples)

where

 dv_ip: the IP address of the digiVIT sensor (normally 192.168.0.145),
 host_ip: the IP address of the host machine this script is running
 on, which should be on the same subnet as the sensor,
 t_incr: the interval between sensor samples in seconds,
 n_samples: the total number of sensor samples to take.

Captured position data will be written to an output .CSV file in the 
same directory as the script. The written file will be named
'logged_digiVIT_data_' followed by the date and time of creation.

The .CSV data file will contain four columns:

Column 1: Sample count
Column 2: Log time (seconds since start of acquisition)
Column 3: Position value in counts from digiVIT (nom. 0 to 100,000)
Column 4: Position value in millimetres (calculated from Column 3)
