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
RIVE biogeo variables creation.
"""

from .Rive_classes import (Dissolved, Particulate, Gaz, Sediment,
                          Phytoplankton, Zooplankton, HeterotrophicBacteria,
                          NitrifBacteria, FecalBacteria, FluxBenthic, FILE_log)


# Dictionary c to store constants from parameters files
c = {}

# Dictionary p to store parameters
p = {}

# Variables
listVar = []

NO3 = Dissolved(listVar, "NO3")
NH4 = Dissolved(listVar, "NH4")

TIP = Dissolved(listVar, "TIP")
PO4 = Dissolved(listVar, "PO4")
PIP = Particulate(listVar, "PIP")

SPM = Particulate(listVar, "SPM")
pH = Dissolved(listVar, "pH")

DSI = Dissolved(listVar, "DSI")
BSI = Particulate(listVar, "BSI")

OXY = Gaz(listVar, "OXY")
N2O = Gaz(listVar, "N2O")
CH4 = Gaz(listVar, "CH4")
CO2 = Gaz(listVar, "CO2")

NO2 = Dissolved(listVar, "NO2")

DOM1 = Dissolved(listVar, "DOM1")
DOM2 = Dissolved(listVar, "DOM2")
DOM3 = Dissolved(listVar, "DOM3")

TA = Dissolved(listVar, 'TA')
DIC = Dissolved(listVar, 'DIC')

POM1 = Particulate(listVar, "POM1")
POM2 = Particulate(listVar, "POM2")
POM3 = Particulate(listVar, "POM3")

SODA = Dissolved(listVar, "SODA")

DIA = Phytoplankton(listVar, 'DIA')
GRA = Phytoplankton(listVar, 'GRA')
CYA = Phytoplankton(listVar, 'CYA')

ZOR = Zooplankton(listVar, 'ZOR')
ZOC = Zooplankton(listVar, 'ZOC')

SHB = HeterotrophicBacteria(listVar, 'SHB')
LHB = HeterotrophicBacteria(listVar, 'LHB')

AFC = FecalBacteria(listVar, 'AFC')
FFC = FecalBacteria(listVar, 'FFC')

AOB = NitrifBacteria(listVar, 'AOB')
NOB = NitrifBacteria(listVar, 'NOB')

listVar = tuple(listVar)
listPhyto = list(filter(lambda x: isinstance(x, Phytoplankton), listVar))
listZoo = list(filter(lambda x: isinstance(x, Zooplankton), listVar))
listGaz = list(filter(lambda x: isinstance(x, Gaz), listVar))
listHetBact = list(filter(lambda x: isinstance(x, HeterotrophicBacteria), listVar))
listFecBact = list(filter(lambda x: isinstance(x, FecalBacteria), listVar))
listNitBact = list(filter(lambda x: isinstance(x, NitrifBacteria), listVar))
listSed = list(filter(lambda x: isinstance(x, Sediment), listVar))
listFluxBenthic = list(filter(lambda x: isinstance(x, FluxBenthic), listVar))
listBent = list(filter(lambda x: isinstance(x, Particulate), listVar)) + [AFC,]

# Benthic respiration
respBent = []

# log file
flog = FILE_log()

