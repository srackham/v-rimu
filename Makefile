MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := test
.DELETE_ON_ERROR:
.SUFFIXES:
.ONESHELL:
.SILENT:

.PHONY: fmt test build-rimuv build-rimuv-optimized

test: fmt build-rimuv
	v -cstrict -enable-globals test .

fmt:
	v fmt -w .

build-rimuv:
	mkdir -p bin
	v -cstrict -enable-globals -o bin/rimuv cmd/rimuv/rimuv.v

build-rimuv-optimized:
	mkdir -p bin
	# Cannot use -cstrict flag for GCC production builds (see https://github.com/vlang/v/issues/16016)
	v -enable-globals -prod -o bin/rimuv -prod cmd/rimuv/rimuv.v
