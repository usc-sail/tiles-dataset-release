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

import numpy as np
from scipy.stats import norm
from scipy import stats
from datetime import datetime
from pyentrp import entropy as ent
import nolds
from scipy.stats import rankdata
import itertools
import math
from scipy.stats import norm
from scipy import stats
import numpy.linalg as la
import gc
import os
from os import listdir
from os.path import isfile, join
import pytz
import itertools
import numpy as np
from scipy.stats import rankdata
import pandas as pd
from scipy import signal
#from am_analysis import am_analysis as ama
from hrv.classical import frequency_domain  #Adding in VERSION 1.1
from scipy import signal, stats
from scipy.special import gamma,psi
from scipy import ndimage
from scipy.linalg import det
from numpy import pi
from sklearn import preprocessing
from sklearn.neighbors import NearestNeighbors


"""Utils for new omsignal feature extraction"""

def get_all_feats(df_rr,df_br,fs=4):
	
	f1_nm=get_time_fname()
	f2_nm=get_freq_fname()
	f3_nm=get_nl_fname()
	f4_nm=get_hra_fname()
	f5_nm=get_nhra_fname()
	f67_nm=get_mspe_fname(scale=5,mod_flag=0)
	f8_nm=get_mstir_fname()
	f910_nm=get_msod_fname(scale=5,scl_up=3,mod_flag=0)
	f1112_nm=get_mspe_fname(scale=5,mod_flag=1)
	f13_nm=get_hr_br_fname()
	f14_nm=get_new_br_fname()
	ibi=np.array(df_rr[['RR0','RR1','RR2','RR3']])
	rr,rr_cov=get_RR(ibi[:,0],ibi[:,1],ibi[:,2],0)
	
	scale_val=5
	try:
		RRs=get_cg_series(rr,scale=scale_val)
		dif_RRs=get_cg_series(abs(np.diff(rr)),scale=scale_val)
	
		dst,dst_mod=get_mot_series(RRs,m=3,lag=1)
		dif_dst,dif_dst_mod=get_mot_series(dif_RRs,m=3,lag=1)
	except:
		dst=[]
		dst_mod=[]

		dif_dst=[]
		dif_dst_mod=[]
		
	try:
		f1=time_domain_hrv(rr)
	except:
		f1=np.zeros(len(f1_nm))*np.nan
	
	try:
		f2=freq_domain_hrv(rr,fs)
	except:
		f2=np.zeros(len(f2_nm))*np.nan
	
	try:
		f3=non_linear_hrv(rr,1)
	except:
		f3=np.zeros(len(f3_nm))*np.nan
	
	try:
		f4=hr_asymmetry(rr)
	except:
		f4=np.zeros(len(f4_nm))*np.nan
	
	try:
		f5=new_hra_feats(rr)
	except:
		f5=np.zeros(len(f5_nm))*np.nan
		
		
	try:
		f6=calc_mspe(dst,scale=scale_val)
		f7=calc_mspe(dif_dst,scale=scale_val)
		f11=calc_mspe(dst_mod,scale=scale_val)
		f12=calc_mspe(dif_dst_mod,scale=scale_val)
	except:
		f6=np.zeros(len(f67_nm)/2)*np.nan
		f11=np.zeros(len(f1112_nm)/2)*np.nan
		f7=np.zeros(len(f67_nm)/2)*np.nan
		f12=np.zeros(len(f1112_nm)/2)*np.nan
	
	try:
		f8,_=calc_mstir(RRs,scale=5)
		f8=np.sum(f8)
	except:
		f8=np.zeros(1)*np.nan
	
	try:
		f9=calc_msod(dst,scale=scale_val,scl_up=3)
		f10=calc_msod(dif_dst,scale=scale_val,scl_up=3)
	except:
		f9=np.zeros(len(f910_nm)/2)*np.nan
		f10=np.zeros(len(f910_nm)/2)*np.nan
	
	try:
		f13,_=get_hr_br_feats(ibi,df_br)
	except:
		f13=np.zeros(len(f13_nm))*np.nan
	
	try:
		f14,_=get_new_br_feats(df_br,rr)
	except:
		f14=np.zeros(len(f14_nm))*np.nan
	
	feats=np.hstack((f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11,f12,f13,f14))
	
	return feats
	

def get_cg_series(xt,scale=5,cg_type='main'):
	"""Returns a list of lists with different scaled RR series """
	Xs=[]
	Xs.append(xt)
	for s in range(2,scale+1):
		if cg_type=='main':
			Xs.append(cg_series(xt,s))

	return Xs
	
	
def get_mot_series(RRs,m,lag):
	#RR series for a given scale
	""" 
	Returns four kind of motif distributions
	--> normal motif distribution
	--> modified motif distribution

	"""
	
	dist=[]
	dist_mod=[]
	
	dist_wt=[]
	dist_mod_wt=[]
	
	for rr in RRs:
		mot_x,mod_mot_x,wt_x=make_mot_series(rr,m,lag)
		
		n_p=len(get_perms(m,0))
		n_pmod=len(get_perms(m,1))
		
		#Normal motif distribution
		mot_dist=get_mot_dist(mot_x,n_p)
		mod_mot_dist=get_mot_dist(mod_mot_x,n_pmod)
		
		
		dist.append(mot_dist)
		dist_mod.append(mod_mot_dist)
		
		
		
	return dist,dist_mod

def get_mot_dist(mot_x,n_p):
	mot_dist = [0] * n_p
	
	for j in range(n_p):
		mot_dist[j] = len(np.where(abs(mot_x-j)==0)[0])
	
	#removing non occring patterns as it breaks entropy
	if len(mot_x)==0:
		mot_dist=np.zeros(n_p)*np.nan
		
	return mot_dist


