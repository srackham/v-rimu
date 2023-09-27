module spans

import srackham.pcre2
import options
import expansion
import quotes
import replacements
import str

// macros and spans package dependency injections.
__global macros_render = fn (text string, silent bool) string {
	return ''
}

// TODO implement as singleton.
// Stores placeholder replacement fragments saved by `preReplacements()` and restored by `postReplacements()`.
__global saved_replacements = []Fragment{}

struct Fragment {
mut:
	text     string
	done     bool
	verbatim string // Replacements text rendered verbatim.
}

// fn init() {
// 	macros_render = fn()
// }

pub fn render(source string) string {
	mut res := pre_replacements(source)
	mut frags := [Fragment{
		text: res
		done: false
	}]
	frags = frag_quotes(frags)
	frags = frag_specials(frags)
	res = defrag(frags)
	return post_replacements(res)
}

// Converts fragments to a string.
fn defrag(frags []Fragment) string {
	mut res := ''
	for frag in frags {
		res += frag.text
	}
	return res
}

// Fragment quotes in all fragments and return resulting fragments array.
fn frag_quotes(frags []Fragment) []Fragment {
	mut res := []Fragment{}
	for _, frag in frags {
		res << frag_quote(frag)
	}
	// Strip backlash from escaped quotes in non-done fragments.
	for i, frag in res {
		if !frag.done {
			res[i].text = quotes.unescape(frag.text)
		}
	}
	return res
}

// Fragment quotes in a single fragment and return resulting fragments array
fn frag_quote(frag Fragment) []Fragment {
	mut res := []Fragment{}
	if frag.done {
		return [frag]
	}
	mut mat := []int{}
	mut next_index := 0
	for {
		mut s := frag.text[next_index..]
		mat = quotes.find(s)
		if mat.len == 0 {
			return [frag]
		}
		// Check if quote is escaped.
		if s[mat[0]] == `\\` {
			next_index += mat[3]
			continue
		}
		// Add frag.text offsets.
		for i, _ in mat {
			mat[i] += next_index
		}
		break
	}
	quote := frag.text[mat[2]..mat[3]]
	mut quoted := frag.text[mat[4]..mat[5]]
	start_index := mat[0]
	mut end_index := mat[1]
	// Check for same closing quote one character further to the right.
	for end_index < frag.text.len && frag.text[end_index] == quote[0] {
		// Move to closing quote one character to right.
		quoted += rune(quote[0]).str()
		end_index += 1
	}
	// Arrive here if we have a matched quote.
	// The quote splits the input fragment into 5 or more output fragments:
	// Text before the quote, left quote tag, quoted text, right quote tag and text after the quote.
	def := quotes.get_definition(quote) or { panic('unexpected error') }
	before := frag.text[..start_index]
	after := frag.text[end_index..]
	res << Fragment{
		text: before
		done: false
	}
	res << Fragment{
		text: def.open_tag
		done: true
	}
	if !def.spans {
		// Spans are disabled so render the quoted text verbatim.
		quoted = str.replace_special_chars(quoted)
		quoted = quoted.replace('\u0000', '\u0001') // Substitute verbatim replacement placeholder.
		res << Fragment{
			text: quoted
			done: true
		}
	} else {
		// Recursively process the quoted text.
		res << frag_quote(Fragment{
			text: quoted
			done: false
		})
	}
	res << Fragment{
		text: def.close_tag
		done: true
	}
	// Recursively process the following text.
	res << frag_quote(Fragment{
		text: after
		done: false
	})
	return res
}

// Return text with replacements replaced with placeholders (see `postReplacements()`).
fn pre_replacements(text string) string {
	saved_replacements = []
	mut frags := frag_replacements([Fragment{
		text: text
		done: false
	}])
	// Reassemble text with replacement placeholders.
	mut res := ''
	for frag in frags {
		if frag.done {
			saved_replacements << frag // Save replaced text.
			res += `\u0000`.str() // Placeholder for replaced text.
		} else {
			res += frag.text
		}
	}
	return res
}

