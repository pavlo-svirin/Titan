#!/usr/bin/env python3.4
import os
from mpi4py import MPI
from subprocess import call

comm = MPI.COMM_WORLD
rank = comm.Get_rank()

print(rank)
#call(["./alien_job.sh", str(rank)])
call(["./alien_job_run.sh", str(rank)])
