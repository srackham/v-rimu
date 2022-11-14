module main

import json
import os
import str

struct RimuvTest {
mut:
	description     string
	args            string
	input           string
	expected_output string
	predicate       string
	exit_code       int
	unsupported     string
	layouts         bool
}

// Execute rimuc in command shell.
// args: rimuc command args.
// input: stdin input string.
fn exec_rimuv(args string, input string) os.Result {
	cmd_input := os.from_slash('./testdata/temp.txt')
	os.write_file(cmd_input, input) or { panic(err) }
	$if windows {
		// Create and execute Windows .bat file.
		cmd := 'type $cmd_input | bin\\rimuv.exe --no-rimurc $args'
		cmd_bat := '.\\testdata\\temp.bat'
		os.write_file(cmd_bat, '@$cmd') or { panic(err) }
		res := os.execute(cmd_bat)
		return os.Result{res.exit_code, str.normalize_newlines(res.output)}
	} $else {
		cmd := 'cat $cmd_input | bin/rimuv --no-rimurc $args'
		return os.execute(cmd)
	}
}

fn read_resource_test() {
	// Throws exception if there is a missing resource file.
	for style in ['classic', 'flex', 'plain', 'sequel', 'v8'] {
		read_resource('$style-header.rmu')
		read_resource('$style-footer.rmu')
	}
	s := os.read_file('./resources/manpage.txt') or {
		assert false, err.msg()
		return
	}
	assert read_resource('manpage.txt') == s
}

fn test_help() {
	res := exec_rimuv('-h', '')
	assert res.exit_code == 0
	assert res.output.starts_with('\nNAME')
}

fn test_illegal_layout() {
	res := exec_rimuv('--layout foobar', '')
	assert res.exit_code == 1
	assert res.output.starts_with('external layouts not supported')
}

fn test_rimuv() {
	// Read JSON test cases.
	mut text := os.read_file('./testdata/rimuc-tests.json') or { panic(err) }
	// Map JSON field names to V struct field names.
	field_map := {
		'expectedOutput': 'expected_output'
		'exitCode':       'exit_code'
	}
	for k, v in field_map {
		text = text.replace('"$k":', '"$v":')
	}
	mut testcases := json.decode([]RimuvTest, text)!

	for mut tc in testcases {
		if tc.unsupported.contains('go') {
			continue
		}
		dump(tc)
		for layout in ['', 'classic', 'flex', 'sequel'] {
			// Skip if not a layouts test and we have a layout, or if it is a layouts test but no layout is specified.
			if (!tc.layouts && layout != '') || (tc.layouts && layout == '') {
				continue
			}
			tc.expected_output = tc.expected_output.replace('./test/fixtures/', './testdata/')
			tc.args = tc.args.replace('./test/fixtures/', './testdata/')
			tc.args = tc.args.replace('./examples/example-rimurc.rmu', './testdata/example-rimurc.rmu')
			if layout != '' {
				tc.args = ' --layout $layout $tc.args'
			}
			res := exec_rimuv(tc.args, tc.input)
			dump(res)
			assert res.exit_code == tc.exit_code
			match tc.predicate {
				'equals' {
					assert res.output == tc.expected_output
				}
				'!equals' {
					assert res.output != tc.expected_output
				}
				'contains' {
					assert res.output.contains(tc.expected_output)
				}
				'!contains' {
					assert !res.output.contains(tc.expected_output)
				}
				'startsWith' {
					assert res.output.starts_with(tc.expected_output)
				}
				else {
					panic(tc.description + ': illegal predicate: ' + tc.predicate)
				}
			}
		}
	}
}
