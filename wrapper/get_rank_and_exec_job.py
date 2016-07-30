#!/usr/bin/env python3.4
import os
import sys
from mpi4py import MPI
from subprocess import call

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
mydir = os.path.dirname(os.path.realpath(__file__))
workdir = sys.argv[0]

print(rank)
#call(["./alien_job.sh", str(rank)])
call([mydir + "/alien_job_run.sh", str(rank), workdir])