'''
Description
% hrv0--> mean RR
% hrv1 --> sdRR
% hrv2---> Coeffcient of Variation
% hrv3--> rmsdd
% hrv4--> pNN50
% hrv5--> mean of first differences
% hrv6--> std of absolute first differences
% hrv7--> mean of absolute first differences (Normalized)
%Assuming input RR series is in msec scale (for pNN50 calculation)
'''
def time_domain_hrv(rr):
	hrv=np.zeros([8])

	hrv[0]=np.mean(rr)

	hrv[1]=np.std(rr)

	hrv[2]=hrv[1]/hrv[0]
	
	norm_rr=(rr-hrv[0])/hrv[1]
	first_diff_norm=np.zeros([len(rr)-1])
	first_diff=np.zeros([len(rr)-1])

	for i in range(1,len(rr)):
		first_diff[i-1]=rr[i]-rr[i-1]
		first_diff_norm[i-1]=norm_rr[i]-norm_rr[i-1]

	abs_first_diff=abs(first_diff)
	#print(first_diff)
	abs_first_diff_norm=abs(first_diff_norm)
	
	hrv[3]=np.sqrt(np.mean(first_diff**2))

	hrv[4]=np.sum((abs_first_diff>50)*1)*100/len(abs_first_diff)

	hrv[5]=np.mean(first_diff)

	hrv[6]=np.std(abs_first_diff)

	hrv[7]=np.mean(abs_first_diff_norm)

	return hrv

def freq_domain_hrv(rri,fs=4):
	rri=rri[np.where(rri>0)]
	freq_feat = frequency_domain(rri=rri,fs=fs,method='welch',interp_method='cubic',detrend='linear')  #Adding
	feats=np.array(list(freq_feat.values())) 
	return feats
	
	
'''
Requires pyentrp and nolds package for calculation

Feature Description
hrv0 --> Sample Entropy
hrv1 --> Shannon Entropy
hrv2 --> Approximate Entropy
hrv3 --> Permutation Entropy
hrv4 ---> Correlation Dimension
hrv5 --> Modified Permutation Entropy
NOT IMPLEMENTED YET
hrv6 --> LLE
hrv7 --> Detrend Fluctuation Analysis
'''

def non_linear_hrv(rr,lag):
	rr_std=np.std(rr)
	rval=0.2*rr_std
	hrv=np.zeros([1])
	
	#hrv[0]=nolds.sampen(rr,emb_dim=3,tolerance=rval)

	hrv[0]=ent.shannon_entropy(rr)

	#hrv[2]=ApEn(rr,3,rval)

	#hrv[1]=ent.permutation_entropy(rr,3,lag)
	
	#hrv[2]=nolds.corr_dim(rr,3)

	#hrv[2]=mod_pe(rr,3,lag)

	#hrv[6]=nolds.lyap_r(rr)
	
	#hrv[7]=nolds.dfa(rr)

	return hrv


'''
Heart rate asymmetry feature
hra0 --> Porta Index
hra1 --> Guzik Index
hra2 --> Karmakar Index
hra3 --> Slope Index
'''
def hr_asymmetry(rr):
	#getting poincare plot coordinates
	#2xpotints PP array with PP(1,1)--> Rn+1 (Y-axis) coordinate and PP(2,1)--> Rn
	#coordinate (X-axis)\
	hra=np.zeros([4])	
	poincare=np.zeros([2,len(rr)-1])
	for i in range(1,len(rr)):
		poincare[0,i-1]=rr[i]
		poincare[1,i-1]=rr[i-1]
	#points above
	pu=np.sum((poincare[0,:]>poincare[1,:])*1)
	pd=np.sum((poincare[0,:]<poincare[1,:])*1) #porta index
	hra[0]=(pd*100)/(pd+pu) #guzik index
	d_plus=0;
	d_minus=0;
	for i in range(0,len(rr)-1):
		#for up
		if poincare[0,i]>poincare[1,i]:
			d_plus=d_plus+(abs(poincare[0,i]-poincare[1,i])/np.sqrt(2));
		elif poincare[0,i]<poincare[1,i]:  #for down
			d_minus=d_minus+(abs(poincare[0,i]-poincare[1,i])/np.sqrt(2));
	if (d_plus+d_minus)!=0:
		hra[1]=(d_plus*100)/(d_plus+d_minus)
	else:
		hra[1]=0
	hra[2]=karmakar_index(rr)	
	hra[3]=slope_index(poincare)
	return hra

def karmakar_index(rr):
	I=0
	D=0
	N=0
	for i in range(2,len(rr)):
	#increasing cloud
		if (rr[i]>rr[i-1] and rr[i-1]>rr[i-2]) or (rr[i]>rr[i-1] and rr[i-1]<=rr[i-2]) or (rr[i]>=rr[i-1] and rr[i-1]<rr[i-2]):
			I=I+1   #increasing cloud
		elif (rr[i]<rr[i-1] and rr[i-1]<rr[i-2]) or (rr[i]<rr[i-1] and rr[i-1]>=rr[i-2]) or (rr[i]<=rr[i-1] and rr[i-1]>rr[i-2]):
			D=D+1  #decreasing cloud
		else:
			N=N+1
	
	if D!=0:
		ki=(I/D)
	else:
		ki=0
		
	return ki

def slope_index(pp):
	thetam=0
	thetap=0
	for i in range(0,len(pp[0,:])):
		if pp[0,i]>pp[1,i]:
			thetap=thetap+(np.pi/4-math.atan(pp[0,i]/pp[1,i]))
		elif pp[0,i]<pp[1,i]:  #for down
			thetam=thetam+(np.pi/4-math.atan(pp[0,i]/pp[1,i]))

	if (thetap+thetam)!=0:
		si=(thetap*100)/(thetap+thetam)
	else:
		si=0
	return si




   
"""Extracts new hra features which might exploit the asymmetry in better ways
Features extracted are:

Centroid asymmetry: Instead of SI and GI calculated as a sum for all distances, the centroid for both sides are calculated and >Their distance, SI and GI are calculated
1. dist_cent
2. ang_cent
3. SI_cent
4. GI_cent

5. p50_asy: for +50 accerlation and deceleration
8. sus_ad_asy
7. zc_avg--> Zero Crossing Acc_to_Dcc 
6. zc_asy--> Encodes info about equals 

Center of Mass Asymmetry: Calculate com considering distance from x=y as weight then calculate the same as 1,2,3,4
9. dist_com
10. ang_com
11. SI_com
12. GI_com

13. sd_asy -->Asymmetry in term of dist from x=-y
14. pnn20 asymmetry
 """

