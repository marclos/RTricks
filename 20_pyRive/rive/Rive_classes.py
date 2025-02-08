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
    Audrey Marescaux (SU - UMR7619 METIS)

License:
This program and the accompanying materials are made available under the
terms of the Eclipse Public License 2.0 which is available at
http://www.eclipse.org/legal/epl-2.0, or the GNU General Public License,
version 3 or any later version with the GNU Classpath Exception which is available
at https://www.gnu.org/software/classpath/license.html.
SPDX-License-Identifier: EPL-2.0 OR GPL-3.0-or-later WITH Classpath-exception-2.0

Description:
RIVE Biogeo classes to store variables parameters and values and classes for results.
"""


class Common(object):
    """
    Defines every biogeochemical variable involved in processes modeled by RIVE
    """
    def __init__(self, listV, name, cH2O=0, cLat=0, n = 24, cH2Odlx = None, cH2OMin = -9999, cH2OMax = -9999):
        self.name = name    # constant
        self.cH2O = cH2O
        self.cLat = cLat
        self.cH2Odlx = [ cH2Odlx for i in range(n) ] # ensemble concentrations to estimat the average concentration cH2O
        self.cH2OMin = cH2OMin
        self.cH2OMax = cH2OMax
        listV.append(self)


class Sediment(object):
    """
    Abstract class that defines sedimentation rates and benthic concentrations
    """
    def __init__(self, vs=0, ksed=0, initBent=0, cBent=0, cBentdlx = None, n = 24, cBentMin = -9999, cBentMax = -9999):
        self.vs = vs    # constant
        self.ksed = ksed
        self.initBent = initBent
        self.cBent = cBent
        self.cBentdlx = [ cBentdlx for i in range(n) ] # ensemble concentrations to estimat the average concentration cBent
        self.cBentMin = cBentMin
        self.cBentMax = cBentMax


class FluxBenthic(object):
    """
    Abstract class that defines benthic flux and retention
    """
    def __init__(self, fluxBent=0, retBent=0, retIntegBent=0, retPotentBent=0):
        self.fluxBent = fluxBent
        self.retBent = retBent
        self.retIntegBent = retIntegBent
        self.retPotentBent = retPotentBent


class RiparianArea(object):
    """
    Abstract class that defines riparian area and associated fluxes
    """
    def __init__(self, inFlxRip=0, retCapRip=0, outFlxRip=0, outCminRip=0, byPassRip=0):
        self.inFlxRip = inFlxRip
        self.retCapRip = retCapRip
        self.outFlxRip = outFlxRip
        self.outCminRip = outCminRip  # constant
        self.byPassRip = byPassRip


class Gaz(Common, FluxBenthic, RiparianArea):
    """
    Gazeous variables involved in processes modeled by RIVE
    """
    def __init__(self, listV, name, cH2O=0, cLat=0,
                 fluxBent=0, retBent=0, retIntegBent=0, retPotentBent=0,
                 inFlxRip=0, retCapRip=0, outFlxRip=0, outCminRip=0, byPassRip=0,
                 schmidt=0, k=0, sat=0, vent=0):
        Common.__init__(self, listV, name,
                        cH2O=0, cLat=0)
        FluxBenthic.__init__(self, fluxBent=0, retBent=0, retIntegBent=0, retPotentBent=0)
        RiparianArea.__init__(self, inFlxRip=0, retCapRip=0, outFlxRip=0, outCminRip=0, byPassRip=0)
        self.schmidt = schmidt
        self.k = k
        self.sat = sat
        self.vent = vent


class Dissolved(Common, FluxBenthic, RiparianArea):
    """
    Dissolved variables involved in processes modeled by RIVE
    """
    def __init__(self, listV, name, cH2O=0, cLat=0,
                 fluxBent=0, retBent=0, retIntegBent=0, retPotentBent=0,
                 inFlxRip=0, retCapRip=0, outFlxRip=0, outCminRip=0, byPassRip=0):
        Common.__init__(self, listV, name,
                        cH2O=0, cLat=0)
        FluxBenthic.__init__(self, fluxBent=0, retBent=0, retIntegBent=0, retPotentBent=0)
        RiparianArea.__init__(self, inFlxRip=0, retCapRip=0, outFlxRip=0, outCminRip=0, byPassRip=0)


class Particulate(Common, FluxBenthic, Sediment, RiparianArea):
    """
    Particulate variables involved in processes modeled by RIVE
    """
    def __init__(self, listV, name, cH2O=0, cLat=0,
                 fluxBent=0, retBent=0, retIntegBent=0, retPotentBent=0,
                 inFlxRip=0, retCapRip=0, outFlxRip=0, outCminRip=0, byPassRip=0,
                 vs=0, ksed=0, cBent=0):
        Common.__init__(self, listV, name,
                        cH2O=0, cLat=0)
        FluxBenthic.__init__(self, fluxBent=0, retBent=0, retIntegBent=0, retPotentBent=0)
        Sediment.__init__(self, vs=0, ksed=0, cBent=0)
        RiparianArea.__init__(self, inFlxRip=0, retCapRip=0, outFlxRip=0, outCminRip=0, byPassRip=0)


class Microorganism(Common, Sediment, RiparianArea):
    """
    Microorganism variables involved in processes modeled by RIVE :
    plankton, bacteria
    """
    def __init__(self, listV, name, cH2O=0, cLat=0,
                 vs=0, ksed=0, cBent=0,
                 inFlxRip=0, retCapRip=0, outFlxRip=0, outCminRip=0, byPassRip=0,
                 ks=0, topt=0, dti=0, mumax20=0, kd20=0, kd=0, mumax=0):
        Common.__init__(self, listV, name,
                        cH2O=0, cLat=0)
        Sediment.__init__(self, vs=0, ksed=0, cBent=0)
        RiparianArea.__init__(self, inFlxRip=0, retCapRip=0, outFlxRip=0, outCminRip=0, byPassRip=0)
        self.ks = ks    # constant
        self.topt = topt    # constant
        self.dti = dti    # constant
        self.mumax20 = mumax20    # constant
        self.kd20 = kd20    # constant
        self.kd = kd
        self.mumax = mumax


class Phytoplankton(Microorganism):
    """
    Phytoplankton variables involved in processes modeled by RIVE :
    diatom (DIA), chlorophyceae (GRA), cyanobacteria (CYA)
    SW 14/12/2021 add cS, cR, ScLat, RcLat, mbssi, mbresp
    """
    def __init__(self, listV, name, n = 24, cH2O=0, cS=0, cR=0, cSdlx = None, cRdlx = None, cLat=0, ScLat=0, RcLat=0,
                 mbssi=0, mbresp=0, deltacS=0, deltacR=0, cSMin = -9999, cRMin = -9999, cSMax = -9999, cRMax = -9999,
                 vs=0, ksed=0, cBent=0,
                 ks=0, topt=0, dti=0, mumax20=0, kd20=0, kd=0, mumax=0,
                 kmax20=0, srmax20=0, kcr20=0, maint20=0,
                 kpp=0, kpn=0, kpsi=0, mSiC=0, cesp=0, alf=0,
                 kmax=0, srmax=0, kcr=0, maint=0,
                 S=0.1, R=0.1, muf=0, virusflag=False):
        Microorganism.__init__(
                 self, listV, name, cH2O=0, cLat=0,
                 vs=0, ksed=0, cBent=0,
                 ks=0, topt=0, dti=0, mumax20=0, kd20=0, kd=0, mumax=0)
        self.kmax20 = kmax20    # constant
        self.srmax20 = srmax20    # constant
        self.kcr20 = kcr20    # constant
        self.maint20 = maint20    # constant
        self.kpp = kpp    # constant
        self.kpn = kpn    # constant
        self.kpsi = kpsi    # constant
        self.mSiC = mSiC    # constant
        self.cesp = cesp    # constant
        self.alf = alf    # constant
        self.kmax = kmax
        self.srmax = srmax
        self.kcr = kcr
        self.maint = maint
        self.S = [ S for i in range(n) ]
        self.R = [ R for i in range(n) ]
        self.cS = cS
        self.cR = cR
        self.cSMin = cSMin
        self.cRMax = cRMax
        self.cSdlx = [ cSdlx for i in range(n) ]
        self.cRdlx = [ cRdlx for i in range(n) ]
        self.deltacS = [ deltacS for i in range(n) ]
        self.deltacR = [ deltacR for i in range(n) ]      
        self.ScLat = ScLat
        self.RcLat = RcLat
        self.mbssi = [ mbssi for i in range(n) ]
        self.mbresp = [ mbresp for i in range(n) ]
        self.muf = [ muf for i in range(n) ]
        self.virusflag = virusflag    # boolean


class Zooplankton(Microorganism):
    """
    Zooplankton variables involved in processes modeled by RIVE : ZOR, ZOC
    """
    def __init__(self, listV, name, cH2O=0, cLat=0,
                 vs=0, ksed=0, cBent=0,
                 ks=0, topt=0, dti=0, mumax20=0, kd20=0, kd=0, mumax=0,
                 Kphy=0, phy0=0, grmax20=0, grmax=0):
        Microorganism.__init__(
                 self, listV, name, cH2O=0, cLat=0,
                 vs=0, ksed=0, cBent=0,
                 ks=0, topt=0, dti=0, mumax20=0, kd20=0, kd=0, mumax=0)
        self.Kphy = Kphy    # constant
        self.phy0 = phy0    # constant
        self.grmax20 = grmax20    # constant
        self.grmax = grmax


class HeterotrophicBacteria(Microorganism):
    """
    Heterotrophic Bacteria variables involved in processes modeled by RIVE
    """
    def __init__(self, listV, name, cH2O=0, cLat=0,
                 vs=0, ksed=0, cBent=0,
                 ks=0, topt=0, dti=0, mumax20=0, kd20=0, kd=0, mumax=0,
                 e1max20=0, e2max20=0, kh1=0, kh2=0, bmax20=0, y=0,
                 e1max=0, e2max=0, bmax=0):
        Microorganism.__init__(
                 self, listV, name, cH2O=0, cLat=0,
                 vs=0, ksed=0, cBent=0,
                 ks=0, topt=0, dti=0, mumax20=0, kd20=0, kd=0, mumax=0)
        self.e1max20 = e1max20    # constant
        self.e2max20 = e2max20    # constant
        self.kh1 = kh1    # constant
        self.kh2 = kh2    # constant
        self.bmax20 = bmax20    # constant
        self.y = y    # constant
        self.e1max = e1max
        self.e2max = e2max
        self.bmax = bmax


class NitrifBacteria(Microorganism):
    """
    Nitrif Bacteria variables involved in processes modeled by RIVE
    """
    def __init__(self, listV, name, cH2O=0, cLat=0,
                 vs=0, ksed=0, cBent=0,
                 ks=0, topt=0, dti=0, mumax20=0, kd20=0, kd=0, mumax=0,
                 kO2=0, kNH4=0, kNO2=0, y=0):
        Microorganism.__init__(
                 self, listV, name, cH2O=0, cLat=0,
                 vs=0, ksed=0, cBent=0,
                 ks=0, topt=0, dti=0, mumax20=0, kd20=0, kd=0, mumax=0)
        self.kO2 = kO2    # constant
        self.kNH4 = kNH4    # constant
        self.kNO2 = kNO2    # constant
        self.y = y    # constant


class FecalBacteria(Microorganism):
    """
    Fecal Bacteria variables involved in processes modeled by RIVE
    """
    def __init__(self, listV, name, cH2O=0, cLat=0,
                 vs=0, ksed=0, cBent=0,
                 ks=0, topt=0, dti=0, mumax20=0, kd20=0, kd=0, mumax=0):
        Microorganism.__init__(
                 self, listV, name, cH2O=0, cLat=0,
                 vs=0, ksed=0, cBent=0,
                 ks=0, topt=0, dti=0, mumax20=0, kd20=0, kd=0, mumax=0)

# define FILE class for log file or time varying output printing
class FILE_log(object):
    def __init__(self, filename=None):
        self.filename = filename
    def openfile(self):
        self.file = open(self.filename,'w')

