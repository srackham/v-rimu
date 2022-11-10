module expansion

import srackham.pcre2
import options

// Processing priority (highest to lowest): container, skip, spans and specials.
// If spans is true then both spans and specials are processed.
// They are assumed false if they are not explicitly defined.
// If a custom filter is specified their use depends on the filter.
pub struct Options {
pub mut:
	container bool
	macros    bool
	skip      bool
	spans     bool // Span substitution also expands special characters.
	specials  bool
mut:
	// xxxMerge specify if the Xxx field has been set.
	container_merge bool
	macros_merge    bool
	skip_merge      bool
	spans_merge     bool
	specials_merge  bool
}

// Merge copies expansion options that are set from from to to.
pub fn (mut to Options) merge(from Options) {
	if from.container_merge {
		to.container = from.container
		to.container_merge = true
	}
	if from.macros_merge {
		to.macros = from.macros
		to.macros_merge = true
	}
	if from.skip_merge {
		to.skip = from.skip
		to.skip_merge = true
	}
	if from.spans_merge {
		to.spans = from.spans
		to.spans_merge = true
	}
	if from.specials_merge {
		to.specials = from.specials
		to.specials_merge = true
	}
}

// Parse block-options string and return ExpansionOptions.
pub fn parse(optsString string) Options {
	mut res := Options{}
	if optsString != '' {
		mut opts := pcre2.must_compile(r'\s+').split_all(optsString.trim_space())
		for opt in opts {
			if options.is_safe_mode_nz() && opt == '-specials' {
				options.error_callback('-specials block option not valid in safeMode')
				continue
			}
			if pcre2.must_compile(r'^[+-](macros|spans|specials|container|skip)$').is_match(opt) {
				mut value := opt[0] == `+`
				match opt[1..] {
					'container' {
						res.container = value
						res.container_merge = true
					}
					'macros' {
						res.macros = value
						res.macros_merge = true
					}
					'skip' {
						res.skip = value
						res.skip_merge = true
					}
					'specials' {
						res.specials = value
						res.specials_merge = true
					}
					'spans' {
						res.spans = value
						res.spans_merge = true
					}
					else {}
				}
			} else {
				options.error_callback('illegal block option: ' + opt)
			}
		}
	}
	return res
}
