# Ansible LIMS role: configure Slurm  

A role to configure the Munge & Slurm on the server. 

## Requirements 
- geerlingguy.repo-epel 
## Role Variables
 
#### Default slurm bariables 
```yaml 
cluster_name: localhost 
control_machine: localhost 
cores: 2
```

#### Required variables

```yaml
slurm_ver: 20.02.2 
```
The version of slurm we're installing is required. 

#### Job memory limits (optional)

```yaml
slurm_mem_enforce: true
slurm_real_memory_mb: <MB>
slurm_def_mem_per_cpu_mb: <MB>
```

Off by default, and then `slurm.conf` is as before: Slurm puts no memory limit
on a job, and refuses any job that requests memory (`--mem`, `--mem-per-cpu`),
because the node has no `RealMemory`.

With `slurm_mem_enforce: true` each job runs in a cgroup that holds it to the
memory Slurm gave it, swap included; a job that goes over is killed alone and
ends as `OUT_OF_MEMORY`.  Slurm places jobs by memory as well as cores.

- `slurm_real_memory_mb`: the memory Slurm may give to all its jobs together.
  Leave out what the database, the web server, the LIMS services and
  interactive users need.  At most the host's memory.
- `slurm_def_mem_per_cpu_mb`: the memory per CPU of a job that requests none
  (a LIMS job requests memory only where its cluster entry sets `mempercore`).
  A job of N CPUs then gets N times this.  Too small a value kills jobs that
  run today; jobs whose memory adds up past `slurm_real_memory_mb` wait.

The role writes `/etc/slurm/cgroup.conf` and sets `ProctrackType=proctrack/cgroup`,
`TaskPlugin=task/cgroup`, `SelectTypeParameters=CR_Core_Memory`, `DefMemPerCPU`
and the node's `RealMemory`, then restarts slurmctld and slurmd: run it with no
jobs in the queue.  It stops before changing anything unless both values are
set and the host has either cgroup v1 with the memory and freezer controllers
(EL 8, where this was tested) or Slurm's cgroup v2 plugin (`cgroup_v2.so`).
On a cgroup v2 host (EL 10) Slurm 22.05 or later must be built with cgroup v2
support (`rpmbuild --with cgroupv2`, which needs `dbus-devel`); this role's
build does not do that yet, and cgroup v2 is untested.  Setting
`slurm_mem_enforce` back to false restores the old `slurm.conf` and leaves
`cgroup.conf` in place, unused.

## Example Playbook 
```yaml
- hosts: servers  
  vars: 
    - slurm_ver: 20.02.2
  roles:
    - config-lims-slurm