def calc_dist_gi_si_ang(cacc,cdec):
	v1=(cacc[0]-cdec[0])  #x axis diff of centroid
	v2=(cacc[1]-cdec[1])
	dist=np.sqrt(v1**2+v2**2)  #not gonna quantify properly
	
	#angle of the centroid with respect to  x+y=c from cacc
	c=cacc[0]+cacc[1]
	xy_int=np.array([c/2,c/2])   
	#vectors for angles
	vec1=cdec-cacc
	vec2=xy_int-cacc 
	ang=py_ang(vec1,vec2)
	
	cent_sp=math.atan(cacc[1]/cacc[0])-np.pi/4
	cent_sn=-math.atan(cdec[1]/cdec[0])+np.pi/4
	si=cent_sp/(cent_sp+cent_sn)*100
	#print(cent_si)
	
	cent_dp=(abs(cacc[1]-cacc[0])/np.sqrt(2))
	cent_dn=(abs(cdec[1]-cdec[0])/np.sqrt(2))
	gi=cent_dp/(cent_dn+cent_dp)*100
	
	return dist,ang,si,gi

def py_ang(v1, v2):
	""" Returns the angle in radians between vecdef get_utc_local(sp_stmps):
	#Takes in list of lists and converts it into equivalent out values
	out=[]
	dates=[]
	for s in sp_stmps:
		tmp=[]
		for i in range(0,len(s)):
			tmp.append(convert_date_time(get_real_date(s[i])))
		out.append(tmp)
		dates.append(get_real_date(s[0])[0:10])
	return out,datestors 'v1' and 'v2'	"""
	cosang = np.dot(v1, v2)
	sinang = la.norm(np.cross(v1, v2))
	return np.arctan2(sinang, cosang)

def graph(formula, x_range):  
	x = np.array(x_range)  
	y = eval(formula)
	plt.plot(x, y)  
	#plt.show()

#graph('x',range(650,850))

def new_hra_feats(rr):

	hra=np.zeros(14)
	poincare=np.zeros([2,len(rr)-1])			
	for i in range(1,len(rr)):
		poincare[0,i-1]=rr[i]
		poincare[1,i-1]=rr[i-1]

	x=(poincare[1,:])
	y=(poincare[0,:])
	  
	cent_acc=np.array([np.mean(x[x<y]),np.mean(y[x<y])])
	cent_dec=np.array([np.mean(x[x>y]),np.mean(y[x>y])])  
	
	hra[0],hra[1],hra[2],hra[3]=calc_dist_gi_si_ang(cent_acc,cent_dec)
	
	p50_p=np.sum(y>x+50)  #50 ms accerlations
	p50_m=np.sum(y<x-50)  #50 ms decelarations
	tmp=p50_p/(p50_m+p50_p)
	if np.isnan(tmp)==False:
		hra[4]=tmp*100
	else:
		hra[4]=50
	
	p20_p=np.sum(y>x+20)  #20 ms accerlations
	p20_m=np.sum(y<x-20)  #20 ms decelarations
	tmp=p20_p/(p20_m+p20_p)
	if np.isnan(tmp)==False:
		hra[13]=tmp*100
	else:
		hra[13]=50
	
	
	val_p=np.where(y>x)
	#print(val)
	#print(np.diff(val))
	diff_p=np.diff(val_p)[0]
	sus_acc=np.sum(diff_p==1)   #when it was high and stayed high
	zc_p=len(diff_p)-sus_acc
	
	
	#for the zero corssing unsustained zero crossings counted only
	val_n=np.where(y<x)
	diff_n=np.diff(val_n)[0]
	sus_dec=np.sum(diff_n==1)   #when it was low and stayed low
	zc_n=len(diff_n)-sus_dec
	
	hra[5]=zc_p/(zc_n+zc_p)*100
	hra[6]=(zc_p+zc_n)/2
	hra[7]=sus_acc/(sus_dec+sus_acc)*100
	
	"""Feature 6 --> Distance from x+y=0 for both half, asymmtry in more
	accelerations when high rather than slow etc--> Side asymmetry"""
	#calculated from x-y+c where c is such that x+y cross over x=y at 400 ms
	sd_plus=0;
	sd_minus=0;
	for i in range(0,len(poincare.T)):
		#for up
		if y[i]>x[i]:
			 sd_plus=sd_plus+(abs(y[i]+x[i]-800)/np.sqrt(2));
		elif y[i]<x[i]:  #for down
			 sd_minus=sd_minus+(abs(y[i]+x[i]-800)/np.sqrt(2));
	
	hra[12]=sd_plus/(sd_plus+sd_minus)*100
		
	Mn=0
	Mp=0
	Ycom_p=0
	Ycom_n=0
	Xcom_p=0
	Xcom_n=0
	for i in range(0,len(x)):	
		mi=abs(y[i]-x[i])/np.sqrt(2)  #considerd mass for this point
		if y[i]>x[i]: #for up
			Mp=Mp + mi
			Ycom_p=mi*y[i]+Ycom_p
			Xcom_p=mi*x[i]+Xcom_p 
		elif y[i]<x[i]:  #for down
			Mn=Mn + mi
			Ycom_n=mi*y[i]+Ycom_n
			Xcom_n=mi*x[i]+Xcom_n 
	com_acc=np.array([Xcom_p/Mp,Ycom_p/Mp])
	com_dec=np.array([Xcom_n/Mn,Ycom_n/Mn])  

	hra[8],hra[9],hra[10],hra[11]=calc_dist_gi_si_ang(com_acc,com_dec)	

	return hra


def get_RR(rr0,rr1,rr2,flg):
	rr_fin=[]
	if len(rr0)>0:
		rr_cov=sum(~np.isnan(rr0))/len(rr0)
		rr3=np.zeros((len(rr0),))
		rr3[:]=np.nan
		rr_arr=np.hstack((np.expand_dims(rr0,1),np.expand_dims(rr1,1),np.expand_dims(rr2,1),np.expand_dims(rr3,1)))
		rr_f=rr_arr.ravel()		
		rr_rem=np.delete(rr_f,np.where(np.isnan(rr_f)==True))
		rr_rem=np.delete(rr_rem,np.where(rr_rem==0))
		if flg==0:
			rr_fin=rr_rem
		else:  #for freq domain features		
			rr_f[np.isnan(rr_f)]=np.nan
			rr_f[np.where(rr_f==0)]=np.nan
			rr_fin=rr_f
	else:
		rr_cov=0

	
	return np.array(rr_fin)*4,rr_cov



