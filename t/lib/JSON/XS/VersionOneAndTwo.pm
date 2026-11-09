package JSON::XS::VersionOneAndTwo;
use strict;
use Exporter 'import';
our @EXPORT = qw(decode_json encode_json from_json to_json);
BEGIN {
	if (eval { require JSON::XS; 1 }) { *decode_json=\&JSON::XS::decode_json; *encode_json=\&JSON::XS::encode_json }
	else { require JSON::PP; *decode_json=\&JSON::PP::decode_json; *encode_json=\&JSON::PP::encode_json }
}
sub from_json { decode_json($_[0]) } sub to_json { encode_json($_[0]) }
1;
