module expansion

pub fn test_parse() {
	testcases := {
		'':                                          Options{}
		'+skip +macros +container +specials +spans': Options{true, true, true, true, true, true, true, true, true, true}
		'+skip +macros +container +specials':        Options{true, true, true, false, true, true, true, true, false, true}
		'-skip +macros +container +specials':        Options{true, true, false, false, true, true, true, true, false, true}
	}
	for k, v in testcases {
		assert parse(k) == v
	}
}
