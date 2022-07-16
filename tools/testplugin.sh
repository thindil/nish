#!/bin/sh

case "${1}" in
   "") echo "No command specified."; exit 1 ;;
   install) echo "Installed." ;;
   uninstall) echo "Uninstalled" ;;
   enable) echo "Enabled" ;;
   disable) echo "Disabled" ;;
   init) echo "Initialized" ;;
   *) echo "Unknown option"; exit 1 ;;
esac
