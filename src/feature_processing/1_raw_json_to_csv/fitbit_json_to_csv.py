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
import sys
import pdb
import csv
import json
import glob
import time
import codecs
import datetime
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'util'))
from file_streamer import FileStreamer
from util import DropCsvDuplicates
from util import LoadJson

# User Variables - change these
do_plot = False
num_lines_per_chunk = 2000
max_num_of_sleep_per_day = 3

# Global variables - do not change these
steps_file_path = None
hr_file_path = None
summary_file_path = None

def SortByTimestamp(folder):
   # Only the daily summary files need sorting
   files = glob.glob(os.path.join(folder, '*_dailySummary.csv'))
   for f in files:
       df = pd.read_csv(f) 
       df = df.sort_values(by=['Timestamp'])
       df.to_csv(f, index=False, header=True)

def ExtractSteps(df, participant_id):
    step_dict = {}
    ids = df['participant_id'] == str(participant_id)
    ids = [i for i in range(len(ids)) if np.array(ids)[i] == True]
    for id in ids:
        date = df['dt'][id].encode('ascii')
        step_data = df['steps'][id]
        data = step_data['activities-steps-intraday']['dataset']
        unix_times = [time.mktime(datetime.datetime.strptime(date+' '+data[i]['time'], '%Y-%m-%d %H:%M:%S').timetuple()) for i in range(len(data))]
        time_stamps = [datetime.datetime.fromtimestamp(t).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] for t in unix_times]
        steps = np.array([data[i]['value'] for i in range(len(data))])

        if do_plot:
            plt.plot(time_stamps/3600, steps)
            plt.xlabel('Unix Time (hours)')
            plt.ylabel('Step Count')
            plt.title('%s, Participant ID: %s'%(date, str(participant_id)))
            plt.show()

        for i in range(len(time_stamps)):
            step_dict[time_stamps[i]] = [steps[i]]
        
    return step_dict

def ExtractHeartRate(df, participant_id):
    hr_dict = {}
    ids = df['participant_id'] == str(participant_id)
    ids = [i for i in range(len(ids)) if np.array(ids)[i] == True]
    for id in ids:
        date = df['dt'][id]
        hr_data = df['heart_rate'][id]
        data = hr_data['activities-heart-intraday']['dataset']
        unix_times = [time.mktime(datetime.datetime.strptime(date+' '+data[i]['time'], '%Y-%m-%d %H:%M:%S').timetuple()) for i in range(len(data))]
        time_stamps = [datetime.datetime.fromtimestamp(t).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] for t in unix_times]
        hrs = np.array([data[i]['value'] for i in range(len(data))])

        if do_plot:
            plt.plot(time_stamps/3600, hrs)
            plt.xlabel('Time (hours)')
            plt.ylabel('Heart Rate')
            plt.title('%s, Participant ID: %s'%(date, str(participant_id)))
            plt.show()

        for i in range(len(time_stamps)):
            hr_dict[time_stamps[i]] = [hrs[i]]
        
    return hr_dict


