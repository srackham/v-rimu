module str

pub fn replace_special_chars(s string) string {
	mut result := ''
	result = s.replace('&', '&amp;')
	result = result.replace('>', '&gt;')
	result = result.replace('<', '&lt;')
	return result
}

// parse_bool returns the boolean value represented by the string.
// It accepts 1, t, T, TRUE, true, True, 0, f, F, FALSE, false, False.
// Any other value returns an error.
pub fn parse_bool(str string) !bool {
	match str {
		'1', 't', 'T', 'true', 'TRUE', 'True' { return true }
		'0', 'f', 'F', 'false', 'FALSE', 'False' { return false }
		else { return error('illegal value') }
	}
}
