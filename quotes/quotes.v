module quotes

import srackham.pcre2

fn init() {
	initialize()
}

pub struct Definition {
pub mut:
	quote     string // Single quote character.
	open_tag  string
	close_tag string
	spans     bool // Allow span elements inside quotes.
	re        pcre2.Regex
}

fn (q1 Definition) == (q2 Definition) bool {
	return q1.quote == q2.quote && q1.open_tag == q2.open_tag && q1.close_tag == q2.close_tag
		&& q1.spans == q2.spans
}

// TODO implement as singleton.
// TODO this is not global, only did this to implement private singleton because top-level mutables are disallowed.
__global defs = []Definition{}
// Mutable definitions initialized by DEFAULT_DEFS.

const (
	default_defs = [
		Definition{
			quote: '**'
			open_tag: '<strong>'
			close_tag: '</strong>'
			spans: true
		},
		Definition{
			quote: '*'
			open_tag: '<em>'
			close_tag: '</em>'
			spans: true
		},
		Definition{
			quote: '__'
			open_tag: '<strong>'
			close_tag: '</strong>'
			spans: true
		},
		Definition{
			quote: '_'
			open_tag: '<em>'
			close_tag: '</em>'
			spans: true
		},
		Definition{
			quote: '``'
			open_tag: '<code>'
			close_tag: '</code>'
			spans: false
		},
		Definition{
			quote: '`'
			open_tag: '<code>'
			close_tag: '</code>'
			spans: false
		},
		Definition{
			quote: '~~'
			open_tag: '<del>'
			close_tag: '</del>'
			spans: true
		},
	]
)

// Reset definitions to defaults.
pub fn initialize() {
	defs = []Definition{len: quotes.default_defs.len}
	for i, def in quotes.default_defs {
		defs[i] = def
	}
	init_reg_exps()
}

// Synthesise re's to find quotes.
fn init_reg_exps() {
	// $1 is quote character(s), $2 is quoted text.
	// Quoted text cannot begin or end with whitespace.
	// Quoted can span multiple lines.
	// Quoted text cannot end with a backslash.
	for i, def in defs {
		defs[i].re = pcre2.must_compile(r'\\?(' + pcre2.escape_meta(def.quote) +
			r')([^\s\\]|(?:\S[\s\S]{0,}?[^\s\\]))' + pcre2.escape_meta(def.quote))
	}
}

// Return the quote definition corresponding to 'quote', return error if not found.
pub fn get_definition(quote string) ?Definition {
	for def in defs {
		if def.quote == quote {
			return def
		}
	}
	// Should never arrive here.
	panic('missing quote definition: ${quote}')
}

// Update existing or add new quote definition.
pub fn set_definition(def Definition) {
	for i, _ in defs {
		if defs[i].quote == def.quote {
			// Update existing definition.
			defs[i].open_tag = def.open_tag
			defs[i].close_tag = def.close_tag
			defs[i].spans = def.spans
			return
		}
	}
	// Double-quote definitions are prepended to the array so they are matched
	// before single-quote definitions (which are appended to the array).
	if def.quote.len == 2 {
		defs.prepend(def)
	} else {
		defs << def
	}
	init_reg_exps()
}

// Strip backslashes from quote characters.
pub fn unescape(s string) string {
	mut res := s
	for def in defs {
		res = res.replace(r'\' + def.quote, def.quote)
	}
	return res
}

// Find looks for the first quote in `text`.
// Quotes prefixed with a backslash are ignored.
// Returns slice holding three index pairs identifying:
// - The entire match: 0..1
// - The left quote    2..3
// - The quoted text   4..5
// Returns [] if not found.
pub fn find(text string) []int {
	mut res := []int{}
	for mut def in defs {
		for m in def.re.find_all_index(text) {
			if res.len == 0 || m[0] < res[0] {
				res = m.clone()
			}
		}
	}
	return res
}
