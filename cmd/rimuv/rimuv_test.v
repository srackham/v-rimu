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
fn rimuv_cmd(args string, input string) string {
	cmd_input := os.from_slash('./testdata/temp.txt')
	os.write_file(cmd_input, input) or { panic(err) }
	$if windows {
		mut cmd := 'type ${cmd_input} | bin\\rimuv.exe --no-rimurc ${args}'
		cmd = 'cmd.exe /Q /C "${cmd}"'
		return cmd
	} $else {
		cmd := 'cat ${cmd_input} | bin/rimuv --no-rimurc ${args}'
		return cmd
	}
}

fn rimuv_exec(cmd string) os.Result {
	$if windows {
		res := os.execute(cmd)
		return os.Result{res.exit_code, str.normalize_newlines(res.output)}
	} $else {
		return os.execute(cmd)
	}
}

fn read_resource_test() {
	// Throws exception if there is a missing resource file.
	for style in ['classic', 'flex', 'plain', 'sequel', 'v8'] {
		read_resource('${style}-header.rmu')
		read_resource('${style}-footer.rmu')
	}
	s := os.read_file('./resources/manpage.txt') or {
		assert false, err.msg()
		return
	}
	assert read_resource('manpage.txt') == s
}

fn test_help() {
	cmd := rimuv_cmd('-h', '')
	res := rimuv_exec(cmd)
	assert res.exit_code == 0
	assert res.output.starts_with('\nNAME')
}

fn test_illegal_layout() {
	cmd := rimuv_cmd('--layout foobar', '')
	res := rimuv_exec(cmd)
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
		text = text.replace('"${k}":', '"${v}":')
	}
	mut testcases := json.decode([]RimuvTest, text)!

	for mut tc in testcases {
		if tc.unsupported.contains('go') {
			continue
		}
		for layout in ['', 'classic', 'flex', 'sequel'] {
			// Skip if not a layouts test and we have a layout, or if it is a layouts test but no layout is specified.
			if (!tc.layouts && layout != '') || (tc.layouts && layout == '') {
				continue
			}
			tc.expected_output = tc.expected_output.replace('./test/fixtures/', './testdata/')
			tc.args = tc.args.replace('./test/fixtures/', './testdata/')
			tc.args = tc.args.replace('./examples/example-rimurc.rmu', './testdata/example-rimurc.rmu')
			if layout != '' {
				tc.args = ' --layout ${layout} ${tc.args}'
			}
			cmd := rimuv_cmd(tc.args, tc.input)
			res := rimuv_exec(cmd)
			mut msg := 'description: ${tc.description}\ncommand: ${cmd}\nexpected: ${tc.exit_code}\ngot: ${res.exit_code}'
			assert res.exit_code == tc.exit_code, msg
			msg = 'description: ${tc.description}\ncommand: ${cmd}\nexpected: ${str.to_literal(tc.expected_output)}\ngot: ${str.to_literal(res.output)}'
			match tc.predicate {
				'equals' {
					assert res.output == tc.expected_output, msg
				}
				'!equals' {
					assert res.output != tc.expected_output, msg
				}
				'contains' {
					assert res.output.contains(tc.expected_output), msg
				}
				'!contains' {
					assert !res.output.contains(tc.expected_output), msg
				}
				'startsWith' {
					assert res.output.starts_with(tc.expected_output), msg
				}
				else {
					panic(tc.description + ': illegal predicate: ' + tc.predicate)
				}
			}
		}
	}
}
