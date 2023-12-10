# Copyright © 2023 Bartek Jasicki
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

## This module contains initialization code of the shell's theme. It is in a
## separate module to avoid circular dependencies.

# Standard library imports
# External modules imports
import contracts
import norm/sqlite
# Internal imports
import commandslist, constants, help, lstring, resultcode, theme

proc initTheme*(db: DbConn; commands: ref CommandsList) {.sideEffect, raises: [],
    tags: [ReadDbEffect, WriteIOEffect, TimeEffect, WriteDbEffect, RootEffect],
    contractual.} =
  ## Initialize the shell's theme. Set help related to the theme.
  ##
  ## * db          - the connection to the shell's database
  ## * commands    - the list of the shell's commands
  ##
  ## Returns the list of available environment variables in the current directory and
  ## the updated helpContent with the help for the commands related to the
  ## variables.
  require:
    db != nil
  body:
    # Add commands related to the shell's theme
    proc themeCommand(arguments: UserInput; db: DbConn;
        list: CommandLists): ResultCode {.raises: [], tags: [WriteIOEffect,
        WriteDbEffect, TimeEffect, ReadDbEffect, ReadIOEffect,
        RootEffect], contractual.} =
      ## The code of the shell's command "theme" and its subcommands
      ##
      ## * arguments - the arguments entered by the user for the command
      ## * db        - the connection to the shell's database
      ## * list      - the additional data for the command, like list of help
      ##               entries, etc
      ##
      ## Returns QuitSuccess if the selected command was successfully executed,
      ## otherwise QuitFailure.
      body:
        # No subcommand entered, show available options
        if arguments.len == 0:
          return showHelpList(command = "theme",
              subcommands = themeCommands, db = db)
        # Show the colors declared in the shell's theme
        if arguments.startsWith(prefix = "show"):
          return showTheme(db = db)
        try:
          return showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 5, text = "theme"),
              helpType = initLimitedString(capacity = 5, text = "theme"), db = db)
        except CapacityError:
          return QuitFailure.ResultCode

    try:
      addCommand(name = initLimitedString(capacity = 5, text = "theme"),
          command = themeCommand, commands = commands,
          subCommands = themeCommands)
    except CapacityError, CommandsListError:
      showThemeError(message = "Can't add commands related to the shell's theme. Reason: ",
          e = getCurrentException())
