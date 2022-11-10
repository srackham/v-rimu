// NOTE: External tests because importing `macros` into `spans` is a cyclic import.
module replace_inline_test

import expansion
import macros
import spans

pub fn test_replace_inline() {
	macros.initialize()

	assert spans.replace_inline(r'*foo {bar}*', expansion.Options{
		macros: true
	}) == r'*foo {bar}*'

	macros.set_value('bar', 'BAR', "'")
	assert spans.replace_inline(r'*foo {bar}*', expansion.Options{
		macros: true
	}) == r'*foo BAR*'

	assert spans.replace_inline(r'*foo {bar}*', expansion.Options{
		macros: true
		spans: true
	}) == r'<em>foo BAR</em>'
}
