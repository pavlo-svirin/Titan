#!/usr/bin/env python3.5
import os
import sys
from mpi4py import MPI
from subprocess import call

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
mydir = os.path.dirname(os.path.realpath(__file__))
workdir = sys.argv[2]
scripts_dir = sys.argv[1]

print("Rank: " + str(rank))
print("workdir: " + workdir)
print("scripts dir" + scripts_dir)
#call(["./alien_job.sh", str(rank)])
call([scripts_dir + "/alien_multijob_run.sh", str(rank), workdir])
