from __future__ import print_function

try:
    from odbAccess import *
    open_odb = openOdb
except ImportError:
    from abaqus import * 
    from abaqusConstants import *
    open_odb = session.openOdb

from os import getcwd
from glob import glob

if __name__ == '__main__':
    for fn in glob('*.odb'):
        print(fn)
        try:
            odb = open_odb(str(fn))
        except:
            print('Could not open ODB. Skipping file.')
        
        try:
            step = next(reversed(odb.steps.values()))
        except StopIteration:
            print('No steps. Skipping file.')
            continue
            
        s, LPF, U = None, None, None
        for reg in step.historyRegions.values():
            if 'UR3' in reg.historyOutputs.keys():
                U = reg.historyOutputs['UR3'].data
            if 'U2' in reg.historyOutputs.keys():
                U = reg.historyOutputs['U2'].data
            if 'LPF' in reg.historyOutputs.keys():
                LPF = reg.historyOutputs['LPF'].data
        if (LPF is None) or (U is None):
            print('Missing necessary history output. Skipping file.')
            continue
        
        s = [x[0] for x in LPF]
        LPF = [x[1] for x in LPF]
        U = [x[1] for x in U]
        
        maxres, neigs = list(), list()
        for incr in odb.diagnosticData.steps[0].increments:
            if len(incr.attempts) < 1:
                maxres.append(float('nan'))
                neigs.append(float('nan'))
                continue
            att = incr.attempts[len(incr.attempts)-1]
            if len(att.iterations) < 1:
                maxres.append(float('nan'))
                neigs.append(float('nan'))
                continue
            it = att.iterations[len(att.iterations)-1]
            for res in it.residuals:
                if res.fieldVariableName == 'Displacement':
                    maxres.append(res.maxResidual)
                    break
            else:
                maxres.append(float('nan'))
            neigs.append(it.numericalProblemSummary.numberOfNegativeEigenvalues)
        
        while len(U) > len(maxres):
            maxres.append(float('nan'))
        while len(maxres) > len(neigs):
            neigs.append(float('nan'))
            
        with open(fn[:-3] + 'csv', 'w') as csv:
            for i in range(len(s)):
                print(repr(s[i]), repr(LPF[i]), repr(U[i]), repr(maxres[i]), neigs[i], sep=',', file=csv)
