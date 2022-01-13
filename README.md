### General information

Nish is an experimental (read: full of bugs and lack of a documentation)
multiplatform command-line shell. At this moment everything is under
organization, thus it is a subject to change in the future.  If you read this
file on GitHub: **please don't send pull requests here**. All will be
automatically closed. Any code propositions should go to the
[Fossil](https://www.laeran.pl/repositories/nish) repository.

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

* ID: The ID of the alias, used mostly for deleting the selected alias
* Name: The name of the alias. The text which have to be entered to execute the
  alias. It doesn't need to be unique, but if two aliases in the same directory
  have the same name, then the first one will be executed.
* Path: The main directory in which the alias works.
* Recursive: If set to 1, the alias is available for all subdirectories of the
  main directory. If set to 0, is available only in the selected directory.
* Commands: The list of commands which will be executed as alias. The alias can
  execute a few commands, but then, each entry on the list have to be separated
  with new line.
* Description: The alias description. Showed on the aliases list.

For example, the definition of the alias can look that:


    ID: 1
    Name: mc
    Path: /
    Recursive: 1
    Commands: mc --nosubshell
    Description: Run MC without subshell

The alias will be executed when the user enters `mc` in the shell. The alias is
the global alias, it is available for the main directory `/` and all
subdirectories. It executes command `mc --nosubshell`.

The definition of the local alias can look that:

    ID: 2
    Name: listdocs
    Path: /home/user
    Recursive: 0
    Commands: cd docs
              ls -lh
    Description: Enter docs directory and list all files

The alias will be executed when the user enters `listdocs` in the shell in the
home directory. It doesn't work in any of its subdirectory. It enters `docs`
directory and then runs the command `ls -lh`.

You can also pass arguments to the commands of the alias. The substitutes for
arguments are start with `$` and have numbers from 1 to 9. Example: `$1`, `$5`.
The definition of alias which uses arguments can look that:

    ID: 3
    Name: fossopen
    Path: /home/user/Projects
    Recursive: 0
    Commands: fossil open fossil/$1.fossil --workdir $1
    Description: Open fossil repo. Required parameter is the name of fossil repo.

The alias will be executed when the user enters `fossopen [reponame]` in the
shell. If the user enter only `fossopen` the shell will report a problem. The
alias is the local alias, which means it doesn't work in subdirectories. It
runs command `fossil open fossil/$1.fossil --workdir [reponame]`. For example,
entering the shell's command: `fossopen myrepo` will execute command:
`fossil open fossil/myrepo.fossil --workdir myrepo`

### How to install

At this moment, the only option is to build it from the source. You will need a
[Nim compiler](https://nim-lang.org/install.html). After installing it, type
in the root directory of the project (where this file is) `nim debug` for build
the program in debug mode or `nim release` to build it in release (optimized)
mode. You can also use *Nimble* package manager to install the shell:
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
