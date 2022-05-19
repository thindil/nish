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

import std/strutils

type
  LimitedString* = object of RootObj
    ## Store all data related to the string
    text: string ## The text of the LimitedString
    capacity: Positive ## The maximum capacity of the LimitedString

func `text=`*(s: var LimitedString; value: string) =
  ## FUNCTION
  ##
  ## The setter for the text of LimitedString. Check if the new value isn't
  ## bigger than the capacity of the string and if not, assing the new value
  ## to it. Raise RangeDefect exception if the new value is longer than allowed
  ## capacity of the LimitedString.
  ##
  ## PARAMETERS
  ##
  ## * s     - The LimitedString to which the new value of text will be assigned
  ## * value - The string which will be assigned as the new value of text
  ##
  ## RETURNS
  ##
  ## Updated LimitedString with the new value of the text field.
  if value.len() > s.capacity:
    raise newException(RangeDefect, "New value for string is longer than its capacity.")
  s.text = value

func `$`*(s: LimitedString): string =
  ## FUNCTION
  ##
  ## Convert LimitedString to string
  ##
  ## PARAMETERS
  ##
  ## * s - The LimitedString which will be converted
  ##
  ## RETURNS
  ##
  ## The converted LimitedString, its value of field text
  result = s.text

func len*(s: LimitedString): Natural =
  ## FUNCTION
  ##
  ## Get the length of the selected LimitedString
  ##
  ## PARAMETERS
  ##
  ## * s - the LimitedString which length will be get
  ##
  ## RETURNS
  ##
  ## The length of the LimitedString, the length of its field text
  result = s.text.len()

func add*(s: var LimitedString; y: string) =
  ## FUNCTION
  ##
  ## Add a string to the selected LimitedString. Check if the new value isn't
  ## bigger than the capacity of the LimitedString and if not, add the string
  ## to the field text of LimitedString. Raise RangeDefect exception if the
  ## new value of LimitedString will be longer than allowed capacity.
  ##
  ## PARAMETERS
  ##
  ## * s - The LimitedString to which the new string will be added
  ## * y - The string to add
  ##
  ## RETURNS
  ##
  ## Updated parameter s
  if y.len() + s.text.len() > s.capacity:
    raise newException(RangeDefect, "New value for string will exceed its capacity.")
  s.text = s.text & y

func add*(s: var LimitedString; y: char) =
  ## FUNCTION
  ##
  ## Add a character to the selected LimitedString. Check if the new value
  ## isn't bigger than the capacity of the LimitedString and if not, add the
  ## character to the field text of LimitedString. Raise RangeDefect exception
  ## if the new value of LimitedString will be longer than allowed capacity.
  ##
  ## PARAMETERS
  ##
  ## * s - The LimitedString to which the new string will be added
  ## * y - The character to add
  ##
  ## RETURNS
  ##
  ## Updated parameter s
  if s.text.len() == s.capacity:
    raise newException(RangeDefect, "New value for string will exceed its capacity.")
  s.text = s.text & y

func initLimitedString*(capacity: Positive; text: string = ""): LimitedString =
  var newLimitedString = LimitedString(capacity: capacity)
  newLimitedString.text = text
  return newLimitedString

func capacity*(s: LimitedString): Positive =
  return s.capacity

func setString*(s: var LimitedString; text: string) =
  if text.len() > s.capacity:
    raise newException(RangeDefect, "New value for string will exceed its capacity.")
  s.text = text

func `[]`*[T, U: Ordinal](s: LimitedString; x: HSlice[T, U]): LimitedString =
  let
    newValue: string = s.text[x]
    length: Positive = (if newValue.len() == 0: 1 else: newValue.len())
  var newLimitedString = LimitedString(capacity: length)
  newLimitedString.text = newValue
  return newLimitedString

func `[]=`*(s: var LimitedString; i: int; val: char) =
  s.text[i] = val

func `!=`*(x: LimitedString; y: string): bool =
  return x.text != y

func `==`*(x: LimitedString; y: string): bool =
  return x.text == y

func `&`*(x: string; y: LimitedString): string =
  return x & y.text

func `&`*(x: LimitedString; y: string): string =
  return x.text & y

func find*(s: LimitedString; sub: char; start: Natural = 0; last = 0): int =
  return s.text.find(sub = sub, start = start, last = last)

func rfind*(s: LimitedString; sub: char; start: Natural = 0; last = -1): int =
  return s.text.rfind(sub = sub, start = start, last = last)

func insert*(x: var LimitedString; item: string; i: Natural = 0) =
  x.text.insert(item = item, i = i)

func startsWith*(s: LimitedString; prefix: string): bool =
  return s.text.startsWith(prefix = prefix)
