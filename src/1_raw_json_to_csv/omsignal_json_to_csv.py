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
# Author: Brandon Booth, Abhishek Jangalwa

import os
import sys
import pdb
import csv
import json
import glob
import time
import pytz
import codecs
import datetime
import scipy.linalg
import numpy as np
import pandas as pd
#import matplotlib.pyplot as plt
from io import StringIO

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'util'))
from file_streamer import FileStreamer
from util import GetLocalTimestampFromUnixTime
from util import DropCsvDuplicates
from util import LoadJson

def ExtractDetailedBioMetrics(df, participant_id):
   indices = np.where(df.participant_id == participant_id)[0]

   detailed_bio_participant_data = []
   for idx in indices:
      rr_data = df.packets_data[idx]
      for packets_idx, packets_data in enumerate(rr_data.split('[')):
         packet_data_list = packets_data.split(']')[0].split(',')
         if (len(packet_data_list))>=80:
		     if packets_idx > 2: # Ignore headers
		        timestamp = packet_data_list[1].replace('"', '')
		        timestamp = np.nan if not timestamp else int(timestamp)/1000 # Want seconds, not milliseconds
		        rr0=packet_data_list[9].replace('"', '').strip()
		        rr0 = np.nan if not rr0 else float(rr0)
		        rr1=packet_data_list[11].replace('"', '').strip()
		        rr1 = np.nan if not rr1 else float(rr1)
		        rr2=packet_data_list[13].replace('"', '').strip()
		        rr2 = np.nan if not rr2 else float(rr2)
		        rr3=packet_data_list[15].replace('"', '').strip()
		        rr3 = np.nan if not rr3 else float(rr3)
		        
		        in0_amp=packet_data_list[19].replace('"', '').strip()
		        in0_amp = np.nan if not in0_amp else float(in0_amp)
		        in0_off=packet_data_list[20].replace('"', '').strip()
		        in0_off = np.nan if not in0_off else float(in0_off)
		        
		        ex0_amp=packet_data_list[21].replace('"', '').strip()
		        ex0_amp = np.nan if not ex0_amp else float(ex0_amp)
		        ex0_off=packet_data_list[22].replace('"', '').strip()
		        ex0_off = np.nan if not ex0_off else float(ex0_off)
		        
		        in1_amp=packet_data_list[23].replace('"', '').strip()
		        in1_amp = np.nan if not in1_amp else float(in1_amp)
		        in1_off=packet_data_list[24].replace('"', '').strip()
		        in1_off = np.nan if not in1_off else float(in1_off)
		        
		        ex1_amp=packet_data_list[25].replace('"', '').strip()
		        ex1_amp = np.nan if not ex1_amp else float(ex1_amp)
		        ex1_off=packet_data_list[26].replace('"', '').strip()
		        ex1_off = np.nan if not ex1_off else float(ex1_off)
		       

		        if ~np.any(~np.isnan([rr0, rr1, rr2, rr3,in0_amp, in1_amp, in0_off, in1_off,ex0_amp, ex1_amp, ex0_off, ex1_off])):
		                 continue
		            
		            
		        detailed_bio_dict = {}
		        detailed_bio_dict['RR0'] = rr0
		        detailed_bio_dict['RR1'] = rr1
		        detailed_bio_dict['RR2'] = rr2
		        detailed_bio_dict['RR3'] = rr3
		        
		        detailed_bio_dict['inhale0_amp'] = in0_amp
		        detailed_bio_dict['inhale0_offset'] = in0_off
		        detailed_bio_dict['inhale1_amp'] = in1_amp
		        detailed_bio_dict['inhale1_offset'] = in1_off
		        
		        detailed_bio_dict['exhale0_amp'] = ex0_amp
		        detailed_bio_dict['exhale0_offset'] = ex0_off
		        detailed_bio_dict['exhale1_amp'] = ex1_amp
		        detailed_bio_dict['exhale1_offset'] = ex1_off
		        detailed_bio_dict['timestamp'] = timestamp
		        detailed_bio_participant_data.append(detailed_bio_dict)

   return detailed_bio_participant_data

