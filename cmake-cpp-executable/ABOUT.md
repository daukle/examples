# cmake-cpp-executable

The same managed toolchain as `cmake-c-executable`, in C++, and with two keys that example does not
use. Read that one first; this one only shows what changes.

```
daukle cmake:run      # prints "hello from daukle"
```

## What changes

**`language = "c++"` changes the default source globs**, from `src/*.c` to `src/*.cpp`, `src/*.cc`
and `src/*.cxx`. It also changes which CMake `LANGUAGES` the generated project declares, so the
generated file is C++ from its first line rather than C with a C++ file in it.

**`standard = 20` becomes `CXX_STANDARD`**, not `C_STANDARD`. One key, two meanings depending on
`language`, which is the kind of thing worth seeing in a generated file rather than trusting.

**`defines` is proved rather than asserted.** `src/main.cpp` prints a different sentence under
`#else`, so a `defines` list that silently failed to reach the compiler would change the output and
fail this example rather than passing quietly. A test that cannot fail is the failure mode this
repository is most careful about.
