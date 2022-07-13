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

import std/[db_sqlite, os, strutils, terminal]
import constants, databaseid, history, input, lstring, output, resultcode

type PluginsList* = seq[string]
  ## FUNCTION
  ##
  ## Used to store the enabled shell's plugins

using
  db: DbConn # Connection to the shell's database
  arguments: UserInput # The string with arguments entered by the user for the command
  pluginsList: var PluginsList # The list of enabled plugins

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

proc addPlugin*(db; arguments; pluginsList): ResultCode =
  if arguments.len() < 5:
    return showError(message = "Please enter the path to the plugin which will be added to the shell.")
  let pluginPath: string = try:
      normalizedPath(path = getCurrentDir() & DirSep & $arguments[4..^1])
    except OSError:
      $arguments[4..^1]
  if not fileExists(filename = pluginPath):
    return showError(message = "File '" & pluginPath & "' doesn't exist.")
  try:
    if db.getRow(query = sql(query = "SELECT id FROM plugins WHERE location=?"),
        pluginPath) != @[""]:
      return showError(message = "File '" & pluginPath & "' is already added as a plugin to the shell.")
    db.exec(query = sql(query = "INSERT INTO plugins (location, enabled) VALUES (?, 1)"), pluginPath)
  except DbError:
    return showError(message = "Can't add plugin to the shell. Reason: ",
        e = getCurrentException())
  pluginsList.add(pluginPath)
  showOutput(message = "File '" & pluginPath &
      "' added as a plugin to the shell.", fgColor = fgGreen);
  return QuitSuccess.ResultCode

proc initPlugins*(db): PluginsList =
  try:
    for dbResult in db.fastRows(query = sql(
        query = "SELECT location, enabled FROM plugins ORDER BY id ASC")):
      if dbResult[1] == "1":
        result.add(dbResult[0])
  except DbError:
    discard showError(message = "Can't read data about the shell's plugins. Reason: ",
        e = getCurrentException())

proc removePlugin*(db; arguments; pluginsList: var PluginsList;
    historyIndex: var HistoryRange): ResultCode =
  if arguments.len() < 8:
    return showError(message = "Please enter the Id to the plugin which will be removed from the shell.")
  let pluginId: DatabaseId = try:
      parseInt($arguments[7 .. ^1]).DatabaseId
    except ValueError:
      return showError(message = "The Id of the plugin must be a positive number.")
  try:
    if db.execAffectedRows(query = sql(query = (
        "DELETE FROM plugins WHERE id=?")), pluginId) == 0:
      historyIndex = updateHistory(commandToAdd = "plugin remove", db = db,
          returnCode = QuitFailure.ResultCode)
      return showError(message = "The plugin with the Id: " & $pluginId &
        " doesn't exist.")
  except DbError:
    return showError(message = "Can't delete plugin from database. Reason: ",
        e = getCurrentException())
  pluginsList.del(pluginId.int - 1)
  historyIndex = updateHistory(commandToAdd = "plugin remove", db = db)
  showOutput(message = "Deleted the plugin with Id: " & $pluginId,
      fgColor = fgGreen)
  return QuitSuccess.ResultCode
