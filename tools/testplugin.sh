#!/bin/sh

case "${1}" in
   "")
      echo 'showError "No command specified."'
      exit 1
      ;;
   install)
      echo 'showOutput "Installed"'
      ;;
   uninstall)
      echo 'showOutput "Uninstalled"'
      ;;
   enable)
      echo 'showOutput "Enabled"'
      ;;
   disable)
      echo 'showOutput "Disabled"'
      ;;
   init)
      echo 'showOutput "Initialized"'
      ;;
   *)
      echo 'showError "Unknown option"'
      exit 1
      ;;
esac
