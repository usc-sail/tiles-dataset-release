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
import time
import pytz
import glob
import codecs
import binascii
import datetime
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'util'))
from file_streamer import FileStreamer
from util import LoadJson
from util import GetLocalTimestamp

# User variables - change these
num_lines_per_chunk = 2000
valid_minew_mac_prefix = 'ac:23:3f'.upper()

# Global variables - do not change these
ble_participant_id_map = None
owl_id_list = None
owl_directory_list = None
missing_ble_log_file = 'missing_ble_ids.log'
temp_humid_minew_keys = ['macAddress', 'batteryPercent', 'temperature', 'humidity']
motion_minew_keys = ['macAddress', 'batteryPercent', 'accelerationX', 'accelerationY', 'accelerationZ']
light_minew_keys = ['macAddress', 'batteryPercent', 'visibleLight']

def GetNearestHub(tiraid_data):
    rssis = [elem['rssi'] for elem in tiraid_data['radioDecodings']]
    owl_ids = [elem['identifier']['value'] for elem in tiraid_data['radioDecodings']]

    max_index = rssis.index(max(rssis))
    return (owl_ids[max_index], rssis[max_index])

def CreateMinewCsvsSafe(df, out_folder):
   temp_humid_file_path = os.path.join(out_folder, './temperatureHumidity.csv')
   motion_file_path = os.path.join(out_folder, './motion.csv')
   light_file_path = os.path.join(out_folder, './light.csv')

   header = ['Timestamp']
   if not os.path.exists(temp_humid_file_path):
      with open(temp_humid_file_path, 'wb') as csvfile:
         csv_writer = csv.writer(csvfile, delimiter=',')
         minew_keys = [key if key != 'macAddress' else 'deviceId' for key in temp_humid_minew_keys]
         csv_writer.writerow(header+minew_keys)
   if not os.path.exists(motion_file_path):
      with open(motion_file_path, 'wb') as csvfile:
         csv_writer = csv.writer(csvfile, delimiter=',')
         minew_keys = [key if key != 'macAddress' else 'deviceId' for key in motion_minew_keys]
         csv_writer.writerow(header+minew_keys)
   if not os.path.exists(light_file_path):
      with open(light_file_path, 'wb') as csvfile:
         csv_writer = csv.writer(csvfile, delimiter=',')
         minew_keys = [key if key != 'macAddress' else 'deviceId' for key in light_minew_keys]
         csv_writer.writerow(header+minew_keys)

   return (temp_humid_file_path, motion_file_path, light_file_path)

def AppendMinewCsv(minew_dict, model_name, file_path):
    if model_name == 'S1':
        minew_keys = temp_humid_minew_keys
    elif model_name == 'ACC':
        minew_keys = motion_minew_keys
    elif model_name == 'E6':
        minew_keys = light_minew_keys
    else:
        print("Unknown 'model_name' parameter passed to WriteMinewCsv. FIX ME!")
        return

    # Write the csv
    with open(file_path, 'ab') as csvfile:
        csv_writer = csv.writer(csvfile, delimiter=',')

        for timestamp in sorted(minew_dict.keys()):
            timestamp_entries = minew_dict[timestamp]

            unique_mac = []
            for timestamp_entry in timestamp_entries:
               if not timestamp_entry['macAddress'] in unique_mac:
                   unique_mac.append(timestamp_entry['macAddress'])
                   entries = [timestamp]
                   for minew_key in minew_keys:
                      if minew_key == 'macAddress':
                         entries.append(timestamp_entry[minew_key].replace(':',''))
                      else:
                         entries.append(timestamp_entry[minew_key])
                   csv_writer.writerow(entries)

    return

def ExtractMinew(df, model_name):
    minew_dict = {}
    tiraid = df['tiraid']

    if model_name == 'S1':
        minew_keys = temp_humid_minew_keys
    elif model_name == 'ACC':
        minew_keys = motion_minew_keys
    elif model_name == 'E6':
        minew_keys = light_minew_keys
    else:
        print("Unknown 'model_name' parameter passed to ExtractMinew. FIX ME!")
        return None

    for i in range(len(tiraid)):
        try:
            if 'minew' in tiraid[i]['identifier']['advData']['serviceData'].keys():
                # Make sure we are looking at the right kind of minew sensor
                minew_data = tiraid[i]['identifier']['advData']['serviceData']['minew']
                if not minew_keys[-1] in minew_data.keys():
                    continue

                local_timestamp = GetLocalTimestamp([tiraid[i]['timestamp']])[0]
                if not local_timestamp in minew_dict.keys():
                    minew_dict[local_timestamp] = []
                entry_dict = {}
                nearest_hub = GetNearestHub(tiraid[i])
                entry_dict['nearestHub'] = nearest_hub[0]
                entry_dict['nearestHubRSSI'] = nearest_hub[1]
                for key in minew_keys:
                    entry_dict[key] = minew_data[key]

                # Make sure data is valid
                if not entry_dict['macAddress'].upper().startswith(valid_minew_mac_prefix):
                    continue

                minew_dict[local_timestamp].append(entry_dict)
        except KeyError:
            pass

    return minew_dict 

def DoOwlJsonToCsv(owl_json_path, out_folder):
   # Make sure the output folder exists and is empty
   if os.path.exists(out_folder):
      print 'Please make sure the output folder is empty before running this script'
      return
   else:
      os.makedirs(out_folder)

   # Start with a fresh missing ble log file
   missing_ble_infile = open(missing_ble_log_file, 'wb')
   missing_ble_infile.close()

   # Get a list of all input json files
   owl_file_names = []
   if os.path.isfile(owl_json_path):
      owl_file_names.append(owl_json_path)
   else:
      owl_file_names = sorted(glob.glob(os.path.join(owl_json_path, '*.jsonl*')))

   # Extract minew data
   for owl_file_name in owl_file_names:
      file_streamer = FileStreamer()
      file_streamer.LoadFile(owl_file_name)
      print("Extracting Minew data from %s"%(owl_file_name))
      file_lines = file_streamer.GetNextLines(num_lines_per_chunk)
      is_finished = len(file_lines) == 0
      while not is_finished:
         df = LoadJson(file_lines)

         temp_humid_dict = ExtractMinew(df, 'S1')
         motion_dict = ExtractMinew(df, 'ACC')
         light_dict = ExtractMinew(df, 'E6')
         (temp_humid_file_path, motion_file_path, light_file_path) = CreateMinewCsvsSafe(df, out_folder)
         AppendMinewCsv(temp_humid_dict, 'S1', temp_humid_file_path)
         AppendMinewCsv(motion_dict, 'ACC', motion_file_path)
         AppendMinewCsv(light_dict, 'E6', light_file_path)

         file_lines = file_streamer.GetNextLines(num_lines_per_chunk)
         is_finished = len(file_lines) == 0

   # Convert MAC addresses to device IDs
   return

if __name__ == '__main__':
   if len(sys.argv) > 2:
      owl_json_path = sys.argv[1]
      out_folder = sys.argv[2]

      DoOwlJsonToCsv(owl_json_path, out_folder)
   else:
      print "Please provide the following command line arguments:\n 1) Owl json file to parse, or the path to a folder containing multiple files (that must be time-ordered when sorted by file name)\n 2) Output folder path"
