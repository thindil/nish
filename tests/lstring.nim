import ../src/[constants, lstring]
import unittest2

suite "Unit tests for lstring module":

  test "Appending a LimitedString to a LimitedString":
    var testString: LimitedString = initLimitedString(capacity = 14, text = "test")
    testString.add(" and test")
    check:
      $testString == "test and test"
    testString.add("2")
    check:
      $testString == "test and test2"
    try:
      testString.add("very long text outside of max allowed lenght")
    except CapacityError:
      assert $testString == "test and test2", "Failed to not append too long string to LimitedString"

  test "Getting length and capacity of a LimitedString":
    let testString: LimitedString = initLimitedString(capacity = 14, text = "test")
    check:
      testString.len == 4
      testString.capacity == 14

  test "Comparison of a LimitedString and a string":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    check:
      testString != "test2"
      testString == "test"

  test "Adding a string to a LimitedString":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    check:
      testString & "test" == "testtest"
      "new" & testString == "newtest"

  test "Converting a LimitedString to a string":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    check:
      $testString == "test"

  test "emptyLimitedString":
    let testString: LimitedString = emptyLimitedString(maxInputLength)
    check:
      testString.capacity == maxInputLength
      testString == ""

  test "Find a character in a LimiteString":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    check:
      testString.find('e') == 1
      testString.find('a') == -1

  test "Assign a too long text to a LimitedString":
    try:
      let testString: LimitedString = initLimitedString(capacity = 4,
          text = "too long text")
      assert $testString == "too long text", "Failed to assing too long text to LimitedString."
    except CapacityError:
      discard

  test "Insert a string into a LimitedString":
    var testString: LimitedString = initLimitedString(capacity = 15, text = "test")
    testString.insert("start and ")
    check:
      $testString == "start and test"
    testString.insert("2", 2)
    check:
      $testString == "st2art and test"
    try:
      testString.insert("very long text outside of max allowed lenght")
    except CapacityError:
      assert $testString == "st2art and test", "Failed to not insert a too long string to LimitedString."

  test "Reverse find of a character in a LimitedString":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    check:
      testString.rfind('e') == 1
      testString.rfind('a') == -1

  test "Insert a character into a LimitedString":
    var testString: LimitedString = initLimitedString(capacity = 14, text = "test")
    testString[3] = 'a'
    check:
      $testString == "tesa"

  test "Get a string's slice from a LimitedString":
    let testString: LimitedString = initLimitedString(capacity = 14, text = "test")
    check:
      $testString[1..2] == "es"

  test "Get a character from a LimitedString":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    check:
      testString[1] == 'e'

  test "Check do a LimitedString starts with the selected string":
    let testString: LimitedString = initLimitedString(capacity = 4, text = "test")
    check:
      testString.startsWith("te")
      not testString.startsWith("as")

  test "Set the text property of a LimitedString":
    var testString: LimitedString = initLimitedString(capacity = 10,
        text = "old text")
    testString.text = "new text"
    check:
      testString == "new text"
    try:
      testString.text = "very long text which should not go"
    except CapacityError:
      assert testString == "new text", "Failed to not set too long string as LimitedString."
