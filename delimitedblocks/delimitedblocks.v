module delimitedblocks

import srackham.pcre2
import blockattributes
import expansion
import iotext
import macros
import options
import spans

__global api_render = fn (source string) string {
	return ''
}

fn init() {
	initialize()
}

const inline_tags = ['a', 'abbr']

const match_inline_tag = pcre2.must_compile(r'(?i)^(a|abbr|acronym|address|b|bdi|bdo|big|blockquote|br|cite|code|del|dfn|em|i|img|ins|kbd|mark|q|s|samp|small|span|strike|strong|sub|sup|time|tt|u|var|wbr)$')

// TODO implement as singleton.
__global delimitedblocks_defs = []Definition{}
// Mutable definitions initialized by DEFAULT_DEFS.

// Multi-line block element definition.
struct Definition {
mut:
	name             string      // Unique identifier.
	open_match       pcre2.Regex // $1 (if defined) is prepended to block content.
	close_match      pcre2.Regex
	open_tag         string
	close_tag        string
	verify           fn (matches []string) bool // Additional match verification checks.
	delimiter_filter fn (matches []string, def &Definition) string // Process opening delimiter. Return any delimiter content.
	content_filter   fn (text string, matches []string, opts expansion.Options) string
	options          expansion.Options
}

fn (d1 Definition) == (d2 Definition) bool {
	return d1.name == d2.name
}

const (
	default_defs = [
		// Delimited blocks cannot be escaped with a backslash.
		// Multi-line macro literal value definition.
		Definition{
			name: 'macro-definition'
			open_match: macros.literal_def_open
			close_match: macros.literal_def_close
			open_tag: ''
			close_tag: ''
			options: expansion.Options{
				macros: true
			}
			delimiter_filter: delimiter_text_filter
			content_filter: macro_def_content_filter
		}
		// Multi-line macro expression value definition.
		// DEPRECATED as of 11.0.0.
		Definition{
			name: 'deprecated-macro-expression'
			open_match: macros.expression_def_open
			close_match: macros.expression_def_close
			open_tag: ''
			close_tag: ''
			options: expansion.Options{
				macros: true
			}
			delimiter_filter: delimiter_text_filter
			content_filter: macro_def_content_filter
		}
		// Comment block.
		Definition{
			name: 'comment'
			open_match: pcre2.must_compile(r'^\\?\/\*+$')
			close_match: pcre2.must_compile(r'^\*+\/$')
			open_tag: ''
			close_tag: ''
			options: expansion.Options{
				skip: true
				specials: true
			}
		}
		// Division block.
		Definition{
			name: 'division'
			open_match: pcre2.must_compile(r'^\\?(\.{2,})([\w\s-]*)$') // $1 is delimiter text, $2 is optional class names.
			open_tag: '<div>'
			close_tag: '</div>'
			options: expansion.Options{
				container: true
				specials: true
			}
			delimiter_filter: class_injection_filter
		}
		// Quote block.
		Definition{
			name: 'quote'
			open_match: pcre2.must_compile(r'^\\?("{2,}|>{2,})([\w\s-]*)$') // $1 is delimiter text, $2 is optional class names.
			open_tag: '<blockquote>'
			close_tag: '</blockquote>'
			options: expansion.Options{
				container: true
				specials: true
			}
			delimiter_filter: class_injection_filter
		}
		// Code block.
		Definition{
			name: 'code'
			open_match: pcre2.must_compile(r'^\\?(-{2,}|`{2,})([\w\s-]*)$') // $1 is delimiter text, $2 is optional class names.
			open_tag: '<pre><code>'
			close_tag: '</code></pre>'
			options: expansion.Options{
				macros: false
				specials: true
			}
			verify: fn (mat []string) bool {
				// The deprecated '-' delimiter does not support appended class names.
				return !(mat[1][0] == `-` && mat[2].trim_space() != '')
			}
			delimiter_filter: class_injection_filter
		}
		// HTML block.
		Definition{
			name: 'html'
			// Block starts with HTML comment, DOCTYPE directive or block-level HTML start or end tag.
			// $1 is first line of block.
			// $2 is the alphanumeric tag name.
			open_match: pcre2.must_compile(r'(?i)^(<!--.*|<!DOCTYPE(?:\s.*)?|<\/?([a-z][a-z0-9]*)(?:[\s>].*)?)$')
			close_match: pcre2.must_compile(r'^$')
			open_tag: ''
			close_tag: ''
			options: expansion.Options{
				macros: true
			}
			verify: fn (mat []string) bool {
				// Return false if the HTML tag is an inline (non-block) HTML tag.
				if mat[2] != '' {
					return !match_inline_tag.is_match(mat[2])
				} else {
					return true // Matched HTML comment or doctype tag.
				}
			}
			delimiter_filter: delimiter_text_filter
			content_filter: fn (text string, _ []string, _ expansion.Options) string {
				return options.html_safe_mode_filter(text)
			}
		}
		// Indented paragraph.
		Definition{
			name: 'indented'
			open_match: pcre2.must_compile(r'^\\?(\s+\S.*)$')
			close_match: pcre2.must_compile(r'^$')
			open_tag: '<pre><code>'
			close_tag: '</code></pre>'
			options: expansion.Options{
				specials: true
			}
			delimiter_filter: delimiter_text_filter
			content_filter: fn (text string, _ []string, _ expansion.Options) string {
				// Strip indent from start of each line.
				first_indent := (pcre2.must_compile(r'\S').find_one_index(text) or { [] })[0]
				mut result := ''
				for line in text.split('\n') {
					// Strip first line indent width or up to first non-space character.
					mut indent := (pcre2.must_compile(r'\S|$').find_one_index(line) or { [] })[0]
					if indent > first_indent {
						indent = first_indent
					}
					result += line[indent..] + '\n'
				}
				return result.trim_string_right('\n')
			}
		}
		// Quote paragraph.
		Definition{
			name: 'quote-paragraph'
			open_match: pcre2.must_compile(r'^\\?(>.*)$')
			close_match: pcre2.must_compile(r'^$')
			open_tag: '<blockquote><p>'
			close_tag: '</p></blockquote>'
			options: expansion.Options{
				macros: true
				spans: true
				specials: true
			}
			delimiter_filter: delimiter_text_filter
			content_filter: fn (text string, _ []string, _ expansion.Options) string {
				// Strip leading > from start of each line and unescape escaped leading >.
				mut result := ''
				for mut line in text.split('\n') {
					line = pcre2.must_compile(r'^>').replace_all(line, '')
					line = pcre2.must_compile(r'^\\>').replace_all(line, '')
					result = result + line + '\n'
				}
				return result.trim_string_right('\n')
			}
		}
		// Paragraph (lowest priority, cannot be escaped).
		Definition{
			name: 'paragraph'
			open_match: pcre2.must_compile(r'(.*)')
			close_match: pcre2.must_compile(r'^$')
			open_tag: '<p>'
			close_tag: '</p>'
			options: expansion.Options{
				macros: true
				spans: true
				specials: true
			}
			delimiter_filter: delimiter_text_filter
		},
	]
)

