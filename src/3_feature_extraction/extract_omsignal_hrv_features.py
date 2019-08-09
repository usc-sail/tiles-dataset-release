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
# Author: Abhishek Tiwari

import os
import sys
import pdb
import numpy as np
import pandas as pd
import glob

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'util'))

from util_hrv import *

def ExtractHRVFeatures(omsignal_csv_path, out_path):
   feats=get_all_fname()
   par_ids,folder,om_dates=get_folders_om(omsignal_csv_path, do_include_gz=True)

   for i, Id in enumerate(par_ids):
      
      print("Subject being processed is ",Id)   
      f_name=omsignal_csv_path+'/'+Id+'_omsignal.csv.gz'
      print(f_name)
      try:
         df=pd.read_csv(f_name) 
      except Exception as e:
         try:
            df = pd.read_csv(f_name[:-3])
         except Exception as e:
            print("Exception: "+str(e))
            continue

      RR_uid=df[['Timestamp','RR0','RR1','RR2','RR3']]
      aggr_df=df[['Timestamp','AvgHeartRate','RRPeakCoverage']]
      df_br=df[['Timestamp','inhale0_amp','inhale1_amp','exhale0_amp','exhale1_amp','inhale0_offset','inhale1_offset','exhale0_offset','exhale1_offset']]
      
      df_ts=df[['Timestamp']]
      aggr_df=aggr_df.dropna()
      ind_locs=(aggr_df.index.values)
      feat_arr=np.zeros((df.shape[0],len(feats)))*np.nan
      for ind_agr in ind_locs:
          df_rr=(RR_uid.iloc[ind_agr-300:ind_agr])
          df_br_tmp=(df_br.iloc[ind_agr-300:ind_agr])
          rr_cov=np.array(df['RRPeakCoverage'].iloc[ind_agr])
          vec=get_all_feats(df_rr,df_br_tmp)
          feat_arr[ind_agr,:]=vec
      data_fin=pd.DataFrame(feat_arr,columns=feats)
      data_fin=pd.concat((df_ts,data_fin),axis=1)
      if not os.path.exists(out_path+'/'):
         os.makedirs(out_path+'/')
      
      data_fin.to_csv(os.path.join(out_path,Id+'_hrv_omsignal.csv'), sep=',', index=False)
   return

if __name__=='__main__':
   if len(sys.argv) > 2:
      omsignal_csv_path = sys.argv[1]
      out_folder = sys.argv[2]

      ExtractHRVFeatures(omsignal_csv_path, out_folder)
   else:
      print ("Please provide the following command line arguments:\n 1) Omsignal csv file to parse or folder containing csv files\n 2) Output folder path")
