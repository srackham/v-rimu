module lineblocks

import srackham.pcre2
import blockattributes
import delimitedblocks
import expansion
import iotext
import macros
import options
import quotes
import replacements
import spans

type LineBlockFilter = fn (mut mat []string, mut reader iotext.Reader, def Definition) string

type LineBlockVerify = fn (mat []string, mut reader iotext.Reader) bool // Additional match verification checks.

struct Definition {
mut:
	mat         pcre2.Regex
	replacement string
	name        string // Optional unique identifier.
	filter      LineBlockFilter = unsafe { nil }
	verify      LineBlockVerify = unsafe { nil } // Additional match verification checks.
}

const defs = [
	// Comment line.
	Definition{
		mat: pcre2.must_compile(r'^\\?\/{2}(.*)$')
	}
	// Expand lines prefixed with a macro invocation prior to all other processing.
	// macro name = $1, macro value = $2
	Definition{
		mat: macros.match_line
		verify: fn (mat []string, mut reader iotext.Reader) bool {
			if macros.literal_def_open.is_match(mat[0])
				|| macros.expression_def_open.is_match(mat[0]) {
				// Do not process macro definitions.
				return false
			}
			// Silent because any macro expansion errors will be subsequently addressed downstream.
			mut value := macros.render(mat[0], true)
			if value.starts_with(mat[0]) || value.contains('\n' + mat[0]) {
				// The leading macro invocation expansion failed or contains itself.
				// This stops infinite recursion.
				return false
			}
			// Insert the macro value into the reader just ahead of the cursor.
			reader.lines.insert(reader.pos + 1, value.split('\n'))
			return true
		}
		filter: fn (mut _ []string, mut _ iotext.Reader, _ Definition) string {
			return '' // Already processed in the `verify` function.
		}
	}
	// Delimited Block definition.
	// name = $1, definition = $2
	Definition{
		mat: pcre2.must_compile(r'^\\?\|([\w\-]+)\|\s*=\s*\x27(.*)\x27$')
		filter: fn (mut mat []string, mut _ iotext.Reader, _ Definition) string {
			if options.is_safe_mode_nz() {
				return '' // Skip if a safe mode is set.
			}
			mat[2] = spans.replace_inline(mat[2], expansion.Options{
				macros: true
			})
			delimitedblocks.set_definition(mat[1], mat[2])
			return ''
		}
	}
	// Quote definition.
	// quote = $1, openTag = $2, separator = $3, closeTag = $4
	Definition{
		mat: pcre2.must_compile(r'^(\S{1,2})\s*=\s*\x27([^|]*)(\|{1,2})(.*)\x27$')
		filter: fn (mut mat []string, mut _ iotext.Reader, _ Definition) string {
			if options.is_safe_mode_nz() {
				return '' // Skip if a safe mode is set.
			}
			quotes.set_definition(quotes.Definition{
				quote: mat[1]
				open_tag: spans.replace_inline(mat[2], expansion.Options{
					macros: true
				})
				close_tag: spans.replace_inline(mat[4], expansion.Options{
					macros: true
				})
				spans: mat[3] == '|'
			})
			return ''
		}
	}
	// Replacement definition.
	// pattern = $1, flags = $2, replacement = $3
	Definition{
		mat: pcre2.must_compile(r'^\\?\/(.+)\/([igm]*)\s*=\s*\x27(.*)\x27$')
		filter: fn (mut mat []string, mut _ iotext.Reader, _ Definition) string {
			if options.is_safe_mode_nz() {
				return '' // Skip if a safe mode is set.
			}
			mut pattern := mat[1]
			mut flags := mat[2]
			mut replacement := mat[3]
			replacement = spans.replace_inline(replacement, expansion.Options{
				macros: true
			})
			replacements.set_definition(pattern, flags, replacement)
			return ''
		}
	}
	// Macro definition.
	// name = $1, value = $2
	Definition{
		mat: macros.line_def
		verify: fn (mat []string, mut _ iotext.Reader) bool {
			// Necessary because Go regexps do not support regexp backreferences,
			return mat[2] == mat[4] // Leading and trailing quote must match.
		}
		filter: fn (mut mat []string, mut _ iotext.Reader, _ Definition) string {
			mut name := mat[1]
			mut quote := mat[2]
			mut value := mat[3]
			value = spans.replace_inline(value, expansion.Options{
				macros: true
			})
			macros.set_value(name, value, quote)
			return ''
		}
	}
	// Headers.
	// $1 is ID, $2 is header text, $3 is the optional trailing ID.
	Definition{
		mat: pcre2.must_compile(r'^\\?([#=]{1,6})\s+(.+?)(?:\s+([#=]{1,6}))?$')
		replacement: '<h$1>$$2</h$1>'
		verify: fn (mat []string, mut _ iotext.Reader) bool {
			// Necessary because Go regexps do not support regexp backreferences,
			return mat[3] == '' || mat[3] == mat[1] // Leading and trailing IDs must match.
		}
		filter: fn (mut mat []string, mut _ iotext.Reader, def Definition) string {
			mat[1] = '${mat[1].len}' // Replace $1 with header number.
			if macros.is_not_blank('--header-ids') && blockattributes_attrs.id == '' {
				blockattributes_attrs.id = blockattributes.slugify(mat[2])
			}
			// TODO *mat instead of correct mat: https://github.com/vlang/v/issues/16253
			return spans.replace_match(*mat, def.replacement, expansion.Options{
				macros: true
			})
		}
	}
	// Block image: <image:src|alt>
	// src = $1, alt = $2
	Definition{
		mat: pcre2.must_compile(r'^\\?<image:([^\s|]+)\|(.+?)>$')
		replacement: '<img src="$1" alt="$2">'
	}
	// Block image: <image:src>
	// src = $1, alt = $1
	Definition{
		mat: pcre2.must_compile(r'^\\?<image:([^\s|]+?)>$')
		replacement: '<img src="$1" alt="$1">'
	}
	// DEPRECATED as of 3.4.0.
	// Block anchor: <<#id>>
	// id = $1
	Definition{
		mat: pcre2.must_compile(r'^\\?<<#([a-zA-Z][\w\-]*)>>$')
		replacement: '<div id="$1"></div>'
		filter: fn (mut mat []string, mut _ iotext.Reader, def Definition) string {
			if options.skip_block_attributes() {
				return ''
			} else {
				// Default (non-filter) replacement processing.
				// TODO *mat instead of correct mat: https://github.com/vlang/v/issues/16253
				return spans.replace_match(*mat, def.replacement, expansion.Options{
					macros: true
				})
			}
		}
	}
	// Block Attributes.
	// Syntax: .class-names #id [html-attributes] block-options
	Definition{
		name: 'attributes'
		mat: pcre2.must_compile(r'^\\?\.[a-zA-Z#"\[+-].*$') // A loose match because Block Attributes can contain macro references.
		verify: fn (mat []string, mut _ iotext.Reader) bool {
			return blockattributes.parse(mat[0])
		}
	}
	// API Option.
	// name = $1, value = $2
	Definition{
		mat: pcre2.must_compile(r'^\\?\.(\w+)\s*=\s*\x27(.*)\x27$')
		filter: fn (mut mat []string, mut _ iotext.Reader, _ Definition) string {
			if !options.is_safe_mode_nz() {
				mut value := spans.replace_inline(mat[2], expansion.Options{
					macros: true
				})
				options.set_option(mat[1], value)
			}
			return ''
		}
	},
]

// If the next element in the reader is a valid line block render it
// and return true, else return false.
pub fn render(mut reader iotext.Reader, mut writer iotext.Writer, allowed []string) bool {
	if reader.eof() {
		panic('premature eof')
	}
	for def in lineblocks.defs {
		if allowed.len > 0 && !allowed.contains(def.name) {
			continue
		}
		mut mat := def.mat.find_one_submatch(reader.cursor()) or { continue }
		if mat[0][0] == `\\` {
			// Drop backslash escape and continue.
			reader.set_cursor(reader.cursor()[1..])
			continue
		}
		if def.verify != unsafe { nil } && !def.verify(mat, mut reader) {
			continue
		}
		mut text := ''
		if def.filter == unsafe { nil } {
			text = spans.replace_match(mat, def.replacement, expansion.Options{
				macros: true
			})
		} else {
			text = def.filter(mut mat, mut reader, def)
		}
		if text != '' {
			text = blockattributes.inject(text)
			writer.write(text)
			reader.next()
			if !reader.eof() {
				writer.write('\n') // Add a trailing '\n' if there are more lines.
			}
		} else {
			reader.next()
		}
		return true
	}
	return false
}