def ExtractBioMetrics(df, participant_id):
   indices = np.where(df.participant_id == participant_id)[0]

   bio_participant_data = []
   for idx in indices:
      bio_dict = {}
      bio_dict['breathing_depth'] = df.analysis_data[idx]['result']['filteredBiometricsVersusTime']['breathingDepth']
      bio_dict['breathing_rate'] = df.analysis_data[idx]['result']['filteredBiometricsVersusTime']['breathingRate']
      bio_dict['cadence'] = df.analysis_data[idx]['result']['filteredBiometricsVersusTime']['cadence']
      bio_dict['heart_rate'] = df.analysis_data[idx]['result']['filteredBiometricsVersusTime']['heartRate']
      bio_dict['intensity'] = df.analysis_data[idx]['result']['filteredBiometricsVersusTime']['intensity']
      bio_dict['steps'] = df.analysis_data[idx]['result']['filteredBiometricsVersusTime']['steps']
      bio_dict['timestamp'] = df.analysis_data[idx]['result']['filteredBiometricsVersusTime']['unixTimestamp']
      bio_participant_data.append(bio_dict)
   return bio_participant_data

def ExtractHRV(df, participant_id):
   indices = np.where(df.participant_id == participant_id)[0]

   hrv_participant_data = []
   for idx in indices:
      hrv_dict = {}
      hrv_dict['angle_from_vertical_in_radians'] = df.analysis_data[idx]['result']['hrv']['angleFromVerticalInRadians']
      hrv_dict['average_breathing_depth'] = df.analysis_data[idx]['result']['hrv']['averageBreathingDepth']
      hrv_dict['average_breathing_rate'] = df.analysis_data[idx]['result']['hrv']['averageBreathingRate']
      hrv_dict['average_g_force'] = df.analysis_data[idx]['result']['hrv']['averageGForce']
      hrv_dict['average_heart_rate'] = df.analysis_data[idx]['result']['hrv']['averageHeartRate']
      hrv_dict['average_x_accel_in_g'] = df.analysis_data[idx]['result']['hrv']['averageXAccelerationInG']
      hrv_dict['average_y_accel_in_g'] = df.analysis_data[idx]['result']['hrv']['averageYAccelerationInG']
      hrv_dict['average_z_accel_in_g'] = df.analysis_data[idx]['result']['hrv']['averageZAccelerationInG']
      hrv_dict['is_sitting'] = df.analysis_data[idx]['result']['hrv']['isSit']
      hrv_dict['is_supine'] = df.analysis_data[idx]['result']['hrv']['isSupine']
      hrv_dict['low_g_coverage'] = df.analysis_data[idx]['result']['hrv']['lowGCoverage']
      hrv_dict['rms_stddev_in_millisec'] = df.analysis_data[idx]['result']['hrv']['rmssdInMs']
      hrv_dict['rr_peak_coverage'] = df.analysis_data[idx]['result']['hrv']['rrCoverage']
      hrv_dict['sdnn_in_millisec'] = df.analysis_data[idx]['result']['hrv']['sdnnInMs']
      hrv_dict['stddev_breathing_depth'] = df.analysis_data[idx]['result']['hrv']['stdevBreathingDepth']
      hrv_dict['stddev_breathing_rate'] = df.analysis_data[idx]['result']['hrv']['stdevBreatingRate'] #(not a typo)
      hrv_dict['stddev_g_force'] = df.analysis_data[idx]['result']['hrv']['stdevGForce']
      hrv_dict['stddev_x_accel_in_g'] = df.analysis_data[idx]['result']['hrv']['stdevXAccelerationInG']
      hrv_dict['stddev_y_accel_in_g'] = df.analysis_data[idx]['result']['hrv']['stdevYAccelerationInG']
      hrv_dict['stddev_z_accel_in_g'] = df.analysis_data[idx]['result']['hrv']['stdevZAccelerationInG']
      hrv_dict['timestamp'] = df.analysis_data[idx]['result']['hrv']['unixTimestamp']
      hrv_participant_data.append(hrv_dict)
   return hrv_participant_data

