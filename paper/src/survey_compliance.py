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
# Authors: Brandon Booth, Karel Mundnich mundnich@usc.edu

import os
import sys
import pdb
import glob
import json
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import tikzplotlib

def CountValidResponses(df, survey_type):
   num_valid_responses = df.shape[0]*[np.nan]
   num_possible_responses = df.shape[0]*[np.nan]
   for row_idx in range(df.shape[0]):
      row = df.iloc[row_idx,:]
      if survey_type == 'job':
         if str(row['work']) == '2': # Did not work that day, ignore work questions
            row = row.drop(['itpd1', 'itpd2', 'irbd1', 'irbd2', 'irbd3', 'irbd4', 'irbd5', 'irbd6', 'irbd7', 'dalal1', 'dalal2', 'dalal3', 'dalal4', 'dalal5', 'dalal6', 'dalal7', 'dalal8', 'dalal9', 'dalal10', 'dalal11', 'dalal12', 'dalal13', 'dalal14', 'dalal15', 'dalal16'])
      elif survey_type == 'health':
         if str(row['tob1']) == '2': # Did not consume tobacco, ignore tobacco questions
            row = row.drop(['tob2_1', 'tob2_2', 'tob2_3', 'tob2_4', 'tob2_5', 'tob2_6', 'tob2_7'])
         if str(row['alc1']) == '2': # Did not consume alcohol, ignore alcohol questions
            row = row.drop(['alc2_1', 'alc2_2', 'alc2_3'])
      elif survey_type == 'personality':
         pass # No questions to cull

      num_valid_responses[row_idx] = row.count()
      num_possible_responses[row_idx] = len(row)
            
   #num_missing = df.isnull().sum().sum()
   #num_valid = df.count().sum()
   return num_valid_responses, num_possible_responses

