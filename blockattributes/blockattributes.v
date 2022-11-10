module blockattributes

import srackham.pcre2
import expansion
import options
import spans

pub struct Attrs {
pub mut:
	classes    string // Space separated HTML class names.
	id         string // HTML element id.
	css        string // HTML CSS styles.
	attributes string // Other HTML element attributes.
	options    expansion.Options
}

// TODO implement as singleton.
__global (
	blockattributes_attrs = Attrs{} // Attrs are those of the last parsed Block Attributes element.
	blockattributes_ids   = []string{} // List of allocated HTML blockattributes_ids.
)

fn init() {
	initialize()
}

// Init resets options to default values.
pub fn initialize() {
	blockattributes_attrs.classes = ''
	blockattributes_attrs.id = ''
	blockattributes_attrs.css = ''
	blockattributes_attrs.attributes = ''
	blockattributes_attrs.options = expansion.Options{}
	blockattributes_ids = []
}

pub fn get_attrs() Attrs {
	return blockattributes_attrs
}

// Parse text to blockattributes_attrs block attributes.
pub fn parse(text string) bool {
	txt := spans.replace_inline(text, expansion.Options{
		macros: true
	})
	// class names = $1, id = $2, css-properties = $3, html-attributes = $4, block-options = $5
	mut m := pcre2.must_compile(r'^\\?\.((?:\s*[a-zA-Z][\w\-]*)+)*(?:\s*)?(#[a-zA-Z][\w\-]*\s*)?(?:\s*)?(?:"(.+?)")?(?:\s*)?(\[.+])?(?:\s*)?([+-][ \w+-]+)?$').find_one_submatch(txt) or {
		return false
	}
	for i, v in m {
		m[i] = v.trim_space()
	}
	if !options.skip_block_attributes() {
		if m[1] != '' { // HTML element class names.
			if blockattributes_attrs.classes != '' {
				blockattributes_attrs.classes += ' '
			}
			blockattributes_attrs.classes += m[1]
		}
		if m[2] != '' { // HTML element id.
			blockattributes_attrs.id = m[2][1..]
		}
		if m[3] != '' { // CSS properties.
			if blockattributes_attrs.css != '' && !blockattributes_attrs.css.ends_with(';') {
				blockattributes_attrs.css += ';'
			}
			if blockattributes_attrs.css != '' {
				blockattributes_attrs.css += ' '
			}
			blockattributes_attrs.css += m[3]
		}
		if m[4] != '' && !options.is_safe_mode_nz() { // HTML attributes.
			if blockattributes_attrs.attributes != '' {
				blockattributes_attrs.attributes += ' '
			}
			blockattributes_attrs.attributes += m[4][1..m[4].len - 1].trim_space()
		}
		if m[5] != '' {
			blockattributes_attrs.options.merge(expansion.parse(m[5]))
		}
	}
	return true
}

// Inject HTML attributes into the HTML `tag` and return result.
// Consume HTML attributes unless the `tag` argument is blank.
pub fn inject(tag string) string {
	mut res := tag
	if res == '' {
		return res
	}
	mut attributes := ''
	if blockattributes_attrs.classes != '' {
		if m := pcre2.must_compile(r'(?i)^<[^>]*class="').find_one_index(res) {
			// Inject class names into first existing class attribute in first res.
			before := res[..m[1]]
			after := res[m[1]..]
			res = before + blockattributes_attrs.classes + ' ' + after
		} else {
			attributes = 'class="' + blockattributes_attrs.classes + '"'
		}
	}
	if blockattributes_attrs.id != '' {
		blockattributes_attrs.id = blockattributes_attrs.id.to_lower()
		has_id := pcre2.must_compile(r'(?i)^<[^<]*id=".*?"').is_match(res)
		if has_id || blockattributes_ids.contains(blockattributes_attrs.id) {
			options.error_callback("duplicate 'id' attribute: " + blockattributes_attrs.id)
		} else {
			blockattributes_ids << blockattributes_attrs.id
		}
		if !has_id {
			attributes += ' id="' + blockattributes_attrs.id + '"'
		}
	}
	if blockattributes_attrs.css != '' {
		if m := pcre2.must_compile(r'(?i)^<[^<]*style="(.*?)"').find_one_index(res) {
			// Inject CSS styles into first existing style attribute in first result.
			before := res[..m[2]]
			after := res[m[3]..]
			mut css := res[m[2]..m[3]]
			css = css.trim_space()
			if !css.ends_with(';') {
				css += ';'
			}
			res = before + css + ' ' + blockattributes_attrs.css + after
		} else {
			attributes += ' style="' + blockattributes_attrs.css + '"'
		}
	}
	if blockattributes_attrs.attributes != '' {
		attributes += ' ' + blockattributes_attrs.attributes
	}
	attributes = attributes.trim_left(' \n')
	if attributes != '' {
		if m := pcre2.must_compile(r'(?i)^(<[a-z]+|<h[1-6])(?:[ >])').find_one_submatch(res) { // Match start result.
			before := m[1]
			after := res[m[1].len..]
			res = before + ' ' + attributes + after
		}
	}
	// Consume the attributes.
	blockattributes_attrs.classes = ''
	blockattributes_attrs.id = ''
	blockattributes_attrs.css = ''
	blockattributes_attrs.attributes = ''
	return res
}

// Slugify converts text to a slug.
pub fn slugify(text string) string {
	mut slug := text
	slug = pcre2.must_compile(r'\W+').replace_all(slug, '-') // Replace non-alphanumeric characters with dashes.
	slug = pcre2.must_compile(r'-+').replace_all(slug, '-') // Replace multiple dashes with single dash.
	slug = slug.trim('-') // Trim leading and trailing dashes.
	slug = slug.to_lower()
	if slug == '' {
		slug = 'x'
	}
	if blockattributes_ids.contains(slug) { // Another element already has that id.
		mut i := 2
		for blockattributes_ids.contains('$slug-$i') {
			i++
		}
		slug += '-$i'
	}
	return slug
}
