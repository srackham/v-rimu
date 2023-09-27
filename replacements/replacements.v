module replacements

import srackham.pcre2
import options

pub struct Definition {
pub mut:
	mat         pcre2.Regex
	replacement string
	filter      fn (submatches []string) string = unsafe { nil }
}

fn (d1 Definition) == (d2 Definition) bool {
	return d1.mat.pattern == d2.mat.pattern
}

// TODO implement as singleton.
// TODO replace this global with `pub fn defs() &[]Definition` singleton.
// Mutable definitions initialized by DEFAULT_DEFS.
__global replacements_defs = []Definition{}

const (
	default_defs = [
		// Begin match with \\? to allow the replacement to be escaped.
		// Global flag must be set on match re's so that the RegExp lastIndex property is set.
		// Replacements and special characters are expanded in replacement groups ($1..).
		// Replacement order is important.
		// DEPRECATED as of 3.4.0.
		// Anchor: <<#id>>
		// NOTE: Main reason for dropping it from go-rimu was because the Filter introduced a cyclic import.
		// Image: <image:src|alt>
		// src = $1, alt = $2
		Definition{
			mat: pcre2.must_compile(r'\\?<image:([^\s|]+)\|((?s).*?)>')
			replacement: '<img src="$1" alt="$2">'
		},
		// Image: <image:src>
		// src = $1, alt = $1
		Definition{
			mat: pcre2.must_compile(r'\\?<image:([^\s|]+?)>')
			replacement: '<img src="$1" alt="$1">'
		},
		// Image: ![alt](url)
		// alt = $1, url = $2
		Definition{
			mat: pcre2.must_compile(r'\\?!\[([^[]*?)]\((\S+?)\)')
			replacement: '<img src="$2" alt="$1">'
		},
		// Email: <address|caption>
		// address = $1, caption = $2
		Definition{
			mat: pcre2.must_compile(r'\\?<(\S+@[\w.\-]+)\|((?s).+?)>')
			replacement: '<a href="mailto:$1">$$2</a>'
		},
		// Email: <address>
		// address = $1, caption = $1
		Definition{
			mat: pcre2.must_compile(r'\\?<(\S+@[\w.\-]+)>')
			replacement: '<a href="mailto:$1">$1</a>'
		},
		// Open link in new window: ^[caption](url)
		// caption = $1, url = $2
		Definition{
			mat: pcre2.must_compile(r'\\?\^\[([^[]*?)]\((\S+?)\)')
			replacement: '<a href="$2" target="_blank">$$1</a>'
		},
		// Link: [caption](url)
		// caption = $1, url = $2
		Definition{
			mat: pcre2.must_compile(r'\\?\[([^[]*?)]\((\S+?)\)')
			replacement: '<a href="$2">$$1</a>'
		},
		// Link: <url|caption>
		// url = $1, caption = $2
		Definition{
			mat: pcre2.must_compile(r'\\?<(\S+?)\|((?s).*?)>')
			replacement: '<a href="$1">$$2</a>'
		},
		// HTML inline tags.
		// Match HTML comment or HTML tag.
		// $1 = tag, $2 = tag name
		Definition{
			mat: pcre2.must_compile(r'(?i)\\?(<!--(?:[^<>&]*)?-->|<\/?([a-z][a-z0-9]*)(?:\s+[^<>&]+)?>)')
			replacement: ''
			filter: fn (mat []string) string {
				return options.html_safe_mode_filter(mat[1])
			}
		},
		// Link: <url>
		// url = $1
		Definition{
			mat: pcre2.must_compile(r'\\?<([^|\s]+?)>')
			replacement: '<a href="$1">$1</a>'
		},
		// Auto-encode (most) raw HTTP URLs as links.
		Definition{
			mat: pcre2.must_compile(r'\\?((?:http|https):\/\/[^\s"\x27]*[A-Za-z0-9/#])')
			replacement: '<a href="$1">$1</a>'
		},
		// Character entity.
		Definition{
			mat: pcre2.must_compile(r'\\?(&[\w#][\w]+;)')
			replacement: ''
			filter: fn (mat []string) string {
				return mat[1]
			}
		},
		// Line-break (space followed by \ at end of line).
		Definition{
			mat: pcre2.must_compile(r'[\\ ]\\(\n|$)')
			replacement: '<br>$1'
		},
		// This hack ensures backslashes immediately preceding closing code quotes are rendered
		// verbatim (Markdown behaviour).
		// Works by finding escaped closing code quotes and replacing the backslash and the character
		// preceding the closing quote with itself.
		// NOTE: match differs from rimu-js and rimu-kt because regxp does not support (?=re) look-ahead.
		Definition{
			mat: pcre2.must_compile(r'\S\\`')
			replacement: '$1'
		},
		Definition{
			// This hack ensures underscores within words rendered verbatim and are not treated as
			// underscore emphasis quotes (GFM behaviour).
			// NOTE: match differs from rimu-js and rimu-kt because regxp does not support (?=re) look-ahead.
			mat: pcre2.must_compile(r'[a-zA-Z0-9]_[a-zA-Z0-9]')
			replacement: '$1'
		},
	]
)

fn init() {
	initialize()
}

// Reset definitions to defaults.
pub fn initialize() {
	replacements_defs = []Definition{cap: replacements.default_defs.len}
	for def in replacements.default_defs {
		replacements_defs << def
	}
}

// Update existing or add new replacement definit
pub fn set_definition(pattern string, flags string, replacement string) {
	mut pat := pattern
	if flags.contains('i') {
		pat = '(?i)' + pat
	}
	if flags.contains('m') {
		pat = '(?m)' + pat
	}
	for i, def in replacements_defs {
		if def.mat.pattern == pat {
			// Update existing definition.
			replacements_defs[i].replacement = replacement
			return
		}
	}
	// Append new definition to end of defs list (custom definitions have lower precedence).
	if re := pcre2.compile(pat) {
		replacements_defs << Definition{
			mat: re
			replacement: replacement
		}
	} else {
		options.error_callback('illegal replacement regular expression: ' + err.msg())
	}
}
