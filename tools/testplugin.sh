#!/bin/sh
# Copyright © 2022 Bartek Jasicki <thindil@laeran.pl>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 3. Neither the name of the copyright holder nor the
# names of its contributors may be used to endorse or promote products
# derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY COPYRIGHT HOLDERS AND CONTRIBUTORS ''AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# As the whole the shell <=> the plugin communication is made by the standard
# input and output, all plugin's calls should be done as standard output
# messages, when the plugin should read the shell's API calls as its command
# line arguments for sections calls, like "install" or "enable", or as a normal
# input for any other like "getOption". Also, multiple plugin's calls can be
# done by one printing command, then calls must be separated by new line, or by
# separated printing command, one call per command. More information about
# available API calls can be found in README.md file or on the project page in
# documentation.

case "${1}" in
   # No API call when calling the plugin specified, show the error information
   # and quit with error code.
   "")
      # Show the selected text in the standard error output
      echo 'showError "No plugin command specified."'
      exit 1
      ;;
   # Called during the plugin installation. A good place to set any options
   # related to the plugin.
   install)
      # Show the messages about installing the plugin and set the shell's
      # option related to the plugin. It can be done in one call (as below) or
      # in separated calls as in "enable" section
      echo 'showOutput "Installing the testplugin."
            setOption testPlugin value "Test option from test plugin" text
            showOutput "Installed the testplugin." fgGreen'
      ;;
   # Called during removing the plugin from the shell's plugins' system. A good
   # place to remove any options set by the plugin.
   uninstall)
      echo 'showOutput "Uninstalling the testplugin."
            removeOption testPlugin
            showOutput "Uninstalled" fgGreen'
      ;;
   # Called during enabling the plugin and during installing it, after the
   # install section. A good place to set some settings for the plugin
   enable)
      # Show the message and read the value of the selected shell option
      echo 'showOutput "Enabling the testplugin"
            getOption testPlugin'
      # Get the answer from the shell from the standard input
      read -t 1 value
      # Show the value of the option, read from the shell
      echo "showOutput \"Value for testPlugin is $value\""
      # Show another message, colored in green
      echo "showOutput \"Enabled the testplugin\" fgGreen"
      ;;
   # Called during disabling the plugin.
   disable)
      # Show the selected text with the selected color on the standard output
      echo 'showOutput "Disabled the testplugin" fgGreen'
      ;;
   # Called during start the shell, when the plugin is enabled. A good place to
   # set settings for the plugin
   init)
      # Show the message and read the value of the selected shell option
      echo 'showOutput "Initializing the testplugin"
            getOption testPlugin'
      # Get the answer from the shell from the standard input
      read -t 1 value
      # Show the value of the option, read from the shell
      echo "showOutput \"Value for testPlugin is $value\""
      # Show another message, colored in green
      echo "showOutput \"Initialized the testplugin\" fgGreen"
      ;;
   # It require to return a string with four values: the plugin name, the
   # plugin description, the supported API version and the list of API commands
   # which will be executed by the plugin (separated by comma). Values have to
   # be separated with semicolon.
   info)
      # Send answer to the shell with the plugin's name, description, API
      # version and list of API commands
      echo 'answer "Testplugin;Test plugin;0.2;install,uninstall,enable,disable,init,info,preCommand,postCommand"'
      ;;
   # Called before each the user's command is executed. The second argument is
   # the full command, with arguments, which will be executed.
   preCommand)
      # Show the message with full to be executed command
      echo "showOutput \"The command which will be executed: ${2}\""
      ;;
   # Called after execution of each the user's command. The second argument is
   # the full command, with arguments, which was executed.
   postCommand)
      # Show the message with full executed command
      echo "showOutput \"The command which was executed: ${2}\""
      ;;
   # Unknown API option called. Quit with status code 2 so the shell can know
   # about unsupported command
   *)
      exit 2
      ;;
esac
