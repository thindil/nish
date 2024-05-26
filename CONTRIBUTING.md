## Bugs reporting

Bugs are not only problems or the program crashes, but also typos. If you
find any bug in the program, please report it at options available at [contact page](https://www.laeran.pl.eu.org/repositories/nish/wiki?name=Contact).

### Some general hints about reporting bugs

* In "Title" field try to write short but not too general description of
  problem. Good example: "The program crash when opening directory". Bad
  example: "The program crashes often."
* In body/comment field try to write that much information about issue as
  possible. In most cases more information is better than less. General rule
  of good problem report is give enough information which allow reproducing
  problem by other people. It may be in form of steps which are needed for
  cause problem.

### Example of bug report:

Title: "The program crashed when trying to enter directory"

Body:

1. Type `cd tmp` in the program
2. Press enter
3. The program crashes

## Features propositions

If you want to talk/propose changes in any existing the program feature or
mechanic, feel free to contact me via options available at [contact page](https://www.laeran.pl.eu.org/repositories/nish/wiki?name=Contact).
General rule about propositions is same as for bugs reports - please,
try to write that much information as possible. This will help us all better
understand purpose of your changes.

## Code propositions

### General information

If you want to start help in the program development, please consider starts
from something easy like fixing bugs. Before you been want to add new feature
to the program, please contact with me via options available at [contact page](https://www.laeran.pl.eu.org/repositories/nish/wiki?name=Contact).
Same as with features proposition - your code may "collide" with my work and
it this moment you may just lose time by working on it. So it is better that
we first discuss your proposition. In any other case, fell free to fix my code.

### Coding standard

The project follows the default coding standards for [Nim](https://nim-lang.org/docs/nep1.html),
with additional extensions:

* All calls to subprograms must use named parameters.
* All subprograms must have pragmas: `raises`, `tags` and `contractual`.
* Subprograms shouldn't propagate exceptions, pragma `raises: []` unless they
  are low level subprograms, like type initialization, etc. The main procedure
  of the program can't raise any exception.
* If possible, subprograms without side effects should be declared as functions.
* All subprograms must have a corresponding unit test, even if it is a very simple
  test.
* All subprograms must have written contracts, even it they are very simple.
* All subprograms must use their parameters.
* All subprograms and public declarations (variables, constants too) must have
  documentation.
* All variables must have declared type and initial value for them.
* The code must be validated with the *nimalyzer* tool, by running it with
  configuration files *tools/nimalyzer.cfg* for the program's code. *nimalyzer*
  can be installed with *nimble*: `nimble install -y nimalyzer`.

### Code submission

A preferred way to submit your code is to use [tickets](https://www.laeran.pl.eu.org/repositories/nish/ticket)
on the project page. Please attach to that ticket file with diff changes, the
best if done with command `fossil patch`. Another diff program will work too.
In that situation, please add information which program was used to create the
diff file. If you prefer you can also use other options from [the contact page](https://www.laeran.pl.eu.org/repositories/nish/wiki?name=Contact).

## Additional debugging options

### Using nimprofiler with the program

To build the program with **nimprofiler** support, compile it with command `nimble analyze`.
More information about **nimprofiler** you can find at [Nim blog](https://nim-lang.org/blog/2017/10/02/documenting-profiling-and-debugging-nim-code.html#profiling-with-nimprof).

### Running unit tests of the program

To execute all unit tests of the program, execute the command `nimble test`.
The program uses [Unittests2](https://github.com/status-im/nim-unittest2) package for tests. More information about running tests (running only selected tests, etc.) please look at the package documentation.
