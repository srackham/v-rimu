module macros

import srackham.pcre2
import options
import spans

pub const (
	// Matches a line starting with a macro invocation. $1 = macro invocation.
	match_line           = pcre2.must_compile(r'^({(?:[\w\-]+)(?:[!=|?](?:|.*?[^\\]))?}).*$')
	// Match single-line macro definition. $1 = name, $2 = delimiter, $3 = value, $4 trailing delimiter.
	line_def             = pcre2.must_compile(r'^\\?{([\w\-]+\x3f?)}\s*=\s*' + "(['`])" + '(.*)' +
		"(['`])" + '$')
	// Match multi-line macro definition literal value open delimiter. $1 is first line of macro.
	literal_def_open     = pcre2.must_compile(r'^\\?{[\w\-]+\??}\s*=\s*\x27(.*)$')
	literal_def_close    = pcre2.must_compile(r'^(.*)\x27$')
	// Match multi-line macro definition expression value open delimiter. $1 is first line of macro.
	expression_def_open  = pcre2.must_compile(r'^\\?{[\w\-]+\??}\s*=\s*' + '`' + '(.*)$')
	expression_def_close = pcre2.must_compile(r'^(.*)`$')
)

struct Macro {
mut:
	name  string
	value string
}

// TODO implement as singleton.
__global macros_defs = []Macro{}

fn init() {
	initialize()
	macros_render = render
}

// Reset definitions to defaults.
pub fn initialize() {
	macros_defs.clear()
	// Initialize predefined macros.
	macros_defs << [Macro{
		name: '--'
		value: ''
	}, Macro{
		name: '--header-ids'
		value: ''
	}]
}

// Return true if macro is defined.
pub fn is_defined(name string) bool {
	for def in macros_defs {
		if def.name == name {
			return true
		}
	}
	return false
}

// Return named macro value.
pub fn value(name string) ?string {
	for def in macros_defs {
		if def.name == name {
			return def.value
		}
	}
	return none
}

// Return true if macro value is non-blank.
pub fn is_not_blank(name string) bool {
	if v := value(name) {
		return v != ''
	} else {
		return false
	}
}

// Set named macro value or add it if it doesn't exist.
// If the name ends with '?' then don't set the macro if it already exists.
// `quote` is a single character: ' if a literal value, ` if an expression value.
pub fn set_value(name string, value string, quote string) {
	mut m := Macro{
		name: name
		value: value
	}
	if options.skip_macro_defs() {
		// Skip if a safe mode is set.
		return
	}
	mut existential := false
	if name.ends_with('?') {
		m.name = name.trim_string_right('?')
		existential = true
	}
	if name == '--' && value != '' {
		options.error_callback("the predefined blank '--' macro cannot be redefined")
		return
	}
	if quote == '`' {
		options.error_callback('unsupported: expression macro values: `' + value + '`')
	}
	for i, def in macros_defs {
		if def.name == m.name {
			if !existential {
				macros_defs[i].value = value
			}
			return
		}
	}
	macros_defs << m
}

// Render all macro invocations in text string.
// Render Simple invocations first, followed by Parametized, Inclusion and Exclusion invocations.
pub fn render(text string, silent bool) string {
	mut result := ''
	mut match_complex := pcre2.must_compile(r'(?s)\\?\{([\w\-]+)([!=|?](?:|.*?[^\\]))}')
	mut match_simple := pcre2.must_compile(r'\\?\{([\w\-]+)()}')
	result = text
	for find in [match_simple, match_complex] {
		simple := find == match_simple
		result = find.replace_all_submatch_fn(result, fn [simple, silent, text] (mat []string) string {
			if mat[0][0] == `\\` {
				return mat[0][1..]
			}
			mut params := mat[2]
			if params != '' && params[0] == `?` { // DEPRECATED: Existential macro invocation.
				if !silent {
					options.error_callback('existential macro invocations are deprecated: ' + mat[0])
				}
				return mat[0]
			}
			name := mat[1]
			mut val := value(name) or {
				if !silent {
					options.error_callback('undefined macro: ' + mat[0] + ': ' + text)
				}
				return mat[0]
			}
			if simple {
				return val
			}
			// Process non-simple macro.
			params = params.replace('\\}', '}')
			match params[0] {
				`|` { // Parametrized macro.
					mut params_list := params[1..].split('|')
					// Substitute macro parameters.
					// Matches macro definition formal parameters [$]$<param-number>[[\]:<default-param-value>$]
					// 1st group: [$]$
					// 2nd group: <param-number> (1, 2..)
					// 3rd group: :[\]<default-param-value>$
					// 4th group: <default-param-value>
					mut param_re := pcre2.must_compile(r'(?s)\\?(\$\$?)(\d+)(\\?:(|.*?[^\\])\$)?')
					val = param_re.replace_all_submatch_fn(val, fn [params_list] (mr []string) string {
						if mr[0][0] == `\\` {
							return mr[0][1..]
						}
						mut p1 := mr[1]
						mut p2 := mr[2].parse_int(10, 0) or { -1 }
						if p2 == 0 {
							return mr[0] // $0 is not a valid parameter name.
						}
						mut p3 := mr[3]
						mut p4 := mr[4]
						mut param := ''
						if params_list.len < p2 {
							// Unassigned parameters are replaced with a blank string.
							param = ''
						} else {
							param = params_list[p2 - 1]
						}
						if p3 != '' {
							if p3[0] == `\\` { // Unescape escaped default parameter.
								param += p3[1..]
							} else {
								if param == '' {
									param = p4 // Assign default parameter value.
									param = param.replace(r'\$', '$') // Unescape escaped $ characters in the default value.
								}
							}
						}
						if p1 == '$$' {
							param = spans.render(param)
						}
						return param
					})
					return val
				}
				`!`, `=` { // Exclusion and Inclusion macro.
					mut pattern := params[1..]
					mut pre := pcre2.compile('^' + pattern + '$') or {
						if !silent {
							options.error_callback('illegal macro regular expression: ' + pattern +
								': ' + text)
						}
						return mat[0]
					}
					mut skip := !pre.is_match(val)
					if params[0] == `!` {
						skip = !skip
					}
					if skip {
						return '\u0002' // Line deletion flag.
					} else {
						return ''
					}
				}
				else {
					options.error_callback('illegal macro syntax: ' + mat[0])
					return ''
				}
			}
		})
	}
	// Delete lines flagged by Inclusion/Exclusion macros.
	if result.contains('\u0002') {
		mut s := ''
		for line in result.split('\n') {
			if !line.contains('\u0002') {
				s += line + '\n'
			}
		}
		result = s.trim_string_right('\n')
	}
	return result
}
