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
    text: string
    capacity: Positive

func `text=`*(s: var LimitedString; value: string) =
  if value.len() > s.capacity:
    raise newException(RangeDefect, "New value for string is longer than its capacity.")
  s.text = value

func `$`*(s: LimitedString): string =
  result = s.text

func len*(s: LimitedString): Natural =
  result = s.text.len()

func add*(s: var LimitedString; y: string) =
  if y.len() + s.text.len() > s.capacity:
    raise newException(RangeDefect, "New value for string will exceed its capacity.")
  s.text = s.text & y

func add*(s: var LimitedString; y: char) =
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
  let newValue: string = s.text[x]
  var newLimitedString = LimitedString(capacity: newValue.len())
  newLimitedString.text = newValue
  return newLimitedString

func `[]=`*(s: var LimitedString; i: int, val: char) =
  s.text[i] = val

func strip*(s: LimitedString; leading: bool = true; trailing: bool = true;
    chars: set[char] = Whitespace): LimitedString =
  let newValue: string = s.text.strip(leading = leading, trailing = trailing, chars = chars)
  var newLimitedString = LimitedString(capacity: newValue.len())
  newLimitedString.text = newValue
  return newLimitedString

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
