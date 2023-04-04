// NOTE: External tests because importing `macros` into `blockattributes` is a cyclic import.
module blockattributes_test

import blockattributes { Attrs, initialize, inject, parse, slugify }
import macros

fn test_parse() {
	macros.initialize()

	initialize()
	parse('.class #id')
	assert blockattributes_attrs == Attrs{
		classes: 'class'
		id: 'id'
	}

	initialize()
	parse('."css"')
	assert blockattributes_attrs == Attrs{
		css: 'css'
	}

	initialize()
	assert !parse("htmlReplacement = 'Foo'")
	assert !parse(".htmlReplac = 'Foo'")
	assert !parse(r'.{macro}')
	assert !parse(".htmlReplacement = 'Foo'")
}

fn test_inject() {
	initialize()
	blockattributes_attrs.id = 'id'
	assert inject('<p>') == '<p id="id">'

	initialize()
	blockattributes_attrs.classes = 'class'
	assert inject('<p>') == '<p class="class">'

	initialize()
	blockattributes_attrs.classes = 'class2'
	assert inject('<p class="class">') == '<p class="class2 class">'
}

fn test_slugify() {
	initialize()

	assert slugify('Foo Bar') == 'foo-bar'
	blockattributes_ids << 'foo-bar'

	assert slugify('Foo Bar') == 'foo-bar-2'

	assert slugify('--') == 'x'
}
