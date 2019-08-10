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
# Author: Brandon Booth

import os
import pdb
import sys
import csv
import json
import math
import time
import glob
import datetime
import numpy as np
import pandas as pd

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'util'))
from file_streamer import FileStreamer
from util import LoadJson
from util import ReverseCsvRows

# Global variables
realizd_file_path = None
num_lines_per_chunk = 100

def AppendCsvData(df, participant_id, out_folder):
   global realizd_file_path

   if df is not None:
      with open(realizd_file_path, 'ab') as realizd_csvfile:
         csv_writer = csv.writer(realizd_csvfile, delimiter=',')

         timestamp_unixtime = [time.mktime(datetime.datetime.strptime(t, '%Y-%m-%d %H:%M:%S').timetuple()) for t in df['session_start']]
         timestamp_end_unixtime = [time.mktime(datetime.datetime.strptime(t, '%Y-%m-%d %H:%M:%S').timetuple()) for t in df['session_stop']]
         timestamp = [datetime.datetime.fromtimestamp(t).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] for t in timestamp_unixtime]
         timestamp_end = [datetime.datetime.fromtimestamp(t).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] for t in timestamp_end_unixtime]
         duration = np.zeros(len(timestamp_end_unixtime))
         for i in range(len(duration)):
            duration[i] = timestamp_end_unixtime[i]-timestamp_unixtime[i]

         for i in range(len(timestamp)):
            csv_writer.writerow([timestamp[i], duration[i]])
   return

def CreateCsvSafe(df, participant_id, out_folder):
   global realizd_file_path

   realizd_file_path = os.path.join(out_folder, './%s.csv'%(str(participant_id)))
   if not os.path.exists(realizd_file_path):
      realizd_header = ['Timestamp', 'SecondsOnPhone']
      with open(realizd_file_path, 'wb') as realizd_csvfile:
         csv_writer = csv.writer(realizd_csvfile, delimiter=',')
         csv_writer.writerow(realizd_header)
   return

def DoRealizdJsonToCsv(realizd_file_name, out_folder):
   # Make sure output folder exists and is empty
   if os.path.exists(out_folder):
      files = glob.glob(os.path.join(out_folder, '*.csv'))
      if len(files) > 0:
         print 'Please make sure the output folder is empty before running this script'
         return False
   else:
      os.makedirs(out_folder)

   # Prepare file streaming
   file_streamer = FileStreamer()
   file_streamer.LoadFile(realizd_file_name)

   print 'Processing lines %d through %d'%(file_streamer.current_line, file_streamer.current_line+num_lines_per_chunk-1)
   header = file_streamer.GetNextLines(1)[0].split(',')
   file_lines = file_streamer.GetNextLines(num_lines_per_chunk)
   is_finished = len(file_lines) ==  0
   while not is_finished:
      df = pd.read_csv(pd.io.common.StringIO('\n'.join(file_lines)), header=None)
      df.columns = header
      participant_ids = np.unique(df['participant_id'])
      for participant_id in participant_ids:
         participant_df = df[df.participant_id == participant_id]
         CreateCsvSafe(participant_df, participant_id, out_folder)
         AppendCsvData(participant_df, participant_id, out_folder)

      print 'Processing lines %d through %d'%(file_streamer.current_line, file_streamer.current_line+num_lines_per_chunk-1)
      file_lines = file_streamer.GetNextLines(num_lines_per_chunk)
      is_finished = len(file_lines) == 0

   return True

if __name__ == '__main__':
    if len(sys.argv) > 2:
        realizd_file_name = sys.argv[1]
        out_folder = sys.argv[2]

        if DoRealizdJsonToCsv(realizd_file_name, out_folder):
             ReverseCsvRows(out_folder)
             os.system('gzip '+os.path.join(out_folder, '*.csv'))
    else:
        print "Please provide the following command line arguments:\n 1) Realizd json file to parse\n 2) Output folder path"