def ExtractAverages(df, participant_id):
   indices = np.where(df.participant_id == participant_id)[0]

   averages_participant_data = []
   for idx in indices:
      averages_dict = {}
      averages_dict['percent_hr'] = df.analysis_data[idx]['result']['averages']['percentHR']
      averages_dict['breathing_rate'] = df.analysis_data[idx]['result']['averages']['breathingRate']
      averages_dict['heart_rate'] = df.analysis_data[idx]['result']['averages']['heartRate']
      averages_dict['cadence'] = df.analysis_data[idx]['result']['averages']['cadence']
      averages_participant_data.append(averages_dict)
   return averages_participant_data

def ExtractTotals(df, participant_id):
   indices = np.where(df.participant_id == participant_id)[0]

   totals_participant_data = []
   for idx in indices:
      totals_dict = {}
      totals_dict['breaths'] = df.analysis_data[idx]['result']['totals']['breaths']
      totals_dict['elapsed_time_in_seconds'] = df.analysis_data[idx]['result']['totals']['elapsedTimeInSeconds']
      totals_dict['steps'] = df.analysis_data[idx]['result']['totals']['steps']
      totals_participant_data.append(totals_dict)
   return totals_participant_data

def ExtractMiscData(df, participant_id):
   indices = np.where(df.participant_id == participant_id)[0]

   misc_participant_data = []
   for idx in indices:
      misc_dict = {}
      if idx in df.recording and len(df.recording[idx]) > 0:
         misc_dict['status'] = df.recording[idx]['status']
         misc_dict['box_name'] = df.recording[idx]['box']['boxName']
         misc_dict['box_life_cycle_id'] = df.recording[idx]['box']['boxLifecycleId']
         misc_dict['recording_start'] = df.recording[idx]['period']['start']
         misc_dict['recording_end'] = df.recording[idx]['period']['end']
         misc_dict['time_zone'] = df.recording[idx]['timeZone']
         misc_participant_data.append(misc_dict)
   return misc_participant_data

def ExtractAllData(df):
   data_dict = {}
   for participant_id in np.unique(df.participant_id):
      data_dict[participant_id] = {}
      data_dict[participant_id]['detailed_biometrics'] = ExtractDetailedBioMetrics(df, participant_id)
      data_dict[participant_id]['misc'] = ExtractMiscData(df, participant_id)
      data_dict[participant_id]['biometrics'] = ExtractBioMetrics(df, participant_id)
      data_dict[participant_id]['hrv'] = ExtractHRV(df, participant_id)
      data_dict[participant_id]['totals'] = ExtractTotals(df, participant_id)

      #time_stamps = [time.strptime(data[i]['time'], '%H:%M:%S') for i in range(len(data))]
      #times = np.array([datetime.timedelta(hours=t.tm_hour,minutes=t.tm_min,seconds=t.tm_sec).total_seconds() for t in time_stamps])

   return data_dict

