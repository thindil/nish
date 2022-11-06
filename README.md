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
most frequently used. Additionally, the command allows selecting the amount of
commands to show, their sorting order and criteria. These settings cam be set
as permanent in the shell's options or ad hoc for the one time.

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

#### Setting the shell's prompt

The shell's prompt can be set to the output of the selected program or script.
To do this, set the value of the shell's option `promptCommand` to the command
line with the desired program or script and its arguments. For example, to set
prompt to show the current date, use command `options set promptCommand date`.
If you want to reset the prompt to the original state, reset its value with
command `options reset promptCommand`.

**ATTENTION:** the command set as the shell's option `promptCommand` will be
executed every time before you execute your command. Thus, be sure it isn't too
heavy for your system, or it isn't dangerous, for example, it doesn't steal
credentials, harm your system, etc.

#### Plugins

The shell's offers a very simple API which allows writing its plugins in any
programming language. The communication between the shell and the plugin are
made by standard input and output, where the API calls are sending as command
line arguments. All arguments for the calls should be enclosed in quotes if
they contain spaces. The plugin's system will probably change over time
especially by adding new API calls. The plugins can reside in any location.
The directory `tools` contains the example plugin `testplugin.sh` written in
Bash.

The current version of API: **0.2**
The minimum required version of API for plugins to work: **0.2**

At this moment, available API calls from the shell:

* `install`: called during installation of the plugin (adding it to the
  shell).
* `uninstall`: called during removing of the plugin from the shell.
* `enable`: called during enabling the plugin.
* `disable`: called during disabling the plugin.
* `init`: called during initialization (starting) of the shell.
* `info`: called during showing information about the plugin. Requested
  response from the plugin should have form:
  `answer [name of the plugin;description of the plugin;API version of the plugin;list of API used (separated by comma)]`.
  This call is required for all plugins to work. If a plugin doesn't have it,
  it won't be added or enabled in the shell.
* `preCommand [command]`: called before the user's command will be executed.
  Command argument is the name of command and all its arguments entered by the
  user.
* `postCommand [command]`: called after the user's command execution.
  Command argument is the name of command and all its arguments entered by the
  user.
* `[command] [arguments]`: called when the plugin added the own or replaced one of
  the built-in commands. Command is the name of the command which will be
  executed, arguments are a string with arguments entered by the user.

**ATTENTION:** the calls set as the `preCommand` and `postCommand` will be
executed every time before and after you execute your command. Thus, be sure it
isn't too heavy for your system, or it isn't dangerous, for example, it doesn't
steal credentials, harm your system, etc.

If the plugin doesn't answer on any API call from the shell, it should return
error code 2, so the shell will known that the API's call isn't supported by
the plugin.

Available API calls from plugins:

* `showError [text]`: show the text in the standard error output
* `showOutput [text] ?color?`: show the text in the standard output. The
  optional argument is the color of the message. Available options are:
  fgBlack, fgRed, fgGreen, fgYellow, fgBlue, fgMagenta, fgCyan, fgWhite and
  fgDefault
* `setOption [option name] [option value] [option description] [option type]`:
  set the shell's option. If the option doesn't exist, create a new with
  selected parameters. Option type should be one of: integer (positive and
  negative), float, boolean (true or false), historySort, natural (0 or above),
  text, command (the value will be checked if is a valid command before added)
* `removeOption [option name]`: remove the selected option from the shell.
* `getOption [option name]`: get the value of the selected shell's option.
* `answer [text]`: set the answer for the shell. At this moment, used only in
  `info` call from the shell.
* `addCommand [command name]`: add the new command to the shell. The name must
  be unique. The command will not be added if there is registered the shell's
  command with that name. If you want to replace an existing command, use call
  `replaceCommand` (see below). Commands named *exit*, *set*, *unset* and *cd*
  can't be added.
* `deleteCommand [command name]`: remove the selected command from the shell.
  The name must be a name of an existing shell's command.
* `replaceCommand [command name]`: replace the selected command with code from
  the plugin. The name must be a name of an existing shell's command.
* `addHelp [topic] [usage] [help content]`: add the new help entry to the
  shell. The topic must be unique. The help entry will not be added if there is
  one with that topic. If you want to replace an existing help entry, use call
  `updateHelp` (see below).
* `deleteHelp [topic]`: delete the help entry with the selected topic. The
  topic must be the topic of an existing help entry.
* `updateHelp [topic] [usage] [help content]`: update the existing help entry
  with the new values. The topic must be a topic of an existing help entry.

#### Advanced help system

The whole content of the help is added to the local database of the shell. It
allows searching for help topics, but also to locally modify the help entries.
The use can in any moment bring back the default content, or update the local
with the new version, with the one command.

The content of the help is located in file *help/help.cfg*. Each entry has the
following scheme:

    [PluginPathOrModuleName]
    topic="The help topic, used to show the help entry"
    usage="The shell's command related to the help topic"
    content="The content of the help entry"

#### Other features

* Simple Tab completion for commands with names of files and directories
  relative to the current directory
* Coloring the user entered command on green when it is valid or red when it is
  invalid, separated colors for environment variables and commands' arguments
  which contains quotes or double quotes
* Setting the terminal title, can be enabled or disabled in the shell's options.

### How to install

#### Precompiled packages

There are available binary packages for Linux and FreeBSD 64-bit both on the
download page. If you want to use Nish on different platform, you have to build
it from the source.

#### Build from the source

You will need:

* [Nim compiler](https://nim-lang.org/install.html)
* [Contracts package](https://github.com/thindil/NimContracts)
* [Nimassets package](https://github.com/xmonader/nimassets)

You can install them manually or by using [Nimble](https://github.com/nim-lang/nimble).
In that second option, type `nimble install https://github.com/thindil/nish` to
install the shell and all dependencies. Generally it is recommended to use
`nimble release` to build the project in release (optimized) mode or
`nimble debug` to build it in the debug mode.

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

The project released under 3-Clause BSD license.

---
That's all for now, as usual, I have probably forgotten about something important ;)

Bartek thindil Jasicki