def add_perm(perm):
	perm.append((1,1,0))
	perm.append((0,1,1))
	perm.append((1,0,1))
	perm.append((0,1,0))
	perm.append((0,0,0))
	perm.append((0,0,1))
	perm.append((1,0,0))
	
	
	return perm

def get_perms(m,mod_flag):
	perm = (list(itertools.permutations(range(m))))
	#adding similar instances	
	if mod_flag==1:
		perm=add_perm(perm)
		
	perm=np.array(perm)
	return np.array(perm)
	
	
def make_mot_series(time_series,m,lag):
	"""Creates a motif series and returns that with the motif distribution """
	n=len(time_series)
	mot_x=[]
	wt_x=[]
	
	mod_mot_x=[]
	
	perms=get_perms(m,0)
	perms_mod=get_perms(m,1)
	
	for i in range(n - lag * (m - 1)):
		smp=time_series[i:i + lag * m:lag]
		wt=np.var(smp)
		
		#orginal dense ranking of data
		mot_array1 = np.array(rankdata(smp, method='dense')-1)
		val=np.where(np.all(perms==mot_array1,axis=1))[0]
		val_mod=val
		
		if val.shape[0]==0:
			mot_array = np.array(rankdata(smp, method='ordinal')-1)
			val=np.where(np.all(perms==mot_array,axis=1))[0]
			val_mod=np.where(np.all(perms_mod==mot_array1,axis=1))[0]
			
		
		mot_x.append(val[0])
		mod_mot_x.append(val_mod[0])
		wt_x.append(wt)
	
	mot_x=np.array(mot_x)
	mod_mot_x=np.array(mod_mot_x)
	wt_x=np.array(wt_x)
	
	
	return mot_x, mod_mot_x, wt_x


	
def perm_ent(mot_dist):
	"""Returns permutation entropy for the motif distribution given """ 
	c=mot_dist
	c = [element for element in c if element != 0]
	p = np.divide(np.array(c), float(sum(c)))
	pe = -sum(p * np.log(p))
	return pe
	
def cg_series(x,scale):
	x_scale=[]
	for i in range(0,len(x),scale):
		#not divided by scale
		val=np.sum(x[i:i+scale])/len(x[i:i+scale])

		x_scale.append(val)

	return np.array(x_scale)
	
def ord_dist(mot_dist_x,mot_dist_y):
	"""Returns ordinal distance between two motif distribution """
	c_x=mot_dist_x
	c_y=mot_dist_y
	p_x=np.divide(np.array(c_x), float(sum(c_x)))
	p_y=np.divide(np.array(c_y), float(sum(c_y)))
	m=len(p_x)
	sq_diff=0
	for j in range(m):
		sq_diff=sq_diff+(p_x[j] -p_y[j])**2
		
	dm=np.sqrt(m/(m-1))*np.sqrt(sq_diff)
	return dm
		


def calc_mspe(distS,scale=10):
	"""Calculates the scaled permutation entropy and thier oridnal sum"""
	"""Takes an input which is a list of lists where distS[i] is motif dist with scale i """
	
	mspe=[]
	for s in range(0,scale):
		distm=distS[s]
		pe=perm_ent(distm)
		mspe.append(pe)

	distS=np.array(distS)
	mspe=np.array(mspe)
	dm_mat=np.zeros((scale,scale))
	
	for i  in range(0,scale-1):
		for j  in range(i,scale):
			dm=ord_dist(distS[i],distS[j])
			dm_mat[i,j]=dm
			dm_mat[j,i]=dm


	com_wts=np.zeros(scale)
	for i in range(0,scale):
		com_wts[i]=np.sum(dm_mat[i,:])/(scale-1)

	com_mspe=np.sum(np.multiply(com_wts,mspe))/np.sum(com_wts)
	mspe_fin=np.hstack((mspe,com_mspe))
	
	return mspe_fin
	
def calc_mstir(Xs,scale=10):
	base='time_ai'
	feat_names=[]
	for i in range(0,scale):
		feat_names.append(base+str(i))
	
	mstir_fin=[]
	for s in range(0,scale):
		xs=Xs[s]
		xs_diff=np.diff(xs)
		ai=(len(np.where(xs_diff<0)[0])-len(np.where(xs_diff>0)[0]))/len(xs_diff)
		#asy=hr_asymmetry(xs)
		#mstir_fin.append(np.hstack(asy,ai))
		mstir_fin.append(ai)
		
	mstir_fin=np.array((mstir_fin))
	return mstir_fin,feat_names
	
"""
#Sample test code 
perm=get_perms(m=3,mod_flag=0)
no_perms=len(perm)
xt=np.array([1,3,4,2,4,6,2,3,6,7,5,8,11,9,2])
yt=np.array([1,5,4,2,4,1,9,3,2,7,5,8,3,9,2])
xm,distx=make_mot_series(xt,m=3,lag=1,perms=perm)
ym,disty=make_mot_series(yt,m=3,lag=1,perms=perm)
pe=perm_ent(distx)
dm=ord_dist(distx,disty,m=len(perm))
out=calc_mspe(xt=np.random.rand(1000),m=3,lag=1,mod_flag=1,scale=10)
out=calc_mstir(xt=np.random.rand(1000),scale=10)
"""


def calc_msod(distS,scale=10,scl_up=2):
	"""Calculates the ordinal distance between the scales -- simple modifie version of calc_mspe. The features are distances of scale 1 till scale up (scl_up=2) from the other scales and their sum"""
	
	mspe_dist=np.array(distS)
	dm_mat=np.zeros((scale,scale))
	for i  in range(0,scale-1):
		for j  in range(i,scale):
			dm=ord_dist(mspe_dist[i],mspe_dist[j])
			dm_mat[i,j]=dm
			dm_mat[j,i]=dm

	feat_vec=np.empty((0))
	for h in range(0,scl_up):
		feat_vec=np.hstack((feat_vec,dm_mat[h,h+1:]))
		#Statistics of the differences -- Add more
		feat_vec=np.hstack(( feat_vec,sum(dm_mat[h,h+1:]) ,sum(np.diff(dm_mat[h,h+1:]))  ))
		
		
	return feat_vec

