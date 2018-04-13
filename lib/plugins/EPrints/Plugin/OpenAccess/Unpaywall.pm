=head1 NAME

EPrints::Plugin::OpenAccess::Unpaywall - retrieve Unpaywall data

=head1 DESCRIPTION

This plugin retrieves unpaywall data for an eprint.

=head1 METHODS

=over 4

=item $self = EPrints::Plugin::OpenAccess::Unpaywall->new( %params )

Creates a new Unpaywall plugin.

=item get_oa_data

Generic wrapper method for retrieving Open Access data for an eprint.

=item get_unpaywall_data

Retrieve the unpaywall data for an eprint.

=back

=cut

package EPrints::Plugin::OpenAccess::Unpaywall;

use strict;
use warnings;

use Date::Calc;
use LWP::Simple;
use LWP::UserAgent;
use JSON;
use Encode;

use base 'EPrints::Plugin::OpenAccess';

sub new
{
        my( $class, %params ) = @_;

        my $self = $class->SUPER::new( %params );

        $self->{name} = "Unpaywall";
        $self->{visible} = "all";
        
        # Default parameters for crawling Unpaywall
        $self->{crawl_retry} = 3;
        $self->{crawl_delay} = 10;
		$self->{crawl_timeout} = 60;
		
        return $self;
}

#
# Generic wrapper method for retrieving Open Access data for an eprint.
#
sub get_oa_data
{
	my ($self) = @_;
	
	my $oadata = {};
	
	$oadata = $self->get_unpaywall_data();
	
	return $oadata;
}

#
# Retrieve the unpaywall data for an eprint, save it either to a JSON file,
# or return it to the caller.
#
sub get_unpaywall_data
{
	my ($self) = @_;
	
	my $json_only = $self->{param}->{json_only};
	
	my $eprint = $self->{eprint};
	my $eprintid = $eprint->id;
	
	my $verbose = $self->{verbose};
	
	my $unpaywall_returndata = {};
	my $unpaywall_response = {};
	
	my $unpaywall_data = $self->_submit_unpaywall_request();
	
    if ( $unpaywall_data->{id} == 200 )
	{
		if ($json_only)
		{
			# Save JSON response to file
			my $filename = $self->{param}->{json_directory} . '/unpaywall_' . sprintf('%06s',$eprintid) . '.json';
			open my $jsonout, ">", $filename or die "Cannot open > $filename\n";
			print $jsonout $unpaywall_data->{content};
			close($jsonout);
			$unpaywall_returndata = {
				'error' => -3
			};
			print STDOUT "Unpaywall JSON response saved to $filename\n" if $verbose;
		}
		else
		{
			# Parse the JSON response
			my $json = JSON->new->allow_nonref;
			$unpaywall_response = $json->decode( $unpaywall_data->{content} );
		
			if ( defined $unpaywall_response->{doi} )
			{
				$unpaywall_returndata = $self->_parse_unpaywall_response( $unpaywall_response );
			}
		}
	}
	else
	{
		$unpaywall_returndata = {
			'error' => $unpaywall_data->{id},
			'remark' => $unpaywall_data->{remark},
		};
	}
	
	return $unpaywall_returndata;
}

#
# Submit the unpaywall API request
#
sub _submit_unpaywall_request
{
	my ($self) = @_;
	
	my $base_url = $self->{session}->get_repository->config( "base_url" );
	
	my $eprint = $self->{eprint};
	my $eprintid = $eprint->id;
	
	my $noise = $self->{param}->{noise};
	
	my $crawl_retry = defined $self->{param}->{crawl_retry} ? $self->{param}->{crawl_retry} : $self->{crawl_retry}; 
	my $crawl_delay = defined $self->{param}->{crawl_delay} ? $self->{param}->{crawl_delay} : $self->{crawl_delay}; 
	my $crawl_timeout = defined $self->{param}->{crawl_timeout} ? $self->{param}->{crawl_timeout} : $self->{crawl_timeout}; 
	
	my $unpaywall_url;
	my $response = {};
	my $unpaywall_data = {};
	$unpaywall_data->{id} = -1;
	
	$unpaywall_url = $self->_get_unpaywall_url();
			
	if ($unpaywall_url ne '')
	{
		print STDERR "unpaywall API URL for eprint $eprintid: [$unpaywall_url]\n" if ($noise >= 2);
				
		my $request_counter = 1;
		my $success = 0;
		my $req = HTTP::Request->new( "GET", $unpaywall_url );
		$req->header( "Accept" => "application/json" );
		$req->header( "Accept-Charset" => "utf-8" );
		$req->header( "User-Agent" => "EPrints Unpaywall Sync; EPrints 3.3.x; " . $base_url );
				
		while (!$success && $request_counter <= $crawl_retry)
		{
			print STDERR "Request #$request_counter\n" if ($noise >= 3);
			my $ua = LWP::UserAgent->new;
			$ua->env_proxy;
			$ua->timeout($crawl_timeout);
			$response = $ua->request($req);
			$success = $response->is_success;
			$request_counter++;
			sleep $crawl_delay if !$success;
		}

		if ( $response->code != 200 )
		{
			print STDERR "Error " . $response->code . " from unpaywall API for eprint $eprintid\n";
			$unpaywall_data->{id} = $response->code;
			$unpaywall_data->{remark} = 'Unpaywall HTTP status ' . $response->code . '. Please check DOI.';
			return $unpaywall_data;
		}

		$unpaywall_data->{id} = 200;
		$unpaywall_data->{content} = $response->content;
		return $unpaywall_data;
	}
	else
	{
		$unpaywall_data->{id} = -2;
		$unpaywall_data->{remark} = 'Error in DOI. Please check.';
		print STDERR "Unpaywall API URL for eprint $eprintid not defined\n";
		return $unpaywall_data;
	}

	return;
}

