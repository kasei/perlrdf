function str (x) {
	warn(x);
	if (x instanceof Object) {
		warn('-> Node');
		if (x.is_literal()) {
			warn('-> literal');
			warn(x.literal_value);
			return x.literal_value;
		} else if (x.is_resource()) {
			warn('-> resource');
			return x.uri_value;
		} else {
			warn('-> blank');
			return x.blank_identifier;
		}
	} else {
		warn('-> Non-Node');
		return x;
	}
}

function square (x) { return x * x; }
function deg2rad(d) { return Math.PI*d/180 }
function gcdistance( lat1, lon1, lat2, lon2 ) {
	lat1	= deg2rad( makeTerm(lat1).toString() );
	lat2	= deg2rad( makeTerm(lat2).toString() );
	lon1	= deg2rad( makeTerm(lon1).toString() );
	lon2	= deg2rad( makeTerm(lon2).toString() );
	var londiff	= Math.abs(lon1 - lon2);
	var s1		= square(Math.sin((lat2 - lat1) / 2));
	var s2		= square(Math.sin( londiff / 2 ));
	
	var sq		= Math.sqrt(
					s1
					+ Math.cos(lat1)
					* Math.cos(lat2)
					* s2
				);
	
	var adist	= 2 * Math.asin( sq );
	var r		= 6372.795;
	var dist	= r * adist;
	var literal	= makeTerm(dist, null, "http://www.w3.org/2001/XMLSchema#float");
	return literal;
}
