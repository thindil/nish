discard """
  exitcode: 0
"""

import ../../src/[constants, lstring]

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
  assert testString.len == 4, "Failed to get the length of LimitedString."
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
  assert testString.find('e') == 1, "Failed to find a character in LimitedString."
  assert testString.find('a') == -1, "Failed to not find a character in LimitedString."

block:
  try:
    let testString: LimitedString = initLimitedString(capacity = 4,
        text = "too long text")
    assert $testString == "too long text", "Failed to assing too long text to LimitedString."
  except CapacityError:
    discard

block:
  var testString: LimitedString = initLimitedString(capacity = 15, text = "test")
  testString.insert("start and ")
  assert $testString == "start and test", "Failed to prepend a string to LimitedString."
  testString.insert("2", 2)
  assert $testString == "st2art and test", "Failed to insert a string into LimitedString."
  try:
    testString.insert("very long text outside of max allowed lenght")
  except CapacityError:
    assert $testString == "st2art and test", "Failed to not insert a too long string to LimitedString."

block:
  let testString: LimitedString = initLimitedString(capacity = 14, text = "test")
  assert testString.len == 4, "Failed to get length of LimitedString."
  assert testString.capacity == 14, "Failed to get capacity of LimitedString"

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert testString.rfind('e') == 1, "Failed to reverse find a character in LimitedString."
  assert testString.rfind('a') == -1, "Failed to not reverse find a non-existing character in LimitedString."

block:
  var testString: LimitedString = initLimitedString(capacity = 14, text = "test")
  testString[3] = 'a'
  assert $testString == "tesa", "Failed to insert a character into LimitedString."

block:
  let testString: LimitedString = initLimitedString(capacity = 14, text = "test")
  assert $testString[1..2] == "es", "Failed to get slice from LimitedString."

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert testString[1] == 'e', "Failed to get a character from LimitedString."

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert testString.startsWith("te"), "Failed to check if LimitedString starts with a string."
  assert not testString.startsWith("as"), "Failed to check if LimitedString not starts with a string."

block:
  var testString: LimitedString = initLimitedString(capacity = 10,
      text = "old text")
  testString.text = "new text"
  assert testString == "new text", "Failed to set string as LimitedString."
  try:
    testString.text = "very long text which should not go"
  except CapacityError:
    assert testString == "new text", "Failed to not set too long string as LimitedString."