"""Test Code"""
"""
Id='0a85fd46-fada-434c-9f7a-08b81f9ed8e7'
print(Id)	
om_path='./omsignal'
f_name=om_path+'/'+Id+'_omsignal.csv'
date='2018-06-14'
	
#open the csv for a given user id
df=pd.read_csv(f_name) 
RR_uid=df[['Timestamp','RR0','RR1','RR2']]
RR_uid['date']=(RR_uid.Timestamp.map(lambda x: x[0:10]))
RR_ui=RR_uid[RR_uid.date==date]

fin_RR=np.array(RR_ui[['RR0','RR1','RR2']])
ibi,rr_cov=get_RR(fin_RR[:,0],fin_RR[:,1],fin_RR[:,2],1)
print(calc_mod_energy(ibi,4))"""




def get_mi(in1, in2):
	## tweak k
	in1 = in1.reshape(-1, 1)
	in2 = in2.reshape(-1, 1)

	return (mutual_information((in1,in2),k=5))


def get_cc_features(in1, in2):
	
	## tweak fs and nperseg
	## f, Pxy = signal.csd(in1, in2, fs=16, nperseg=120)

	f, Pxy = signal.coherence(in1, in2,fs=4)

	p = np.abs(Pxy)

	return np.array((p.mean(), p.std(), stats.kurtosis(p), p.max(), p.min(), np.abs(p.max()-p.min()), np.median(p)))



def get_hr_br_feats(rr_5,df_br):
	fnm=['brhr_mi','brhr_msc_mn','brhr_msc_std','brhr_msc_kurt','brhr_msc_max','brhr_msc_min','brhr_msc_rng','brhr_msc_med','brhr_pearson']
	
	br_5=np.array(df_br[['inhale0_amp','exhale0_amp','inhale1_amp','exhale1_amp']])
	
	br_5[:,1]=br_5[:,1]*-1
	br_5[:,3]=br_5[:,3]*-1
	br_5=br_5.ravel()
	rr_5=rr_5.ravel()

	df_tmp=pd.Series(br_5)
	df_rr=pd.Series(rr_5)
	rr_5=np.array(df_rr.interpolate())
	br_5=np.array(df_tmp.interpolate())



	br_5=(br_5[~np.isnan(rr_5)])
	rr_5=(rr_5[~np.isnan(rr_5)])
	rr_5=(rr_5[~np.isnan(br_5)])
	br_5=(br_5[~np.isnan(br_5)])
	
	try:
		br_5=preprocessing.scale(br_5)
		rr_5=preprocessing.scale(rr_5)
		f1=(get_mi(rr_5, br_5))
		f2=(get_cc_features(rr_5, br_5))
		f3=np.corrcoef(rr_5,br_5)[0,1]
	except:
		return np.zeros(len(fnm))*np.nan,fnm
	return np.hstack((f1,f2,f3)),fnm

def get_new_br_feats(df_br,ibi):
	"""The new features to be calculated include
	i. Inhale amplitude variation
	ii. Exhale Amplitude Varition
	iii. Inhale exhall ratio variability: Calculate Inhale/Exhale Ratio series
	iv. Fractal Features"""
	
	#Inhalation and exhalation amplitude features:
	f1_nm=['br_inh_mean','br_inh_std','br_inh_cv','br_exh_mean','br_exh_std','br_exh_cfv']
	
	f1=np.zeros((6))*np.nan
	try:
		in_am,ex_am=make_inex_am_series(df_br)
		f1[0]=np.mean(in_am)
		f1[1]=np.std(in_am)
		f1[2]=f1[0]/f1[1]
		f1[3]=np.mean(ex_am)
		f1[4]=np.std(ex_am)
		f1[5]=f1[3]/f1[4]
	except:
		f1=f1
	
	#Features of IER variability and HRV- IER interaction
	f2_nm=['br_ier_mean','br_ier_std','br_ier_cv','br_ier_pe','br_ier_corr_dim','br_ier_samp_en','br_ier_hrv_mn','br_ier_hrv_std']
	f2=np.zeros((8))*np.nan
	ier=make_ier_series(df_br)
	try:
		ier=make_ier_series(df_br)
		f2[0]=np.mean(ier)
		f2[1]=np.std(ier)
		f2[2]=f1[0]/f1[1]
		f2[3]=ent.permutation_entropy(ier,3,1)
	except:
		f2=f2
		
	try:
		f2[4]=nolds.corr_dim(ier,3)
		f2[5]=nolds.sampen(ier,2)
		f2[6]=np.mean(ibi)/f2[0]
		f2[7]=np.std(ibi)/f2[1]
	except:
		f2=f2
	
	#Fractal features for iterbreathing inteval
	f3_nm=['br_ibi_mn','br_ibi_std','br_ibi_corr_dim','br_ibi_pe','br_dif_ibi_pe','br_ibi_samp_en','br_dif_ibi_samp_en']
	f3=np.zeros((7))*np.nan
	
	try:
		ibri=make_ibri_series(df_br)
		f3[0]=np.mean(ibri)
		f3[1]=np.std(ibri)
		f3[3]=ent.permutation_entropy(ibri,3,1)
		f3[4]=ent.permutation_entropy(abs(np.diff(ibri)),3,1)
	except:
		f3=f3
		
	try:
		f3[2]=nolds.corr_dim(ibri,3)
		f3[5]=nolds.sampen(ibri,2)
		f3[6]=nolds.sampen(abs(np.diff(ibri)),2)
	except:
		f3=f3
	
	feats=np.hstack((f1,f2,f3))
	f_name=f1_nm+f2_nm+f3_nm
	return feats,f_name
	

	
	
def make_inex_am_series(df_br):
	"""Returns the inhale/exhale amplitude series """
	
	in_am=np.array(df_br[['inhale0_amp','inhale1_amp']])
	ex_am=np.array(df_br[['exhale0_amp','exhale1_amp']])
	in_am=in_am.ravel()
	ex_am=ex_am.ravel()
	in_am=in_am[~np.isnan(in_am)]
	ex_am=ex_am[~np.isnan(ex_am)]
	return in_am,ex_am
	