// Reset definitions to defaults.
pub fn initialize() {
	delimitedblocks_defs = []Definition{len: delimitedblocks.default_defs.len}
	for i, def in delimitedblocks.default_defs {
		delimitedblocks_defs[i] = def
		delimitedblocks_defs[i].options = def.options // Clone expansion options.
		if def.close_match.is_nil() {
			delimitedblocks_defs[i].close_match = def.open_match
		}
	}
}

// If the next element in the reader is a valid delimited block render it
// and return true, else return false.
pub fn render(mut reader iotext.Reader, mut writer iotext.Writer, allowed []string) bool {
	if reader.eof() {
		panic('premature eof')
	}
	for _, def in delimitedblocks_defs {
		if allowed.len > 0 && !allowed.contains(def.name) {
			continue
		}
		mut mat := def.open_match.find_one_submatch(reader.cursor()) or { [] }
		if mat.len != 0 {
			// Escape non-paragraphs.
			if mat[0][0] == `\\` && def.name != 'paragraph' {
				// Drop backslash escape and continue.
				reader.set_cursor(reader.cursor()[1..])
				continue
			}
			if def.verify != unsafe { nil } && !def.verify(mat) {
				continue
			}
			// Process opening delimiter.
			mut delimiter_text := ''
			if def.delimiter_filter != unsafe { nil } {
				delimiter_text = def.delimiter_filter(mat, &def)
			}
			// Read block content into lines.
			mut lines := []string{}
			if delimiter_text != '' {
				lines << delimiter_text
			}
			// Read content up to the closing delimiter.
			reader.next()
			mut content := reader.read_to(def.close_match)
			if reader.eof() && ['code', 'comment', 'division', 'quote'].contains(def.name) {
				options.error_callback('unterminated ' + def.name + ' block: ' + mat[0])
			}
			reader.next() // Skip closing delimiter.
			lines << content
			// Calculate block expansion options.
			mut opts := def.options
			opts.merge(blockattributes_attrs.options)
			// Translate block.
			if !opts.skip {
				mut text := lines.join('\n')
				if def.content_filter != unsafe { nil } {
					text = def.content_filter(text, mat, opts)
				}
				mut opentag := def.open_tag
				if def.name == 'html' {
					text = blockattributes.inject(text)
				} else {
					opentag = blockattributes.inject(opentag)
				}
				if opts.container {
					blockattributes_attrs.options.container = false // Consume before recursing.
					text = api_render(text)
				} else {
					text = spans.replace_inline(text, opts)
				}
				mut closetag := def.close_tag
				if def.name == 'division' && opentag == '<div>' {
					// Drop div tags if the opening div has no attributes.
					opentag = ''
					closetag = ''
				}
				text = opentag + text + closetag
				writer.write(text)
				if text != '' && !reader.eof() {
					// Add a trailing "\n" if we"ve written a non-blank line and there are more source lines left.
					writer.write('\n')
				}
			}
			// Reset consumed Block Attributes expansion options.
			blockattributes_attrs.options = expansion.Options{}
			return true
		}
	}
	return false // No matching delimited block found.
}

