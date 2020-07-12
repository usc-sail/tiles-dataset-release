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
# Authors: Brandon M Booth

import os
import sys
import pdb
import glob
import tqdm
import argparse
import datetime
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import tikzplotlib

wave1_threshold = datetime.datetime(2018, 4, 1, 0, 0)
wave2_threshold = datetime.datetime(2018, 5, 1, 0, 0)

def ComputeFitbitSensorCompliance(fitbit_hr_path, tikz_plot_path, show_plots):
   fitbit_files = glob.glob(os.path.join(fitbit_hr_path, '*.csv.gz'))
   avg_daily_hrs = []
   wave1_daily_hrs = []
   wave2_daily_hrs = []
   wave3_daily_hrs = []
   for fitbit_file in tqdm.tqdm(fitbit_files, 'Fitbit Compliance'):
      participant_id = os.path.basename(fitbit_file).split('.')[0]
      df = pd.read_csv(fitbit_file)
      df.set_index('Timestamp', inplace=True)
      df.index = [datetime.datetime.strptime(x, '%Y-%m-%dT%H:%M:%S.%f') for x in df.index]
      minute_df = df.groupby(pd.Grouper(freq='min')).count()
      valid_minute_df = minute_df > 0
      daily_df = valid_minute_df.groupby(pd.Grouper(freq='D')).sum()
      avg_daily_hours = (daily_df/60.0).mean()['HeartRatePPG']
      avg_daily_hrs.append(avg_daily_hours)

      if df.index[0] < wave1_threshold:
         wave1_daily_hrs.append(avg_daily_hours)
      elif df.index[0] < wave2_threshold:
         wave2_daily_hrs.append(avg_daily_hours)
      else:
         wave3_daily_hrs.append(avg_daily_hours)

   if show_plots or tikz_plot_path:
      fig, axs = plt.subplots(2,2)
      bins = list(range(25))
      axs[0,0].hist(wave1_daily_hrs, bins=bins)
      axs[0,1].hist(wave2_daily_hrs, bins=bins)
      axs[1,0].hist(wave3_daily_hrs, bins=bins)
      axs[1,1].hist(avg_daily_hrs, bins=bins)
      axs[0,0].set_xlabel('Average number of hours per day')
      axs[0,0].set_ylabel('Number of Participants')
      axs[0,0].set_title('Wave 1')
      axs[0,1].set_xlabel('Average number of hours per day')
      axs[0,1].set_ylabel('Number of Participants')
      axs[0,1].set_title('Wave 2')
      axs[1,0].set_xlabel('Average number of hours per day')
      axs[1,0].set_ylabel('Number of Participants')
      axs[1,0].set_title('Wave 3')
      axs[1,1].set_xlabel('Average number of hours per day')
      axs[1,1].set_ylabel('Number of Participants')
      axs[1,1].set_title('Combined')
      plt.title('Fitbit Compliance')

      if tikz_plot_path is not None:
         tikzplotlib.save(tikz_plot_path)
      if show_plots:
         plt.show()

   return

