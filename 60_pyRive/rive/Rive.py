# -*- coding: utf-8 -*-
#!/usr/bin/python

"""
RIVE Model - Sorbonne University (SU) / CNRS
https://www.federation-fire.cnrs.fr/rive

Created on March 2014

@authors:
    Marie.Silvestre@sorbonne-universite.fr (CNRS - FR3020 FIRE)
    Vincent.Thieu@sorbonne-universite.fr (SU - UMR7619 METIS)
    Gilles.Billen@sorbonne-universite.fr (CNRS - UMR7619 METIS)
    Josette.Garnier@sorbonne-universite.fr (CNRS - UMR7619 METIS)
    Audrey Marescaux (CNRS - UMR7619 METIS)
    Xingcheng.Yan@sorbonne-universite.fr (CNRS - UMR7619 METIS)
    Shuaitao.Wang@sorbonne-universite.fr (CNRS - UMR7619 METIS)

License:
This program and the accompanying materials are made available under the
terms of the Eclipse Public License 2.0 which is available at
http://www.eclipse.org/legal/epl-2.0, or the GNU General Public License,
version 3 or any later version with the GNU Classpath Exception which is available
at https://www.gnu.org/software/classpath/license.html.
SPDX-License-Identifier: EPL-2.0 OR GPL-3.0-or-later WITH Classpath-exception-2.0

Description:
- benthic processes
- phytoplankton growth
- biogeo processes in water column
"""

from __future__ import division, print_function, unicode_literals
from math import exp, fabs
from statistics import mean
import numpy as np
from .Rive_var import (DIA, GRA, CYA, ZOR, ZOC, LHB, SHB, AOB, NOB, AFC, FFC,
                      SPM, NO3, NH4, NO2, PO4, TIP, PIP, DSI, BSI,
                      DOM1, DOM2, DOM3, POM1, POM2, POM3, SODA,
                      OXY, CH4, N2O, TA, DIC, CO2, pH,
                      listPhyto, listZoo, listHetBact, listGaz,
                      listSed, listNitBact,listVar,listBent,
                      p, c, flog)
from .Rive_functions import phosph, mich, fTemp, calcCO2

c['convC2Chl'] = 1000 / 35  # conversion: mgC into microgChla
cn = 7  # weight / weight C/N ratio of biodegradable organic matter
cp = 40  # weight / weight C/P ratio of biodegradable organic matter
N = 24 #number of simulations needed to run SW 20/01/2022

def main(ctime, ftime, temp, depth, dlx, dilu):
    """RIVE main function
    :param ctime: time cursor indicating the day or decade of the year
    :param ftime: time cursor multiplying factor (number of days in a ctime period) eg 1 for day; 10 for decade etc
    :param temp: water temperature in °C
    :param depth: river/reservoir depth in meters
    :param dlx: restime time in hour (for RIVER = time to travel 1 km, for RESERVOIR = 24h)
    :param dilu: dilution rate in h-1
    """

    step_t_cmuf = 0.5  # Time step to run computation in calcmuf every 30min for 1 day
    step_d_cmuf = 0.02  # Depth step to run calcMuf 0.02 => every 2 cm along the depth profil
    step_t_rive = min(0.1, dlx) # Time step to run calcWaterColumn (in h, max = 0.1 h = 6 min)

    
    if(dlx == 24):
        N = 1
        
    # range_t_rive from 0 to time to travel 1 km (=dlx) using st_rive
    # range_t_rive = (x * step_t_rive for x in range(1, int(dlx / step_t_rive) + 1))
    
    for i in range(N):
        range_t_rive = np.arange(i, dlx + i, step_t_rive)
        for ttx in range_t_rive :
            if(ttx > 23.99):
                ttx -= 24.
                
            # zf: depth of the upper fluid sediment layer, in m
            density = 2300000  # density of the sediment material, in g/m3
            porosity = 0.88  # porosity of the fluid sediment layer, dimensionless
            p['zf'] = SPM.cBent / (density * (1 - porosity))

            # compaction rate of the upper sediment layer in h-1
            if SPM.cBent < c['sedThreshold']:
                p['compaction'] = 0
            else:
                p['compaction'] = c['compactionMax'] * (SPM.cBent - c['sedThreshold']) / SPM.cBent

            # benthic processes
            calcBent(temp=temp, depth=depth, id_sim=i)

            # calcMuf_seq_conc: run every time step
            calcMuf_nycthemeral(ctime=ctime, ftime=ftime, ttx=ttx, depth=depth, step_t_rive=step_t_rive, step_t_cmuf=step_t_cmuf, step_d_cmuf=step_d_cmuf, id_sim=i)
            # calc biogeo in WaterColumn
            calcWaterColumn(ctime=ctime, ftime=ftime, depth=depth, dlx=dlx, dilu=dilu, st=step_t_rive, temp=temp,id_sim=i)
    
    # SW 20/01/2022 add calculation of average concentration for river case
    calcMeanConcentration()