#
#  Parse the unpaywall API response
#
sub _parse_unpaywall_response
{
	my ($self, $data) = @_;
	
	my $unpaywall_parse_response = {};
	
	my $is_oa;
	my $journal_is_oa;
	my $journal_is_in_doaj;
	my $oa_type;
	my $doaj;
	my $driver_version = '';
	my $journal = '';
	my $publisher = '';
	my $license = '';
	my $url = '';
	my $remark = '';
	
	
	if (defined $data->{HTTP_Status_code})
	{
		return $unpaywall_parse_response if ($data->{HTTP_Status_code} == 404); 
	}
	
	if (defined $data->{is_oa})
	{
		$is_oa = $data->{is_oa};
	}
	
	if (defined $data->{journal_is_oa} )
	{
		$journal_is_oa = $data->{journal_is_oa};
	}
	
	if (defined $data->{journal_is_in_doaj} )
	{
		$journal_is_in_doaj = $data->{journal_is_in_doaj};
	}
	
	if (defined $data->{journal_name} )
	{
		$journal = $data->{journal_name};
	}
	
	if (defined $data->{publisher} )
	{
		$publisher = $data->{publisher};
	}
	
	if (defined $data->{best_oa_location}->{license})
	{
		$license = $data->{best_oa_location}->{license};
	}
	
	if (defined $data->{best_oa_location}->{url_for_pdf})
	{
		$url = $data->{best_oa_location}->{url_for_pdf};
	}
	
	# OA Status = closed
	if ( $is_oa eq 'false' && $journal_is_oa eq 'false' && $journal_is_in_doaj eq 'false' )
	{
		$oa_type = "closed";
		$doaj = "FALSE";
	}
	
	# OA Status = gold 
	if ( $is_oa eq 'true' && $journal_is_oa eq 'true' && $journal_is_in_doaj eq 'true' )
	{
		# do further checks, but not really needed
		my $host_type = $data->{best_oa_location}->{host_type};
		if ( $host_type eq 'publisher' )
		{
			$oa_type = "gold";
			$doaj = "TRUE";
			$driver_version = $data->{best_oa_location}->{version};
		}
		if ( $host_type eq 'repository' )
		{
			$remark = 'Unpaywall data may be a false positive: Says journal is in DOAJ, but it is not. Please check.';
		}
	}
	
	# OA Status = hybrid or green
	if ( $is_oa eq 'true' && $journal_is_oa eq 'false' && $journal_is_in_doaj eq 'false' )
	{
		my $host_type = $data->{best_oa_location}->{host_type};
		if ( $host_type eq 'publisher' )
		{
			$oa_type = "hybrid";
			$doaj = "FALSE";
			$driver_version = $data->{best_oa_location}->{version};
		}
		elsif ( $host_type eq 'repository' )
		{
			$oa_type = "green";
			$doaj = "FALSE";
			$driver_version = $data->{best_oa_location}->{version};
		}
		else
		{
			$oa_type = "";
			$doaj = "FALSE";
		}
	}
	
	$unpaywall_parse_response = {
		'error' => 0,
		'oa_type' => $oa_type,
		'is_doaj' => $doaj,
		'journal' => $journal,
		'publisher' => $publisher,
		'license' => $license,
		'url' => $url,
		'driver_version' => $driver_version,
		'remark' => $remark,
		
	};
	
	return $unpaywall_parse_response;
}

#
# unpaywall API URL for a given journal eprint
# Returns an empty string if there is no valid DOI

sub _get_unpaywall_url
{
	my ($self) = @_;
	
	my $session = $self->{session};
	my $eprint = $self->{eprint};

	my $uri = '';

	my $base_uri = $session->config( 'unpaywallapi', 'uri' );
	my $email = $session->config( 'unpaywallapi', 'email' );
	
	# check the DOI and construct the URL
	if ( $eprint->is_set( "doi" ) )
	{
		my $doi = $eprint->get_value( "doi" );
		
		# strip off the resolver base URL, if any
		$doi =~ s|^http(s)?://(dx\.)?doi\.org||;
		
		# strip off doi: prefix, if any
		$doi =~ s|^doi:||;
				
		# check prefix
		if( $doi =~ /^10\.\d\d\d\d(\d)?\// )
		{
			my $uri_string = $base_uri . "/" . $doi;
			$uri = URI->new( $uri_string );
			$uri->query_form(
				email => $email
			);
		}
	}
    
	return $uri;
}

1;

=head1 AUTHOR

Martin Brändle <martin.braendle@id.uzh.ch>, Zentrale Informatik, University of Zurich

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2018- University of Zurich.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of ZORA and JDB based on EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