def ExtractDailySummary(df, participant_id):
    summary_dict = {}
    ids = df['participant_id'] == str(participant_id)
    ids = [i for i in range(len(ids)) if np.array(ids)[i] == True]
    for id in ids:
        # Date
        date = df['dt'][id]
        
        # Heart rate summary
        try:
            resting_hr = df['heart_rate'][id]['activities-heart'][0]['value']['restingHeartRate']
        except KeyError:
            resting_hr = np.nan
        
        hr_zones_to_extract = ['Out of Range', 'Fat Burn', 'Cardio', 'Peak']
        hr_zone_values_to_extract = ['min', 'max', 'minutes', 'caloriesOut']
        hr_zones = {}
        for hr_zone_to_extract in hr_zones_to_extract:
            hr_zones[hr_zone_to_extract] = {}
            for hr_zone_value_to_extract in hr_zone_values_to_extract:
                hr_zones[hr_zone_to_extract][hr_zone_value_to_extract] = np.nan
        try:
            hr_zone_names = [s['name'] for s in df['heart_rate'][id]['activities-heart'][0]['value']['heartRateZones']]
            for hr_zone_to_extract in hr_zones_to_extract:
                if hr_zone_to_extract in hr_zone_names:
                    idx = hr_zone_names.index(hr_zone_to_extract)
                    for hr_zone_value_to_extract in hr_zone_values_to_extract:
                        value = df['heart_rate'][id]['activities-heart'][0]['value']['heartRateZones'][idx][
                            hr_zone_value_to_extract]
                        hr_zones[hr_zone_to_extract][hr_zone_value_to_extract] = value
        except KeyError:
            pass
        
        # Sleep and step summary
        try:
            number_of_sleep = len(df['sleep'][id]['sleep'])
        except KeyError:
            number_of_sleep = 0
        
        # Initialize Sleep data, assume there are maximum of 3 sleep per day
        sleep_data = {}
        for i in range(max_num_of_sleep_per_day):
            sleep_data['light' + '_' + str(i + 1)] = np.nan
            sleep_data['wake' + '_' + str(i + 1)] = np.nan
            sleep_data['deep' + '_' + str(i + 1)] = np.nan
            sleep_data['rem' + '_' + str(i + 1)] = np.nan
            sleep_data['startTime' + '_' + str(i + 1)] = np.nan
            sleep_data['endTime' + '_' + str(i + 1)] = np.nan
            sleep_data['minutesAwake' + '_' + str(i + 1)] = np.nan
            sleep_data['efficiency' + '_' + str(i + 1)] = np.nan
        
        # Order the sleep indices so the first one is the main sleep
        # and all other sleeps (naps) are in the same order
        sleep_indices = []
        for i in range(number_of_sleep):
            is_main_sleep = False
            if 'isMainSleep' in df['sleep'][id]['sleep'][i]:
                is_main_sleep = df['sleep'][id]['sleep'][i]['isMainSleep']
            if is_main_sleep:
                sleep_indices.insert(0, i)
            else:
                sleep_indices.append(i)

        if len(sleep_indices) > 0 and sleep_indices[0] != 0:
            print("Main sleep reordered for "+participant_id+" on "+date)

        # Read sleep data
        sleep_order_idx = 1
        for sleep_data_idx in sleep_indices:
            try:
                sleep_data['light' + '_' + str(sleep_order_idx)] = df['sleep'][id]['sleep'][sleep_data_idx]['levels']['summary']['light'][
                    'minutes']
                sleep_data['wake' + '_' + str(sleep_order_idx)] = df['sleep'][id]['sleep'][sleep_data_idx]['levels']['summary']['wake'][
                    'minutes']
                sleep_data['deep' + '_' + str(sleep_order_idx)] = df['sleep'][id]['sleep'][sleep_data_idx]['levels']['summary']['deep'][
                    'minutes']
                sleep_data['rem' + '_' + str(sleep_order_idx)] = df['sleep'][id]['sleep'][sleep_data_idx]['levels']['summary']['rem'][
                    'minutes']
            except (KeyError, IndexError):
                sleep_data['light' + '_' + str(sleep_order_idx)] = np.nan
                sleep_data['wake' + '_' + str(sleep_order_idx)] = np.nan
                sleep_data['deep' + '_' + str(sleep_order_idx)] = np.nan
                sleep_data['rem' + '_' + str(sleep_order_idx)] = np.nan
            
            try:
                sleep_data['minutesAwake' + '_' + str(sleep_order_idx)] = df['sleep'][id]['sleep'][sleep_data_idx]['minutesAwake']
                sleep_data['efficiency' + '_' + str(sleep_order_idx)] = df['sleep'][id]['sleep'][sleep_data_idx]['efficiency']
                
                sleep_start_time = df['sleep'][id]['sleep'][sleep_data_idx]['startTime']
                sleep_end_time = df['sleep'][id]['sleep'][sleep_data_idx]['endTime']
                if not (isinstance(sleep_start_time, float) and np.isnan(sleep_start_time)):
                    # Convert sleep time stamps to seconds since midnight on current date.
                    # Note: If the end time is the next day, the seconds since midnight will be greater than
                    #       24 hours
                    date_midnight_time = time.strptime(date, '%Y-%m-%d')
                    sleep_start_time = time.strptime(sleep_start_time, '%Y-%m-%dT%H:%M:%S.%f')
                    sleep_end_time = time.strptime(sleep_end_time, '%Y-%m-%dT%H:%M:%S.%f')
                    sleep_start_time_stamp = datetime.datetime.fromtimestamp(time.mktime(sleep_start_time)).strftime(
                        '%Y-%m-%dT%H:%M:%S.%f')[:-3]
                    sleep_end_time_stamp = datetime.datetime.fromtimestamp(time.mktime(sleep_end_time)).strftime(
                        '%Y-%m-%dT%H:%M:%S.%f')[:-3]
                else:
                    sleep_start_time_stamp = np.nan
                    sleep_end_time_stamp = np.nan
                sleep_data['startTime' + '_' + str(sleep_order_idx)] = sleep_start_time_stamp
                sleep_data['endTime' + '_' + str(sleep_order_idx)] = sleep_end_time_stamp
            
            except (KeyError, IndexError):
                sleep_data['startTime' + '_' + str(sleep_order_idx)] = np.nan
                sleep_data['endTime' + '_' + str(sleep_order_idx)] = np.nan
                sleep_data['minutesAwake' + '_' + str(sleep_order_idx)] = np.nan
                sleep_data['efficiency' + '_' + str(sleep_order_idx)] = np.nan
            sleep_order_idx += 1
        
        try:
            time_in_bed_mins = df['sleep'][id]['summary']['totalTimeInBed']
            time_asleep_total = df['sleep'][id]['summary']['totalMinutesAsleep']
        except (KeyError, IndexError):
            time_in_bed_mins = np.nan
            time_asleep_total = np.nan
        
        try:
            num_steps = int(df['steps'][id]['activities-steps'][0]['value'])
        except (KeyError, IndexError):
            num_steps = np.nan
        
        summary_dict[date] = {}
        summary_dict[date]['RestingHeartRate'] = resting_hr
        summary_dict[date]['NumberSteps'] = num_steps
        
        summary_dict[date]['SleepMinutesInBed'] = time_in_bed_mins
        summary_dict[date]['SleepMinutesAsleep'] = time_asleep_total
        
        summary_dict[date]['SleepPerDay'] = number_of_sleep
        
        # Note: Now the sleep data in sleep_data is ordered so main
        # sleep is the first item
        for i in range(max_num_of_sleep_per_day):
            summary_dict[date]['Sleep' + str(i + 1) + 'MinutesStageLight'] = sleep_data['light' + '_' + str(i + 1)]
            summary_dict[date]['Sleep' + str(i + 1) + 'MinutesStageWake'] = sleep_data['wake' + '_' + str(i + 1)]
            summary_dict[date]['Sleep' + str(i + 1) + 'MinutesStageDeep'] = sleep_data['deep' + '_' + str(i + 1)]
            summary_dict[date]['Sleep' + str(i + 1) + 'MinutesStageRem'] = sleep_data['rem' + '_' + str(i + 1)]
            summary_dict[date]['Sleep' + str(i + 1) + 'MinutesAwake'] = sleep_data['minutesAwake' + '_' + str(i + 1)]
            summary_dict[date]['Sleep' + str(i + 1) + 'Efficiency'] = sleep_data['efficiency' + '_' + str(i + 1)]
            summary_dict[date]['Sleep' + str(i + 1) + 'BeginTimestamp'] = sleep_data['startTime' + '_' + str(i + 1)]
            summary_dict[date]['Sleep' + str(i + 1) + 'EndTimestamp'] = sleep_data['endTime' + '_' + str(i + 1)]
        
        for hr_zone in sorted(hr_zones.keys()):
            for hr_zone_value_type in sorted(hr_zones[hr_zone].keys()):
                hr_zone_header_name = hr_zone + '_' + hr_zone_value_type
                value = hr_zones[hr_zone][hr_zone_value_type]
                summary_dict[date][hr_zone_header_name] = value
    
    return summary_dict

