import os
import glob
import numpy as np
import pandas as pd

from functools import reduce
from days_at_work import *

def readDataStreams(files):
	data = dict()

	for file in files:
		# Look through all the possible data streams
		if file.rfind('owlinone') > 0:
			# Read the file and create index with dates
			data['owlinone'] = pd.read_csv(file, index_col=0)
		if file.rfind('omsignal') > 0:
			# Read the file and create index with dates
			data['omsignal'] = pd.read_csv(file, index_col=0)
		if file.rfind('surveys') > 0:
			data['surveys'] = pd.read_csv(file, index_col=0)

	return data

def getParticipantIDsFromData(data):
	columns = dict()

	for key in data:
		columns[key] = list(data[key])

	return sorted(list(set().union(*columns.values())))

def checkIndices(data):
	"""Make sure that the indices are the same in all data sets"""

	indices = dict()

	for key in data:
		indices[key] = list(data[key].index)

	return not sorted(list(set().difference(*indices.values())))

def mergeTwoDataStreams(data_stream_A, data_stream_B):

	participantIDs = getParticipantIDsFromData({"stream_1": data_stream_A, "stream_2": data_stream_B})

	days_at_Keck = pd.merge(data_stream_A, data_stream_B, left_index=True, right_index=True)

	# Fill NaN values with zeros to perform or operation
	days_at_Keck = days_at_Keck.fillna(0)

	for participant in participantIDs:
		x = participant + '_x'
		y = participant + '_y'
		if x in days_at_Keck.columns and y in days_at_Keck.columns:
			days_at_Keck[participant] = np.logical_or(days_at_Keck[x], days_at_Keck[y])
			del days_at_Keck[x]
			del days_at_Keck[y]
		elif x in days_at_Keck.columns and y not in days_at_Keck.columns:
			days_at_Keck[participant] = days_at_Keck[x]
			del days_at_Keck[x]
		elif x not in days_at_Keck.columns and y in days_at_Keck.columns:
			days_at_Keck[participant] = days_at_Keck[y]
			del days_at_Keck[y]

	days_at_Keck.replace(to_replace=True, value=1, inplace=True)
	days_at_Keck.replace(to_replace=False, value=np.nan, inplace=True)
	days_at_Keck = days_at_Keck.reindex(sorted(days_at_Keck.columns), axis=1)

	return days_at_Keck

def mergeDaysAtWorkFromStreams(data):

	participantIDs = getParticipantIDsFromData(data)
	assert(checkIndices(data)), "Indices are not the same in all data streams"

	return reduce(mergeTwoDataStreams, [data[key] for key in data])

def daysAtWorkInTheLastXDays(days_at_Keck, days):
	assert days >= 1

	participantIDs = list(days_at_Keck)
	last_worked_days = pd.DataFrame(index = days_at_Keck.index)

	days_at_Keck = days_at_Keck.fillna(0)

	for participant in participantIDs:
		# We make a rolling window
		last_worked_days[participant] = days_at_Keck[participant].rolling(days + 1, min_periods=1, center=False).apply(np.nansum, raw=True) - days_at_Keck[participant]

	last_worked_days = last_worked_days.reindex(sorted(last_worked_days.columns), axis=1)
	last_worked_days = last_worked_days.replace(to_replace=0.0, value=np.nan)

	return last_worked_days

def check_positive(value):
    ivalue = int(value)
    if ivalue <= 0:
         raise argparse.ArgumentTypeError("%s is an invalid positive int value" % value)
    return ivalue

def checkStreamsFromFiles(features_directory, files):
	assert(files), "Features directory does not contain files ending in _days_at_work.csv. Please check directory."

	possible_streams = ['omsignal', 'owlinone', 'surveys']
	file_streams = [os.path.basename(file)[:-17] for file in files] # 17 counting backwards in *_days_at_work.csv

	for stream in file_streams:
		if stream not in possible_streams:
			print("Warning: '" + stream + "'" + ' is not a data stream. Removing from files to process.')
			file_streams.remove(stream)
			files.remove(os.path.join(features_directory, stream + '_days_at_work.csv'))

	print('Processing files:')
	for file in files:
		print('     * ' + file)

	return files, file_streams

def main(features_directory, days):

	files = glob.glob(os.path.join(features_directory, '*_days_at_work.csv'))
	files, streams = checkStreamsFromFiles(features_directory, files)

	data = readDataStreams(files)

	days_at_work = mergeDaysAtWorkFromStreams(data)
	x_previous_days_at_work = daysAtWorkInTheLastXDays(days_at_work, days)

	merged_days_at_work_path = os.path.join(features_directory, 'merged_days_at_work.csv')
	print('Saving merged data in ' + merged_days_at_work_path + ' from the following streams:')
	for stream in streams:
		print('     * ' + stream)
	days_at_work.to_csv(merged_days_at_work_path, index_label='Timestamp')

	x_previous_days_at_work_path = os.path.join(features_directory, str(days) + '_previous_days_at_Keck.csv')
	print('Saving '+ str(days) + ' previous days at work in ' + x_previous_days_at_work_path)
	x_previous_days_at_work.to_csv(x_previous_days_at_work_path, index_label='Timestamp')

if __name__ == "__main__":
	parser = argparse.ArgumentParser(description='Find last X days at work.')
	parser.add_argument('-x', '--days', type=check_positive, choices=range(1, 10), default=3,
		help='Number of days worked at Keck in the last X days')
	parser.add_argument('-f', '--features_directory', type=str, required=True,
		help='Directory with processed data.')
	args = parser.parse_args()

	features_directory = os.path.expanduser(os.path.normpath(args.features_directory))
	main(features_directory, args.days)