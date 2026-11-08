# Ansible LIMS role: upgrade Slurm in place

Brings one existing Slurm cluster to the pinned Slurm (`slurm_ver`, 26.05.5)
and, if asked, turns on job memory limits.  Unlike `config-lims-slurm`, which
renders a one-node `slurm.conf` for a new host, it changes only the lines it
needs in each node's existing `slurm.conf` and `cgroup.conf`, so hand-edited
clusters (several nodes, other node names, extra settings) keep their setup.

Run it with `upgrade-slurm-playbook.yml` against every node of one cluster,
with no jobs queued or running and the LIMS idle.

## Inventory

One group per cluster.  The host running slurmctld has `slurm_controller=true`
(not needed for a one-node cluster); a host whose `NodeName` in `slurm.conf` is
not its short host name has `slurm_node_name`.  For example:

```ini
[clusterA]
headnode   slurm_controller=true
computenode
[clusterB]
host0      slurm_controller=true slurm_node_name=node0 slurm_real_memory_mb=400000
host1      slurm_node_name=node1 slurm_real_memory_mb=40000
```

Every `NodeName` in `slurm.conf` must be a host of the group (a node that is
down still has to be reachable), and node ranges (`node[1-4]`) are not handled.
Nodes reached through another host need `ansible_ssh_common_args` with
`-o ProxyJump=...`.

## Running it

```
ansible-playbook -i inventory upgrade-slurm-playbook.yml -e slurm_cluster=clusterA --check
ansible-playbook -i inventory upgrade-slurm-playbook.yml -e slurm_cluster=clusterA
```

`--check` makes all the checks and shows the changes to `slurm.conf` and
`cgroup.conf` (staged under `slurm_backup_root/staged`), changing nothing else.
Memory limits are turned on with:

```
-e slurm_mem_enforce=true -e slurm_def_mem_per_cpu_mb=<MB>
```

and `slurm_real_memory_mb` per host where its node line has no `RealMemory`
(see the config-lims-slurm README for what the values mean).
`-e slurm_upgrade=false` sets the limits without upgrading.

## What it does

Before stopping anything, on every node:

- refuses if jobs are queued, the nodes run different Slurm versions or one
  newer than `slurm_ver`, `slurm.conf` differs between the nodes (other than
  lines matching `slurm_conf_may_differ`, the controller address lines), a
  node of `slurm.conf` is not in the play, slurmdbd accounting is configured
  (its database must be upgraded one release step at a time), or there is no
  copy of the installed packages in `slurm_old_rpm_dir` to roll back to
  (override with `slurm_upgrade_without_rpm_backup=true`);
- with memory limits: refuses unless each node's `RealMemory` is known, fits
  its memory, and the host's cgroups support it (as config-lims-slurm checks);
- builds `slurm_ver` on the controller with `rpmbuild`, like config-lims-slurm,
  and copies the packages to the other nodes;
- stages the new files and requires them to be the same on every node.  On an
  upgrade it comments out settings `slurm_ver` rejects (`slurm_conf_defunct`,
  `cgroup_conf_defunct`); with memory limits it sets `ProctrackType`,
  `TaskPlugin`, `SelectTypeParameters`, `DefMemPerCPU`, each node's
  `RealMemory`, and `ConstrainRAMSpace`, `ConstrainSwapSpace` and
  `AllowedSwapSpace` in `cgroup.conf`.

Then:

- backs up `/etc/slurm`, the package list and package files, the controller's
  state and slurmd's spool to `slurm_backup_root/<date-time>` on every node;
- stops slurmd on every node, then slurmctld;
- installs the new packages;
- if the old release is older than `slurm_state_min_version` (the oldest whose
  saved state `slurm_ver` reads), empties the state and spool directories and
  sets `FirstJobId` to the next job number, so job numbers go on rising (the
  LIMS keys each job on its Slurm job number);
- puts the staged files in place, starts munge, slurmctld, then slurmd;
- verifies that every node is idle on the expected version, the settings are
  live, and a probe job runs on every node (within its memory limit, with
  limits on).

If anything fails after the backup, it stops and prints how to put the backup
back:

```
ansible-playbook -i inventory upgrade-slurm-playbook.yml -e slurm_cluster=clusterA -e slurm_rollback_from=<date-time>
```

which reinstalls the old packages, restores `/etc/slurm` (the replaced copy
stays in the backup directory) and the state, starts the daemons and waits
for every node to be idle on the old version.  The restored state is the one
from before the run, so job numbers given out since (the probe jobs, and any
job submitted in between) are given out again: keep the LIMS idle until the
cluster is back.

## Notes

- The pin and its checksum are `slurm_ver` and `slurm_md5` in
  `defaults/main.yml`; keep them equal to `install-lims-server-playbook.yml`, and update
  `slurm_state_min_version` with them (Slurm reads saved state from the three
  previous releases).
- GPUs (`GresTypes`, `gres.conf`) are left as they are; the role's Slurm build
  has no NVML support.
- The controller must also be a node of `slurm.conf`.
