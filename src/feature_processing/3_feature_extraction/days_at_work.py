import os
import sys
import glob
import errno
import argparse
import numpy as np
import pandas as pd
from pathlib import Path
from dateutil import rrule
from datetime import datetime, timedelta

def getParticipantIDsFromFiles(files):
	underscore_index = os.path.basename(files[0]).rfind('_')

	participantIDs = []

	if underscore_index != -1:
		for file in files:
			participantIDs.append(os.path.basename(file)[:underscore_index])
	else:
		for file in files:
			participantIDs.append(os.path.basename(file).split('.')[0])

	return participantIDs

def getAllParticipantIDs(owl_files, om_files):
	owlParticipantIDs = getParticipantIDsFromFiles(owl_files)
	omParticipantIDs = getParticipantIDsFromFiles(om_files)

	participantIDs = mergeParticipantLists(owlParticipantIDs, omParticipantIDs)

	return sorted(participantIDs)

def mergeParticipantLists(listA, listB):
	inA = set(listA)
	inB = set(listB)

	return list(inA) + list(inB - inA)

def getParticipantIDFromFileName(file):
	slash_index = file.rfind('/')
	underscore_index = file.rfind('_')

	return file[slash_index + 1:underscore_index]

def getDatesFromFiles(files):
	start_dates = []
	end_dates = []

	for f, file in enumerate(files):
		sys.stdout.write('\r')
		# the exact output you're looking for:
		sys.stdout.write("%d/%d files processed" % (f+1, len(files)))
		sys.stdout.flush()
		data = getDataFrame(file)
		start_dates.append(data.index[0])
		end_dates.append(data.index[-1])

	return min(start_dates), max(end_dates)

def getDataFrame(file):
	# Read and prepare owl data per participant
	data = pd.read_csv(file, index_col=0)
	data.index = pd.to_datetime(data.index)

	return data

def getDaysAtWorkDataFrame(file):
	return pd.read_csv(file, index_col=0)

def main(input_dir, output_dir, stream):
	csv_file = os.path.join(output_dir, stream + '_days_at_work.csv')

	if not os.path.exists(csv_file):
		# Obtain participant IDs from file names
		files = glob.glob(os.path.join(input_dir, '*.csv.gz'))
		if not files:
			raise FileNotFoundError('Passed data directory is empty')

		if stream in ['omsignal', 'owlinone']:
			participantIDs = getParticipantIDsFromFiles(files)

			# Create a time range for the data to be used. We read through all the
			# files and obtain the earliest and latest dates. This is the time range
			# used to produced the data to be saved in 'preprocessed/'
			print('Finding all dates, this may take a while...', end='')
			start_date, end_date = getDatesFromFiles(files)
			dates_range = pd.date_range(start=start_date, end=end_date, normalize=True)
			print('done.')

			# OMsignal has a problem with the dates. We check the range
			if dates_range[0] < datetime(2018,2,19) and dates_range[-1] > datetime(2018,7,14):
				dates_range = pd.date_range(start=datetime(2018,2,19), end=datetime(2018,7,14), normalize=True)

			# Initialize the time frame to store days at Keck
			days_at_work = pd.DataFrame(np.nan, index=dates_range, columns=participantIDs)

			for participant in participantIDs:
				print("Processing participant", participant)
				if stream == 'owl_in_one' or stream == 'owlinone':
					file = os.path.join(input_dir, participant + '.csv.gz')
				elif stream == 'omsignal':
					file = os.path.join(input_dir, participant + '_omsignal.csv.gz')

				data = getDataFrame(file)
				dates_worked = list(set([date.date() for date in data.index]))

				if stream == 'owl_in_one' or stream == 'owlinone' or stream == 'omsignal':
					for date in dates_range:
						if date.date() in dates_worked:
							days_at_work.loc[date.date(), participant] = 1

		elif stream == 'surveys':
			id_dir = Path(__file__).parent.absolute().parent/'util/mitreids.csv'
			try:
				MGT = pd.read_csv(os.path.join(input_dir, 'MGT.csv.gz'), index_col='Date')
			except UnicodeDecodeError:
				MGT = pd.read_csv(os.path.join(input_dir, 'MGT.csv.gz'), index_col='Date', encoding='cp1252')

			IDs = pd.read_csv(id_dir, index_col=1)
			IDs.columns = ['ParticipantID']
			IDs.index.names = ['MitreID']

			MGT.index = pd.to_datetime(MGT.index)

			start_date = min(MGT.index).date()
			end_date = max(MGT.index).date()

			dates_range = pd.date_range(start=start_date, end=end_date)
			participantIDs = sorted(list(IDs['ParticipantID'].unique()))

			days_at_work = pd.DataFrame(np.nan, index=dates_range, columns=participantIDs)

			for index, row in MGT.iterrows():
			    try:
			        participant = IDs.loc[row['Name']]['ParticipantID']
			        if row['context3'] == 2.0: # At work when answering the survey according to MGT, question 1
			            days_at_work.loc[index.date()][participant] = 1.0
			    except KeyError:
			        print('Participant ' + row['Name'] + ' is not in participant list from ' + id_dir.stem)

		if not os.path.exists(output_dir):
			try:
				print('Creating directory ' + output_dir)
				os.makedirs(output_dir)
			except OSError as e:
				if e.errno != errno.EEXIST:
					raise

		if 'days_at_work' in locals():
			days_at_work.to_csv(os.path.join(output_dir, stream + '_days_at_work.csv'), index_label='Timestamp')

	else:
		print('File ' + csv_file + ' already exists. Exiting.')

if __name__ == "__main__":
	parser = argparse.ArgumentParser(description='Create a dataframe of worked days.')
	parser.add_argument('-s', '--stream', type=str, required=True,
		choices=['omsignal', 'owlinone', 'surveys'])
	parser.add_argument('-i', '--input_dir', type=str, required=True,
		help='Directory for data to be processed.')
	parser.add_argument('-o', '--output_dir', type=str, required=True,
		help='Output directory with processed data.')
	args = parser.parse_args()

	input_dir = os.path.expanduser(os.path.normpath(args.input_dir))
	output_dir = os.path.expanduser(os.path.normpath(args.output_dir))
	stream = os.path.expanduser(os.path.normpath(args.stream))

	main(input_dir, output_dir, stream)