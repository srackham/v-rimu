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
	v -cstrict -enable-globals -o bin/rimuv rimuv/rimuv.v

build-rimuv-optimized:
	# Cannot use -cstrict flag for GCC production builds (see https://github.com/vlang/v/issues/16016)
	v -enable-globals -prod -o bin/rimuv -prod rimuv/rimuv.v
