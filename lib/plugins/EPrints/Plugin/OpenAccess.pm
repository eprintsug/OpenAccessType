=head1 NAME

EPrints::Plugin::OpenAccess - Managing Open Access metadata

=head1 DESCRIPTION

This plugin manages Open Access metadata for an eprint. It uses 
Unpaywall and, if available, data from JDB.

=head1 METHODS

=over 4

=item $self = EPrints::Plugin::OpenAccess->new( %params )

Creates a new OpenAccess plugin.

=item get_oa_type

Gets Open Access type using a variety of configurable sources.

=item get_eprint_oa_metadata

Gets available OA metadata from an eprint.

=item guess_oa_type

Guess the Open Access type from the eprint only. A conservative guess is made.

=item update_oa_data

Updates the Open Access type and DOAJ flag.

=back

=cut

package EPrints::Plugin::OpenAccess;

use strict;
use warnings;

use Encode;

use base 'EPrints::Plugin';

sub new
{
        my( $class, %params ) = @_;

        my $self = $class->SUPER::new( %params );

        $self->{name} = "OpenAccess";
        $self->{visible} = "all";

        return $self;
}


sub get_oa_type
{
	my ($self) = @_;
	
	my $oa_data = {};
	my $oa_sources_data = {};
	my $session = $self->{session};
	my $repo_id = $session->get_repository->id;
	
	my $oa_data_eprint = $self->get_eprint_oa_metadata();

	my $oa_plugins = $session->get_repository->config( 'openaccess', 'plugins' );
	
	# Collect first all results from sources
	foreach my $oa_plugin (@$oa_plugins)
	{
		my $plugin = $session->plugin( $oa_plugin->{name} );
		if ( defined $plugin )
		{
			$plugin->{eprint} = $self->{eprint};
			$plugin->{param} = $self->{param};
			
			my $source = $oa_plugin->{source};
			$oa_sources_data->{$source} = $plugin->get_oa_data(); 
			$oa_sources_data->{$source}->{priority} = $oa_plugin->{priority};
		}
		else
		{
			print STDERR $oa_plugin->{name} . " missing.\n";
		}
	}
	
	# Evaluate OA data based on sources response and priority, discover conflicts
	foreach my $oa_plugin (sort { $b->{priority} <=> $a->{priority} } @$oa_plugins )
	{
		my $source = $oa_plugin->{source};
		my $priority = $oa_plugin->{priority};

		foreach my $property (keys %{$oa_sources_data->{$source}})
		{
			my $current_value = $oa_sources_data->{$source}->{$property};
			if ( !defined $oa_data->{$property} && defined $current_value )
			{
				$oa_data->{$property}->{value} = $current_value;
				$oa_data->{$property}->{priority} = $priority;
				$oa_data->{$property}->{source} = $source;
				$oa_data->{$property}->{conflict_source} = '';
				$oa_data->{$property}->{conflict_value} = '';
			}
			else
			{
				my $captured_value = $oa_data->{$property}->{value};
				my $captured_source = $oa_data->{$property}->{source};
				my $captured_priority = $oa_data->{$property}->{priority};
				
				# values of different sources are the same, but priority is lower
				if ( defined $current_value && $current_value eq $captured_value )
				{
					if ( $priority lt $captured_priority )
					{
						$oa_data->{$property}->{source} = $source;
					}
				}
				else
				{
					# conflict between values
					if ( defined $current_value && $priority lt $captured_priority )
					{
						$oa_data->{$property}->{value} = $current_value;
						$oa_data->{$property}->{priority} = $priority;
						$oa_data->{$property}->{source} = $source;
						$oa_data->{$property}->{conflict_source} = $captured_source;
						$oa_data->{$property}->{conflict_value} = $captured_value;
					}
				}
			}
		}
	}
	
	# Check against data of the eprint
	# APC
	if ( defined $oa_data_eprint->{apc_fee} )
	{
		$oa_data->{apc_fee}->{value} = $oa_data_eprint->{apc_fee};
		$oa_data->{apc_fee}->{priority} = 0;
		$oa_data->{apc_fee}->{source} = $repo_id;
		$oa_data->{apc_currency}->{value} = $oa_data_eprint->{apc_currency};
		$oa_data->{apc_currency}->{priority} = 0;
		$oa_data->{apc_currency}->{source} = $repo_id;
		$oa_data->{apc_year}->{value} = $oa_data_eprint->{apc_year};
		$oa_data->{apc_year}->{priority} = 0;
		$oa_data->{apc_year}->{source} = $repo_id;
	}
	
	if ( !defined $oa_data->{apc_fee}->{value} )
	{ 
		$oa_data->{apc_fee}->{value} = 0;
	}
	
	# Access rights and possible conflicts
	if ( defined $oa_data_eprint->{access_rights} )
	{
		my $access_rights = $oa_data_eprint->{access_rights};
		
		$oa_data->{access_rights}->{value} = $access_rights;
		$oa_data->{access_rights}->{priority} = 0;
		$oa_data->{access_rights}->{source} = $repo_id;
		
		my $conflict_source = $oa_data->{oa_type}->{source};
		my $conflict_value = $oa_data->{oa_type}->{value};
		
		if ( $access_rights eq 'info:eu-repo/semantics/openAccess' && $conflict_value eq 'closed' )
		{
			$oa_data->{oa_type}->{value} = 'green';
			$oa_data->{oa_type}->{priority} = 0;
			$oa_data->{oa_type}->{source} = $repo_id;
			$oa_data->{oa_type}->{conflict_source} = $conflict_source;
			$oa_data->{oa_type}->{conflict_value} = $conflict_value;
			$oa_data->{remark}->{value} = 'Conflicting OA type for ' . $repo_id . ' (green) and ' . $conflict_source . 
			  ' (closed): ' . $repo_id . ' has prevalence.';
		}
		
		if ( $access_rights ne 'info:eu-repo/semantics/openAccess' && defined $conflict_value &&  
		  $conflict_value ne '' && $conflict_value ne 'closed' )
		{
			$oa_data->{oa_type}->{value} = 'closed';
			$oa_data->{oa_type}->{priority} = 0;
			$oa_data->{oa_type}->{source} = $repo_id;
			$oa_data->{oa_type}->{conflict_source} = $conflict_source;
			$oa_data->{oa_type}->{conflict_value} = $conflict_value;
			$oa_data->{remark}->{value} = 'Conflicting OA type for ' . $repo_id . ' (closed) and ' . $conflict_source . 
			  ' (' . $conflict_value . '): ' . $repo_id . ' has prevalence.';
		}
	}
	
	# Assign the remaining eprint values
	$oa_data->{type}->{value} = $oa_data_eprint->{type};
	$oa_data->{has_full_text}->{value} = $oa_data_eprint->{has_full_text};
	$oa_data->{eprint_url}->{value} = $oa_data_eprint->{eprint_url};
	$oa_data->{url}->{value} = $oa_data_eprint->{url};
	$oa_data->{published_version}->{value} = $oa_data_eprint->{published_version};
	$oa_data->{content}->{value} = $oa_data_eprint->{content};
	$oa_data->{update_apc}->{value} = "No";
	$oa_data->{tentative_oa_type}->{value} = "";
	
	if ( !defined $oa_data->{publisher}->{value} )
	{
		$oa_data->{publisher}->{value} = $oa_data_eprint->{publisher};
		$oa_data->{publisher}->{priority} = 0;
		$oa_data->{publisher}->{source} = $repo_id;
	}
	
	my $oa_type = $oa_data->{oa_type}->{value};
	if ( defined $oa_type && ( $oa_type eq 'gold' ||  $oa_type eq 'hybrid' ) )
	{
		$oa_data->{update_apc}->{value} = "";
		
		# Add a remark if OA type is gold or hybrid and published version is missing
		if ( $oa_data->{content}->{value} ne 'published' )
		{
			$oa_data->{remark}->{value} = 'Published version can be added';
		}
	}
	
	# Guess OA type if not determined before from eprint record
	if ( !defined $oa_type || $oa_type eq '' )
	{
		my $oa_type_tentative = $self->guess_oa_type();
		
		$oa_data->{tentative_oa_type}->{value} = $oa_type_tentative;
		
		$oa_data->{oa_type}->{value} = $oa_type_tentative;
		$oa_data->{oa_type}->{priority} = 0;
		$oa_data->{oa_type}->{source} = $repo_id;
	}
	
	return $oa_data;
}