def make_ier_series(df_br):
	"""Get inhale exhale variability ratio:
	Use some specific rules:
	i. Inhale will follow exhale for most cases, on top of that
	ii. Inhale one with exhale one as well --> could be ignored for the analysis
	iii. For inhale exhale offset empty segments corrspond to 1 sec, others to 40 ms * number of ticks
	 """
	    
	in_ex=np.array(df_br[['inhale0_offset','exhale0_offset']])
	in_ex=in_ex*40  #making the time series in mili seconds
	in_t=[]
	ex_t=[]
	ext_time=0  #extra time in msec to add to event
	l_eve=0   #if the last NOTED event was inhale(0), exhale(1)
	for ix in range(0,in_ex.shape[0]):
		if np.isnan(in_ex[ix,0])==False and np.isnan(in_ex[ix,1])==True:
			in_t.append(ext_time+in_ex[ix,0])
			ext_time=1000-in_ex[ix,0]
			l_eve=0
		elif np.isnan(in_ex[ix,0])==True and np.isnan(in_ex[ix,1])==False:
			ex_t.append(ext_time+in_ex[ix,1])
			ext_time=1000-in_ex[ix,1]
			l_eve=1
		elif  np.isnan(in_ex[ix,0])==True and np.isnan(in_ex[ix,1])==True:
			ext_time=ext_time+1000
		elif np.isnan(in_ex[ix,0])==False and np.isnan(in_ex[ix,1])==False:
			if l_eve==0:  #Last event was inhale: read exhale first
				ex_t.append(ext_time+in_ex[ix,1])
				ext_time=0
				in_t.append(ext_time+in_ex[ix,0]-in_ex[ix,1])
				ext_time=1000-in_ex[ix,0]
			elif l_eve==1:
				in_t.append(ext_time+in_ex[ix,0])
				ext_time=0
				ex_t.append(ext_time+in_ex[ix,1]-in_ex[ix,0])
				ext_time=1000-in_ex[ix,1]
		if ext_time>3000: #Long time due to noise in system (all nan)
			ext_time=1000   #reset it to within limit
			
	
	in_t=np.array(in_t)
	ex_t=np.array(ex_t)
	if len(in_t)==len(ex_t):
		ier=np.divide(in_t,ex_t)
	elif len(in_t)>len(ex_t):
		in_t=in_t[0:len(ex_t)]
		ier=np.divide(in_t,ex_t)
	elif len(ex_t)>len(in_t):
		ex_t=ex_t[0:len(in_t)]
		ier=np.divide(in_t,ex_t)
		
	return ier
#test array
#br=np.array([[2,np.nan],[np.nan,18],[np.nan,np.nan],[12,np.nan],[np.nan,15],[np.nan,np.nan],[2,np.nan],[np.nan,5]])
#output
#in_t=[80.0, 1760.0, 1480.0]
#ex_t=[1640.0, 1120.0, 1120.0]

def make_ibri_series(df_br):
	"""Creates the inter-breathing interval time series using inhale points
	only: not using exhale as trying to follow time series"""
	inh=np.array(df_br[['inhale0_offset']])*40
	ibri=[]
	ex_time=0
	#inh=inh[np.isnan(inh)]=1000 #Exhale information ppackets useless
	for ix in range(0,len(inh)):
		if np.isnan(inh[ix])==True:
			ex_time=1000
		else:
			ibri.append(ex_time+inh[ix])
			ex_time=1000-inh[ix]
	
	ibri=np.array(ibri).T.squeeze()
	return np.array(ibri)
	
def ApEn(U, m, r):

	def _maxdist(x_i, x_j):
		return max([abs(ua - va) for ua, va in zip(x_i, x_j)])

	def _phi(m):
		x = [[U[j] for j in range(i, i + m - 1 + 1)] for i in range(N - m + 1)]
		C = [len([1 for x_j in x if _maxdist(x_i, x_j) <= r]) / (N - m + 1.0) for x_i in x]
		return (N - m + 1.0)**(-1) * sum(np.log(C))

	N = len(U)

	return abs(_phi(m+1) - _phi(m))

"""Calculate the modified Permutation Entropy for a degree 3"""

def mod_pe(time_series, m, delay):
	n = len(time_series)
	permutations = (list(itertools.permutations(range(m))))
	#adding similar instances	
	permutations.append((1,1,0))
	permutations.append((0,1,1))
	permutations.append((1,0,1))
	permutations.append((0,1,0))
	permutations.append((0,0,0))
	permutations=np.array(permutations)
	c = [0] * len(permutations)

	for i in range(n - delay * (m - 1)):
		sorted_index_array = np.array(rankdata(time_series[i:i + delay * m:delay], method='dense')-1)
		for j in range(len(permutations)):
			if abs(permutations[j] - sorted_index_array).any() == 0:
				c[j] += 1

	c = [element for element in c if element != 0]
	p = np.divide(np.array(c), float(sum(c)))
	pe = -sum(p * np.log(p))
	return pe


def nearest_distances(X, k=1):
	'''
	X = array(N,M)
	N = number of points
	M = number of dimensions
	returns the distance to the kth nearest neighbor for every point in X
	'''
	knn = NearestNeighbors(n_neighbors=k)
	knn.fit(X)
	d, _ = knn.kneighbors(X) # the first nearest neighbor is itself
	return d[:, -1] # returns the distance to the kth nearest neighbor


def entropy_gaussian(C):
	'''
	Entropy of a gaussian variable with covariance matrix C
	'''
	if np.isscalar(C): # C is the variance
		return .5*(1 + np.log(2*pi)) + .5*np.log(C)
	else:
		n = C.shape[0] # dimension
		return .5*n*(1 + np.log(2*pi)) + .5*np.log(abs(det(C)))


def entropy(X, k=1):
	''' Returns the entropy of the X.
	Parameters
	===========
	X : array-like, shape (n_samples, n_features)
		The data the entropy of which is computed
	k : int, optional
		number of nearest neighbors for density estimation
	
	'''

	# Distance to kth nearest neighbor
	r = nearest_distances(X, k) # squared distances
	n, d = X.shape
	volume_unit_ball = (pi**(.5*d)) / gamma(.5*d + 1)
	
	return (d*np.mean(np.log(r + np.finfo(X.dtype).eps))
			+ np.log(volume_unit_ball) + psi(n) - psi(k))


def mutual_information(variables, k=1):
	'''
	Returns the mutual information between any number of variables.
	Each variable is a matrix X = array(n_samples, n_features)
	where
	  n = number of samples
	  dx,dy = number of dimensions
	Optionally, the following keyword argument can be specified:
	  k = number of nearest neighbors for density estimation
	Example: mutual_information((X, Y)), mutual_information((X, Y, Z), k=5)
	'''
	if len(variables) < 2:
		raise AttributeError(
				"Mutual information must involve at least 2 variables")
	all_vars = np.hstack(variables)
	return (sum([entropy(X, k=k) for X in variables])
			- entropy(all_vars, k=k))


