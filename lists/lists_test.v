module lists

import iotext

pub fn test_render() {
	mut testcases := {
		'- foo': '<ul><li>foo</li></ul>'
	}
	for k, v in testcases {
		mut reader := iotext.new_reader(k)
		mut writer := iotext.new_writer()
		render(mut reader, mut writer)
		assert writer.string() == v
	}
}
