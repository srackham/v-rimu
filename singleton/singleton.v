module singleton

/*
The singleton should be a struct with the actual data residing in struct fields.
See https://discordapp.com/channels/592103645835821068/592294828432424960/934198551884468275
*/

@[unsafe]
fn private_get[T]() &T {
	mut static s := &T(unsafe { nil })
	if u64(s) == 0 {
		s = &T{}
	}
	return s
}

pub fn get[T]() &T {
	return unsafe { private_get[T]() }
}
