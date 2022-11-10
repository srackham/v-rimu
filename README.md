# Rimu Markup for V

_rimu-v_ is a port of the [Rimu Markup
language](https://github.com/srackham/rimu) written in the [V programming language](https://vlang.io/).


## Features
Functionally identical to the [JavaScript
impementation](https://github.com/srackham/rimu) version 11.4.
the following exceptions:


## Installation
Download, build, test and install (requires V 0.3.2 or better):

    git clone https://github.com/srackham/rimu-v.git
    cd rimu-v
    make


## Using the rimu-v library
Example usage:

TODO FROM HERE
``` v
package main

import (
    "fmt"

    "github.com/srackham/rimu-v/v11/rimu"
)

func main() {
    // Prints "<p><em>Hello Rimu</em>!</p>"
    fmt.Println(rimu.Render("*Hello Rimu*!", rimu.RenderOptions{}))
}
```
To compile and run this simple application:

1. Copy the code above to a file named `hello-rimu.go` and put it in an empty
   directory.
2.  Change to the directory and run the following Go commands:

        go mod init example.com/hello-rimu
        go mod tidy
        go run hello-rimu.go

See also Rimu
[API documentation](https://srackham.github.io/rimu/reference.html#api).


## Rimu CLI command
The [Rimu CLI command](https://srackham.github.io/rimu/reference.html#rimuc-command) is named
`rimugo`.


## Learn more
Read the [documentation](https://srackham.github.io/rimu/reference.html) and
experiment with Rimu in the [Rimu
Playground](http://srackham.github.io/rimu/rimuplayground.html).

See the Rimu [Change
Log](http://srackham.github.io/rimu/changelog.html) for the latest
changes.


## Implementation
- The largely one-to-one correspondence between the canonical
  [TypeScript code](https://github.com/srackham/rimu) and the Go code
  eased porting and debugging.  This will also make it easier to
  cross-port new features and bug-fixes.

- All Rimu implementations share the same JSON driven test suites
  comprising over 300 compatibility checks.