def ComputeOMSignalSensorCompliance(omsignal_hr_path, days_at_work_path, tikz_plot_path, show_plots):
   days_at_work_df = pd.read_csv(days_at_work_path)
   days_at_work_df.set_index('Timestamp', inplace=True)
   omsignal_files = glob.glob(os.path.join(omsignal_hr_path, '*.csv.gz'))
   avg_daily_at_work_hrs = []
   wave1_daily_at_work_hrs = []
   wave2_daily_at_work_hrs = []
   wave3_daily_at_work_hrs = []
   for omsignal_file in tqdm.tqdm(omsignal_files, 'OMSignal Compliance'):
      participant_id = os.path.basename(omsignal_file).split('.')[0]
      df = pd.read_csv(omsignal_file)
      df.set_index('Timestamp', inplace=True)
      df.index = [datetime.datetime.strptime(x, '%Y-%m-%dT%H:%M:%S.%f') for x in df.index]
      minute_df = df.groupby(pd.Grouper(freq='min')).count()
      valid_minute_df = minute_df > 0
      daily_df = valid_minute_df.groupby(pd.Grouper(freq='D')).sum()

      days_at_work_pid_df = days_at_work_df.loc[:,days_at_work_df.columns == participant_id]
      days_at_work_masked_pid_df = days_at_work_pid_df.index[~np.isnan(days_at_work_pid_df).values.flatten()]
      daily_df.index = [datetime.datetime.strftime(x, '%Y-%m-%d') for x in daily_df.index]
      daily_at_work_df = daily_df.loc[days_at_work_masked_pid_df, :]

      avg_daily_at_work_hours = (daily_at_work_df/60.0).mean()['HeartRate']
      avg_daily_at_work_hrs.append(avg_daily_at_work_hours)

      if df.index[0] < wave1_threshold:
         wave1_daily_at_work_hrs.append(avg_daily_at_work_hours)
      elif df.index[0] < wave2_threshold:
         wave2_daily_at_work_hrs.append(avg_daily_at_work_hours)
      else:
         wave3_daily_at_work_hrs.append(avg_daily_at_work_hours)

   if show_plots or tikz_plot_path:
      fig, axs = plt.subplots(2,2)
      bins = list(range(25))
      axs[0,0].hist(wave1_daily_at_work_hrs, bins=bins)
      axs[0,1].hist(wave2_daily_at_work_hrs, bins=bins)
      axs[1,0].hist(wave3_daily_at_work_hrs, bins=bins)
      axs[1,1].hist(avg_daily_at_work_hrs, bins=bins)
      axs[0,0].set_xlabel('Average number of hours per day')
      axs[0,0].set_ylabel('Number of Participants')
      axs[0,0].set_title('Wave 1')
      axs[0,1].set_xlabel('Average number of hours per day')
      axs[0,1].set_ylabel('Number of Participants')
      axs[0,1].set_title('Wave 2')
      axs[1,0].set_xlabel('Average number of hours per day')
      axs[1,0].set_ylabel('Number of Participants')
      axs[1,0].set_title('Wave 3')
      axs[1,1].set_xlabel('Average number of hours per day')
      axs[1,1].set_ylabel('Number of Participants')
      axs[1,1].set_title('Combined')
      plt.title('OMSignal Compliance')

      if tikz_plot_path is not None:
         tikzplotlib.save(tikz_plot_path)
      if show_plots:
         plt.show()

   return

def ComputeSensorCompliance(root_data_path, tikz_plot_path, show_plots):
   #if tikz_plot_path is not None:
   #   out_fitbit_tikz = os.path.join(os.path.dirname(tikz_plot_path), os.path.basename(tikz_plot_path).split('.')[0] + '_fitbit.tex')
   #else:
   #   out_fitbit_tikz = None
   #ComputeFitbitSensorCompliance(os.path.join(root_data_path, 'fitbit', 'heart-rate'), out_fitbit_tikz, show_plots)
   if tikz_plot_path is not None:
      out_omsignal_tikz = os.path.join(os.path.dirname(tikz_plot_path), os.path.basename(tikz_plot_path).split('.')[0] + '_omsignal.tex')
   else:
      out_omsignal_tikz = None
   omsignal_features_path = os.path.join(root_data_path, 'omsignal', 'features')
   days_at_work_path = os.path.join(root_data_path, 'metadata', 'days-at-work', 'omsignal_days_at_work.csv.gz')
   ComputeOMSignalSensorCompliance(omsignal_features_path, days_at_work_path, out_omsignal_tikz, show_plots)

   return

if __name__=='__main__':
   parser = argparse.ArgumentParser()
   parser.add_argument('--data_root_path', required=True, help='The path to the root folder in the data set (containing sensor data in subfolders)')
   parser.add_argument('--show_plots', required=False, action='store_true', help='Flag enables plot display')
   parser.add_argument('--tikz_plot', required=False, help='Output file path for tikz plot code')
   try:
      args = parser.parse_args()
   except:
      parser.print_help()
      sys.exit(0)
   ComputeSensorCompliance(args.data_root_path, args.tikz_plot, args.show_plots)
