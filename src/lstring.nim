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
    text: string       ## The text of the LimitedString
    capacity: Positive ## The maximum capacity of the LimitedString
  CapacityError* = object of CatchableError # Raised when the new value of string will be longer than allowed maximum

func `text=`*(s: var LimitedString; value: string) {.gcsafe, raises: [
    CapacityError], tags: [].} =
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
    raise newException(exceptn = CapacityError,
        message = "New value for string is longer than its capacity.")
  s.text = value

func `$`*(s: LimitedString): string {.gcsafe, raises: [], tags: [].} =
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

func len*(s: LimitedString): Natural {.gcsafe, raises: [], tags: [].} =
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

func add*(s: var LimitedString; y: string) {.gcsafe, raises: [CapacityError],
    tags: [].} =
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
    raise newException(exceptn = CapacityError,
        message = "New value for string will exceed its capacity.")
  s.text = s.text & y

func add*(s: var LimitedString; y: char) {.gcsafe, raises: [CapacityError],
    tags: [].} =
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
    raise newException(exceptn = CapacityError,
        message = "New value for string will exceed its capacity.")
  s.text = s.text & y

func initLimitedString*(capacity: Positive;
    text: string): LimitedString {.gcsafe, raises: [CapacityError], tags: [].} =
  ## FUNCTION
  ##
  ## Initialize the new LimitedString with the selected capacity and content.
  ## Raises RangeDefect if the selected text is longer than the selected
  ## capacity.
  ##
  ## PARAMETERS
  ##
  ## * capacity - The maximum length of the newly created LimitedString
  ## * text     - The content of the newly created LimitedString.
  ##
  ## RETURNS
  ##
  ## The new LimitedString with the selected capacity and content
  if text.len() > capacity:
    raise newException(exceptn = CapacityError,
        message = "New value for string will exceed its capacity.")
  return LimitedString(capacity: capacity, text: text)

func capacity*(s: LimitedString): Positive {.gcsafe, raises: [], tags: [].} =
  ## FUNCTION
  ##
  ## Get the maximum allowed capacity of the selected LimitedString
  ##
  ## PARAMETERS
  ##
  ## * s - The LimitedString which the capacity will be get
  ##
  ## RETURNS
  ##
  ## The maximum allowed capacity of the selected LimitedString
  return s.capacity

func setString*(s: var LimitedString; text: string) {.gcsafe, raises: [
    CapacityError], tags: [].} =
  ## FUNCTION
  ##
  ## Set the new value for the selected LimitedString. Raised RangeDefect if
  ## the new text is longer than the maximum capacity of the LimitedString
  ##
  ## PARAMETERS
  ##
  ## * s    - The LimitedString which content will be replaced
  ## * text - The new value of the LimitedString content
  ##
  ## RETURNS
  ##
  ## The updated LimitedString
  if text.len() > s.capacity:
    raise newException(exceptn = CapacityError,
        message = "New value for string will exceed its capacity.")
  s.text = text

func `[]`*[T, U: Ordinal](s: LimitedString; x: HSlice[T,
    U]): LimitedString {.gcsafe, raises: [], tags: [].} =
  ## FUNCTION
  ##
  ## Get the slice of the selected LimitedString
  ##
  ## PARAMETERS
  ##
  ## * s - The LimitedString which slice of text will be get
  ## * x - The range of the slice of text to get
  ##
  ## RETURNS
  ##
  ## The new LimitedString with the slice with the selected range
  let
    newValue: string = s.text[x]
    length: Positive = (if newValue.len() == 0: 1 else: newValue.len())
  var newLimitedString = LimitedString(capacity: length)
  newLimitedString.text = newValue
  return newLimitedString

func `[]=`*(s: var LimitedString; i: int; val: char) {.gcsafe, raises: [],
    tags: [].} =
  ## FUNCTION
  ##
  ## Replace the selected character in LimitedString
  ##
  ## PARAMETERS
  ##
  ## * s   - The LimitedString in which the character will be replaced
  ## * i   - The index on which the character will be replaced. Starts from 0
  ## * val - The new value for the character
  ##
  ## RETURNS
  ##
  ## The updated parameter s
  s.text[i] = val

func `!=`*(x: LimitedString; y: string): bool {.gcsafe, raises: [], tags: [].} =
  ## FUNCTION
  ##
  ## Compare the selected LimitedString and string
  ##
  ## PARAMETERS
  ## * x - The LimitedString to compare
  ## * y - The string to compare
  ##
  ## RETURNS
  ##
  ## False if string and field text of LimitedString are equal, otherwise true
  return x.text != y

