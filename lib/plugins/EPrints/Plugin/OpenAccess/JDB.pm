=head1 NAME

EPrints::Plugin::OpenAccess::JDB - retrieve JDB Open Access data

=head1 DESCRIPTION

This plugin retrieves JDB Open Access data for an eprint.

=head1 METHODS

=over 4

=item $self = EPrints::Plugin::OpenAccess::JDB->new( %params )

Creates a new JDB plugin.

=item get_oa_data

Generic method for retrieving Open Access data for an eprint.

=back

=cut

package EPrints::Plugin::OpenAccess::JDB;

use strict;
use warnings;

use Date::Calc;
use Encode;

use base 'EPrints::Plugin::OpenAccess';

sub new
{
        my( $class, %params ) = @_;

        my $self = $class->SUPER::new( %params );

        $self->{name} = "JDB";
        $self->{visible} = "all";

        return $self;
}

#
# Generic wrapper method for retrieving Open Access data for an eprint.
#
sub get_oa_data
{
	my ($self) = @_;
	
	my $oadata = $self->_get_jdb_oa_data();
	
	return $oadata;
}


#
#  Get the JDB data
#
sub _get_jdb_oa_data
{
	my ($self) = @_;
	
	my $noise = $self->{param}->{noise};
	my $jdb = 'jdb';
	
	my $session_jdb = EPrints::Session->new( 1, $jdb, $noise );
	if ( !defined $session_jdb )
	{
		print STDERR "Failed to load repository: $jdb\n";
		return;
	}
	
	my $dataset_jdb = $session_jdb->get_repository->get_dataset( "archive" );
	if ( !defined $dataset_jdb )
	{
		print STDERR "Could not access the $jdb archive dataset!\n";
		$session_jdb->terminate;
		return;
	}
	
	my $eprint = $self->{eprint};
	
	return { 'error' => 1 } unless ( $eprint->is_set( "jdb_id") );
	
	my $jdb_id = $eprint->get_value( "jdb_id" );
	my $eprint_jdb = $dataset_jdb->dataobj( $jdb_id );
	return { 'error' => 2 } if ( !defined $eprint_jdb );
			
	my $jdb_data = $self->_process_jdb_record( $dataset_jdb, $eprint_jdb );
	
	return $jdb_data;
};

sub _process_jdb_record
{
	my ($self, $dataset, $eprint) = @_;
	
	my $pubyear = $self->{pubyear}; 
	
	my $is_doaj;
	my $is_hybrid;
	my $apc;
	my $oa_type = '';

	# DOAJ flag
	if ($eprint->is_set( "doaj" ))
	{
		$is_doaj = $eprint->get_value( "doaj" );
	}
	
	# SHERPA/RoMEO hybrid flag
	if ($eprint->is_set( "sr_is_hybrid" ))
	{
		$is_hybrid = $eprint->get_value( "sr_is_hybrid" );
	}
	
	my $journal_title = $eprint->get_value( "title" );
	my $publisher = $self->_get_publisher( $dataset, $eprint );
	
	# Process APCs
	$apc = $eprint->get_value( "apc" );
	my @apc_array = @$apc;
	
	my $apc_currency = "USD";
	my $apc_fee = 0;
	my $apc_year = 0;
	
	foreach my $apc_record (@apc_array)
	{
		my $apc_date = $apc_record->{date};
		my ($year) = EPrints::Time::split_value( $apc_date );
			
		if ( defined $pubyear && $year == $pubyear)
		{
			$apc_currency = $apc_record->{currency};
			$apc_fee = $apc_record->{fee};
			$apc_year = $year;
		}
	}
	
	# take the last entry if the year does not match
	my $apc_record_count = scalar( @$apc );
	if ( $apc_year == 0 && $apc_record_count > 0 )
	{
		my $apc_line = $apc_array[$apc_record_count - 1];
		
		$apc_currency = $apc_line->{currency};
		$apc_fee = $apc_line->{fee};
		($apc_year) = EPrints::Time::split_value( $apc_line->{date} );
	}
	
	$oa_type = 'gold' if (defined $is_doaj && $is_doaj eq "TRUE");
	
	my $jdb_data = {
		'error' => 0,
		'oa_type' => $oa_type,
		'is_doaj' => $is_doaj,
		'journal_is_hybrid' => $is_hybrid,
		'journal' => $journal_title,
		'publisher' => $publisher,
		'apc_currency' => $apc_currency,
		'apc_fee' => $apc_fee,
		'apc_year' => $apc_year,
	};
	
	return $jdb_data;
}

sub _get_publisher
{
	my ($self, $dataset, $eprint) = @_; 

	my $publisher = "Undefined";
	my $the_publisher;
	
	if( $eprint->is_set( "the_publisher" ) )
	{
		$the_publisher = $eprint->get_value( "the_publisher" );
	}
	else
	{
		$the_publisher = 0;
	}
	
	if ($the_publisher)
	{
		my $eprint_publisher = $dataset->dataobj( $the_publisher );
		if ( defined $eprint_publisher )
		{ 
			if ( $eprint_publisher->is_set( "name" ) )
			{
				$publisher = $eprint_publisher->get_value( "name" );
			}
		}
		else
		{
			my $eprintid = $eprint->id;
			print STDERR "Publisher reference $the_publisher not defined for JDB eprint $eprintid.\n";
		}
	}
	
	return $publisher;
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