// Replace replacements placeholders with replacements text from savedReplacement
fn post_replacements(text string) string {
	return pcre2.must_compile(r'[\x{0000}\x{0001}]').replace_all_fn(text, fn (mat string) string {
		mut frag := Fragment{}
		frag, saved_replacements = saved_replacements[0], saved_replacements[1..].clone() // Remove frag from start of list.
		if mat == `\u0000`.str() {
			return frag.text
		} else {
			return str.replace_special_chars(frag.verbatim)
		}
	})
}

// Fragment replacements in all fragments and return resulting fragments array.
fn frag_replacements(frags []Fragment) []Fragment {
	mut res := []Fragment{}
	res = frags.clone()
	for def in replacements_defs {
		mut tmp := []Fragment{}
		for frag in res {
			tmp << frag_replacement(frag, def)
		}
		res = tmp.clone()
	}
	return res
}

// Fragment replacements in a single fragment for a single replacement definition.
// Return resulting fragments list.
fn frag_replacement(frag Fragment, def replacements.Definition) []Fragment {
	mut res := []Fragment{}
	if frag.done {
		return [frag]
	}
	mut mat := def.mat.find_one_index(frag.text) or { return [frag] }
	// Arrive here if we have a matched replacement.
	// The kluge is because Go regexp does not support `(?=pat)`.
	mut pattern := def.mat.pattern
	mut kludge := pattern == r'\S\\`' || pattern == r'[a-zA-Z0-9]_[a-zA-Z0-9]'
	if kludge {
		mat[1]--
	}
	// The replacement splits the input fragment into 3 output fragments:
	// Text before the replacement, replaced text and text after the replacement.
	before := frag.text[..mat[0]]
	matched := frag.text[mat[0]..mat[1]]
	after := frag.text[mat[1]..]
	res << Fragment{
		text: before
		done: false
	}
	mut replacement := ''
	if kludge {
		replacement = matched
	} else if matched.starts_with(r'\') {
		// Remove leading backslash.
		replacement = str.replace_special_chars(matched[1..])
	} else {
		submatches := def.mat.find_one_submatch(matched) or { panic('unexpected error') }
		if def.filter == unsafe { nil } {
			replacement = replace_match(submatches, def.replacement, expansion.Options{})
		} else {
			replacement = def.filter(submatches)
		}
	}
	res << Fragment{
		text: replacement
		done: true
		verbatim: matched
	}
	// Recursively process the remaining text.
	res << frag_replacement(Fragment{
		text: after
		done: false
	}, def)
	return res
}

fn frag_specials(frags []Fragment) []Fragment {
	// Replace special characters in all non-done fragments.
	mut res := []Fragment{len: frags.len}
	for i, _ in frags {
		mut frag := frags[i]
		if !frag.done {
			frag.text = str.replace_special_chars(frag.text)
		}
		res[i] = frag
	}
	return res
}

// Replace pattern "$1" or "$$1", "$2" or "$$2"... in `replacement` with corresponding match groups
// from `groups`. If pattern starts with one "$" character add specials to `opts`,
// if it starts with two "$" characters add spans to `opts`.
pub fn replace_match(groups []string, replacement string, o expansion.Options) string {
	mut opts := o
	return pcre2.must_compile(r'(\${1,2})(\d)').replace_all_submatch_fn(replacement, fn [groups, mut opts] (matches []string) string {
		mut res := ''
		// Replace $1, $2 ... with corresponding match groups.
		match true {
			matches[1] == '$$' {
				opts.spans = true
			}
			else {
				opts.specials = true
			}
		}
		i := matches[2].parse_int(10, 0) or { -1 } // match group number.
		if i >= groups.len {
			options.error_callback('undefined replacement group: ' + matches[0])
			return ''
		}
		res = groups[i] // match group text.
		return replace_inline(res, opts)
	})
}

// Replace the inline elements specified in options in text and return the result.
pub fn replace_inline(text string, opts expansion.Options) string {
	mut res := text
	if opts.macros {
		res = macros_render(res, false)
	}
	// Spans also expand special characters.
	if opts.spans {
		res = render(res)
	} else if opts.specials {
		res = str.replace_special_chars(res)
	}
	return res
}
