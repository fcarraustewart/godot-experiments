#!/usr/bin/env python
import os

env = SConscript("/Users/fel_c/Projects/GraphicsCourse/godot-cpp/SConstruct")

env.Append(CPPPATH=["src"])

sources = Glob("src/*.cpp")

library = env.SharedLibrary(
    "bin/libphysics.{}.{}.dylib".format(env["platform"], env["target"]),
    sources,
)

Default(library)
