# java-hello-jar

A managed Java project. The repository holds `daukle.toml` and `src/main/java/` and **no build
file**: no Gradle, no Maven, no wrapper, no `pom.xml`. daukle downloads a JDK, verifies it against a
digest the plugin pins, and runs `javac` and `jar` out of it.

```
daukle java:run     # compiles and runs, printing "hello from daukle"
daukle java:jar     # packages build/daukle/java/example-java-hello-jar.jar
daukle tasks        # lists the three tasks the plugin declares and their order
```

## What to look at

**The manifest names a coordinate, not a file.** `daukle/java@^1.0.0` is resolved through the
`[resolvers.github]` entry, which is itself pinned by URL and digest. Nothing here vendors a copy of
the plugin.

**`main` is a class name, not a path.** The plugin turns it into
`src/main/java/com/example/Main.java` and hands `javac` a source path, so there is no source list to
maintain.

**`version = "21"` is an exact major version.** `">=17"` is refused. The plugin ships a table of
pinned JDK archives with their published digests, and matching a range would mean a semver
implementation in Lua.

## What this example cannot show

**A classpath.** This toolchain compiles against the JDK and your own sources, and has no mechanism
for an external dependency: `daukle.provision` unpacks an archive and does not keep it, and a
classpath entry is the archive. Coordinates for Java libraries are what `daukle/gradle` and a future
`maven` plugin are for, and neither replaces its tool. If your project needs one jar from Maven
Central, this is not yet the toolchain for it.

**A class reached only reflectively or through `ServiceLoader`** is not compiled unless you name it
in `roots`. `javac -sourcepath` compiles what is reachable from the roots it is given.

## The first run is slow

Roughly 331 MB of JDK, with no progress reported while it downloads. It is cached per digest
afterwards, shared by every project on the machine that pins the same JDK.

## The two `.txt` files, which are harness inputs rather than part of the example

`task.txt` and `expect-output.txt` are read by `test/run.sh`, not by daukle. `task.txt` holds the
one task CI runs here, `java:run`, and `expect-output.txt` the clause its output must contain,
`hello from daukle`. They sit beside the example rather than in `test/` so each example
carries its own expectations. An example with no `task.txt` is checked for its generated files
and never run.

**There is no committed executable here, and nothing is missing.** `java:run` really does build and
run the program; `build/` is gitignored, which is the only reason you cannot see the result in the
repository.
