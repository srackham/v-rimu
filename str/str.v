module str

// `normalize_newlines` translates `\r` newline sequences to `\n`.
fn normalize_newlines(s string) string {
	return s
		.replace('\r\n', '\n')
		.replace('\n\r', '\n')
		.replace('\r', '\n')
}

// `to_literal` translates white space characters to escape sequences.
fn to_literal(s string) string {
	return s
		.replace('\r', '\\r')
		.replace('\n', '\\n')
		.replace('\t', '\\t')
}

// `replace_special_chars` translates HTML special characters to character entities.
pub fn replace_special_chars(s string) string {
	return s
		.replace('&', '&amp;')
		.replace('>', '&gt;')
		.replace('<', '&lt;')
}

// parse_bool returns the boolean value represented by the string.
// It accepts 1, t, T, TRUE, true, True, 0, f, F, FALSE, false, False.
// Any other value returns an error.
pub fn parse_bool(s string) !bool {
	match s {
		'1', 't', 'T', 'true', 'TRUE', 'True' { return true }
		'0', 'f', 'F', 'false', 'FALSE', 'False' { return false }
		else { return error('illegal value') }
	}
}