def ComputeSurveyCompliance(root_data_path, tikz_out_folder=None):
   if tikz_out_folder is not None:
      if not os.path.isdir(tikz_out_folder):
         os.makedirs(tikz_out_folder)

   fig, ax = plt.subplots(2,3)

   #################
   # IGTB compliance
   #################
   igtb_file = os.path.join(root_data_path,'surveys','scored','IGTB','IGTB.csv.gz')
   igtb_df = pd.read_csv(igtb_file)
   igtb_df.loc[igtb_df.ID == 'SD1025', 'igtb_incomplete'] = 0 # This particpant did complete, but forgot to click submit
   igtb_num_total = igtb_df.shape[0]
   igtb_num_complete = igtb_num_total - np.sum(igtb_df['igtb_incomplete'] == 1)
   igtb_opt_in = len(igtb_df['ID'].unique())
   num_participants_total = igtb_df.shape[0]
   print("IGTB participant opt-in: (%d/%d) %3.2f%%"%(igtb_opt_in,num_participants_total, 100.0*float(igtb_opt_in)/num_participants_total))
   print("IGTB compliance: (%d/%d) %3.2f%%"%(igtb_num_complete, igtb_num_total, 100.0*float(igtb_num_complete)/igtb_num_total))
   print("--------------------")

   ################
   # MGT compliance
   ################
   job_survey_cols = ['context1', 'context2', 'context3', 'context4', 'stress', 'anxiety', 'pand1', 'pand2', 'pand3', 'pand4', 'pand5', 'pand6', 'pand7', 'pand8', 'pand9', 'pand10', 'work', 'itpd3', 'itpd1', 'itpd2', 'irbd1', 'irbd2', 'irbd3', 'irbd4', 'irbd5', 'irbd6', 'irbd7', 'dalal1', 'dalal2', 'dalal3', 'dalal4', 'dalal5', 'dalal6', 'dalal7', 'dalal8', 'dalal9', 'dalal10', 'dalal11', 'dalal12', 'dalal13', 'dalal14', 'dalal15', 'dalal16'] 
   health_survey_cols = ['context1', 'context2', 'context3', 'context4', 'stress', 'anxiety', 'pand1', 'pand2', 'pand3', 'pand4', 'pand5', 'pand6', 'pand7', 'pand8', 'pand9', 'pand10', 'sleep_1', 'ex1_1', 'ex2_1', 'tob1', 'tob2_1', 'tob2_2', 'tob2_3', 'tob2_4', 'tob2_5', 'tob2_6', 'tob2_7', 'alc1', 'alc2_1', 'alc2_2', 'alc2_3']
   personality_survey_cols = ['context1', 'context2', 'context3', 'context4', 'stress', 'anxiety', 'pand1', 'pand2', 'pand3', 'pand4', 'pand5', 'pand6', 'pand7', 'pand8', 'pand9', 'pand10', 'bfid1', 'bfid2', 'bfid3', 'bfid4', 'bfid5', 'bfid6', 'bfid7', 'bfid8', 'bfid9', 'bfid10']
   mgt_compliance = {}
   for survey_type in ['job', 'health', 'personality']:
      mgt_compliance[survey_type] = {}

   mgt_files = glob.glob(os.path.join(root_data_path,'surveys','raw','MGT','*.csv.gz'))
   for f in mgt_files:
      mgt_df = pd.read_csv(f)
      mgt_df = mgt_df.iloc[1:,:] # cut out the question description row

      # Figure out the survey type
      survey_type = mgt_df['surveytype'][1]
      if survey_type == 'job':
         survey_cols = job_survey_cols
      elif survey_type == 'health':
         survey_cols = health_survey_cols
      elif survey_type == 'personality':
         survey_cols = personality_survey_cols
      else:
         print('ERROR: Unknown survey type. Must FIX!')
         pdb.set_trace()

      mgt_df_responses = mgt_df.loc[:,survey_cols]
      num_valid_responses, num_possible_responses = CountValidResponses(mgt_df_responses, survey_type)

      #print("File: "+str(f))
      #print("    Survey type: "+survey_type)
      #print("    MGT Compliance: (%d/%d) %3.2f%%"%(np.sum(num_valid_responses), np.sum(num_possible_responses), 100.0*float(np.sum(num_valid_responses))/np.sum(num_possible_responses)))
      #print("--------------------")

      for row_idx in range(mgt_df.shape[0]):
         participant_id = mgt_df.loc[mgt_df.index[row_idx], 'Name']
         if not participant_id in mgt_compliance[survey_type]:
            mgt_compliance[survey_type][participant_id] = {'num_valid': 0, 'num_possible': 0}
         mgt_compliance[survey_type][participant_id]['num_valid'] += num_valid_responses[row_idx]
         mgt_compliance[survey_type][participant_id]['num_possible'] += num_possible_responses[row_idx]

   for (i, survey_type) in enumerate(mgt_compliance.keys()):
      num_unique_participants = len(mgt_compliance[survey_type].keys())
      num_valid = 0
      num_possible = 0
      for participant_id in mgt_compliance[survey_type].keys():
         num_valid += mgt_compliance[survey_type][participant_id]['num_valid']
         num_possible += mgt_compliance[survey_type][participant_id]['num_possible']
      print("Survey type: "+str(survey_type))
      print("    MGT Participant Opt-in: (%d/%d) %3.2f%%"%(num_unique_participants, num_participants_total, 100.0*float(num_unique_participants)/num_participants_total))
      print("    MGT Average Compliance: (%d/%d) %3.2f%%"%(num_valid, num_possible, 100.0*float(num_valid)/num_possible))

      # Generate histogram of the compliance per participant 
      hist_valid = []
      max_possible = 0
      for participant_id in mgt_compliance[survey_type].keys():
         hist_valid.append(mgt_compliance[survey_type][participant_id]['num_valid'])
         max_possible = max(max_possible, mgt_compliance[survey_type][participant_id]['num_possible'])
      hist_valid = np.array(hist_valid).astype(float)/max_possible
      
      ax[0][i].hist(hist_valid)
      ax[0][i].title.set_text('MGT %s Survey Compliance Histogram Per Participant'%(survey_type))
      ax[0][i].set_xlabel('Ratio of Completed MGT Questions')
      ax[0][i].set_ylabel('Number of Participants')
      # if tikz_out_folder is not None:
      #    tikz_out_path = os.path.join(tikz_out_folder, 'mgt_%s_compliance_hist.tex'%(survey_type))
      
   print("--------------------")

   ##################
   # S-MGT compliance
   ##################
   smgt_file = os.path.join(root_data_path,'surveys','raw','S-MGT','S-MGT.csv.gz')
   smgt_df = pd.read_csv(smgt_file)
   smgt_compliance = {}
   for survey_type in ['psych_flex', 'engage_psycap']:
      smgt_compliance[survey_type] = {}
   for row_idx in range(smgt_df.shape[0]):
      row = smgt_df.iloc[row_idx,:]
      survey_type = row['survey_type']
      if isinstance(row['results_updated'], float):
         num_valid = 0
      else:
         results = row['results_updated']
         results = results.replace("'",'"')
         results = results.replace('son"s', "son's")
         responses = json.loads(results)
         num_valid= len(responses.keys())
      
      if survey_type == 'psych_flex':
         num_possible = 15
      elif survey_type == 'engage_psycap':
         num_possible = 29
      else:
         print("ERROR: unknown S-MGT survey type. FIX ME!")
         pdb.set_trace()

      participant_id = row['participant_id']
      if not participant_id in smgt_compliance[survey_type].keys():
         smgt_compliance[survey_type][participant_id] = {'num_valid': 0, 'num_possible': 0}
      smgt_compliance[survey_type][participant_id]['num_valid'] += num_valid
      smgt_compliance[survey_type][participant_id]['num_possible'] += num_possible

   for (i, survey_type) in enumerate(['psych_flex', 'engage_psycap']):
      num_unique_ids = len(smgt_compliance[survey_type].keys())
      num_valid = 0
      num_possible = 0
      for participant_id in smgt_compliance[survey_type].keys():
         num_valid += smgt_compliance[survey_type][participant_id]['num_valid']
         num_possible += smgt_compliance[survey_type][participant_id]['num_possible']
      print("Survey type: "+survey_type)
      print("    S-MGT Participant Opt-in: (%d/%d) %3.2f%%"%(num_unique_ids, num_participants_total, 100.0*float(num_unique_ids)/num_participants_total))
      print("    S-MGT Average Compliance: (%d/%d) %3.2f%%"%(num_valid, num_possible, 100.0*float(num_valid)/num_possible))

      # Generate histogram of the compliance per participant 
      hist_valid = []
      max_possible = 0
      for participant_id in smgt_compliance[survey_type].keys():
         hist_valid.append(smgt_compliance[survey_type][participant_id]['num_valid'])
         max_possible = max(max_possible, smgt_compliance[survey_type][participant_id]['num_possible'])
      hist_valid = np.array(hist_valid).astype(float)/max_possible

      ax[1][i].hist(hist_valid)
      ax[1][i].title.set_text('S-MGT %s Survey Compliance Histogram Per Participant'%(survey_type))
      ax[1][i].set_xlabel('Ratio of Completed S-MGT Questions')
      ax[1][i].set_ylabel('Number of Participants')
      # if tikz_out_folder is not None:
      #    tikz_out_path = os.path.join(tikz_out_folder, 'smgt_%s_compliance_hist.tex'%(survey_type))
      #    tikzplotlib.save(tikz_out_path)

   # Generate histogram of the compliance per participant across MGT, and S-MGT surveys
   # First, get a list of all participants
   participant_ids = []
   for mgt_survey_type in mgt_compliance.keys():
      participant_ids.extend(mgt_compliance[mgt_survey_type].keys())
   for smgt_survey_type in smgt_compliance.keys():
      participant_ids.extend(smgt_compliance[smgt_survey_type].keys())
   participant_ids = np.unique(participant_ids)

   # Second, assumble data for histogram
   hist_valid = []
   max_possible = 0
   for participant_id in participant_ids:
      num_valid_responses = 0
      num_possible_responses = 0
      for mgt_survey_type in mgt_compliance.keys():
         if participant_id in mgt_compliance[mgt_survey_type].keys():
            num_valid_responses += mgt_compliance[mgt_survey_type][participant_id]['num_valid']
            num_possible_responses += mgt_compliance[mgt_survey_type][participant_id]['num_possible']
      for smgt_survey_type in smgt_compliance.keys():
         if participant_id in smgt_compliance[smgt_survey_type].keys():
            num_valid_responses += smgt_compliance[smgt_survey_type][participant_id]['num_valid']
            num_possible_responses += smgt_compliance[smgt_survey_type][participant_id]['num_possible']

      hist_valid.append(num_valid_responses)
      max_possible = max(max_possible, num_possible_responses)

   # Third, plot the histogram
   hist_valid = np.array(hist_valid).astype(float)/max_possible

   ax[1][-1].hist(hist_valid)
   ax[1][-1].title.set_text('Combined MGT and S-MGT Survey Compliance Histogram Per Participant')
   ax[1][-1].set_xlabel('Ratio of Completed Questions')
   ax[1][-1].set_ylabel('Number of Participants')
   

   if tikz_out_folder is not None:
      tikz_out_path = os.path.join(tikz_out_folder, 'survey_compliance.tex')
      tikzplotlib.save(tikz_out_path)
   else:
      plt.show()

   return

if __name__=='__main__':
   parser = argparse.ArgumentParser()
   parser.add_argument('--data_root_path', required=True, help='The path to the root folder in the data set (containing a surveys subfolder)')
   parser.add_argument('--tikz_out_folder', required=False, help='The output folder for tikz-formatted images')
   try:
      args = parser.parse_args()
   except:
      parser.print_help()
      sys.exit(0)
   ComputeSurveyCompliance(args.data_root_path, args.tikz_out_folder)
