import tikzplotlib
import pandas as pd
import matplotlib.pyplot as plt

fitbit = pd.read_csv("../data/tikz/fitbit.csv")
omsignal = pd.read_csv("../data/tikz/omsignal.csv")
owlinone = pd.read_csv("../data/tikz/owlinone.csv")

fig, ax = plt.subplots(3,1)

ax[0].hist(fitbit['hours'], label='Fitbit', color='tab:blue')
ax[0].set_xlim((0,24))
ax[0].set_ylabel('Participants')
ax[0].grid(which='major', axis='both')
ax[0].legend()

ax[1].hist(omsignal['hours'], label='OMsignal garments', color='tab:orange')
ax[1].set_xlim((0,24))
ax[1].set_ylabel('Participants')
ax[1].grid(which='major', axis='both')
ax[1].legend(loc='upper left')

ax[2].hist(owlinone['hours'], label="Jelly phones", color='tab:green')
ax[2].set_xlim((0,24))
ax[2].set_xlabel('Average number of sensor usage hours')
ax[2].set_ylabel('Participants')
ax[2].grid(which='major', axis='both')
ax[2].legend(loc='upper left')

# plt.show()
tikzplotlib.save("usage_histograms.tex")