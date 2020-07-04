import argparse
import pandas as pd
import matplotlib.pyplot as plt

from pathlib import Path
from tikzplotlib import save

def main(args):
    args.recordings = Path(args.recordings).absolute()
    args.participant_info = Path(args.data_root_path).joinpath("metadata/participant-info/participant-info.csv.gz").absolute()

    recordings = pd.read_csv(str(args.recordings))
    participant_info = pd.read_csv(str(args.participant_info))

    fig, ax = plt.subplots(nrows=3,  ncols=1)
    for i in [1,2,3]:
        recordings.merge(participant_info, on="ParticipantID", how="inner").groupby("Wave").get_group(i).hist(column='HoursRecorded', bins=range(0,200,10), ax=ax[i-1])
        ax[i-1].set_xlim((0,175))

    print(f"Saving to file {args.output}")
    save(args.output)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Compute audio histograms for recorded hours.')
    parser.add_argument('--recordings', type=str, required=False, default="../data/audio/count_wav123.csv", help='File in this repo containing audio details.')
    parser.add_argument('--data_root_path', required=True, help='The path to the root folder in the data set (containing a surveys subfolder)')
    parser.add_argument('--output', type=str, required=False, default="audio-integrity.tex", help="Output .tex file")

    args = parser.parse_args()

    main(args)