def mutual_information_2d(x, y, sigma=1, normalized=False):
	"""
	Computes (normalized) mutual information between two 1D variate from a
	joint histogram.
	Parameters
	----------
	x : 1D array
		first variable
	y : 1D array
		second variable
	sigma: float
		sigma for Gaussian smoothing of the joint histogram
	Returns
	-------
	nmi: float
		the computed similariy measure
	"""
	bins = (256, 256)

	jh = np.histogram2d(x, y, bins=bins)[0]

	# smooth the jh with a gaussian filter of given sigma
	ndimage.gaussian_filter(jh, sigma=sigma, mode='constant',
								 output=jh)

	# compute marginal histograms
	jh = jh + EPS
	sh = np.sum(jh)
	jh = jh / sh
	s1 = np.sum(jh, axis=0).reshape((-1, jh.shape[0]))
	s2 = np.sum(jh, axis=1).reshape((jh.shape[1], -1))

	# Normalised Mutual Information of:
	# Studholme,  jhill & jhawkes (1998).
	# "A normalized entropy measure of 3-D medical image alignment".
	# in Proc. Medical Imaging 1998, vol. 3338, San Diego, CA, pp. 132-143.
	if normalized:
		mi = ((np.sum(s1 * np.log(s1)) + np.sum(s2 * np.log(s2)))
				/ np.sum(jh * np.log(jh))) - 1
	else:
		mi = ( np.sum(jh * np.log(jh)) - np.sum(s1 * np.log(s1))
			   - np.sum(s2 * np.log(s2)))

	return mi

def get_utc_local(sp_stmps):
	#Takes in list  and converts it into equivalent out values
	out=[]
	dates=[]
	tmp=[]
	for s in sp_stmps:		
		tmp.append(convert_date_time(get_real_date(s)))	
		dates.append(get_real_date(s)[0:10])
	
	return np.array(tmp),(np.array(dates))
	
def get_real_date(stmp):
	utc_dt = datetime.utcfromtimestamp(stmp).replace(tzinfo=pytz.utc)
	tz = pytz.timezone('America/Los_Angeles')
	dt=utc_dt.astimezone(tz)
	real_time=dt.strftime('%Y-%m-%d %H:%M:%S ')
	return real_time	

def get_folders_om(om_path, do_include_gz=False):
	folder=[]
	om_dates=[]
	par_ids=[]
	for root, dirs, files in os.walk(om_path):
		for di in dirs:
			folder.append(di)
			om_dates.append(di[:10])
		for name in files:
			if name.endswith((".csv")) or (do_include_gz and name.endswith(".csv.gz")):
				 par_ids.append(name.split('_')[0])
	return (np.unique(np.array(par_ids))),np.array(folder),np.array(om_dates)
	
def add_unix_dat_cols(df_om,df_fb,df_sur):
	df_om['date']=(df_om.Timestamp.map(lambda x: x[0:10])) 
	df_fb['date']=(df_fb.Timestamp.map(lambda x: x[0:10]))
	df_om['UTC']=(df_om.Timestamp.map(lambda x: convert_date_time(x)))
	df_fb['UTC']=(df_fb.Timestamp.map(lambda x: convert_date_time(x)))
	df_sur['date']=(df_sur.timestamp.map(lambda x: x[0:10]))	
	df_sur['UTC']=(df_sur.timestamp.map(lambda x: convert_date_time(x)))
	
	return df_om,df_fb,df_sur
	
def sensor_wear_date(df_om,df_fb,df_sur):
	#print('Om Dates are \n')
	om_dt=(np.unique(np.array(df_om['date'])))
	#print('Fitbit Dates are \n')
	fb_dt=(np.unique(np.array(df_fb['date'])))
	
	sur_dt=(np.unique(np.array(df_sur['date'])))
	return om_dt,fb_dt,sur_dt
	
def weighted_avg_and_std(values, weights):
	average = np.average(values,axis=0, weights=weights)
	# Fast and numerically precise:
	variance = np.average((values-average)**2,axis=0, weights=weights)
	return (average, np.sqrt(variance))


"""Older version -- just rr coverage considerd """
def calc_feats(series):  #16 replaced by 23
	print(series.shape)
	wts=np.expand_dims(series[:,-1],1)
	wt_fin=np.repeat(wts, series.shape[1]-1, axis=1)  #for the number of features
	series=series[:,0:-1]
	feats=np.zeros([13,series.shape[1]])
	feats[0]=np.mean(series,axis=0)
	feats[1]=np.std(series,axis=0)
	feats[2]=feats[0]/feats[1]
	feats[3]=np.median(series,axis=0)
	feats[4]=np.amin(series,axis=0)
	feats[5]=np.amax(series,axis=0)
	feats[6]=stats.skew(series,axis=0)
	feats[7]=stats.kurtosis(series,axis=0)
	feats[8]=np.percentile(series,25,axis=0)
	feats[9]=np.percentile(series,75,axis=0)
	feats[10],feats[11]=weighted_avg_and_std(series, wt_fin)
	feats[12]=feats[10]/feats[11]
	
	return np.reshape(feats,(13*(series.shape[1])))  #Unrolling the series 

"""Newer version -- just rr coverage considerd """
def calc_feats_msqi(series):  #16 replaced by 23
	#calculates both for rr cov and msqi weights
	qi_wts=np.expand_dims(series[:,-1],1)
	rr_wts=np.expand_dims(series[:,-2],1)
	qi_wt_fin=np.repeat(qi_wts, series.shape[1]-2, axis=1)  #for the number of features
	rr_wt_fin=np.repeat(rr_wts, series.shape[1]-2, axis=1)  #for the number of features
	series=series[:,0:-2]
	feats=np.zeros([16,series.shape[1]])
	feats[0]=np.mean(series,axis=0)
	feats[1]=np.std(series,axis=0)
	feats[2]=feats[0]/feats[1]
	feats[3]=np.median(series,axis=0)
	feats[4]=np.amin(series,axis=0)
	feats[5]=np.amax(series,axis=0)
	feats[6]=stats.skew(series,axis=0)
	feats[7]=stats.kurtosis(series,axis=0)
	feats[8]=np.percentile(series,25,axis=0)
	feats[9]=np.percentile(series,75,axis=0)
	feats[10],feats[11]=weighted_avg_and_std(series, rr_wt_fin)
	feats[12]=feats[10]/feats[11]
	feats[13],feats[14]=weighted_avg_and_std(series, qi_wt_fin)
	feats[15]=feats[13]/feats[14]
	
	return np.reshape(feats,(16*(series.shape[1])))  #Unrolling the series	 