func `==`*(x: LimitedString; y: string): bool {.gcsafe, raises: [], tags: [].} =
  ## FUNCTION
  ##
  ## Compare the selected LimitedString and string
  ##
  ## PARAMETERS
  ## * x - The LimitedString to compare
  ## * y - The string to compare
  ##
  ## RETURNS
  ##
  ## True if string and field text of LimitedString are equal, otherwise false
  return x.text == y

func `&`*(x: string; y: LimitedString): string {.gcsafe, raises: [], tags: [].} =
  ## FUNCTION
  ##
  ## Concatenates string and LimitedString into one string
  ##
  ## PARAMETERS
  ##
  ## * x - The string to concatenate
  ## * y - The LimitedString which field text will be concatenate
  ##
  ## RETURNS
  ##
  ## The newly created string with merged both strings
  return x & y.text

func `&`*(x: LimitedString; y: string): string {.gcsafe, raises: [], tags: [].} =
  ## FUNCTION
  ##
  ## Concatenates LimitedString and string into one string
  ##
  ## PARAMETERS
  ##
  ## * x - The LimitedString which field text will be concatenate
  ## * y - The string to concatenate
  ##
  ## RETURNS
  ##
  ## The newly created string with merged both strings
  return x.text & y

func find*(s: LimitedString; sub: char; start: Natural = 0;
    last = 0): int {.gcsafe, raises: [], tags: [].} =
  ## FUNCTION
  ##
  ## Find the selected character in the selected LimitedString.
  ##
  ## PARAMETERS
  ##
  ## * s     - The LimitedString which will be check for the selected character
  ## * sub   - The character which will be looked for in the LimitedString
  ## * start - The position from which search should start. Can be empty.
  ##           Default value is 0, start from the beginning of the LimitedString.
  ## * last  - The position to which search should go. Can be empty. Default
  ##           value is 0, which means no limit.
  ##
  ## RETURNS
  ##
  ## The position of the character in the LimitedString or -1 if character not
  ## found
  return s.text.find(sub = sub, start = start, last = last)

func rfind*(s: LimitedString; sub: char; start: Natural = 0;
    last = -1): int {.gcsafe, raises: [], tags: [].} =
  ## FUNCTION
  ##
  ## Reverse find the selected character in the selected LimitedString. Start
  ## looking from the end of the LimitedString.
  ##
  ## PARAMETERS
  ##
  ## * s     - The LimitedString which will be check for the selected character
  ## * sub   - The character which will be looked for in the LimitedString
  ## * start - The position from which search should start. Can be empty.
  ##           Default value is 0, start from the beginning of the LimitedString.
  ## * last  - The position to which search should go. Can be empty. Default
  ##           value is 0, which means no limit.
  ##
  ## RETURNS
  ##
  ## The position of the character in the LimitedString or -1 if character not
  ## found
  return s.text.rfind(sub = sub, start = start, last = last)

func insert*(x: var LimitedString; item: string; i: Natural = 0) {.gcsafe,
    raises: [CapacityError], tags: [].} =
  ## FUNCTION
  ##
  ## Insert the selected string into LimitedString at the selected position
  ##
  ## PARAMETERS
  ##
  ## * x    - The LimitedString to which the string will be inserted
  ## * item - The string to insert
  ## * i    - The position at which the string will be inserted. Can be empty.
  ##          Default value is 0, at start of the LimitedString
  ##
  ## RETURNS
  ##
  ## The updated paramater x
  let oldValue: string = x.text
  x.text.insert(item = item, i = i)
  if x.text.len() > x.capacity:
    x.text = oldValue
    raise newException(exceptn = CapacityError,
        message = "New value for string will exceed its capacity.")

func startsWith*(s: LimitedString; prefix: string): bool {.gcsafe, raises: [],
    tags: [].} =
  ## FUNCTION
  ##
  ## Check if the selected LimitedString starts with the selected string
  ##
  ## PARAMETERS
  ##
  ## * s      - The LimitedString which will be checked
  ## * prefix - The string which will be looking for at the start of the
  ##            LimitedString
  ##
  ## RETURNS
  ##
  ## True if the LimitedString starts with the prefix, otherwise false
  return s.text.startsWith(prefix = prefix)

func emptyLimitedString*(capacity: Positive = 1): LimitedString {.gcsafe, raises: [], tags: [].} =
  ## FUNCTION
  ##
  ## Create the new empty LimitedString with the the selected capacity.
  ##
  ## PARAMETERS
  ##
  ## * capacity - The maximum length of the newly created empty LimitedString.
  ##              Can be empty. Default value is 1
  ##
  ## RETURNS
  ##
  ## The new empty LimitedString with the selected capacity.
  return LimitedString(capacity: capacity, text: "")

