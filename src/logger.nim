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

## This module contains code related to logging the shell debug messages to
## a file. The logging works only if the shell was build in debug mode.

# External modules imports
import contracts

when defined(debug):
# Standard library imports
  import std/[logging, terminal]
# Internal imports
  import constants
# External modules imports
  import nimalyzer

{.push ruleOff: "varUplevel".}
when defined(debug):
  var logger: FileLogger = nil
{.pop ruleOff: "varUplevel".}

proc logToFile*(message: string) {.sideEffect, raises: [], tags: [WriteIOEffect,
    RootEffect], contractual.} =
  ## Log the selected message into a file. This procedure works only when
  ## the shell is compiled in debug mode.
  ##
  ## * message - the text which will be logged to a file
  require:
    message.len > 0
  body:
    when defined(debug):
      try:
        logger.log(level = lvlDebug, args = message)
      except Exception as e:
        {.ruleOff: "namedParams".}
        try:
          stderr.styledWriteLine(fgRed, "Can't log the message to the file.")
          stderr.styledWriteLine(fgRed, $e.name)
          stderr.styledWriteLine(fgRed, getCurrentExceptionMsg())
          stderr.styledWrite(fgRed, getStackTrace(e = e))
        except:
          discard
        {.ruleOn: "namedParams".}

proc startLogging*() {.sideEffect, raises: [], tags: [WriteIOEffect,
    RootEffect], contractual.} =
  ## Start the logging system of the shell. This procedure works only when
  ## the shell is compiled in debug mode.
  body:
    when defined(debug):
      try:
        logger = newFileLogger(fileName = "nish.log",
            fmtStr = "[$time] - $levelname: ")
      except Exception as e:
        {.ruleOff: "namedParams".}
        try:
          stderr.styledWriteLine(fgRed, "Can't start logging to the file.")
          stderr.styledWriteLine(fgRed, $e.name)
          stderr.styledWriteLine(fgRed, getCurrentExceptionMsg())
          stderr.styledWrite(fgRed, getStackTrace(e = e))
        except:
          discard
        {.ruleOn: "namedParams".}
      setLogFilter(lvl = lvlAll)
      logToFile(message = "Starting shell, version " & version & " in debug mode.")