def convert_date_time(datetimestr):
	datetimestr=datetimestr+' -0000'
	try:
		# Date string with fractions of second e.g. '2017-11-09T23:24:00.00 -0800'
		dt_obj = datetime.strptime( datetimestr, '%Y-%m-%dT%H:%M:%S.%f %z')
	except:
		# Date string no fractions of second, e.g. '2017-11-09T23:24:00 -0800'
		dt_obj = datetime.strptime( datetimestr, '%Y-%m-%d %H:%M:%S %z')
		
	unixtime = dt_obj.timestamp()
	return unixtime

def get_all_fname():
	f1_nm=get_time_fname()
	f2_nm=get_freq_fname()
	f3_nm=get_nl_fname()
	f4_nm=get_hra_fname()
	f5_nm=get_nhra_fname()
	f67_nm=get_mspe_fname(scale=5,mod_flag=0)
	f8_nm=get_mstir_fname()
	f910_nm=get_msod_fname(scale=5,scl_up=3,mod_flag=0)
	f1112_nm=get_mspe_fname(scale=5,mod_flag=1)
	f13_nm=get_hr_br_fname()
	f14_nm=get_new_br_fname()
	return f1_nm+f2_nm+f3_nm+f4_nm+f5_nm+f67_nm+f8_nm+f910_nm+f1112_nm+f13_nm+f14_nm



"""Contains all the different features name masks required for feature extraction """

def get_hr_br_fname():
	fnm=['brhr_mi','brhr_msc_mn','brhr_msc_std','brhr_msc_kurt','brhr_msc_max','brhr_msc_min','brhr_msc_rng','brhr_msc_med','brhr_pearson']
	return fnm

def get_new_br_fname():
	f1_nm=['br_inh_mean','br_inh_std','br_inh_cv','br_exh_mean','br_exh_std','br_exh_cfv']
	f2_nm=['br_ier_mean','br_ier_std','br_ier_cv','br_ier_pe','br_ier_corr_dim','br_ier_samp_en','br_ier_hrv_mn','br_ier_hrv_std']
	f3_nm=['br_ibi_mn','br_ibi_std','br_ibi_corr_dim','br_ibi_pe','br_dif_ibi_pe','br_ibi_samp_en','br_dif_ibi_samp_en']
	
	return f1_nm+f2_nm+f3_nm


def get_time_fname():
	nm_time=['meanRR','sdRR','Coef_Var','rmsdd','pNN50','mn_first_diff','std_abs_first_diff','mn_abs_first_diff_norm']
	return nm_time

def get_freq_fname():
	nm_freq=['total_f','vlf','lf','hf','lf_hf','lfnu','hfnu']
	return nm_freq
	
def get_nl_fname():
	nm_nl=['Sh_Ent']
	return nm_nl
	
def get_hra_fname():
	nm_hra=['Porta_Index','Guzik_Index','Karmakar_Index','Slope_Index']
	return nm_hra
	
def get_nhra_fname():	
	nm_nhra=['dist_cent','ang_cent','SI_cent','GI_cent','p50_asy','zc_asy','zc_avg','sus_ad_asy','dist_com','ang_com','SI_com','GI_com','sd_asy','p20_asy']
	return nm_nhra

def get_mspe_fname(scale=5,mod_flag=0):
	
	#feature and functional names
	feat_names=[]
	if mod_flag==0:
		base='PE_s'
	else:
		base='Mod_PE_s'
	
	
	for i in range(1,scale+1):
		feat_names.append(base+str(i))

	feat_names.append('Ord_wt_'+base)
	
	mspe_names=feat_names
	
	diff_mspe=[]
	
	for i,nm in enumerate(mspe_names):
		diff_mspe.append('dif_'+nm)
	

	feats=mspe_names+diff_mspe

		
	return feats
	
def get_msod_fname(scale=5,scl_up=3,mod_flag=0):
	
	#feature and functional names
	feat_names=[]
	if mod_flag==0:
		base='Ordist_s'
	else:
		base='Mod_Ordist_s'
		
	for j in range(1,scl_up+1):	
		for i in range(1,scale+1):
			if i>j: #to avoid repeatability and other issues
				feat_names.append(base+str(j)+'_s'+str(i))
		feat_names.append(base+str(j)+'_sum')
		feat_names.append(base+str(j)+'_sum_fd')
	
	msod_names=feat_names
	diff_msod=[]
	for i,nm in enumerate(msod_names):
		diff_msod.append('dif_'+nm)
	
	#On OD and Diff OD considerd and nothing else
	feats=msod_names+diff_msod
	
	return feats

def get_mstir_fname():
	ft=['tot_asym_index']
	return ft
	
def get_all_fname():
	f1_nm=get_time_fname()
	f2_nm=get_freq_fname()
	f3_nm=get_nl_fname()
	f4_nm=get_hra_fname()
	f5_nm=get_nhra_fname()
	f67_nm=get_mspe_fname(scale=5,mod_flag=0)
	f8_nm=get_mstir_fname()
	f910_nm=get_msod_fname(scale=5,scl_up=3,mod_flag=0)
	f1112_nm=get_mspe_fname(scale=5,mod_flag=1)
	f13_nm=get_hr_br_fname()
	f14_nm=get_new_br_fname()
	
	feat=f1_nm+f2_nm+f3_nm+f4_nm+f5_nm+f67_nm+f8_nm+f910_nm+f1112_nm+f13_nm+f14_nm
	
	feats=[]
	for t in feat:
		tmp='INRS_'+t
		feats.append(tmp)
		
	return feats

	
def get_br_all_fname():
	f13_nm=get_hr_br_fname()
	f14_nm=['AvgBreathingRate','AvgBreathingDepth','StdDevBreathingRate','StdDevBreathingDepth']
	return f13_nm
