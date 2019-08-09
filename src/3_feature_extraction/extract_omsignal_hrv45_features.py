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
import numpy as np
import pandas as pd
import warnings
warnings.filterwarnings('ignore')
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'util'))
from util_hrv import *

def ExtractHRVFeatures(omsignal_csv_path, out_path):
   feats=get_all_fname()
   par_ids,folder,om_dates=get_folders_om(omsignal_csv_path, do_include_gz=True)
   
   for i, Id in enumerate(par_ids):
      
      print("Subject being processed is ",Id)   
      f_name=omsignal_csv_path+'/'+Id+'_omsignal.csv.gz'
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
      
      df['unix']=(df.Timestamp.map(lambda x: convert_date_time(x)))
      #where shift greater than 4 hours (add 1 as diff signal)
      sfts=np.where(np.diff(np.array(df['unix']))>(4*3600))[0]+1 

      sfts=np.insert(sfts,0,0) #shift start time
      
      aggr_df=aggr_df.dropna()
      ind_locs_all=np.array(aggr_df.index.values)
      ind_locs_day=[]
      
      if len(sfts)>1:
         for ixt in range(1,len(sfts)):
            tmp=ind_locs_all[np.where(ind_locs_all>sfts[ixt-1])]
            tmp=tmp[np.where(tmp<sfts[ixt])]
            ind_locs_day.append(tmp)
      else: #Case of having just a single shift
         ixt=0 #Only one day account for last day accounts for this
   
      #Account for last day as well:
      tmp=ind_locs_all[np.where(ind_locs_all>sfts[ixt])]
      ind_locs_day.append(tmp)
      
      df_ts=df[['Timestamp']]
      res=45
      feat_arr=np.zeros((df_ts.shape[0],len(feats)))*np.nan
      skip=int(res/5)
      for ind_locs in ind_locs_day:

         if len(ind_locs)==0:
            continue
         #asumming first one 5 minute aggreagte comes at 5min
         ind_1=ind_locs[0]-300  
         ind_locs=ind_locs[skip-1::skip]
         ind_locs=np.insert(ind_locs,0,ind_1)
         for ixt in range(1,len(ind_locs)):
            ind_agr=ind_locs[ixt]
            df_rr=(RR_uid.iloc[ind_locs[ixt-1]:ind_agr])
            df_br_tmp=(df_br.iloc[ind_locs[ixt-1]:ind_agr])
            rr_cov=np.array(df['RRPeakCoverage'].iloc[ind_agr])
            vec=get_all_feats(df_rr,df_br_tmp)
            feat_arr[ind_agr,:]=vec

      feats_res=[]
      for ft in feats:
         feats_res.append(ft+'_45R')
      
      data_fin=pd.DataFrame(feat_arr,columns=feats_res)
      data_fin=pd.concat((df_ts,data_fin),axis=1)
      if not os.path.exists(out_path+'/'):
         os.makedirs(out_path+'/')
      data_fin.to_csv(os.path.join(out_path, Id+'_hrv_omsignal45.csv'), sep=',', index=False)
   return


if __name__=='__main__':
   if len(sys.argv) > 2:
      omsignal_csv_path = sys.argv[1]
      out_folder = sys.argv[2]
      
      ExtractHRVFeatures(omsignal_csv_path, out_folder)
   else:
      print ("Please provide the following command line arguments:\n 1) Omsignal csv file to parse or folder containing csv files\n 2) Output folder path")
