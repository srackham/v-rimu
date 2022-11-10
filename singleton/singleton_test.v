module singleton_test

import singleton

pub struct Context {
pub mut:
	val string
mut:
	initialized bool
}

// context returns a ref to the Context singleton.
pub fn context() &Context {
	mut ctx := singleton.get<Context>()
	if !ctx.initialized {
		ctx.val = 'default value'
		ctx.initialized = true
	}
	return ctx
}

fn test_singleton() {
	mut ctx := context()
	assert ctx.val == 'default value'
	context().val = 'foo'
	assert ctx.val == 'foo'
	context().val = 'bar'
	assert ctx.val == 'bar'
}
