module rimu

import json
import v.util

struct DocOptions {
mut:
	safe_mode        int
	html_replacement string
	reset            bool
}

struct RenderTest {
mut:
	description string
	input       string
	expected    string
	callback    string
	options     DocOptions
	unsupported string
}

pub fn test_render() {
	// Read JSON test cases.
	mut text := util.read_file('./testdata/rimu-tests.json') or { panic(err) }
	// Map JSON field names to V struct field names.
	field_map := {
		'expectedOutput':   'expected'
		'expectedCallback': 'callback'
		'safeMode':         'safe_mode'
		'htmlReplacement':  'html_replacement'
	}
	for k, v in field_map {
		text = text.replace('"${k}":', '"${v}":')
	}
	mut testcases := json.decode([]RenderTest, text)!
	// Append test with invalid UTF-8 input because JSON does not support binary data (all strings are valid UTF-8)).
	testcases << RenderTest{
		description: 'Invalid UTF-8 input'
		input: '\xbb'
		expected: ''
		callback: 'error: invalid UTF-8 input'
		options: DocOptions{
			reset: true
		}
	}
	for tc in testcases {
		if tc.unsupported.contains('go') {
			continue
		}
		mut msg := ''
		mut msgptr := &msg
		mut opts := RenderOptions{
			reset: tc.options.reset
			safe_mode: tc.options.safe_mode
			html_replacement: tc.options.html_replacement
			callback: fn [mut msgptr] (message CallbackMessage) {
				unsafe {
					*msgptr = *msgptr + message.kind + ': ' + message.text + '\n'
				}
			}
		}
		mut got := render(tc.input, opts)
		assert got == tc.expected, 'description: ${tc.description}\nexpected: ${tc.expected}\ngot: ${got}'
		if tc.callback != '' {
			assert msg.trim_space() == tc.callback
		} else if msg != '' {
			assert false, '${tc.description}: unexpected callback: ${msg}'
		}
	}
}
