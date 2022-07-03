### General information

Nish is an experimental (read: full of bugs and lack of a documentation)
multiplatform command-line shell. If you read this file on GitHub:
**please don't send pull requests here**. All will be automatically closed.
Any code propositions should go to the
[Fossil](https://www.laeran.pl/repositories/nish) repository.

**IMPORTANT:** If you read the file in the project code repository: This
version of the file is related to the future version of the shell. It may
contain information not present in released versions of the program. For
that information, please refer to the README.md file included into the release.

### The project's goals

At this moment the project has two goals:

* Allow me to learn Nim language. ;)
* Test a few features and solutions to various issues related to my daily
  work with different shells.

The second goal can be expanded to:

* User defined global but also a directory related commands.
* Interactive mode for the shell's commands.
* Ability to edit, add, delete, enable or disable commands via shell.
* And probably many more which will be added during the development of the
  project.

### Features

#### Use database for store all data related to the shell

This may look like overkill, but the shell uses sqlite for store all its data.
For now, it is only the shell's aliases, but with time there will be more. At
this moment it is very experimental feature. If it doesn't work, it will be
replaced.

#### Global and local aliases

The shell allows declaring not only standard aliases, which are available
everywhere, but also aliases which available only in the selected directories.
For example, you can declare alias `build` which in one directory will be
executing `make -j5` and in another `nim release`. Aliases can be declared for
just one directory or for each subdirectory of the selected directory too. At
this moment, available options for aliases are:

* ID: The ID of the alias, used mostly for deleting or editing the selected
  alias.
* Name: The name of the alias. The text which have to be entered to execute the
  alias. It doesn't need to be unique, but if two aliases in the same directory
  have the same name, then the first one will be executed. The name can contain
  only letters, numbers, and underscores.
* Path: The main directory in which the alias works. It must be an existing
  directory.
* Recursive: If set to 1, the alias is available for all subdirectories of the
  path. If set to 0, is available only in the selected directory.
* Commands: The list of commands which will be executed as alias. The alias can
  execute a few commands, but then, each entry on the list have to be separated
  with new line.
* Description: The alias description. Showed on the aliases list.
* Output: Where to redirect the output of the commands executed by the alias.
  By default, or if this option set to `stdout`, the output not redirected
  at all. If set to `stderr`, then the standard output redirected to the
  standard error. When set to any other value, it is the path (relative or
  absolute) to the file to which the output will be saved. If the file exists,
  the output will be added to its content. **IMPORTANT:** only default setting
  allows interacting with the commands executed by the alias. Any other setting
  allows only read without any ability to pass any input to the executed
  commands.

For example, the definition of the alias can look that:


    ID: 1
    Name: mc
    Path: /
    Recursive: 1
    Commands: mc --nosubshell
    Description: Run MC without subshell
    Output: stdout

The alias will be executed when the user enters `mc` in the shell. The alias is
the global alias, it is available for the main directory `/` and all
subdirectories. It executes command `mc --nosubshell`. The output of the alias
will be as default, nothing is redirected.

The definition of the local alias can look that:

    ID: 2
    Name: listdocs
    Path: /home/user
    Recursive: 0
    Commands: cd docs && ls -lh
    Description: Enter docs directory and list all files
    Output: result.txt

The alias will be executed when the user enters `listdocs` in the shell in the
home directory. It doesn't work in any of its subdirectory. It enters `docs`
directory and then runs the command `ls -lh`. If the next command should be
executed only when the previous command was successful, use `&&` to merge them.
If the next command should be executed only when the previous failed, use `||`
to merge them. The output of the alias will be redirected to the file
`result.txt` which will be located in the same directory where the alias was
executed.

You can also pass arguments to the commands of the alias. The substitutes for
arguments are start with `$` and have numbers from 1 to 9. Example: `$1`, `$5`.
The definition of alias which uses arguments can look that:

    ID: 3
    Name: fossopen
    Path: /home/user/Projects
    Recursive: 0
    Commands: fossil open fossil/$1.fossil --workdir $1
    Description: Open fossil repo. Required parameter is the name of fossil repo.
    Output: stderr

