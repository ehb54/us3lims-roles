#!/bin/bash
# Load the ultrascan/gui module in every shell (installed by build-us3).
#
# Named zz-us3.sh so it runs after the other /etc/profile.d scripts. Some Lmod setups
# (e.g. a cloud image's z99-lmod-default-modules.sh) run "module restore", which drops
# any module loaded before them (ultrascan-tickets#1199).

command -v module >/dev/null 2>&1 || return 0

# The ultrascan/* and mpi/* modulefiles are in /etc/modulefiles and /usr/share/modulefiles.
# environment-modules searches both; Lmod may not, so add the missing ones.
for us3_moddir in /etc/modulefiles /usr/share/modulefiles; do
   case ":${MODULEPATH:-}:" in
      *":${us3_moddir}:"*) ;;
      *) [ -d "${us3_moddir}" ] && module use --append "${us3_moddir}" ;;
   esac
done
unset us3_moddir

# Lmod prints a note when unloading a module that is not loaded
if module is-loaded ultrascan/gui; then
   module unload ultrascan/gui
fi
module load ultrascan/gui