def CreateCsvsSafe(df, participant_id, out_folder):
    global steps_file_path
    global hr_file_path
    global summary_file_path

    steps_file_path = os.path.join(out_folder, './%s_stepCount.csv'%(str(participant_id)))
    hr_file_path = os.path.join(out_folder, './%s_heartRate.csv'%(str(participant_id)))
    summary_file_path = os.path.join(out_folder, './%s_dailySummary.csv'%(str(participant_id)))

    if not os.path.exists(steps_file_path):
        steps_header = ['Timestamp', 'StepCount']
        with open(steps_file_path, 'wb') as steps_csvfile:
            csv_writer = csv.writer(steps_csvfile, delimiter=',')
            csv_writer.writerow(steps_header)

    if not os.path.exists(hr_file_path):
        hr_header = ['Timestamp', 'HeartRatePPG']
        with open(hr_file_path, 'wb') as hr_csvfile:
           csv_writer = csv.writer(hr_csvfile, delimiter=',')
           csv_writer.writerow(hr_header)

    if not os.path.exists(summary_file_path):
        summary_dict = ExtractDailySummary(df, participant_id)
        if summary_dict:
            summary_header = sorted(summary_dict[summary_dict.keys()[0]].keys())
            with open(summary_file_path, 'wb') as summary_csvfile:
                csv_writer = csv.writer(summary_csvfile, delimiter=',')
                csv_writer.writerow(['Timestamp']+summary_header)

    return


