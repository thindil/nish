discard """
  exitcode: 0
"""

import ../../src/[input, lstring]

block:
  var testString: LimitedString = initLimitedString(capacity = 14, text = "test")
  testString.add(" and test")
  assert $testString == "test and test"
  testString.add("2")
  assert $testString == "test and test2"
  try:
    testString.add("very long text outside of max allowed lenght")
  except CapacityError:
    assert $testString == "test and test2"

block:
  let testString: LimitedString = initLimitedString(capacity = 14, text = "test")
  assert testString.len() == 4
  assert testString.capacity == 14

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert testString != "test2"
  assert testString == "test"

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert testString & "test" == "testtest"
  assert "new" & testString == "newtest"

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert $testString == "test"

block:
  let testString: LimitedString = emptyLimitedString(maxInputLength)
  assert testString.capacity == maxInputLength
  assert testString == ""

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert testString.find('e') == 1
  assert testString.find('a') == -1

block:
  let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
  assert $testString == "test"
  try:
    let testString2: LimitedString = initLimitedString(capacity = 4, text = "too long text")
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
  var testString: LimitedString = initLimitedString(capacity = 4, text = "")
  assert $testString == ""
  try:
    testString.setString(text = "test")
    assert $testString == "test"
  except CapacityError:
    discard
  try:
    testString.setString(text = "testdfwerwerwerwewr")
  except CapacityError:
    assert $testString == "test"

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
  var testString: LimitedString = initLimitedString(capacity = 10, text = "old text")
  testString.text = "new text"
  assert testString == "new text"
  try:
    testString.text = "very long text which should not go"
  except CapacityError:
    discard
  assert testString == "new text"
