#!/bin/sh

case "${1}" in
   "")
      echo 'showError "No command specified."'
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
      echo 'showOutput "Initialized"'
      ;;
   *)
      echo 'showError "Unknown option"'
      exit 1
      ;;
esac
