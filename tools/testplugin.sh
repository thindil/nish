#!/bin/sh

case "${1}" in
   "")
      echo 'showError "No plugin command specified."'
      exit 1
      ;;
   install)
      echo 'showOutput "Installing the testplugin."
            setOption testPlugin value "Test option from test plugin" text
            showOutput "Installed the testplugin." fgGreen'
      ;;
   uninstall)
      echo 'showOutput "Uninstalling the testplugin."
            removeOption testPlugin
            showOutput "Uninstalled" fgGreen'
      ;;
   enable)
      echo 'showOutput "Enabling the testplugin"
            getOption testPlugin'
      read -t 1 value
      echo "showOutput \"Value for testPlugin is $value\""
      echo "showOutput \"Initialized the testplugin\" fgGreen"
      ;;
   disable)
      echo 'showOutput "Disabled"'
      ;;
   init)
      echo 'showOutput "Initializing the testplugin"
            getOption testPlugin'
      read -t 1 value
      echo "showOutput \"Value for testPlugin is $value\""
      echo "showOutput \"Initialized the testplugin\" fgGreen"
      ;;
   *)
      echo 'showError "Unknown plugin command."'
      exit 1
      ;;
esac
