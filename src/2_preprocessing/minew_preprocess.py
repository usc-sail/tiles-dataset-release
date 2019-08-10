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
import glob
import numpy as np
import pandas as pd

valid_minew_mac_prefix = 'ac233f'.upper()

def DoMinewPreprocess(in_path, out_path):
   # Ensure the output folder exists
   if not os.path.isdir(out_path):
      os.makedirs(out_path)

   files = glob.glob(os.path.join(in_path, '*.csv*'))
   for f in files:
      file_basename = os.path.basename(f)
      out_file_name = os.path.join(out_path, file_basename)
      if not out_file_name.endswith('.gz'):
         out_file_name += '.gz'

      df = pd.read_csv(f)
      
      # Eliminate invalid rows
      valid_idx = [x.upper().startswith(valid_minew_mac_prefix) for x in df['deviceId']]
      df = df[pd.Series(valid_idx, name='bools').values]

      df.to_csv(out_file_name, header=True, index=False, compression='gzip')

   return

if __name__ == '__main__':
   if len(sys.argv) > 2:
      minew_csv_folder = sys.argv[1]
      out_minew_csv_folder = sys.argv[2]
      DoMinewPreprocess(minew_csv_folder, out_minew_csv_folder)
   else:
      print('Please provide the following command line arguments:\n 1) Path to folder containing minew CSV files\n 2) Output folder path for preprocessed minew CSVs')
