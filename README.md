# Rimu Markup for V

_v-rimu_ is a port of the [Rimu Markup language](https://github.com/srackham/rimu) written in the [V programming language](https://vlang.io/).

## Features
Functionally identical to the [Rimu TypeScript implementation](https://github.com/srackham/rimu) version 11.4.

## Implementation
This implementation is a verbatim port of the canonical [TypeScript code](https://github.com/srackham/rimu).

## Learn more
See the [Rimu documentation](https://srackham.github.io/rimu/reference.html).

## Installation
The following V command installs the Rimu module and its dependencies:

    v install srackham.rimu

Example installation and test workflows for Ubuntu, macOS and Windows can be found in the Github Actions [workflow file](https://github.com/srackham/v-rimu/blob/master/.github/workflows/ci.yml).

## Using the v-rimu library
Example usage:

``` v
module main

import srackham.rimu

fn main() {
	println(rimu.render('*Hello Rimu*!', rimu.RenderOptions{}))
}
```
To compile and run this simple application:

1. Copy the code above to a file named `hello-rimu.v`
2. Run it directly:

        v -enable-globals run hello-rimu.v

3. Compile it to an executable and run it:

        v -enable-globals -o hello hello-rimu.v
        ./hello

See also the [Rimu API documentation](https://srackham.github.io/rimu/reference.html#api).


## Rimu CLI command
The V port of the [Rimu CLI command](https://srackham.github.io/rimu/reference.html#rimuc-command) is `rimuv`.

To build the `rimuv` executable:

    v install srackham.rimu
    git clone https://github.com/srackham/v-rimu
    cd v-rimu
    make build-rimuv

Execute `rimuv`, for example:

    ./bin/rimuv --help