def calcBent(temp, depth, id_sim):
    """ Benthic processes
    :param temp: temperature in °C
    :param depth: river/reservoir depth in meters
    """
    # Coxd: carbon oxidant demand in equ/m²/h
    cOxD = 4 / 12 * ((p['k1b'] * POM1.cBentdlx[id_sim] + c['k2b'] * POM2.cBentdlx[id_sim]) + p['compaction'] * (POM1.cBentdlx[id_sim] + POM2.cBentdlx[id_sim]))
    p['respBent'] = cOxD * 12 / 4 / depth  # gC/m-3/h ou mgC/l/h

    # Ammonr: depth integrated ammonification rate, in gN/m²/h
    ammonifRate = (cOxD * 12 / 4) / cn

    # Pminr: depth integrated rate of organic phosphorus mineralisation, in gP/m²/h
    pMinRate = (cOxD * 12 / 4) / cp

    # SiDissRate: depth integrated maximum biogenic silica dissolution rate
    SiDissRate = p['kbSi'] * BSI.cBentdlx[id_sim] + p['compaction'] * BSI.cBentdlx[id_sim]

    # Fluxes of dissolved nutrients
    #TODO: define topt and dti to replace 20 and 17

    fNITendo = 0.015 * p['zf'] * OXY.cH2Odlx[id_sim] / OXY.sat * fTemp(temp=temp, topt=20, dti=17)  # in gN/m²/h
    fNITexo = 0.00125 * NH4.cH2Odlx[id_sim] * p['zf'] / (p['zf'] + 0.002) * OXY.cH2Odlx[id_sim] / OXY.sat * fTemp(temp=temp, topt=20, dti=17) # in gN/m²/h
    fNH4 = 0.9 - 140 * p['zf'] ** 3
    NH4.fluxBent = - fNH4 * ammonifRate + fNITendo + fNITexo  # in gN/m²/h

    nitOxd = 8 / 14 * (fNITendo + fNITexo)

    fOXY = 1 - cOxD / (cOxD + 0.00075 * (OXY.cH2Odlx[id_sim] / OXY.sat) / p['zf'])

    OXY.fluxBent = 32 / 4 * (fOXY * cOxD + nitOxd)  # in gO2/m²/h

    if OXY.cH2Odlx[id_sim] == 0:
        OXY.cH2Odlx[id_sim] = 0.00000001

    molarRatio = NO3.cH2Odlx[id_sim] / 14 / (OXY.cH2Odlx[id_sim] / 32) # molar ratio between NO3 and OXY in the overlaying layer
                                                 # modified by XY 04/04/2021

    a = 2 * molarRatio / (molarRatio + 1.8)  # dimensionless
    b = NO3.cH2Odlx[id_sim] / 14 * (1 - p['zf'] / (p['zf'] + 0.0005))  # dimensionless

    fNO3 = a * (1 - cOxD ** 0.7 / (cOxD ** 0.7 + b ** 0.7))  # in equ/m²/h

    NO3.fluxBent = 14 / 5 * fNO3 * cOxD - fNITendo - fNITexo   # in gN/m²/h

    fPO4 = 1 - (p['zf'] ** 2.5 / (p['zf'] ** 2.5 + 0.032 ** 2.5))  # dimensionless
    PO4.fluxBent = - fPO4 * pMinRate  # in gP/m²/h

    fSIO = 1 - BSI.cBentdlx[id_sim] / (BSI.cBentdlx[id_sim] + exp(0.08 * temp)) - (0.3 + 0.02 * temp) * DSI.cH2Odlx[id_sim] / 28  # dimensionless
    DSI.fluxBent = -fSIO * SiDissRate  # in gSi/m²/h

