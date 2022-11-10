module delimitedblocks

import iotext
import macros

pub fn test_init() {
	init()
	assert default_defs.len == delimitedblocks_defs.len
	assert default_defs == delimitedblocks_defs
}

pub fn test_render() {
	testcases := {
		'foo':                            '<p>foo</p>'
		'  foo':                          '<pre><code>foo</code></pre>'
		"\{v}='foo' \\\nfoo' \\\\\nbar'": ''
	}
	init()
	for k, v in testcases {
		mut reader := iotext.new_reader(k)
		mut writer := iotext.new_writer()
		assert render(mut reader, mut writer, [])
		assert writer.string() == v
	}
	assert macros.is_defined('v')
	assert macros.render(r'{v}', true) == "foo'\nfoo' \\\nbar"
}

pub fn test_get_definition() {
	init()
	mut def := get_definition('paragraph')!
	assert def.open_tag == '<p>'
	if _ := get_definition('MISSING') {
		assert false, 'should have returned an error'
	} else {
		assert err.msg() == 'missing quote delimitedblock definition: MISSING'
	}
}

pub fn test_set_definition() {
	init()
	set_definition('indented', '<foo>|</foo>')
	mut def := get_definition('indented')!
	assert def.open_tag == '<foo>'
	assert def.close_tag == '</foo>'
}