sub get_eprint_oa_metadata
{
	my ($self) = @_;
	
	my $session = $self->{session};
	my $eprint = $self->{eprint};
	
	my $eprint_oa_metadata = {};
	
	my $base_url = $session->config( "base_url" );
	
	my $content_priority_list = {
		"submitted" => 1,
		"accepted" => 2,
		"published" => 3,
	};
	
	#
	# try to find the content with the highest priority
	# published > accepted > submitted > other
	#
	my $has_full_text = 0;
	my $published_version = 0;
	my $content_major = '';
	my $content_priority = 0;
	
	my @documents = $eprint->get_all_documents();
	
	$has_full_text = 1 if ( scalar(@documents) > 0);
	
	foreach my $doc (@documents)
	{
		if ($doc->is_set( "content"))
		{
			my $content = $doc->get_value( "content" );
			$published_version = 1 if ( $content eq "published" );
			if (defined $content_priority_list->{$content} )
			{
				if ( $content_priority_list->{$content} > $content_priority )
				{
					$content_major = $content;
					$content_priority = $content_priority_list->{$content};
				}
			}
		}
	}
	
	my $eprintid = $eprint->get_value( "eprintid" );
	my $eprint_url = $base_url . "/id/eprint/" . $eprintid;
	
	my $url;
	if ($eprint->is_set( "doi" ))
	{
		my $doi = $eprint->get_value( "doi" );
		$url = "https://doi.org/" . $doi;
	}
	elsif ($eprint->is_set( "official_url" ))
	{
		$url = $eprint->get_value( "official_url" );
	}
	else
	{
		$url = "Undefined";
	}
	
	my $publisher = '';
	if ( $eprint->is_set( "publisher" ) )
	{
		$publisher = $eprint->get_value( "publisher" );
	}
	
	if ( $eprint->exists_and_set( "apc_currency") )
	{
		$eprint_oa_metadata->{apc_currency} = $eprint->get_value( "apc_currency" );
		$eprint_oa_metadata->{apc_fee} = $eprint->get_value( "apc_fee" );
		my $apc_date = $eprint->get_value( "apc_date" );
		my ($apc_year) = EPrints::Time::split_value( $apc_date );
		$eprint_oa_metadata->{apc_year} = $apc_year;
	}
	
	if ( $eprint->is_set( "oa_status" ) )
	{
		$eprint_oa_metadata->{oa_type} = $eprint->get_value( "oa_status" );
	}
	
	$eprint_oa_metadata->{type} = $eprint->get_value( "type" );
	$eprint_oa_metadata->{has_full_text} = $has_full_text;
	$eprint_oa_metadata->{eprint_url} = $eprint_url;
	$eprint_oa_metadata->{url} = $url;
	$eprint_oa_metadata->{published_version} = $published_version;
	$eprint_oa_metadata->{content} = $content_major;
	$eprint_oa_metadata->{publisher} = $publisher;

	if ( $eprint->exists_and_set( "access_rights" ) )
	{
		$eprint_oa_metadata->{access_rights} = $eprint->get_value( "access_rights" );
	}
	
	return $eprint_oa_metadata;
}


sub guess_oa_type
{
	my ($self) = @_;
	
	my $tentative_oa_type = "closed";
	my $eprint = $self->{eprint};
	
	if ( $eprint->exists_and_set( "access_rights" ) )
	{
		my $access_rights = $eprint->get_value( "access_rights" );
	
		if ( $access_rights eq 'info:eu-repo/semantics/openAccess' ) 
		{
			$tentative_oa_type = "green";
		}
	}
	
	return $tentative_oa_type;
}

sub update_oa_data
{
	my ($self, $oa_type, $doaj) = @_;
	
	my $eprint = $self->{eprint};
	
	$eprint->set_under_construction( 1 );
	
	$eprint->set_value( "oa_status", $oa_type);
	$eprint->set_value( "doaj", $doaj);	
	$eprint->commit();
	
	$eprint->set_under_construction( 0 );
	
	return;
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

