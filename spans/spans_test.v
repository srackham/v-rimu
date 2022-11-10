module spans

pub fn test_render() {
	testcases := {
		'':                     ''
		'foo':                  'foo'
		// Quotes.
		'*foo*':                '<em>foo</em>'
		'**foo**':              '<strong>foo</strong>'
		'*foo* **bar**':        '<em>foo</em> <strong>bar</strong>'
		'*foo __bar__*':        '<em>foo <strong>bar</strong></em>'
		'***foo bar***':        '<strong><em>foo bar</em></strong>'
		'`**foo**`':            '<code>**foo**</code>'
		// Replacements.
		'<image:foo|bar>':      '<img src="foo" alt="bar">'
		'<image:foo|bar\nboo>': '<img src="foo" alt="bar\nboo">'
	}
	for k, v in testcases {
		assert render(k) == v
	}
}

// pub fn test_replace_inline() {
// 	assert replace_inline('.class #id', expansion.Options{
// 		macros: true
// 	}) == '.class #id'
// }

pub fn test_defrag() {
	assert defrag([Fragment{ text: '' }]) == ''
	assert defrag([Fragment{ text: 'foo' }, Fragment{
		text: 'bar'
	}]) == 'foobar'
}
