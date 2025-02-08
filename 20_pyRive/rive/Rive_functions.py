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
Functions used by Rive module.
"""

from __future__ import division
from math import exp, sqrt, log, cos, log10

from .Rive_var import (c, p)


def fTemp(temp, topt, dti):
    """
    :param temp: temperature in °C
    :param topt: optimal temperature in °C
    :param dti: range of temperature in °C
    """

    return exp(-((temp - topt) ** 2 / dti ** 2)) / exp(-((20 - topt) ** 2 / dti ** 2))


def mich(S, Ks):
    """ Michaelis Menten kinetics
    :param S: substrate concentration
    :param Ks: Michaelis constant
    """

    return S / (S + Ks)


def phosph(cTIP, cSPM):
    """ Adsorption equilibrium of PO4 on suspended matters
    :param cTIP: concentration of Total Inorganic Phophorus
    :param cSPM: concentration of Supended Mater
    :return: PO4 concentration
    """

    rP = c['kpads'] - cTIP + cSPM * c['pac']
    return (-rP + sqrt(rP ** 2 + 4 * cTIP * c['kpads'])) / 2


def rho(T, sal, P):
    """ Calculate water density (kg.m-3) - the International Ine Atmosphere Equation
        Millero and Poisson, Deep-sea Research (1981)
    :param T: temperature in °C
    :param sal: salinity in PSU
    :param P: applied pressure (bars) (0 in Freshwater)
    :return: ROP (kg.m-3)
    """

    #      Rho0
    A0 = 0.999842594E03
    A1 = 6.793952E-02
    A2 = -9.095290E-03
    A3 = 1.001685E-04
    A4 = -1.120083E-06
    A5 = 6.536332E-09

    #      A
    B0 = 8.24493E-01
    B1 = -4.0899E-03
    B2 = 7.6438E-05
    B3 = -8.2467E-07
    B4 = 5.3875E-09

    #      B
    C0 = -5.72466E-03
    C1 = 1.0227E-04
    C2 = -1.6546E-06

    #      C
    D0 = 4.8314E-04

    E0 = 1.965221E04
    E1 = 1.484206E02
    E2 = -2.327105E00
    E3 = 1.360477E-02
    E4 = -5.155288E-05

    #    parameters in k(S,T,0)
    F0 = 5.46746E01
    F1 = -0.603459E00
    F2 = 1.09987E-02
    F3 = -6.1670E-05

    G0 = 7.944E-02
    G1 = 1.6483E-02
    G2 = -5.3009E-04

    H0 = 3.239908E00
    H1 = 1.43713E-03
    H2 = 1.16092E-04
    H3 = -5.77905E-07

    I0 = 2.2838E-03
    I1 = -1.0981E-05
    I2 = -1.6078E-06

    J0 = 1.91075E-04

    K0 = 8.50935E-05
    K1 = -6.12293E-06
    K2 = 5.2787E-08

    M0 = -9.9348E-07
    M1 = 2.0816E-08
    M2 = 9.1697E-10

    KW = E0 + E1 * T + E2 * T ** 2 + E3 * T ** 3 + E4 * T ** 4
    AW = H0 + H1 * T + H2 * T ** 2 + H3 * T ** 3
    BW = K0 + K1 * T + K2 * T ** 2

    B = BW + (M0 + M1 * T + M2 * T ** 2) * sal
    A = AW + (I0 + I1 * T + I2 * T ** 2) * sal + J0 * sal ** 1.5E00

    #      k(S,T,0)
    KNUL = KW + (F0 + F1 * T + F2 * T ** 2 + F3 * T ** 3) * sal
    KNUL = KNUL + (G0 + G1 * T + G2 * T ** 2) * sal ** 1.5E00

    #      k(S,T,P) Secant bulk modulus
    KP = KNUL + A * P + B * P ** 2

    #      Water density
    ROW = A0 + A1 * T + A2 * T ** 2 + A3 * T ** 3 + A4 * T ** 4 + A5 * T ** 5
    RONUL = ROW + (B0 + B1 * T + B2 * T ** 2 + B3 * T ** 3 + B4 * T ** 4) * sal

    #      Sea water density
    RONUL = RONUL + (C0 + C1 * T + C2 * T ** 2) * sal ** 1.5E00 + D0 * sal ** 2
    ROP = RONUL / (1.E00 - P / KP)

    return ROP


def CO2_dry_wet_conversion(temp_air, xCO2a, sal):
    """ Dry-wet air conversion (Weiss & Price, 1980) (XCO2a = wet; xCO2 = dry in uatm)
    :param temp_air: air temperature in °C
    :param sal: salinity in PSU
    :param xCO2a: atmospheric CO2 partial pressure
    :return: xCO2 (uatm)
    """

    VPH2O = exp(24.4543 - 67.4509 * (100. / (temp_air + 273.15)) - 4.8489 * log((temp_air + 273.15) / 100.) - 0.000544 * sal)
    xCO2 = (1 - VPH2O) * xCO2a                     #  Doe, 1994 or Pierrot and al., 2006
    return xCO2


def CO2_solubility(temp, sal):
    """ Solubility of CO2 gas (mol.kg-1.atm-1)
    :param temp: temperature in °C
    :param sal: salinity in PSU
    :return: k0 (mol.kg-1.atm-1)
    """

    TK = temp + 273.15
    io = -60.2409 + 93.4517 * (100. / TK) + 23.3585 * log(TK / 100.)
    io = io + sal * (0.023517 - 0.023656 * (TK / 100.) + 0.0047036 * (TK / 100.) ** 2)
    k0 = exp(io)
    return k0


def calcCO2(pH, temp, sal, TA, DIC, CO2, id_sim):
    """
    Calculation program of carbonate speciation and CO2 exchange at the air-water interface
    N. Gypens, A.V. Borges, A. Marescaux
    March 2019

    Outputs

    State variables: DIC and TA
    Dissolved inorganic carbon (DIC): photosynthesis and respiration
    Total alkalinity (TA): N transformation and CaCO3 dissolution and precipitation (CaCO3 TODO)

    Computes the speciation of the carbonate system with any two parameters (based on mode 'm')
    The carbonate system introduces six variables (CO2, HCO3-, CO32-, H+, DIC and CA) and implies four equations.
    In consequence if 2 variables are known, the system is determined and all other component can be calculated
    See Zeebe and Wolf-Gladrow, CO2 in Seawater: Equilibrium, Kinetics, Isotopes Chapter 1, Equilibrium p4

    temp        : Temperature                       (deg C)
    sal         : Salinity                          (PSU)
    m           : Mode indicator                    (-)
    TA          : Total alkalinity                  (umol.kg-1)
    DIC0        : Total dissolved inorganic carbon  (umol.m-3)
    DIC         : Total dissolved inorganic carbon  (mgC.L-1)
    pH          : pH                                (-)
    id_sim      : identifier simulation SW 01/06/2022 (-)
    CO3         : Total carbonate (CO32-) []        (mgC.L-1)
    HCO3        : Total bicarbonate (HCO3-) []      (mgC.L-1)
    CO2         : Total dissolved CO2               (mgC.L-1)

    TCO3        : Total carbonate (CO32-) []        (umol.kg-1)
    THCO3       : Total bicarbonate (HCO3-) []      (umol.kg-1)
    TCO2        : Total dissolved CO2               (umol.kg-1)

    pCO2        : partial pressure of CO2           (uatm)


    Kb          : Acid Dissociation Constants # http://www2.chemistry.msu.edu/courses/cem262/aciddissconst.html
    Analytical Chemistry, An Introduction 7th Edition: Appendix 2, p. A-3

    K1 and K2 : Dissociation constants of carbonic acid :
    Millero, Marine Chemistry (2006)
    Harned and Davis, Journal of the American Chemical Society (1943)
    Harned and Scholes, Journal of the American Chemical Society (1941)
    Zeebe and Wolf-Gladrow (2001)

    # Initialization of CO2 module
    P = 1013.25     : atmospheric pressure                (hPa)
    sal = 0         : Salinity                            (PSU)


    m = 1           # Select case 1 if no pH; select case 2 if pH is available
    n = 2           # Select case to calculate the speciation of carbonate by 1) by TA or 2) by DIC (prefer 2)
    pH.cH2O = 7.84  # if m = 2, give pH                     (-)

    """

    import decimal
    decimal.getcontext().prec = 100

    m = 1  # (pH is not an input of the model)
    n = 2  # Choice between CO2 calculated from TA or DIC, Marescaux et al. 2019 => n=2 DIC

    #Kb = 5.81 * 10E-10  # dissociation constant of boric acid (no need in freshwater)
    
    # SW 30/05/2022 5.81 * 10E-10 equals to 5.81 * 10^-9, but the value should be 5.81 * 10^-10 mol L-1
    #Kb = 5.81 * 10E-10 # dissociation constant of boric acid (no need in freshwater)
    Kb = 5.81E-10  # dissociation constant of boric acid (no need in freshwater)
    Bor0 = 0  # Total dissolved boron concentration (freshwater=0mM and Sea water = 0.41mM)

    TK = temp + 273.15

    # I = 19.924 * sal / (1000 - 1.005 * sal) Ionic strength for sea water

    #   K1 and K2 for carbonate (english log= french ln)
    pk1c = -126.34048 + 6320.813 / TK + 19.568224 * log(TK)
    pk2c = -90.18333 + 5143.692 / TK + 14.613358 * log(TK)

    K1C = 10 ** (-1. * pk1c)
    K2C = 10 ** (-1. * pk2c)

    #     Solubility of CO2 gas (mol.kg-1.atm-1)
    k0 = CO2_solubility(temp, sal=0)

    # Select case m=1 => No pH in input
    if m == 1:
        # Calcul pH: derived from Culberson(1980). Development Nathalie Gypens and Audrey Marescaux
        # ( DIC : conversion mg.C L-1 en µmol kg-1)
        DIC_m = DIC.cH2Odlx[id_sim] / 12 / rho(temp, 0, 0) * 10 ** 6

        Xdiss = (1. - Bor0 / TA.cH2Odlx[id_sim]) * Kb + (1 - DIC_m / TA.cH2Odlx[id_sim]) * K1C  # = pCulb in the publication
        Ydiss = (1 - (Bor0 + DIC_m) / TA.cH2Odlx[id_sim]) * K1C * Kb + (1 - 2 * DIC_m / TA.cH2Odlx[id_sim]) * K1C * K2C  # = qCulb in the publication
        Zdiss = (1 - (Bor0 + 2 * DIC_m) / TA.cH2Odlx[id_sim]) * K1C * K2C * Kb  # = rCulb in the publication
        aCulb = (Xdiss ** 2 - 3 * Ydiss) / 9  # =-aCulb/3
        bCulb = (-(2 * Xdiss ** 3 - 9 * Xdiss * Ydiss + 27 * Zdiss)) / 54  # = bCulb/2 in the publication
        phyCulb = cos(round(bCulb / round(((aCulb ** 3) ** 0.5), 30), 30))
        Hdiss = 2 * aCulb ** 0.5 * cos(phyCulb / 3) - Xdiss / 3  # H hydrogen ion activity

        pH.cH2Odlx[id_sim] = -1. * log10(Hdiss)
        
        if n == 1:
            # CO2 as a function of AC (Speciation of carbonate see Marescaux et al. 2019)
            # BOH4 = Kb * Bor0 / (Hdiss + Kb) tetrahydroxyborate = 0 for Freshwater : AC = TA
            AC = TA.cH2Odlx[id_sim] - Kb * Bor0 / (Kb + Hdiss)                     # µmol L-1
            TCO3 = AC * K2C / (Hdiss + 2 * K2C)                         # µmol L-1
            THCO3 = AC / (1. + 2. * K2C / Hdiss)                        # µmol L-1
            TCO2 = (AC * Hdiss / K1C) / (1. + 2. * K2C / Hdiss)         # µmol L-1
            p['pCO2'] = TCO2 / k0                                       # conversion µmol kg-1 en uatm or ppm
            CO2.cH2Odlx[id_sim] = TCO2 * 12 * 10 ** (-3)                           # CO2 : conversion µmol L-1 en mgC L-1

        elif n == 2:
            # CO2 as a function of DIC (Speciation of carbonate see Marescaux et al. 2019)
            CO3 = (K2C / Hdiss) * DIC.cH2Odlx[id_sim] / (Hdiss / K1C + K2C / Hdiss + 1.)       # mgC L-1
            HCO3 = DIC.cH2Odlx[id_sim] / (1. + Hdiss/K1C + K2C / Hdiss)                        # mgC L-1
            CO2.cH2Odlx[id_sim] = (Hdiss / K1C) * DIC.cH2Odlx[id_sim] / (1. + K2C / Hdiss + Hdiss / K1C)  # mgC L-1
            p['pCO2'] = CO2.cH2Odlx[id_sim] / (k0 * 12 * 10 ** (-3))                           # Henry's law + conversion mgC L-1 en uatm or ppm

    # case 2 (if the pH is available, speciation of carbonate)
    elif m == 2:
        H3O = 10. ** (-1. * pH.cH2Odlx[id_sim])
        AC = TA.cH2Odlx[id_sim] - Kb * Bor0 / (Kb + H3O)
        TCO3 = AC * K2C / (H3O + 2 * K2C)
        THCO3 = AC / (1. + 2. * K2C / H3O)
        CO2t = (AC * H3O / K1C) / (1. + 2. * K2C / H3O)
        p['pCO2'] = CO2t / k0
        CO2.cH2Odlx[id_sim] = CO2t * rho(temp, sal, P=0) * 12 * 10 ** (-6)  # CO2 : conversion µmol kg-1 en mgC L-1

    return CO2.cH2Odlx[id_sim]
