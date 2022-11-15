module api

pub fn test_init() {
	init()
}

pub fn test_render() {
	mut rmu := '."color:red"\nHello World!'
	mut html := '<p style="color:red">Hello World!</p>'
	assert render(rmu) == html

	/*
	# Title
Paragraph **bold** `code` _emphasised text_

.test-class [title="Code"]
  Indented `paragraph`

- Item 1
""
Quoted
""
- Item 2
 . Nested 1

{x} = '1$$1$$2'
{x?} = '2'
\{x}={x|}
{x|2|3}
	*/
	rmu = '# Title\nParagraph **bold** `code` _emphasised text_\n\n.test-class [title="Code"]\n  Indented `paragraph`\n\n- Item 1\n""\nQuoted\n""\n- Item 2\n . Nested 1\n\n{x} = \'1$$1$$2\'\n{x?} = \'2\'\n\\{x}={x|}\n{x|2|3}'
	/*
	<h1>Title</h1>
<p>Paragraph <strong>bold</strong> <code>code</code> <em>emphasised text</em></p>
<pre class="test-class" title="Code"><code>Indented `paragraph`</code></pre>
<ul><li>Item 1<blockquote><p>Quoted</p></blockquote>
</li><li>Item 2<ol><li>Nested 1</li></ol></li></ul><p>{x}=1
123</p>
	*/
	html = '<h1>Title</h1>\n<p>Paragraph <strong>bold</strong> <code>code</code> <em>emphasised text</em></p>\n<pre class="test-class" title="Code"><code>Indented `paragraph`</code></pre>\n<ul><li>Item 1<blockquote><p>Quoted</p></blockquote>\n</li><li>Item 2<ol><li>Nested 1</li></ol></li></ul><p>{x}=1\n123</p>'
	assert render(rmu) == html
}
