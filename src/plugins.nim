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

import std/db_sqlite
import constants, history, input, lstring, output, resultcode

type PluginsList* = seq[string]
  ## FUNCTION
  ##
  ## Used to store the enabled shell's plugins

using db: DbConn # Connection to the shell's database

proc createPluginsDb*(db): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [WriteDbEffect, ReadDbEffect, WriteIOEffect], locks: 0.} =
  ## FUNCTION
  ##
  ## Create the table plugins
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if creation was successfull, otherwise QuitFailure and
  ## show message what wrong
  try:
    db.exec(query = sql(query = """CREATE TABLE plugins (
               id          INTEGER       PRIMARY KEY,
               location    VARCHAR(""" & $maxInputLength &
          """) NOT NULL,
               enabled     BOOLEAN       NOT NULL
            )"""))
  except DbError:
    return showError(message = "Can't create 'plugins' table. Reason: ",
        e = getCurrentException())
  return QuitSuccess.ResultCode

proc helpPlugins*(db): HistoryRange {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Show short help about available subcommands related to the plugins
  ##
  ## PARAMETERS
  ##
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The new length of the shell's commands' history.
  showOutput(message = """Available subcommands are: list, delete, show, add, enable, disable

        To see more information about the subcommand, type help plugin [command],
        for example: help plugin list.
""")
  return updateHistory(commandToAdd = "plugin", db = db)

proc pluginAdd*(db; arguments: UserInput): ResultCode =
  if arguments.len() < 8:
    return showError(message = "Please enter the path to the plugin which will be added to the shell.")
  return QuitSuccess.ResultCode

proc pluginsInit*(db): PluginsList =
  for dbResult in db.fastRows(query = sql(
      query = "SELECT location, enabled FROM plugins")):
    if dbResult[1] == "1":
      result.add(dbResult[0])
