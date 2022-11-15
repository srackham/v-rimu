module lineblocks

import iotext

pub fn test_render() {
	mut testcases := {
		'# foo':                   '<h1>foo</h1>'
		'// foo':                  ''
		'<image:foo|bar>':         '<img src="foo" alt="bar">'
		'<<#foo>>':                '<div id="foo"></div>'
		'.class #id "css"':        ''
		".safeMode='0'":           ''
		"|code|='<code>|</code>'": ''
		"^='<sup>|</sup>'":        ''
		"/\\.{3}/i = '&hellip;'":  ''
		"{foo}='bar'":             ''
	}
	for k, v in testcases {
		mut reader := iotext.new_reader(k)
		mut writer := iotext.new_writer()
		render(mut reader, mut writer, [])
		assert writer.string() == v
	}
}
