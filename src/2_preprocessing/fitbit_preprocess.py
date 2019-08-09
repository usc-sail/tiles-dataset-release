#!/usr/bin/env python
# Copyright (C) 2019 SAIL Lab @ University of Southern California
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Author: Victor Zhang, Brandon Booth

import os
import sys
import pdb
import glob
import shutil
import pandas
import numpy as np

def copyFile(fileName, outputPath):
    shutil.copy(fileName, outputPath)
    
def cleanHR(heartRateFile):
    minRepeatWindowSize = 50

    print(os.path.basename(heartRateFile))
    hrDF = pandas.read_csv(heartRateFile)
    hrColIdx = hrDF.columns.get_loc('HeartRatePPG')
    repeatIndexStart = -1
    repeatValue = None
    for i in range(hrDF.shape[0]):
        if repeatIndexStart < 0:
            repeatIndexStart = i
            repeatValue = hrDF.iloc[i, hrColIdx]
        elif hrDF.iloc[i, hrColIdx] == repeatValue:
            continue
        else:
            if i-repeatIndexStart-1 >= minRepeatWindowSize:
                # Nan-fill the sequence of same heart rate data
                hrDF.iloc[repeatIndexStart:i-1, hrColIdx] = np.nan
            repeatIndexStart = i
            repeatValue = hrDF.iloc[i, hrColIdx]
            
    return hrDF
    
def saveFiles(hr, output):
    hr.to_csv(output, sep = ',', index = False)
    
def DoFitbitPreprocess(in_path, out_path):
   # Ensure the output folder exists
   if not os.path.isdir(out_path):
      os.makedirs(out_path)

   files = glob.glob(os.path.join(in_path, '*.csv*'))
   #change to input folder
   for f in files:
      file_basename = os.path.basename(f)
      out_file_name = os.path.join(out_path, file_basename)
      if out_file_name.endswith(".gz"):
         out_file_name = out_file_name[0:-3]
      if 'heartRate.csv' in file_basename:
          cleanedFile = cleanHR(f)
          saveFiles(cleanedFile, out_file_name)
      else:
          print("Copying file from %s to %s"%(f, out_file_name))
          copyFile(f, out_file_name)

   print("Output path is %s"%(out_path))
   for f in glob.glob(os.path.join(out_path, '*')):
      print(f)

if __name__ == '__main__':
   if len(sys.argv) > 2:
      fitbit_csv_folder = sys.argv[1]
      out_fitbit_csv_folder = sys.argv[2]
      DoFitbitPreprocess(fitbit_csv_folder, out_fitbit_csv_folder)
   else:
      print('Please provide the following command line arguments:\n 1) Path to folder containing fitbit CSV files\n 2) Output folder path for preprocessed fitbit CSVs')