def WriteParticipantCsvs(data_dict, out_folder):
   for participant_id in data_dict.keys():
      file_path =  os.path.join(out_folder, participant_id+'_omsignal.csv')

      header = ['Timestamp']
      bio_header = ['BreathingDepth', 'BreathingRate', 'Cadence', 'HeartRate', 'Intensity', 'Steps']
      hrv_header = ['AngleFromVertical_rad', 'AvgBreathingDepth', 'AvgBreathingRate', 'AvgGForce', 'AvgHeartRate', 'AvgXAccel_g', 'AvgYAccel_g', 'AvgZAccel_g', 'Sitting', 'Supine', 'LowGCoverage', 'RMSStdDev_ms', 'RRPeakCoverage', 'SDNN_ms', 'StdDevBreathingDepth', 'StdDevBreathingRate', 'StdDevGForce', 'StdDevXAccel_g', 'StdDevYAccel_g', 'StdDevZAccel_g']
      detailed_bio_header = ['RR0', 'RR1', 'RR2', 'RR3','inhale0_amp','inhale0_offset','inhale1_amp','inhale1_offset','exhale0_amp','exhale0_offset','exhale1_amp','exhale1_offset']
      header.extend(bio_header)
      header.extend(hrv_header)
      header.extend(detailed_bio_header)

      bio = []
      for bio_data in data_dict[participant_id]['biometrics']:
         bio.append(np.vstack((bio_data['timestamp'], bio_data['breathing_depth'], bio_data['breathing_rate'], bio_data['cadence'], bio_data['heart_rate'], bio_data['intensity'], bio_data['steps'])).T)

      if len(bio) == 0:
         bio = np.zeros((1, 1+len(bio_header)))
      else:
         bio = np.vstack((bio))

      hrv = []
      for hrv_data in data_dict[participant_id]['hrv']:
         hrv.append(np.vstack((hrv_data['timestamp'], hrv_data['angle_from_vertical_in_radians'], hrv_data['average_breathing_depth'], hrv_data['average_breathing_rate'], hrv_data['average_g_force'], hrv_data['average_heart_rate'], hrv_data['average_x_accel_in_g'], hrv_data['average_y_accel_in_g'], hrv_data['average_z_accel_in_g'], hrv_data['is_sitting'], hrv_data['is_supine'], hrv_data['low_g_coverage'], hrv_data['rms_stddev_in_millisec'], hrv_data['rr_peak_coverage'], hrv_data['sdnn_in_millisec'], hrv_data['stddev_breathing_depth'], hrv_data['stddev_breathing_rate'], hrv_data['stddev_g_force'], hrv_data['stddev_x_accel_in_g'], hrv_data['stddev_y_accel_in_g'], hrv_data['stddev_z_accel_in_g'])).T)
      if len(hrv) == 0:
         hrv = np.zeros((1, 1+len(hrv_header)))
      else:
         hrv = np.vstack((hrv))

      detailed_bio = []
      for detailed_bio_data in data_dict[participant_id]['detailed_biometrics']:
         detailed_bio.append(np.vstack((detailed_bio_data['timestamp'], detailed_bio_data['RR0'], detailed_bio_data['RR1'], detailed_bio_data['RR2'], detailed_bio_data['RR3'],detailed_bio_data['inhale0_amp'],detailed_bio_data['inhale0_offset'],detailed_bio_data['inhale1_amp'],detailed_bio_data['inhale1_offset'],detailed_bio_data['exhale0_amp'],detailed_bio_data['exhale0_offset'],detailed_bio_data['exhale1_amp'],detailed_bio_data['exhale1_offset'])).T)
      if len(detailed_bio) == 0:
         detailed_bio = np.zeros((1, 1+len(detailed_bio_header)))
      else:
         detailed_bio = np.vstack((detailed_bio))

      # Prep block matrix concatenation
      concat_mats = [bio, hrv, detailed_bio]
      data_shape = [0, 0]
      for mat in concat_mats:
         data_shape[0] += mat.shape[0]
         data_shape[1] += mat.shape[1]
      data_shape[1] -= len(concat_mats)-1 #Ignore timestamp columns on subsequent mats

      # Block matrix concat with NaN entries for missing data
      data = np.zeros(data_shape)*np.nan
      shape_idx = [0,0]
      for mat in concat_mats:
         if shape_idx[0] == 0:
            data[0:mat.shape[0],0:mat.shape[1]] = mat
            shape_idx[0] += mat.shape[0]
            shape_idx[1] += mat.shape[1]
         else:
            data[shape_idx[0]:shape_idx[0]+mat.shape[0],shape_idx[1]:shape_idx[1]+mat.shape[1]-1] = mat[:,1:] # Ignore leading timestamp column
            data[shape_idx[0]:shape_idx[0]+mat.shape[0],0] = mat[:,0] # Add timestamp data to existing column
            shape_idx[0] += mat.shape[0]
            shape_idx[1] += mat.shape[1]-1

      # Sort rows
      data = data[data[:,0].argsort()]

      # Merge rows with the same timestamp
      last_timestamp = None
      i = 0
      delete_row_indices = []
      while i < data.shape[0]:
         cur_timestamp = data[i,0]
         if last_timestamp != cur_timestamp:
            last_timestamp = cur_timestamp
            i = i+1
         else:
            start_idx = i-1
            row = data[start_idx,:]
            while i < data.shape[0] and data[i,0] == last_timestamp:
               mask = ~np.isnan(data[i,:])
               row[mask] = data[i,mask]
               i = i+1
            data[start_idx,:] = row # Merge
            delete_row_indices.extend(range(start_idx+1,i))
      data = np.delete(data, delete_row_indices, 0)

      # Remove dates near January 1970 (omsignal firmware bug?)
      i = 0
      delete_row_indices = []
      while i < data.shape[0]:
         cur_timestamp = data[i,0]
         if cur_timestamp < 946684800: # 01/01/2000 @ 12:00am UTC+0
            delete_row_indices.append(i)
         i = i+1
      data = np.delete(data, delete_row_indices, 0)
      

      date_str = GetLocalTimestampFromUnixTime(data[:,0])
      tmp_df1 = pd.DataFrame(date_str,columns=[header[0]])
      tmp_df2 = pd.DataFrame(data[:,1:], columns=header[1:])
      final_df = pd.concat([tmp_df1, tmp_df2], axis=1)

      if os.path.exists(file_path):
         with open(file_path, 'a') as csv_file:
            final_df.to_csv(csv_file, index=False, header=False)
      else:
         final_df.to_csv(file_path, index=False)
      #np.savetxt(file_path, data, delimiter=',', header=','.join(header), comments='')
   return

