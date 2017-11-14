  # Kai Programming Language
An expressive low level programming language.

## Documentation
Read the docs at [docs.kai-lang.org](http://docs.kai-lang.org)

## Featured projects
Have you built something cool? Feel free to share it here!

* [KaiNES](https://github.com/BrettRToomey/KaiNES): A pure-Kai NES emulator.
* [KaiVM](https://github.com/BrettRToomey/KaiVM): A register-based VM and disassembler.

## Download and Install
In the future, Kai will offer official binary distribution through brew and other package managers. See [building Kai](#building-kai).

##  Building Kai
Before you can begin building Kai, you must install the following dependencies: 

* Swift 4.0
* LLVM 4
* libgit2

### Swift 4
On Mac, the preferred way to install Swift 4 is by installing [Xcode](https://developer.apple.com/xcode/). After installing Xcode, make sure to run it once and say `yes` to installing the command-line tools. 

### LLVM 
By far, the easiest way to install LLVM on Mac is through [brew](https://brew.sh). After setting up brew, run the following to install the correct version of LLVM:
```
brew install llvm@4.0
```

#### Using LLVM with Swift Package Manager
Now that LLVM is installed, append the directory to your path in `~/.bash_profile`

```
/usr/local/opt/llvm/bin
``` 

In order for Swift Package Manager to build against LLVM's libraries, we need to setup a pkg-config file. Thankfully, [LLVMSwift](https://github.com/trill-lang/LLVMSwift_) has a script for this:

Grab the script by running `swift package update` in Kai's root directory. Then, run: 
```
swift .build/checkouts/LLVMSwift.git-<version-here>/utils/make-pkgconfig.swift
```

### LibGit2
Just like LLVM, [libgit2](https://libgit2.github.com) can be installed through brew.
```
brew install libgit2
```