// Return block definition or an error if not found.
pub fn get_definition(name string) !&Definition {
	for i, def in delimitedblocks_defs {
		if def.name == name {
			return &delimitedblocks_defs[i]
		}
	}
	return error('missing quote delimitedblock definition: $name')
}

// Update existing named definition.
// Value syntax: <open-tag>|<close-tag> block-options
pub fn set_definition(name string, value string) {
	mut def := get_definition(name) or {
		options.error_callback('illegal delimited block name: ' + name + ': |' + name + "|='" +
			value + "'")
		return
	}
	mut mat := pcre2.must_compile(r'^(?:(<[a-zA-Z].*>)\|(<[a-zA-Z/].*>))?(?:\s*)?([+-][ \w+-]+)?$').find_one_submatch(value.trim_space()) or {
		options.error_callback('illegal delimited block definition: |' + name + "|='" + value + "'")
		return
	}
	if value.contains('|') {
		def.open_tag = mat[1]
		def.close_tag = mat[2]
	}
	if mat[3] != '' {
		def.options.merge(expansion.parse(mat[3]))
	}
}

// delimiterFilter that returns opening delimiter line text from match group
fn delimiter_text_filter(matches []string, _ &Definition) string {
	return matches[1]
}

// delimiterFilter for code, division and quote blocks.
// Inject $2 into block class attribute, set close delimiter to $1.
fn class_injection_filter(mat []string, mut def Definition) string {
	mut p1 := mat[2].trim_space()
	if p1 != '' {
		blockattributes_attrs.classes = p1
	}
	// closeMatch must be set at runtime so we correctly match closing delimiter
	def.close_match = pcre2.must_compile(r'^' + pcre2.escape_meta(mat[1]) + '$')
	return ''
}

// contentFilter for multi-line macro definitions.
fn macro_def_content_filter(text string, matches []string, opts expansion.Options) string {
	quote := rune(matches[0][matches[0].len - matches[1].len - 1]).str() // The lead macro value quote character.
	name := (pcre2.must_compile(r'^{([\w\-]+\??)}').find_one_submatch(matches[0]) or { [] })[1] // Extract macro name from opening delimiter.
	mut txt := text
	txt = pcre2.must_compile(r'(' + quote + r') *\\\n').replace_all(txt, '$1\n') // Unescape line-continuations.
	txt = pcre2.must_compile(r'(' + quote + r' *[\\]+)\\\n').replace_all(txt, '$1\n') // Unescape escaped line-continuations.
	txt = spans.replace_inline(txt, opts) // Expand macro invocations.
	macros.set_value(name, txt, quote)
	return ''
}