def DoOmsignalJsonToCsv(omsignal_file_path, out_folder):
	# Make sure output folder exists and is empty
   if os.path.exists(out_folder):
      files = glob.glob(os.path.join(out_folder, '*.csv'))
      if len(files) > 0:
         print 'Please make sure the output folder is empty before running this script'
         return False
   else:
      os.makedirs(out_folder)

   if os.path.isdir(omsignal_file_path):
      omsignal_files = glob.glob(os.path.join(omsignal_file_path,'*.jsonl*'))
   else:
      omsignal_files = [omsignal_file_path]


   for omsignal_file_name in omsignal_files:
		# Prepare file streaming
		print("File name is", omsignal_file_name)
		file_streamer = FileStreamer()
		file_streamer.LoadFile(omsignal_file_name)

		num_lines_per_chunk = 1
		print 'Processing lines %d through %d'%(file_streamer.current_line, file_streamer.current_line+num_lines_per_chunk-1)
		file_lines = file_streamer.GetNextLines(num_lines_per_chunk)
		is_finished = len(file_lines) == 0
		while not is_finished:
			df = LoadJson(file_lines)
			data_dict = ExtractAllData(df)
			WriteParticipantCsvs(data_dict, out_folder)
			
			print 'Processing lines %d through %d'%(file_streamer.current_line, file_streamer.current_line+num_lines_per_chunk-1)
			file_lines = file_streamer.GetNextLines(num_lines_per_chunk)
			is_finished = len(file_lines) == 0

   return True


if __name__ == '__main__':
   if len(sys.argv) > 2:
      omsignal_file_path = sys.argv[1]
      out_folder = sys.argv[2]

      success = DoOmsignalJsonToCsv(omsignal_file_path, out_folder)
      if success:
         DropCsvDuplicates(out_folder)
   else:
      print "Please provide the following command line arguments:\n 1) Omsignal json file to parse or folder containing json files\n 2) Output folder path"
