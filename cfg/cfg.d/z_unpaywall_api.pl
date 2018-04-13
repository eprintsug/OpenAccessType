###############################################################################
#
#  Unpaywall API Configuration. See https://unpaywall.org/api/v2
#
###############################################################################
$c->{unpaywallapi} = {};

#
# The base URL of the unpaywall API 
#
$c->{unpaywallapi}->{uri} = URI->new( 'http://api.unpaywall.org/v2' );
#
# The e-mail address of the requester
#
$c->{unpaywallapi}->{email} = 'your_email@here';