def calcMuf_nycthemeral(ctime, ftime, ttx, depth, step_t_rive, step_t_cmuf, step_d_cmuf, id_sim):
    """ Compute muf for Phytoplankton and excrphy
    :param ctime: time cursor indicating the day or decade of the year
    :param ftime: time cursor multiplying factor (number of days in a ctime period) eg 1 for day; 10 for decade etc
    :param ttx: time cursor indicating the hour of the day ctime
    :param depth: river depth in meters
    :param step_t_cmuf: Time step to run computation in calcmuf every 30min for 1 day
    :param step_d_cmuf: Depth step to run calcMuf 0.02 => every 2 cm along the depth profil
    """

    from math import sin, pi  # asinh
    flimnut = {}
    ssi = {}
    sri = {}
    cri = {}
    muh = {}
    resp = {}
    excr = {}

    # Calculation of limiting kinetics for nutrients (flimut)
    for phyto in listPhyto:

        flimnut[phyto.name] = min((mich(S=NH4.cH2Odlx[id_sim] + NO3.cH2Odlx[id_sim], Ks=phyto.kpn), mich(S=PO4.cH2Odlx[id_sim], Ks=phyto.kpp)))

        
        if phyto.name == "DIA":
            flimnut[phyto.name] = min(flimnut[phyto.name], mich(S=DSI.cH2Odlx[id_sim], Ks=DIA.kpsi))

        phyto.muf[id_sim] = 0.
        phyto.deltacS[id_sim] = 0.
        phyto.deltacR[id_sim] = 0.
        
    # create liste of time and depth step to iterate later in calcmuh
    range_t_cmuf = [(x * step_t_cmuf) + step_t_cmuf for x in range(1, int(24 / step_t_cmuf))]
    range_d_cmuf = [(x * step_d_cmuf) for x in range(int(depth / step_d_cmuf) + 1)]  # every 0.02 m until depth

    # calculate light attenuation according to PHY and SPM concentration
    cPHY = DIA.cH2Odlx[id_sim] + GRA.cH2Odlx[id_sim] + CYA.cH2Odlx[id_sim]
    eta = 0.2 + 0.042 * SPM.cH2Odlx[id_sim] + 0.02 * cPHY * c['convC2Chl']  # relation determined on the Scheldt by CL

    # get light data at right time (either day x 1 or dec x 10)
    photoperiod = c['photoperiod'][ctime * ftime]
    luminosity = c['luminosity'][ctime * ftime]

    p['excrPhy'] = 0

    h = ttx
    #print(id_sim)
    
    # calculation of depth-integrated photosynthesis rate
    for phyto in listPhyto:
        ssi[phyto.name] = 0
    io = 0
    
    # SW 17/03/2022 delay of 8 hours
    if h > 8 and (h - 8) < photoperiod:
        io = pi / 2 * luminosity * sin(pi * (h - 8) / photoperiod)
        
        for z in range_d_cmuf:
            il = io * exp(- eta * z)
            for phyto in listPhyto:
                ssi[phyto.name] += phyto.kmax * (1 - exp(- phyto.alf * il / phyto.kmax)) * step_d_cmuf  # 0.02 m

        for phyto in listPhyto:
            ssi[phyto.name] /= depth    # h-1

    # LOOP on phyto species
    for phyto in listPhyto:
        if(phyto.cH2Odlx[id_sim] > 0.):
            phyto.S[id_sim] = phyto.cSdlx[id_sim] / phyto.cH2Odlx[id_sim]
            phyto.R[id_sim] = phyto.cRdlx[id_sim] / phyto.cH2Odlx[id_sim]
        else:
            phyto.S[id_sim] = phyto.R[id_sim] = 0.
        
        # primary production
        ssi[phyto.name] = ssi[phyto.name] * phyto.cH2Odlx[id_sim] # mgC.L-1.h-1
        phyto.mbssi[id_sim] = ssi[phyto.name]
                  
        # reserves synthesis (sri)
        sri[phyto.name] = phyto.srmax * mich(S=phyto.S[id_sim], Ks=phyto.ks) * phyto.cH2Odlx[id_sim] # mgC.L-1.h-1

        # reserves catabolism (cri)
        cri[phyto.name] = phyto.kcr * phyto.cRdlx[id_sim] # mgC.L-1.h-1
        # excretion (excr)
        excr[phyto.name] = 0.02 * ssi[phyto.name] / 35 + 0.038 / 35 * phyto.cH2Odlx[id_sim] # mgC.L-1.h-1
           
        muh[phyto.name] = phyto.mumax * mich(S=phyto.S[id_sim], Ks=phyto.ks) * flimnut[phyto.name] # h-1
        resp[phyto.name] = (phyto.maint + phyto.cesp * muh[phyto.name]) * phyto.cH2Odlx[id_sim] # mgC.L-1.h-1
        phyto.mbresp[id_sim] = resp[phyto.name]
            
        # calculation of phyto.cS and phyto.cR
        phyto.deltacS[id_sim] = (ssi[phyto.name] - resp[phyto.name] - sri[phyto.name] + cri[phyto.name] 
                    - muh[phyto.name] * phyto.cH2Odlx[id_sim] - excr[phyto.name]) * step_t_rive # mgC.L-1
        phyto.deltacR[id_sim] = (sri[phyto.name] - cri[phyto.name]) * step_t_rive # mgC.L-1


        phyto.muf[id_sim] = muh[phyto.name] # h-1

        # print DIA fluxes for GMD paper mgC L-1 h-1, muh h-1 SW 14/03/2023
        if phyto.name == 'DIA':
            if not flog.file.closed:
                flog.file.write('%d %f %f %f %f '%(ctime, ssi[phyto.name], -resp[phyto.name], -excr[phyto.name], muh[phyto.name]))
                #flog.file.write('%d %f %f %f %f '%(ctime, ssi[phyto.name]/phyto.cH2Odlx[id_sim], -resp[phyto.name]/phyto.cH2Odlx[id_sim], -excr[phyto.name]/phyto.cH2Odlx[id_sim], muh[phyto.name]))
        # END of phyto LOOP

    # Total excretion of phytoplankton feeding substrates directly hydrolysable by heterotrophic bacteria
    # SW 20/01/2022 if we want to do a parallel computing, we need maybe p['excrPhy'][id_sim]
    p['excrPhy'] += excr['DIA'] + excr['GRA'] + excr['CYA'] # mgC.L-1.h-1

    # END of Time LOOP (24 hours)