def AppendCsvData(df, participant_id, out_folder):
    global steps_file_path
    global hr_file_path
    global summary_file_path

    step_dict = ExtractSteps(df, participant_id)
    if step_dict:
       with open(steps_file_path, 'ab') as steps_csvfile:
           csv_writer = csv.writer(steps_csvfile, delimiter=',')
           for unix_time in sorted(step_dict.keys()):
               for row in step_dict[unix_time]:
                   steps = int(row)
                   csv_writer.writerow([unix_time, steps])

    hr_dict = ExtractHeartRate(df, participant_id)
    if hr_dict:
       with open(hr_file_path, 'ab') as hr_csvfile:
           csv_writer = csv.writer(hr_csvfile, delimiter=',')
           for unix_time in sorted(hr_dict.keys()):
               for row in hr_dict[unix_time]:
                   hr = int(row)
                   csv_writer.writerow([unix_time, hr])
        
    summary_dict = ExtractDailySummary(df, participant_id)
    if summary_dict:
       summary_header = sorted(summary_dict[summary_dict.keys()[0]].keys())
       with open(summary_file_path, 'ab') as csvfile:
           csv_writer = csv.writer(csvfile, delimiter=',')
           for date in sorted(summary_dict.keys()):
               row = [date]
               for summary_item in summary_header:
                   row.append(summary_dict[date][summary_item])
               csv_writer.writerow(row)

    return True


def DoFitbitJsonToCsv(fitbit_file_path, out_folder):
    # Make sure output folder exists and is empty
    if os.path.exists(out_folder):
        files = glob.glob(os.path.join(out_folder, '*.csv*'))
        if len(files) > 0:
            print 'Please make sure the output folder is empty before running this script'
            return
    else:
        os.makedirs(out_folder)

    if os.path.isdir(fitbit_file_path):
        fitbit_files = glob.glob(os.path.join(fitbit_file_path,'*.jsonl*'))
    else:
        fitbit_files = [fitbit_file_path]
        
    for fitbit_file_name in fitbit_files:
        # Prepare file streaming
        file_streamer = FileStreamer()
        file_streamer.LoadFile(fitbit_file_name)
        print 'Processing file: '+fitbit_file_name

        print 'Processing lines %d through %d'%(file_streamer.current_line, file_streamer.current_line+num_lines_per_chunk-1)
        file_lines = file_streamer.GetNextLines(num_lines_per_chunk)
        is_finished = len(file_lines) ==  0
        while not is_finished:
            df = LoadJson(file_lines)
            participant_ids = df['participant_id'].unique()
            for participant_id in participant_ids:
                CreateCsvsSafe(df, participant_id, out_folder)
                AppendCsvData(df, participant_id, out_folder)

            print 'Processing lines %d through %d'%(file_streamer.current_line, file_streamer.current_line+num_lines_per_chunk-1)
            file_lines = file_streamer.GetNextLines(num_lines_per_chunk)
            is_finished = len(file_lines) == 0

    return

if __name__ == '__main__':
    if len(sys.argv) > 2:
        fitbit_file_path = sys.argv[1]
        out_folder = sys.argv[2]

        DoFitbitJsonToCsv(fitbit_file_path, out_folder)
        DropCsvDuplicates(out_folder)
        SortByTimestamp(out_folder)
    else:
        print "Please provide the following command line arguments:\n 1) Fitbit json file to parse or folder containing json files\n 2) Output folder path"
