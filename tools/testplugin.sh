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
      read value
      echo 'showOutput "Value for testplugin is $value"
            showOutput "Enabled the testplugin"'
      ;;
   disable)
      echo 'showOutput "Disabled"'
      ;;
   init)
      echo 'showOutput "Initializing the testplugin"
            getOption testPlugin'
      read value
      echo 'showOutput "Value for testplugin is $value"
            showOutput "Initialized the testplugin"'
      ;;
   *)
      echo 'showError "Unknown plugin command."'
      exit 1
      ;;
esac
