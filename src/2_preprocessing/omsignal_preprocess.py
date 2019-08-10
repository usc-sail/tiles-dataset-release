#!/usr/bin/env python3
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
# Authors: Victor Zhang, Abhishek Jangalwa, Brandon Booth

import os
import sys
import glob
import numpy as np
import pandas as pd
from shutil import copyfile
import time

def cleanOmsignal(fileName, in_path):
   t1 = time.time()
   #print("\n Running from " + str(t1), end = " ")
   os.chdir(in_path)
   dataFrame = pd.read_csv(fileName, sep = ',')

   dataFrame.loc[dataFrame['HeartRate'] < 30 , 'HeartRate'] = None
   dataFrame.loc[dataFrame['HeartRate'] > 240, 'HeartRate'] = None
   dataFrame.loc[dataFrame['BreathingRate'] == 0, 'BreathingRate'] = None
   dataFrame.loc[dataFrame['BreathingDepth'] == 0, 'BreathingDepth'] = None

   t2 = time.time()
   #print(" to " + str(t2))
   #print(" Time taken: ", str(t2-t1))
 
   return dataFrame

def saveFile(df, output):
   compr = 'infer'
   if output.endswith('.gz'):
      compr = 'gzip'
   df.to_csv(output, sep=',', index=False, compression=compr)
   return
    
def DoOmsignalPreprocess(in_path, out_path):
   if not os.path.isdir(out_path):
      os.makedirs(out_path)

   files = glob.glob(os.path.join(in_path, '*.csv*'))
   for f in files:
      file_basename = os.path.basename(f)
      participant_id = file_basename.split('_')[0]
      cleanedFile = cleanOmsignal(file_basename, in_path)

      out_file_name = os.path.join(out_path, participant_id+'.csv.gz')
      saveFile(cleanedFile, out_file_name)
   return

if __name__ == '__main__':
   if len(sys.argv) > 2:
      omsignal_csv_folder = sys.argv[1]
      out_omsignal_csv_folder = sys.argv[2]
      DoOmsignalPreprocess(omsignal_csv_folder, out_omsignal_csv_folder)
   else:
      print('Please provide the following command line arguments:\n 1) Path to folder containing omsignal CSV files\n 2) Output folder path for preprocessed omsignal CSVs')
