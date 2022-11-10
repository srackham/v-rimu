module str

pub fn test_replace_special_chars() {
	assert replace_special_chars('') == ''
	assert replace_special_chars('<>&') == '&lt;&gt;&amp;'
}

pub fn test_parse_bool() {
	testcases := {
		'1':     true
		't':     true
		'T':     true
		'true':  true
		'TRUE':  true
		'True':  true
		'0':     false
		'f':     false
		'F':     false
		'false': false
		'FALSE': false
		'False': false
	}
	for k, v in testcases {
		assert parse_bool(k)! == v
	}
	if _ := parse_bool('foo') {
		assert false, 'an error should have occured'
	}
}
