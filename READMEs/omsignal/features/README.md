# OMsignal features
This file describes the OMsignal `features` files.

## Description
Each one of the files contains the features obtained from the OMsignal garmentsfor each participant. This is organized in a table with the following columns:

 - `AvgBreathingRate` and `StdDevBreathingRate`: The average and standard deviation of breathing rate in breaths per minute.

 - `AvgBreathingDepth` and `StdDevBreathingDepth`: The average and standard deviation of breathing depths in normalized units.

 - `SDNN_ms`: Standard deviation of all Normal to Normal heart beat (NN) intervals in milliseconds.

 - `RMSStdDev_ms`: The square root of the mean of the sum of the squares of adjacent NN intervals in milliseconds.

 - `RRPeakCoverage`: The square root of the mean of the sum of the squares of adjacent NN intervals in milliseconds.

 - `LowGCoverage`: Ratio of the time spent in low acceleration mode (acceleration < 1g, where g is approximately 9.81 m/s^2) over the recording interval (5min). `LowGCoverage	` measures how long the person was still during the recording interval.

 - `Sitting`: This flag indicates when the person is still and upright for 5min.

 - `Supine`: This flag indicates when the person is lying flat and horizontal for 5min.

 - `AvgXAccel_g` and `StdDevXAccel_g`: the average and standard deviation of the acceleration in the X axis in g.

 - `AvgYAccel_g` and `StdDevYAccel_g`: the average and standard deviation of the acceleration in the Y axis in g.

 - `AvgZAccel_g` and `StdDevZAccel_g`: the average and standard deviation of the acceleration in the Z axis in g.

 - `AvgGForce` and `StdDevGForce`: The mean absolute peak acceleration and standard deviation of the acceleration measured at the trunk in g.

 - `AngleFromVertical_rad`: The mean absolute angular deviation from vertical in radians.
