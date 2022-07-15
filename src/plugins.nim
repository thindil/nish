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

import std/[db_sqlite, os, strutils, tables, terminal]
import columnamount, constants, databaseid, history, input, lstring, output, resultcode

type PluginsList* = Table[string, string]
  ## FUNCTION
  ##
  ## Used to store the enabled shell's plugins

using
  db: DbConn # Connection to the shell's database
  arguments: UserInput # The string with arguments entered by the user for the command
  pluginsList: var PluginsList # The list of enabled plugins
  historyIndex: var HistoryRange # The index of the last command in the shell's history

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
  showOutput(message = """Available subcommands are: list, remove, show, add, enable, disable

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
    let newId = db.insertID(query = sql(
        query = "INSERT INTO plugins (location, enabled) VALUES (?, 1)"), pluginPath)
    pluginsList[$newId] = pluginPath
  except DbError:
    return showError(message = "Can't add plugin to the shell. Reason: ",
        e = getCurrentException())
  showOutput(message = "File '" & pluginPath &
      "' added as a plugin to the shell.", fgColor = fgGreen);
  return QuitSuccess.ResultCode

proc initPlugins*(db): PluginsList =
  try:
    for dbResult in db.fastRows(query = sql(
        query = "SELECT id, location, enabled FROM plugins ORDER BY id ASC")):
      if dbResult[2] == "1":
        result[dbResult[0]] = dbResult[1]
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
  pluginsList.del($pluginId)
  historyIndex = updateHistory(commandToAdd = "plugin remove", db = db)
  showOutput(message = "Deleted the plugin with Id: " & $pluginId,
      fgColor = fgGreen)
  return QuitSuccess.ResultCode

proc togglePlugin*(db; arguments; pluginsList: var PluginsList;
    historyIndex: var HistoryRange; disable: bool = true): ResultCode =
  let idStart: int = (if disable: 8 else: 7)
  if arguments.len() < (idStart + 1):
    return showError(message = "Please enter the Id to the plugin which will be disabled.")
  let
    pluginId: DatabaseId = try:
        parseInt($arguments[idStart .. ^1]).DatabaseId
      except ValueError:
        return showError(message = "The Id of the plugin must be a positive number.")
    pluginState: BooleanInt = (if disable: 0 else: 1)
  try:
    if db.execAffectedRows(query = sql(query = (
        "UPDATE plugins SET enabled=? WHERE id=?")), pluginState, pluginId) == 0:
      historyIndex = updateHistory(commandToAdd = "plugin disable", db = db,
          returnCode = QuitFailure.ResultCode)
      return showError(message = "The plugin with the Id: " & $pluginId &
        " doesn't exist.")
    if disable:
      pluginsList.del($pluginId)
    else:
      pluginsList[$pluginId] = db.getValue(query = sql(query = (
          "SELECT location FROM plugins WHERE id=?")), pluginId)
  except DbError:
    return showError(message = "Can't " & (
        if disable: "disable" else: "enable") & " plugin. Reason: ",
        e = getCurrentException())
  historyIndex = updateHistory(commandToAdd = "plugin disable", db = db)
  showOutput(message = (if disable: "Disabled" else: "Enabled") &
      " the plugin with Id: " & $pluginId, fgColor = fgGreen)
  return QuitSuccess.ResultCode

proc listPlugins*(arguments; historyIndex; plugins: PluginsList; db) {.gcsafe,
    sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect,
    WriteDbEffect, ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## List enabled plugins, if entered command was "plugin list all" list all
  ## installed then.
  ##
  ## PARAMETERS
  ##
  ## * arguments    - the user entered text with arguments for showing plugins
  ## * historyIndex - the index of command in the shell's history
  ## * plugins      - the list of enabled plugins
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The parameter historyIndex updated after execution of showing the plugins'
  ## list
  let
    columnLength: ColumnAmount = try: db.getValue(query =
        sql(query = "SELECT location FROM plugins ORDER BY LENGTH(location) DESC LIMIT 1")).len().ColumnAmount
      except DbError: 10.ColumnAmount
    spacesAmount: ColumnAmount = try: terminalWidth().ColumnAmount /
        12 except ValueError: 6.ColumnAmount
  if arguments == "list":
    showFormHeader(message = "Enabled plugins are:")
    try:
      showOutput(message = indent(s = "ID   $1" % [alignLeft(
        s = "Path",
        count = columnLength.int)], count = spacesAmount.int),
            fgColor = fgMagenta)
    except ValueError:
      showOutput(message = indent(s = "ID   Path",
          count = spacesAmount.int), fgColor = fgMagenta)
    for id, location in plugins.pairs:
      showOutput(message = indent(s = alignLeft(id, count = 4) & " " &
          alignLeft(s = location, count = columnLength.int),
              count = spacesAmount.int))
    historyIndex = updateHistory(commandToAdd = "plugin list", db = db)
  elif arguments == "list all":
    showFormHeader(message = "All available plugins are:")
    try:
      showOutput(message = indent(s = "ID   $1 Enabled" % [alignLeft(
          s = "Path", count = columnLength.int)], count = spacesAmount.int),
              fgColor = fgMagenta)
    except ValueError:
      showOutput(message = indent(s = "ID   Path Enabled",
          count = spacesAmount.int), fgColor = fgMagenta)
    try:
      for row in db.fastRows(query = sql(
          query = "SELECT id, location, enabled FROM plugins")):
        showOutput(message = indent(s = alignLeft(row[0], count = 4) & " " &
            alignLeft(s = row[1], count = columnLength.int) & " " & (if row[
                2] == "1": "Yes" else: "No"), count = spacesAmount.int))
    except DbError:
      discard showError(message = "Can't read info about plugin from database. Reason:",
          e = getCurrentException())
      return
    historyIndex = updateHistory(commandToAdd = "plugin list all", db = db)

proc showPlugin*(arguments; historyIndex; plugins: PluginsList;
    db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteIOEffect, ReadIOEffect, ReadDbEffect, WriteDbEffect, ReadEnvEffect,
    TimeEffect].} =
  ## FUNCTION
  ##
  ## Show details about the selected plugin, its ID, path and status
  ##
  ## PARAMETERS
  ##
  ## * arguments    - the user entered text with arguments for the showing
  ##                  plugin
  ## * historyIndex - the index of the last command in the shell's history
  ## * plugins      - the list of enabled plugins
  ## * db           - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the selected plugin was properly show, otherwise
  ## QuitFailure. Also, updated parameter historyIndex
  if arguments.len() < 6:
    historyIndex = updateHistory(commandToAdd = "plugin show", db = db,
        returnCode = QuitFailure.ResultCode)
    return showError(message = "Enter the ID of the plugin to show.")
  let id: DatabaseId = try:
      parseInt(s = $arguments[5 .. ^1]).DatabaseId
    except ValueError:
      return showError(message = "The Id of the plugin must be a positive number.")
  let row: Row = try:
        db.getRow(query = sql(query = "SELECT location, enabled FROM plugins WHERE id=?"), args = id)
    except DbError:
      return showError(message = "Can't read plugin data from database. Reason: ",
          e = getCurrentException())
  if row[0] == "":
    historyIndex = updateHistory(commandToAdd = "plugin show", db = db,
        returnCode = QuitFailure.ResultCode)
    return showError(message = "The plugin with the ID: " & $id &
      " doesn't exists.")
  historyIndex = updateHistory(commandToAdd = "plugin show", db = db)
  let spacesAmount: ColumnAmount = try:
      terminalWidth().ColumnAmount / 12
    except ValueError:
      6.ColumnAmount
  showOutput(message = indent(s = alignLeft(s = "Id:", count = 13),
      count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
  showOutput(message = $id)
  showOutput(message = indent(s = alignLeft(s = "Path:", count = 13),
      count = spacesAmount.int), newLine = false, fgColor = fgMagenta)
  showOutput(message = row[0])
  showOutput(message = indent(s = "Enabled: ", count = spacesAmount.int),
      newLine = false, fgColor = fgMagenta)
  showOutput(message = (if row[1] == "1": "Yes" else: "No"))
  return QuitSuccess.ResultCode
