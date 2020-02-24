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

bins = [float(x)/20 for x in range(0,21)]

def CountValidResponses(df, survey_type):
   num_valid_responses = df.shape[0]*[np.nan]
   num_possible_responses = df.shape[0]*[np.nan]
   num_surveys_started = df.shape[0]*[np.nan]
   num_surveys = df.shape[0]*[np.nan]
   for row_idx in range(df.shape[0]):
      row = df.iloc[row_idx,:]
      if survey_type == 'job':
         if str(row['work']) == str(float(2)) or str(row['work']) == str(np.nan): # Did not work that day or unknown work status => ignore work questions
            row = row.drop(['itpd1', 'itpd2', 'itpd3', 'irbd1', 'irbd2', 'irbd3', 'irbd4', 'irbd5', 'irbd6', 'irbd7', 'dalal1', 'dalal2', 'dalal3', 'dalal4', 'dalal5', 'dalal6', 'dalal7', 'dalal8', 'dalal9', 'dalal10', 'dalal11', 'dalal12', 'dalal13', 'dalal14', 'dalal15', 'dalal16'])
      elif survey_type == 'health':
         if str(row['tob1']) == str(float(2)) or str(row['tob1']) == str(np.nan): # Did not consume tobacco or unknown => ignore tobacco questions
            row = row.drop(['tob2_1', 'tob2_2', 'tob2_3', 'tob2_4', 'tob2_5', 'tob2_6', 'tob2_7'])
         if str(row['alc1']) == str(float(2)) or str(row['alc1']) == str(np.nan): # Did not consume alcohol or unknown => ignore alcohol questions
            row = row.drop(['alc2_1', 'alc2_2', 'alc2_3'])
      elif survey_type == 'personality':
         pass # No questions to cull

      num_valid_responses[row_idx] = row.count()
      num_possible_responses[row_idx] = len(row)
      num_surveys_started[row_idx] = 1 if row.count() > 0 else 0
      num_surveys[row_idx] = 1

      # Don't count surveys not started when counting valid responses
      if row.count() == 0:
         num_valid_responses[row_idx] = 0
         num_possible_responses[row_idx] = 0

   return num_valid_responses, num_possible_responses, num_surveys_started, num_surveys