def calcWaterColumn(ctime, ftime, depth, dlx, dilu, st, temp, id_sim):
    """ Biogeochemical processes that occur in the water column
    :param ctime: time cursor indicating the day or decade of the year
    :param ftime: time cursor multiplying factor (number of days in a ctime period) eg 1 for day; 10 for decade etc
    :param depth: river depth in meters
    :param dlx: time in hour to travel 1 km for river
    :param dilu: dilution rate in h-1
    :param st: time step (in h)
    :param temp: water temperature in °C
    """

    d = {}    # delta
    dBent = {}    # delta benthic

    grmoul = {}
    kdfc = {}
    rdmt = {}
    kdbb = {}
    upt = {}
    hydr = {}
    nitr = {}

    sal = 0

    '''
    # SW 14/12/2021 no correction for instance
    # management of bacteria (minimum seeding)
    if SHB.cH2O == 0:
        SHB.cH2O = 0.000001
    if AOB.cH2O == 0:
        AOB.cH2O = 0.000001

    # management of  phytoplankton (minimum seeding, growth, viruses, mussel)
    if DIA.cH2O == 0:
        DIA.cH2O = 0.001
    if GRA.cH2O == 0:
        GRA.cH2O = 0.001
    if CYA.cH2O == 0:
        CYA.cH2O = 0.0001
    '''
    # ============================
    # Suspended matter and Bentic pools
    # ============================
    sedim = {}  # sedimentation

    for var in listSed:
        sedim[var.name] = var.ksed * var.cH2Odlx[id_sim]  # mg/l/h

    sedim['SPM'] = min(sedim['SPM'], SPM.cH2Odlx[id_sim] / st)

    if SPM.cH2Odlx[id_sim] < p['capSPM'] and SPM.cBentdlx[id_sim] > c['sedThreshold']:
        erosSPM = SPM.ksed * (p['capSPM'] - SPM.cH2Odlx[id_sim]) * (SPM.cBentdlx[id_sim] - c['sedThreshold']) / SPM.cBent
    else:
        erosSPM = 0

    erosSPM = min(erosSPM, 0.5 * SPM.cBentdlx[id_sim] / depth / st)    # g/m²/m/h= mg/l/h

    d['SPM'] = - sedim['SPM'] + erosSPM    # mg/l/h = g/m3/h
    dBent['SPM'] = (sedim['SPM'] - erosSPM) * depth - p['compaction'] * SPM.cBentdlx[id_sim]    # g/m²/h
    sedim['TIP'] = sedim['SPM'] * (TIP.cH2Odlx[id_sim] - PO4.cH2Odlx[id_sim]) / SPM.cH2Odlx[id_sim]    # mgP/l/h

    if SPM.cBentdlx[id_sim] > c['sedThreshold']:
        txeros = erosSPM * depth / SPM.cBentdlx[id_sim]    # erosion rate of benthic stock, in h-1
    else:
        txeros = 0

    sumSedim = (sedim['SHB'] + sedim['LHB'] + sedim['AOB'] + sedim['NOB']
                + sedim['DIA'] + sedim['GRA'] + sedim['CYA']
                + sedim['ZOR'] + sedim['ZOC'])  # XY add ZOO sinking rate 04/04/2021
    dBent['POM1'] = ((c['epsd1'] + c['epsp1']) * sumSedim * depth
                    + sedim['POM1'] * depth - POM1.cBentdlx[id_sim] * (txeros + p['compaction'] + p['k1b']))    # gC/m²/h
    dBent['POM2'] = ((c['epsd2'] + c['epsp2']) * sumSedim * depth
                    + sedim['POM2'] * depth - POM2.cBentdlx[id_sim] * (txeros + p['compaction'] + c['k2b']))   # gC/m²/h
    dBent['POM3'] = ((c['epsd3'] + c['epsp3']) * sumSedim * depth
                    + sedim['POM3'] * depth - POM3.cBentdlx[id_sim] * (txeros + p['compaction']))    # gC/m²/h

    dBent['BSI'] = ((sedim['DIA'] * DIA.mSiC + sedim['SPM'] * BSI.cH2Odlx[id_sim] / SPM.cH2Odlx[id_sim]) * depth
                    - BSI.cBentdlx[id_sim] * (txeros + p['compaction'] + p['kbSi'] * (1 - DSI.cH2Odlx[id_sim] / p['siOsat'])))    # mgSi/m²/h
    dBent['PIP'] = (sedim['TIP'] * depth
                    - PIP.cBentdlx[id_sim] * (txeros + p['compaction'])
                    + (p['k1b'] * POM1.cBentdlx[id_sim] + c['k2b'] * POM2.cBentdlx[id_sim]) / 40
                    + PO4.fluxBent)    # mgP/m²/h
    dBent['AFC'] = (sedim['AFC'] * depth
                    - AFC.cBentdlx[id_sim] * (txeros + p['compaction'] + AFC.kd))    # knb/m2/h GB 2/2/10 #SW 02/04/2021

    # define PHY variable as sum of DIA, GRA and CYA
    cPHY = DIA.cH2Odlx[id_sim] + GRA.cH2Odlx[id_sim] + CYA.cH2Odlx[id_sim] + DIA.cSdlx[id_sim] + GRA.cSdlx[id_sim] + CYA.cSdlx[id_sim] + DIA.cRdlx[id_sim] + GRA.cRdlx[id_sim] + CYA.cRdlx[id_sim]

    # ============================
    # Zooplankton
    # =============================
    cr = {}
    gr = {}
    for zoo in listZoo:
        if cPHY < zoo.phy0 or OXY.cH2Odlx[id_sim] < 1:  # (1 mgO2/l = 30 micromol * 32/1000)
            cr[zoo.name] = 0
            gr[zoo.name] = 0
        else:
            cr[zoo.name] = zoo.mumax * (cPHY - zoo.phy0) / (cPHY - zoo.phy0 + zoo.Kphy) * zoo.cH2Odlx[id_sim]
            gr[zoo.name] = zoo.grmax * (cPHY - zoo.phy0) / (cPHY - zoo.phy0 + zoo.Kphy) * zoo.cH2Odlx[id_sim]
        d[zoo.name] = cr[zoo.name] - zoo.kd * zoo.cH2Odlx[id_sim] - sedim[zoo.name]     # XY add ZOO sinking rate 04/04/2021

    respZoo = gr['ZOR'] - cr['ZOR'] + gr['ZOC'] - cr['ZOC'] # in mgC/l/h

    d['ZOR'] -= p['grBenth'] * p['mussel'] / depth * ZOR.cH2Odlx[id_sim]

    # ============================
    # Phytoplankton
    # =============================
    for phyto in listPhyto:
        '''
        # management of excessive phytoplankton growth
        if phyto.cH2O > 200 / c['convC2Chl']:
            phyto.muf = 0

        # viruses management : extinction of viruses if PHY goes down 5 microgChla
        elif phyto.cH2O < 5 / c['convC2Chl']:
            phyto.virusflag = False
        '''
        # mussel grazing
        if phyto.cH2Odlx[id_sim] < (ZOR.phy0 / 3):
            grmoul[phyto.name] = 0
        else:
            grmoul[phyto.name] = (p['grBenth'] * p['mussel'] / depth) * (phyto.cH2Odlx[id_sim] - (ZOR.phy0 / 3))
        
        # SW 05/01/2022 for GMD paper
        grmoul[phyto.name] = 0

    '''
    # management of  phytoplankton coeff. (continue)
    if (DIA.virusflag or DIA.cH2O > 200 / c['convC2Chl']) and (ctime * ftime) > 150:  # dec 15 or day 150
        kdfc['DIA'] = 10 * DIA.kd
        DIA.virusflag = True
    else:
        kdfc['DIA'] = DIA.kd

    if GRA.virusflag or GRA.cH2O > 200 / c['convC2Chl']:
        kdfc['GRA'] = 10 * GRA.kd
        GRA.virusflag = True
    else:
        kdfc['GRA'] = GRA.kd

    if CYA.virusflag or CYA.cH2O > 60 / c['convC2Chl']:
        kdfc['CYA'] = 10 * CYA.kd
        CYA.virusflag = True
    else:
        kdfc['CYA'] = CYA.kd
    '''
    # Phyto mortality rate
    for phyto in listPhyto:
        kdfc[phyto.name] = phyto.kd
        
    # Phyto delta :
    if cPHY > 0.:
        for phyto in listPhyto:
            d[phyto.name] = ((phyto.muf[id_sim] - kdfc[phyto.name] - phyto.ksed -
                          (gr['ZOR'] + gr['ZOC']) / cPHY) * phyto.cH2Odlx[id_sim] -
                         grmoul[phyto.name])
            
            
            phyto.deltacS[id_sim] = phyto.deltacS[id_sim] - (kdfc[phyto.name] + phyto.ksed + (gr['ZOR'] + gr['ZOC']) / cPHY) * phyto.cSdlx[id_sim] * st #mgC/l
            phyto.deltacR[id_sim] = phyto.deltacR[id_sim] - (kdfc[phyto.name] + phyto.ksed + (gr['ZOR'] + gr['ZOC']) / cPHY) * phyto.cRdlx[id_sim] * st #mgC/l
    else:
        for phyto in listPhyto:
            d[phyto.name] = 0.
            
    # =================================================================
    # print DIA rate for GMD paper mgC L-1 h-1 or h-1 SW 14/03/2023
    # =================================================================
    for phyto in listPhyto:        
        if phyto.name == 'DIA':
            mort_dia = -kdfc[phyto.name] * (phyto.cH2Odlx[id_sim] + phyto.cSdlx[id_sim] + phyto.cRdlx[id_sim]) ## here just 1 sim mgC L-1 h-1
            #mort_dia = -kdfc[phyto.name] ## here just 1 sim h-1
            zoo_grazing = -(gr['ZOR'] + gr['ZOC']) / cPHY * (phyto.cH2Odlx[id_sim] + phyto.cSdlx[id_sim] + phyto.cRdlx[id_sim]) # grazing F + S + R mgC L-1 h-1
            #zoo_grazing = -(gr['ZOR'] + gr['ZOC']) / cPHY # grazing F + S + R mgC L-1 h-1
            if not flog.file.closed:
                flog.file.write('%f %f '%(mort_dia, zoo_grazing))

    # ============================
    # Silica
    # ============================
    DSI.fluxBent = 0. #SW 09/03/2021 for water column case study, to be removed for gitlab
    p['kbSi'] = 0. #SW 09/03/2021 for water column case study
    d['DSI'] = (- DIA.muf[id_sim] * DIA.cH2Odlx[id_sim] * DIA.mSiC
                + p['kbSi'] * (1 - DSI.cH2Odlx[id_sim] / p['siOsat']) * BSI.cH2Odlx[id_sim]
                - DSI.fluxBent / depth)
    d['BSI'] = ((kdfc['DIA'] + (gr['ZOR'] + gr['ZOC']) / cPHY + p['grBenth'] * p['mussel'] / depth)
                * DIA.cH2Odlx[id_sim] * DIA.mSiC
                - (sedim['SPM'] / SPM.cH2Odlx[id_sim] + p['kbSi'] * (1 - DSI.cH2Odlx[id_sim] / p['siOsat'])) * BSI.cH2Odlx[id_sim]
                + txeros * BSI.cBent / depth)

    # ============================
    # Bacteria small and large (SHB, LHB)
    # ============================
    respBact = 0
    for bact in listHetBact:
        if OXY.cH2Odlx[id_sim] >= 1:  # (1 mgO2/l = 30 µmol * 32/1000)
            rdmt[bact.name] = bact.y
        else:
            if NO3.cH2Odlx[id_sim] >= 0.21:  # (15 µmol * 14 / 1000)
                rdmt[bact.name] = bact.y / 2
            else:
                rdmt[bact.name] = bact.y / 3

        kdbb[bact.name] = bact.kd * rdmt[bact.name] / bact.y
        upt[bact.name] = bact.bmax * mich(S=SODA.cH2Odlx[id_sim], Ks=bact.ks) * bact.cH2Odlx[id_sim]
        d[bact.name] = (rdmt[bact.name] * upt[bact.name] - kdbb[bact.name] * bact.cH2Odlx[id_sim] - sedim[bact.name])
        respBact += (1 - rdmt[bact.name]) * upt[bact.name]  # in mgC/l.h

    # ============================
    # Organic matter (SODA, DOM1,2,3, POM 1,2,3)
    # ============================
    BAT = SHB.cH2Odlx[id_sim] + LHB.cH2Odlx[id_sim]
    hydr['DOM1'] = SHB.e1max * mich(S=DOM1.cH2Odlx[id_sim], Ks=SHB.kh1) * BAT
    hydr['DOM2'] = SHB.e2max * mich(S=DOM2.cH2Odlx[id_sim], Ks=SHB.kh2) * BAT
    d['SODA'] = hydr['DOM1'] + hydr['DOM2'] - upt['SHB'] - upt['LHB'] + p['excrPhy']
    
    # ===================================================================================
    # print LHB rate and SMS (SODA) for GMD paper mgC L-1 h-1 or h-1 SW 14/03/2023
    # ===================================================================================
    growth_lhb_mh = rdmt['LHB'] * upt['LHB'] / LHB.cH2Odlx[id_sim] # h-1  
    growth_lhb= rdmt['LHB'] * upt['LHB'] #mgC L-1 h-1
    mort_lhb = -kdbb['LHB'] * LHB.cH2Odlx[id_sim] #mgC L-1 h-1
    upatke_sum = -(upt['SHB'] + upt['LHB'])
    if not flog.file.closed:
        flog.file.write('%f %f %f %f %f '%(growth_lhb_mh, growth_lhb, -kdbb['LHB'], mort_lhb, upatke_sum))
    
    const = 0
    for micro in (DIA, GRA, CYA, SHB, LHB, AOB, NOB, ZOR, ZOC):
        const += micro.kd * micro.cH2Odlx[id_sim]

    # consider S and R mortality
    for micro in (DIA, GRA, CYA):
        const += micro.kd * (micro.cSdlx[id_sim] + micro.cRdlx[id_sim])
    
    d['DOM1'] = c['epsd1'] * const - hydr['DOM1'] + p['k1b'] * POM1.cH2Odlx[id_sim]
    d['DOM2'] = c['epsd2'] * const - hydr['DOM2'] + c['k2b'] * POM2.cH2Odlx[id_sim]
    d['DOM3'] = c['epsd3'] * const

    d['POM1'] = c['epsp1'] * const - p['k1b'] * POM1.cH2Odlx[id_sim] - sedim['POM1'] + txeros * POM1.cBentdlx[id_sim] / depth
    d['POM2'] = c['epsp2'] * const - c['k2b'] * POM2.cH2Odlx[id_sim] - sedim['POM2'] + txeros * POM2.cBentdlx[id_sim] / depth
    d['POM3'] = c['epsp3'] * const - sedim['POM3'] + txeros * POM3.cBentdlx[id_sim] / depth

    # ============================
    # Nitrif. bacteria
    # ============================
    nitr['AOB'] = AOB.mumax / AOB.y * mich(S=NH4.cH2Odlx[id_sim], Ks=AOB.kNH4) * mich(S=OXY.cH2Odlx[id_sim], Ks=AOB.kO2) * AOB.cH2Odlx[id_sim]  # in mgN/l/h
    if OXY.cH2Odlx[id_sim] < NOB.kO2:
        nitr['AOBbis'] = nitr['AOB'] * mich(S=NO2.cH2Odlx[id_sim], Ks=NOB.kNO2) / 10    # 10 % of nitrification flux produce N2O
    else:
        nitr['AOBbis'] = 0
    nitr['AOB'] = min(nitr['AOB'], NH4.cH2Odlx[id_sim] / st)
    if nitr['AOB'] > 3 / 2 * 14 / 32 * OXY.cH2Odlx[id_sim] / st:
        nitr['AOB'] = 3 * 14 / 32 * OXY.cH2Odlx[id_sim] / st

    nitr['NOB'] = NOB.mumax / NOB.y * mich(S=NO2.cH2Odlx[id_sim], Ks=NOB.kNO2) * mich(S=OXY.cH2Odlx[id_sim], Ks=NOB.kO2) * NOB.cH2Odlx[id_sim]
    nitr['NOB'] = min(nitr['NOB'], NO2.cH2Odlx[id_sim] / st)
    if nitr['NOB'] > OXY.cH2Odlx[id_sim] / 2 * 14 / 32 / st:
        nitr['NOB'] = OXY.cH2Odlx[id_sim] * 14 / 32 / st    # modif GB 18 dec 2010

    # ============================
    # Gaz
    # ============================
    # initialization of CO2 from TA and DIC inputs
    try:
        if TA.cH2Odlx[id_sim] > 2000:
            if CO2.cH2Odlx[id_sim] == 0.0 or pH.cH2Odlx[id_sim]==0:
                calcCO2(pH=pH, temp=temp, sal=sal, TA=TA, DIC=DIC, CO2=CO2, id_sim=id_sim)

    except:
        pass
    # ventilation / outgasing
    for gaz in listGaz:
        gaz.vent = gaz.k * (gaz.sat - gaz.cH2Odlx[id_sim]) # vent fluxes in gX/m2/h
        
    # ============================
    # Oxygen
    # ============================
    actOrg = (respBact + respZoo) / 12 * 32   # mgO2/l/h
    phot = (DIA.mbssi[id_sim] + GRA.mbssi[id_sim] + CYA.mbssi[id_sim]) * 1.25 / 12 * 32 # mgO2/l/h

    # respiration
    resp_phy = (DIA.mbresp[id_sim] + GRA.mbresp[id_sim] + CYA.mbresp[id_sim]) * 1.25 / 12 * 32
    respPhyC = DIA.mbresp[id_sim] + GRA.mbresp[id_sim] + CYA.mbresp[id_sim] #mgC/l/h SW 30/05/2022
    OXY.fluxBent = 0. # for water column case study
    d['OXY'] = (OXY.vent / depth + phot - resp_phy - actOrg - nitr['AOB'] * 3 / 2 * 32 / 14 - nitr['NOB'] / 2 * 32 / 14
                - (OXY.fluxBent + p['grBenth'] * p['mussel'] * (cPHY + ZOR.cH2Odlx[id_sim]) * 0.8 / 12 * 32)
                / depth)    # mgO2/l/h

    if d['OXY'] < 0 and d['OXY'] < (2 - OXY.cH2Odlx[id_sim]) / st:
        nitr['AOB'] = 0
        nitr['NOB'] = 0
        denit = (actOrg - (OXY.cH2Odlx[id_sim] - 2 + OXY.vent /depth + phot)) * 4 / 5 * 14 / 32
        denit = max(denit, 0)
        d['OXY'] = 0
    else:
        denit = 0

    # ============================
    # Nitrif. bacteria (continue)
    # ============================
    for bact in listNitBact:
        d[bact.name] = bact.y * nitr[bact.name] - bact.kd * bact.cH2Odlx[id_sim] - sedim[bact.name]

    # ============================
    # N2O
    # ============================
    prodN2Oden = c['pNden'] * denit
    d['N2O'] = N2O.vent /depth + prodN2Oden + nitr['AOBbis'] + NO3.retIntegBent * c['pNden'] / depth

    # ============================
    # CH4
    # ============================
    kCH4bent = 4 * 12 / 14   # mgCH4/mgNH4
    flxNH4Threshold = 10 * (p['compaction'] * SPM.cBent * 0.2 / 4 + c['df'] * 400 / p['zf']) * 14 / 1000    # gN/L
    if NH4.fluxBent + flxNH4Threshold < 0:
        prodbentCH4 = kCH4bent * (- (NH4.fluxBent + flxNH4Threshold))
    else:
        prodbentCH4 = 0
    d['CH4'] = CH4.vent /depth + prodbentCH4

    # ============================
    # Common biomass coefficients expressed in carbon C
    # ============================
    uptPhyC = DIA.muf[id_sim] * DIA.cH2Odlx[id_sim] + GRA.muf[id_sim] * GRA.cH2Odlx[id_sim] + CYA.muf[id_sim] * CYA.cH2Odlx[id_sim] + p['excrPhy']
    photPhyC = DIA.mbssi[id_sim] + GRA.mbssi[id_sim] + CYA.mbssi[id_sim] # SW 30/05/2022
    
    uptBactC = rdmt['SHB'] * upt['SHB'] + rdmt['LHB'] * upt['LHB']
    coefC = (upt['SHB'] + upt['LHB'] - uptBactC + respZoo
             + p['grBenth'] * p['mussel'] / depth * (cPHY + ZOR.cH2Odlx[id_sim]) * 0.5)

    # ============================
    # Nitrogen : Nitrate, nitrite, Ammonium
    # ============================
    #uptPhyN = photPhyC / cn    # mgN/l.h
    uptPhyN = uptPhyC / cn # mgN/l.h SW 05/04/2023 uptake N and P related to growth
    if NH4.cH2Odlx[id_sim] > 0 and NO3.cH2Odlx[id_sim] > 0:
        uptPhyNH4 = uptPhyN * (NH4.cH2Odlx[id_sim] / (NH4.cH2Odlx[id_sim] + NO3.cH2Odlx[id_sim])) ** (0.025)
    else:
        uptPhyNH4 = 0
    uptPhyNO3 = uptPhyN - uptPhyNH4
    ammonif = coefC / cn
    
    NO3.fluxBent = 0. # SW 08/01/2021 no sediment for marne bassine test, to be removed for gitlab
    NH4.fluxBent = 0. # SW 08/01/2021 no sediment for marne bassine test, to be removed for gitlab
    PO4.fluxBent = 0. # SW 08/01/2021 no sediment for marne bassine test, to be removed for gitlab

    d['NO3'] = - denit - NO3.fluxBent / depth - uptPhyNO3 + nitr['NOB']
    d['NH4'] = ammonif - NH4.fluxBent / depth - uptPhyNH4 - nitr['AOB'] # SW 02/04/2020 remove (- uptBactN)
    d['NO2'] = nitr['AOB'] - nitr['NOB']

    # ============================
    # Phosphorus
    # ============================
    #uptPhyPO4 = photPhyC / cp
    uptPhyPO4 = uptPhyC / cp # mgN/l.h SW 05/04/2023 uptake N and P related to growth
    releaseP = coefC / cp     # mgP/l.h

    d['TIP'] = (releaseP - PO4.fluxBent / depth - uptPhyPO4
                - sedim['TIP'] + txeros * PIP.cBentdlx[id_sim] / depth)  # XY 28/04/2021 remove (- uptBactP)

    # ============================
    # Fecal Bacteria
    # ============================
    d['FFC'] = - FFC.kd * FFC.cH2Odlx[id_sim]
    d['AFC'] = - AFC.kd * AFC.cH2Odlx[id_sim] - sedim['AFC'] + txeros * AFC.cBentdlx[id_sim] / depth

    # ============================
    # Dissolved inorganic carbon
    # ============================
    d['DIC'] = ((respBact + respZoo + p['respBent'] + respPhyC)
                + (5. /4. * denit * 12 / 14) - photPhyC + (CO2.vent / depth))  # mgC/l.h
    
    # ============================
    # Total alkalinity
    # ============================
    if uptPhyN > 0.: #SW 16/10/2020
        #d['TA'] = 14 / 106 * (respBact + respZoo + p['respBent'] + respPhyC) / 12.0 * 10 ** (3) \
        #      + (denit - 2 * (nitr['AOB'] + nitr['AOBbis'])) / 14.0 * 10 ** (3) \
        #      + (17 / 106 * uptPhyNO3 / uptPhyN - 15 / 106 * uptPhyNH4 / uptPhyN) * photPhyC / 12 * 10 ** 3  # umol/l.h
        d['TA'] = 14 / 106 * (respBact + respZoo + p['respBent'] + respPhyC) / 12.0 * 10 ** (3) \
              + (denit - 2 * (nitr['AOB'] + nitr['AOBbis'])) / 14.0 * 10 ** (3) \
              + (17 / 106 * uptPhyNO3 / uptPhyN - 15 / 106 * uptPhyNH4 / uptPhyN) * uptPhyC / 12 * 10 ** 3  # umol/l.h

    else:
        d['TA'] = 14 / 106 * (respBact + respZoo + p['respBent'] + respPhyC) / 12.0 * 10 ** (3) \
              + (denit - 2 * (nitr['AOB'] + nitr['AOBbis'])) / 14.0 * 10 ** (3)  # umol/l.h

    # ============================
    # INCREMENTATION
    # ============================
    SPM.cH2Odlx[id_sim] = max(SPM.cH2Odlx[id_sim] + st * (d['SPM'] - dilu * (SPM.cH2Odlx[id_sim] - SPM.cLat)), 0.)

    for var in (LHB, DOM1, DOM2, DOM3, POM1, POM2, POM3, SODA,
                NH4, NO3, TIP, DSI, BSI, FFC, AFC):
        var.cH2Odlx[id_sim] = max(var.cH2Odlx[id_sim] + st * (d[var.name] - dilu * (var.cH2Odlx[id_sim] - var.cLat)),
                           0.0)
        
        # ===================================================================================
        # print LHB net change and net input for GMD paper mgC L-1 h-1 SW 14/03/2023
        # ===================================================================================
        if(var == LHB):
            dt_lhb = d[var.name] - dilu * (var.cH2Odlx[id_sim] - var.cLat) # mgC L-1 h-1
            input_lhb =  - dilu * (var.cH2Odlx[id_sim] - var.cLat)
            if not flog.file.closed:
                flog.file.write('%f %f '%(dt_lhb, input_lhb))
            
    DSI.cH2Odlx[id_sim] = min(DSI.cH2Odlx[id_sim], p['siOsat'])
    
    
    PO4.cH2Odlx[id_sim] = phosph(cTIP=TIP.cH2Odlx[id_sim], cSPM=SPM.cH2Odlx[id_sim])
    
    
    try:
        if TA.cH2Odlx[id_sim] > 2000:
            for var in (TA, DIC):
                var.cH2Odlx[id_sim] = max(var.cH2Odlx[id_sim] + st * (d[var.name] - dilu * (var.cH2Odlx[id_sim] - var.cLat)),
                               0.0)
            CO2.cH2Odlx[id_sim] = calcCO2(pH=pH, temp=temp, sal=sal, TA=TA, DIC=DIC, CO2=CO2, id_sim=id_sim)

    except:
        pass

    for var in (DIA, GRA, CYA, SHB):
        var.cH2Odlx[id_sim] = max(var.cH2Odlx[id_sim] + st * (d[var.name] - dilu * (var.cH2Odlx[id_sim] - var.cLat)),
                       0.)

        # ===================================================================================
        # print DIA net change and net input for GMD paper mgC L-1 h-1 SW 14/03/2023
        # ===================================================================================
        if(var == DIA):
            dt_dia = (d[var.name] +  var.deltacS[id_sim] / st  + var.deltacR[id_sim] / st) - dilu * (var.cH2Odlx[id_sim] - var.cLat) - dilu * (var.cSdlx[id_sim] - var.ScLat) - dilu * (var.cRdlx[id_sim] - var.RcLat) # F + S + R mgC L-1 h-1
            input_dia =  - dilu * (var.cH2Odlx[id_sim] - var.cLat) - dilu * (var.cSdlx[id_sim] - var.ScLat) - dilu * (var.cRdlx[id_sim] - var.RcLat) # mgC L-1 h-1
            if not flog.file.closed:
                flog.file.write('%f %f\n'%(dt_dia, input_dia))

    
    for var in listPhyto:
        var.cSdlx[id_sim] = max(var.cSdlx[id_sim] + var.deltacS[id_sim] - st * dilu * (var.cSdlx[id_sim] - var.ScLat), 
                                0)
        var.cRdlx[id_sim] = max(var.cRdlx[id_sim] + var.deltacR[id_sim] - st * dilu * (var.cRdlx[id_sim] - var.RcLat), 
                                0)

    for var in listZoo:
        var.cH2Odlx[id_sim] = max(var.cH2Odlx[id_sim] + st * (d[var.name] - dilu * (var.cH2Odlx[id_sim] - var.cLat)),
                       0.)

    for var in (NO2,):
        var.cH2Odlx[id_sim] = max(var.cH2Odlx[id_sim] + st * (d[var.name] - dilu * (var.cH2Odlx[id_sim] - var.cLat)),
                       0.000000)

    for var in (AOB, NOB):
        var.cH2Odlx[id_sim] = max(var.cH2Odlx[id_sim] + st * (d[var.name] - dilu * (var.cH2Odlx[id_sim] - var.cLat)),
                       0.000000)

    for var in (N2O,):
        var.cH2Odlx[id_sim] = max(var.cH2Odlx[id_sim] + st * (d[var.name] - dilu * (var.cH2Odlx[id_sim] - var.cLat)),
                       0.0000000)

    for var in (CH4,):
        var.cH2Odlx[id_sim] = max(var.cH2Odlx[id_sim] + st * (d[var.name] - dilu * (var.cH2Odlx[id_sim] - var.cLat)),
                       0.0000000)

    for var in (OXY,):
        var.cH2Odlx[id_sim] = max(var.cH2Odlx[id_sim] + st * (d[var.name] - dilu * (var.cH2Odlx[id_sim] - var.cLat)),
                       0.0000000)

    SPM.cBentdlx[id_sim] = SPM.cBentdlx[id_sim] + st * 24 * ftime / dlx * dBent['SPM']
    if SPM.cBentdlx[id_sim] <= 0:
        SPM.cBentdlx[id_sim] = SPM.initBent

    for var in (POM1, POM2, POM3, BSI, PIP, AFC):
        var.cBentdlx[id_sim] = var.cBentdlx[id_sim] + st * 24 * ftime / dlx * dBent[var.name]
        if var.cBentdlx[id_sim] <= 0:
            var.cBentdlx[id_sim] = var.initBent * SPM.cBentdlx[id_sim] / SPM.initBent

# SW 20/01/2022 calculation of average concentrations of all variables
def calcMeanConcentration():
    for var in listVar:
        var.cH2O = mean(i for i in var.cH2Odlx if i is not None)
        var.cH2OMin = min(i for i in var.cH2Odlx if i is not None)
        var.cH2OMax = max(i for i in var.cH2Odlx if i is not None)
    for var in listPhyto:
        var.cS = mean(i for i in var.cSdlx if i is not None)
        var.cSMin = min(i for i in var.cSdlx if i is not None)
        var.cSMax = max(i for i in var.cSdlx if i is not None)
        var.cR = mean(i for i in var.cRdlx if i is not None)
        var.cRMin = min(i for i in var.cRdlx if i is not None)
        var.cRMax = max(i for i in var.cRdlx if i is not None)
    # for sediment layer
    for var in listBent:
        var.cBent = mean(i for i in var.cBentdlx if i is not None)
        var.cBentMin = min(i for i in var.cBentdlx if i is not None)
        var.cBentMax = max(i for i in var.cBentdlx if i is not None)
    
