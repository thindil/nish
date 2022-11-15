discard """
  exitcode: 0
"""

import ../../src/[input, lstring]

block:
  var testString: LimitedString = initLimitedString(capacity = 14, text = "test")
  testString.add(" and test")
  assert $testString == "test and test", "Failed to append a string to LimitedString."
  testString.add("2")
  assert $testString == "test and test2", "Failed to append another string to LimitedString."
  try:
    testString.add("very long text outside of max allowed lenght")
  except CapacityError:
    assert $testString == "test and test2", "Failed to not append too long string to LimitedString"

block:
  let testString: LimitedString = initLimitedString(capacity = 14, text = "test")
  assert testString.len() == 4, "Failed to get the length of LimitedString."
  assert testString.capacity == 14, "Failed to get the capacity of LimitedString."

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert testString != "test2", "Failed to compare different LimitedString and string."
  assert testString == "test", "Failed to compare the same LimitedString and string."

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert testString & "test" == "testtest", "Failed to append a string to LimitedString."
  assert "new" & testString == "newtest", "Failed to preprend a string to LimitedString."

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert $testString == "test", "Failed to convert LimitedString to string."

block:
  let testString: LimitedString = emptyLimitedString(maxInputLength)
  assert testString.capacity == maxInputLength, "Failed to set the proper capacity for an empty LimitedString."
  assert testString == "", "Failed to set the proper text for an empty LimitedString."

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert testString.find('e') == 1, "Failed to find a character in LimitedString"
  assert testString.find('a') == -1, "Failed to not find a character in LimitedString"

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert $testString == "test"
  try:
    let testString2: LimitedString = initLimitedString(capacity = 4,
        text = "too long text")
    assert $testString2 == "too long text"
  except CapacityError:
    quit 0

block:
  var testString: LimitedString = initLimitedString(capacity = 15, text = "test")
  testString.insert("start and ")
  assert $testString == "start and test"
  testString.insert("2", 2)
  assert $testString == "st2art and test"
  try:
    testString.insert("very long text outside of max allowed lenght")
  except CapacityError:
    assert $testString == "st2art and test"

block:
  let testString: LimitedString = initLimitedString(capacity = 14, text = "test")
  assert testString.len() == 4
  assert testString.capacity == 14

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert testString.rfind('e') == 1
  assert testString.rfind('a') == -1

block:
  var testString: LimitedString = initLimitedString(capacity = 14, text = "test")
  testString[3] = 'a'
  assert $testString == "tesa"

block:
  let testString: LimitedString = initLimitedString(capacity = 14, text = "test")
  assert $testString[1..2] == "es"

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert testString[1] == 'e'

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert testString.startsWith("te")
  assert not testString.startsWith("as")

block:
  var testString: LimitedString = initLimitedString(capacity = 10,
      text = "old text")
  testString.text = "new text"
  assert testString == "new text"
  try:
    testString.text = "very long text which should not go"
  except CapacityError:
    discard
  assert testString == "new text"