def ComputeSurveyCompliance(root_data_path, tikz_out_folder=None):
   if tikz_out_folder is not None:
      if not os.path.isdir(tikz_out_folder):
         os.makedirs(tikz_out_folder)

   plt.ion()
   fig, ax = plt.subplots(2,3)
   fig2, ax2 = plt.subplots(2,3)

   #################
   # IGTB compliance
   #################
   igtb_file = os.path.join(root_data_path,'surveys','scored','baseline','part_one-abs_vocab_gats_audit_psqi_ipaq_iod_ocb_irb_itp_bfi_pan_stai.csv.gz')
   igtb_df = pd.read_csv(igtb_file)
   igtb_df.loc[igtb_df.participant_id == 'SD1025', 'igtb_incomplete'] = 0 # This particpant did complete, but forgot to click submit
   igtb_num_total = igtb_df.shape[0]
   igtb_num_complete = igtb_num_total - np.sum(igtb_df['igtb_incomplete'] == 1)
   igtb_opt_in = len(igtb_df['participant_id'].unique())
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

   mgt_file = os.path.join(root_data_path,'surveys','raw','EMAs','job_personality_health-context_stress_anxiety_pand_bfid_sleep_ex_tob_alc_work_itpd_irbd_dalal.csv.gz')
   mgt_df = pd.read_csv(mgt_file)
   mgt_surveys = mgt_df.groupby('survey_type')
   mgt_groups= [x for x in mgt_surveys]
   for mgt_group in mgt_groups:
      survey_type = mgt_group[0]
      mgt_df = mgt_group[1]

      # Figure out the survey type
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
      num_valid_responses, num_possible_responses, num_surveys_started, num_surveys = CountValidResponses(mgt_df_responses, survey_type)

      #print("File: "+str(f))
      #print("    Survey type: "+survey_type)
      #print("    MGT Compliance: (%d/%d) %3.2f%%"%(np.sum(num_valid_responses), np.sum(num_possible_responses), 100.0*float(np.sum(num_valid_responses))/np.sum(num_possible_responses)))
      #print("--------------------")

      for row_idx in range(mgt_df.shape[0]):
         participant_id = mgt_df.loc[mgt_df.index[row_idx], 'participant_id']
         if not participant_id in mgt_compliance[survey_type]:
            mgt_compliance[survey_type][participant_id] = {'num_valid': 0, 'num_possible': 0, 'num_surveys_started': 0, 'num_surveys': 0}
         mgt_compliance[survey_type][participant_id]['num_valid'] += num_valid_responses[row_idx]
         mgt_compliance[survey_type][participant_id]['num_possible'] += num_possible_responses[row_idx]
         mgt_compliance[survey_type][participant_id]['num_surveys_started'] += num_surveys_started[row_idx]
         mgt_compliance[survey_type][participant_id]['num_surveys'] += num_surveys[row_idx]

   for (i, survey_type) in enumerate(mgt_compliance.keys()):
      num_unique_participants = len(mgt_compliance[survey_type].keys())
      num_valid = 0
      num_possible = 0
      num_surveys_started = 0
      num_surveys = 0
      for participant_id in mgt_compliance[survey_type].keys():
         num_valid += mgt_compliance[survey_type][participant_id]['num_valid']
         num_possible += mgt_compliance[survey_type][participant_id]['num_possible']
         num_surveys_started += mgt_compliance[survey_type][participant_id]['num_surveys_started']
         num_surveys += mgt_compliance[survey_type][participant_id]['num_surveys']
      print("Survey type: "+str(survey_type))
      print("    MGT Participant Opt-in: (%d/%d) %3.2f%%"%(num_unique_participants, num_participants_total, 100.0*float(num_unique_participants)/num_participants_total))
      print("    MGT Average Compliance: (%d/%d) %3.2f%%"%(num_valid, num_possible, 100.0*float(num_valid)/num_possible))
      print("    MGT Surveys Started: (%d/%d) %3.2f%%"%(num_surveys_started, num_surveys, 100.0*float(num_surveys_started)/num_surveys))

      # Generate histogram of the compliance per participant 
      hist_valid = []
      hist_started = []
      for participant_id in mgt_compliance[survey_type].keys():
         num_valid = mgt_compliance[survey_type][participant_id]['num_valid']
         num_possible = mgt_compliance[survey_type][participant_id]['num_possible']
         if num_possible > 0:
            hist_valid.append(float(num_valid)/num_possible)
         num_surveys_started = mgt_compliance[survey_type][participant_id]['num_surveys_started']
         num_surveys = mgt_compliance[survey_type][participant_id]['num_surveys']
         if num_surveys > 0:
            hist_started.append(float(num_surveys_started)/num_surveys)
      
      ax[0][i].hist(hist_valid, bins=bins)
      ax[0][i].title.set_text('MGT %s Survey Compliance Histogram Per Participant'%(survey_type))
      ax[0][i].set_xlabel('Ratio of Completed MGT Questions')
      ax[0][i].set_ylabel('Number of Participants')
      ax2[0][i].hist(hist_started, bins=bins)
      ax2[0][i].title.set_text('MGT %s Surveys Started Histogram Per Participant'%(survey_type))
      ax2[0][i].set_xlabel('Percentage of Surveys Started')
      ax2[0][i].set_ylabel('Number of Participants')
      # if tikz_out_folder is not None:
      #    tikz_out_path = os.path.join(tikz_out_folder, 'mgt_%s_compliance_hist.tex'%(survey_type))
      
   print("--------------------")

   ##################
   # S-MGT compliance
   ##################
   psycap_file = os.path.join(root_data_path, 'surveys', 'raw', 'EMAs', 'psychological_capital-Psycap_Location_Activity_Engage_IS_CS_HS.csv.gz')
   psyflex_file = os.path.join(root_data_path, 'surveys', 'raw', 'EMAs', 'psychological_flexibility-Activity_Experience_PF.csv.gz')
   psycap_df = pd.read_csv(psycap_file)
   psyflex_df = pd.read_csv(psyflex_file)
   smgt_compliance = {}
   for survey in [('psych_flex', psyflex_df), ('engage_psycap', psycap_df)]:
      survey_type = survey[0]
      smgt_df = survey[1]
      smgt_compliance[survey_type] = {}
      if survey_type == 'psych_flex':
         single_response_cols = ['Activity'] + (['PF%d'%(i) for i in range(1,14)])
         multi_response_cols = ['Experience%d'%(i) for i in range(1,15)]
         num_single_responses = len(single_response_cols) - pd.isnull(smgt_df[single_response_cols]).sum(axis=1)
         num_multi_responses = len(multi_response_cols) - pd.isnull(smgt_df[multi_response_cols]).sum(axis=1)

         smgt_df['num_valid'] = num_single_responses + num_multi_responses.clip(upper=1)
         smgt_df['num_possible'] = len(single_response_cols) + 1
         smgt_df['num_surveys_started'] = smgt_df['num_valid'].clip(upper=1)
         smgt_df['num_surveys'] = 1 
         smgt_df.loc[smgt_df['num_valid'] == 0,'num_possible'] = 0 # Remove non-starter responses

      if survey_type == 'engage_psycap':
         single_response_cols = ['Location', 'Activity'] + ['Engage%d'%(i) for i in range(1,4)] + ['Psycap%d'%(i) for i in range(1,13)] + ['IS1', 'IS2', 'IS3', 'CS1', 'CS2', 'CS3', 'CS4', 'CS5', 'HS1', 'HS2', 'HS3', 'HS4']
         num_single_responses = len(single_response_cols) - pd.isnull(smgt_df[single_response_cols]).sum(axis=1)

         smgt_df['num_valid'] = num_single_responses
         smgt_df['num_possible'] = len(single_response_cols)
         smgt_df['num_surveys_started'] = smgt_df['num_valid'].clip(upper=1)
         smgt_df['num_surveys'] = 1
         smgt_df.loc[smgt_df['num_valid'] == 0,'num_possible'] = 0 # Remove non-starter responses

      for row_idx in range(smgt_df.shape[0]):
         row = smgt_df.iloc[row_idx,:]
         participant_id = row['participant_id']
         if not participant_id in smgt_compliance[survey_type].keys():
            smgt_compliance[survey_type][participant_id] = {'num_valid': 0, 'num_possible': 0, 'num_surveys_started': 0, 'num_surveys': 0}
         smgt_compliance[survey_type][participant_id]['num_valid'] += row['num_valid']
         smgt_compliance[survey_type][participant_id]['num_possible'] += row['num_possible']
         smgt_compliance[survey_type][participant_id]['num_surveys_started'] += row['num_surveys_started']
         smgt_compliance[survey_type][participant_id]['num_surveys'] += row['num_surveys']

   for (i, survey_type) in enumerate(['psych_flex', 'engage_psycap']):
      num_unique_ids = len(smgt_compliance[survey_type].keys())
      num_valid = 0
      num_possible = 0
      num_surveys_started = 0
      num_surveys = 0
      for participant_id in smgt_compliance[survey_type].keys():
         num_valid += smgt_compliance[survey_type][participant_id]['num_valid']
         num_possible += smgt_compliance[survey_type][participant_id]['num_possible']
         num_surveys_started += smgt_compliance[survey_type][participant_id]['num_surveys_started']
         num_surveys += smgt_compliance[survey_type][participant_id]['num_surveys']
      print("Survey type: "+survey_type)
      print("    S-MGT Participant Opt-in: (%d/%d) %3.2f%%"%(num_unique_ids, num_participants_total, 100.0*float(num_unique_ids)/num_participants_total))
      print("    S-MGT Average Compliance: (%d/%d) %3.2f%%"%(num_valid, num_possible, 100.0*float(num_valid)/num_possible))
      print("    S-MGT Surveys Started: (%d/%d) %3.2f%%"%(num_surveys_started, num_surveys, 100.0*float(num_surveys_started)/num_surveys))

      # Generate histogram of the compliance per participant 
      hist_valid = []
      hist_stated = []
      for participant_id in smgt_compliance[survey_type].keys():
         num_valid = smgt_compliance[survey_type][participant_id]['num_valid']
         num_possible = smgt_compliance[survey_type][participant_id]['num_possible']
         hist_valid.append(float(num_valid)/num_possible)
         num_surveys_started = smgt_compliance[survey_type][participant_id]['num_surveys_started']
         num_surveys = smgt_compliance[survey_type][participant_id]['num_surveys']
         hist_started.append(float(num_surveys_started)/num_surveys)

      ax[1][i].hist(hist_valid, bins=bins)
      ax[1][i].title.set_text('S-MGT %s Survey Compliance Histogram Per Participant'%(survey_type))
      ax[1][i].set_xlabel('Ratio of Completed S-MGT Questions')
      ax[1][i].set_ylabel('Number of Participants')
      ax2[1][i].hist(hist_started, bins=bins)
      ax2[1][i].title.set_text('S-MGT %s Surveys Started Histogram Per Participant'%(survey_type))
      ax2[1][i].set_xlabel('Percentage of Started Surveys')
      ax2[1][i].set_ylabel('Number of Participants')
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
   hist_started = []
   for participant_id in participant_ids:
      num_valid_responses = 0
      num_possible_responses = 0
      num_surveys_started = 0
      num_surveys = 0
      for mgt_survey_type in mgt_compliance.keys():
         if participant_id in mgt_compliance[mgt_survey_type].keys():
            num_valid_responses += mgt_compliance[mgt_survey_type][participant_id]['num_valid']
            num_possible_responses += mgt_compliance[mgt_survey_type][participant_id]['num_possible']
            num_surveys_started += mgt_compliance[mgt_survey_type][participant_id]['num_surveys_started']
            num_surveys += mgt_compliance[mgt_survey_type][participant_id]['num_surveys']
      for smgt_survey_type in smgt_compliance.keys():
         if participant_id in smgt_compliance[smgt_survey_type].keys():
            num_valid_responses += smgt_compliance[smgt_survey_type][participant_id]['num_valid']
            num_possible_responses += smgt_compliance[smgt_survey_type][participant_id]['num_possible']
            num_surveys_started += smgt_compliance[smgt_survey_type][participant_id]['num_surveys_started']
            num_surveys += smgt_compliance[smgt_survey_type][participant_id]['num_surveys']

      hist_valid.append(float(num_valid_responses)/num_possible_responses)
      hist_started.append(float(num_surveys_started)/num_surveys)

   ax[1][-1].hist(hist_valid, bins=bins)
   ax[1][-1].title.set_text('Combined MGT and S-MGT Survey Compliance Histogram Per Participant')
   ax[1][-1].set_xlabel('Ratio of Completed Questions')
   ax[1][-1].set_ylabel('Number of Participants')
   ax2[1][-1].hist(hist_started, bins=bins)
   ax2[1][-1].title.set_text('Combined MGT and S-MGT Percentage Surveys Started Histogram Per Participant')
   ax2[1][-1].set_xlabel('Percentage of Surveys Started')
   ax2[1][-1].set_ylabel('Number of Participants')

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
