require "autoload"
require 'dub'
require 'lfs'
require 'xml'

lk = {}
require 'lk/Dir'
require 'lk/util'

local exepath = arg[-1]

 local ins = dub.Inspector()
 ins:parse('test/fixtures/simple/include')
 --ins:parseXml('test/fixtures/simple/doc/xml', true)
 local binder = dub.LuaBinder()
 binder:bind(ins, {output_directory = 'bindings_path', only = {'Simple'}})
 --dub.LuaBinder.COMPILER = 'c:/Devel/mingw/msys/1.0/bin/sh.exe -c "PATH=/bin:/mingw/bin env PATH=/c/Users/tim/bin:.:/usr/local/bin:/mingw/bin:/bin g++.exe '
 --dub.LuaBinder.QUOTE = '"'
 --binder:build('lib/Simple.so', 'bindings_path', '%.cpp', '-Itest/fixtures/simple/include -I/c/Devel/LuaJIT-2.0.0-beta5/src/ ../qc/tools/host/win/lua51.dll')
 --require 'Simple'
 --local s = Simple(4.5)