The alias will be executed when the user enters `fossopen [reponame]` in the
shell. If the user enter only `fossopen` the shell will report a problem. The
alias is the local alias, which means it doesn't work in subdirectories. It
runs command `fossil open fossil/[reponame].fossil --workdir [reponame]`. For
example, entering the shell's command: `fossopen myrepo` will execute command:
`fossil open fossil/myrepo.fossil --workdir myrepo`. The output of the command
will be redirected to the standard error.

There is also special argument `$0` which mean all remaining arguments entered
by the user. The definition of alias which uses that argument can look that:

    ID: 4
    Name: foss
    Path: /
    Recursive: 1
    Commands: fossil $0
    Description: Alias for command fossil.
    Output: stdout

The alias will be executed when the user enters `foss` or `foss [arguments]` in
the shell. For example, entering the shell's command: `foss help` will execute
command: `fossil help`. The output of the alias will not be redirected.

#### Advanced shell's commands' history

There are available a few commands to manipulate the shell's commands' history
like show history or clear it. It is also possible to set the amount of
commands to store in the shell's history or the shell should store also invalid
commands or not.

When there is some text entered by the user, the history search only commands
which starts with the entered text.

The shell sorts the commands' history not only by most recently used but also by
most frequently used. Additinally, the command allows to select the amount of
commands to show, their sorting order and criteria. These settings cam be set
as pernament in the shell's options or ad hoc for the one time.

#### Advanced shell's configuration

All shell's options can be previewed from the shell. Additionally, it is
possible to set them inside the shell and reset options' values to the default
values. Also, there are options which are read-only, like for example, the
current version of the shell's database schema.

#### Global and local environment variables

Beside standard support for environment variables, with `set` and `unset`
commands, the shell offers also ability to set environment variables only for
the selected directories, in the same way how aliases set. At this moment,
available options for variables are:

* ID: The ID of the variable, used mostly for deleting or editing the selected
  variable
* Name: The name of the variable. It doesn't need to be unique, but if two
  variables in the same directory have the same name, then the last one value
  will be set as current value of the variable.
* Path: The main directory in which the variable set.
* Recursive: If set to 1, the variable is available for all subdirectories of
  the path. If set to 0, is available only in the selected directory.
* Value: The value of the variable.
* Description: The variable description. Showed on the variables list.

For example, the definition of the variable can look that:


    ID: 1
    Name: MY_VAR
    Path: /
    Recursive: 1
    Value: someval
    Description: Test variable

The definition of the local variable can look that:

    ID: 2
    Name: MY_VAR2
    Path: /home/user
    Recursive: 0
    Value: anotherval
    Description: The second test variable

The variable will be available only in the user's home directory. It doesn't
work in any of its subdirectory.

**IMPORTANT:** Commands `set` and `unset` doesn't work with the shell's
specific environment variables presented above. They work only with the
standard environment variables. To manage the shell's specific environment
variables use subcommands of the `variable` command.

#### Other features

* Simple Tab completion for commands with names of files and directories
  relative to the current directory
* Coloring the user entered command on green when it is valid or red when it is
  invalid

### How to install

At this moment, the only option is to build it from the source. You will need a
[Nim compiler](https://nim-lang.org/install.html). After installing it, type
in the root directory of the project (where this file is) `nim debug` for build
the program in debug mode or `nim release` to build it in release (optimized)
mode. You can also use [Nimble](https://github.com/nim-lang/nimble) package manager to install the shell:
`nimble install https://github.com/thindil/nish`.

### Design goals

* Provide sane defaults: even if command shells are for power users, it doesn't
  mean that their time isn't valuable. Provide good default settings for the
  new installation of the shell.
* A simple, extendable core: the base shell should be small as possible,
  contains only things useful for everyone. The rest of functionality should be
  in the shell's plugins.
* Configure not rule: add an ability to configure, enable or disable almost
  everything: style, commands, functionality.
* Safety first: prioritize the safety and security over new features or even
  speed. A broken program is less useful than the working simple one.
* KISS: Keep It Simple Stupid: when looking for a solution of a problem, use the
  simplest approach. After all the code have been maintained for some time.

### License

The project is released under 3-Clause BSD license.

---
That's all for now, as usual, I have probably forgotten about something important ;)

Bartek thindil Jasicki
