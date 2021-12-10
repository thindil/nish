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
* Test a few features and solutions to various problems related to my daily
  work with different shells.

The second goal can be expanded to:

* User defined global but also a directory related commands.
* Interactive mode for the shell's commands.
* Ability to edit, add, delete, enable or disable commands via shell.
* And probably many more which will be added during the development of the
  project.

### How to install

[TBD]

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
