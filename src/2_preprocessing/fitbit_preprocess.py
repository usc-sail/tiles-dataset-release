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
    if os.path.isdir(outputPath):
        shutil.copy(fileName, outputPath)
    else:
        outputFolder = os.path.dirname(outputPath)
        outputFile = os.path.join(outputFolder, os.path.basename(fileName))
        shutil.copy(fileName, outputFolder)
        os.rename(outputFile, outputPath)

    if outputPath.endswith('.gz') and not fileName.endswith('.gz'):
        os.rename(outputPath, outputPath[:-3])
        os.system('gzip '+outputPath[:-3])

    return
    
def cleanHR(heartRateFile):
    minRepeatWindowSize = 50

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
    
def saveFiles(df, output):
   compr = 'infer'
   if output.endswith('.gz'):
      compr = 'gzip'
   df.to_csv(output, sep=',', index=False, compression=compr)
    
def DoFitbitPreprocess(in_path, out_path):
   out_hr_path = os.path.join(out_path, 'heart-rate')
   out_sc_path = os.path.join(out_path, 'step-count')
   out_ds_path = os.path.join(out_path, 'daily-summary')
   # Ensure the output folders exist
   if not os.path.isdir(out_hr_path):
      os.makedirs(out_hr_path)
   if not os.path.isdir(out_sc_path):
      os.makedirs(out_sc_path)
   if not os.path.isdir(out_ds_path):
      os.makedirs(out_ds_path)

   files = glob.glob(os.path.join(in_path, '*.csv*'))
   #change to input folder
   for f in files:
      file_basename = os.path.basename(f)
      participant_id = file_basename.split('_')[0]
      if 'heart' in file_basename:
         out_file_name = os.path.join(out_hr_path, participant_id+'.csv.gz')
         cleaned_file = cleanHR(f)
         saveFiles(cleaned_file, out_file_name)
      elif 'step' in file_basename:
         out_file_name = os.path.join(out_sc_path, participant_id+'.csv.gz')
         copyFile(f, out_file_name)
      elif 'daily' in file_basename:
         out_file_name = os.path.join(out_ds_path, participant_id+'.csv.gz')
         copyFile(f, out_file_name)

if __name__ == '__main__':
   if len(sys.argv) > 2:
      fitbit_csv_folder = sys.argv[1]
      out_fitbit_csv_folder = sys.argv[2]
      DoFitbitPreprocess(fitbit_csv_folder, out_fitbit_csv_folder)
   else:
      print('Please provide the following command line arguments:\n 1) Path to folder containing fitbit CSV files\n 2) Output folder path for preprocessed fitbit CSVs')
