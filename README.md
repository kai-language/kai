# Kai
An expressive low level programming language.

## 📚 Docs
Read the docs at https://kai-language.github.io/docs/

## 🚀 Getting Started 
Before you can begin building Kai, you must install the following tools: 

* Swift 3.1
* LLVM (3.9)

### Swift 3.1
On Mac, the preferred way to install Swift 3.1 is by installing [Xcode](https://developer.apple.com/xcode/). After installing Xcode, make sure to run it once and say `yes` to installing the command-line tools. 

### 🐉 LLVM 
By far, the easiest way to install LLVM on Mac is through [brew](https://brew.sh). After setting up brew, run the following to install the correct version of LLVM:
```
brew install llvm@3.9
```

Now that LLVM is installed, append the directory to your path in `~/.bash_profile`

```
/usr/local/opt/llvm/bin
``` 

In order for Swift Package Manager to build against LLVM's libraries, we need to setup a pkg-config file. Thankfully, [LLVMSwift](https://github.com/trill-lang/LLVMSwift_) has a script for this:

Grab the script by running `swift package update` in Kai's root directory. Then, run: 
```
swift .build/checkouts/LLVMSwift.git-<numbers here>/utils/make-pkgconfig.swift
```
_(note: The numbers for you at the time of running this may be different, so make sure to take advantage of your terminal's autocompletion)_
