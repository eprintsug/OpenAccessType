package EPrints::Plugin::Stats::Processor::EPrint::OAStatus;

use base 'EPrints::Plugin::Stats::Processor';

# Processor::EPrint::OAStatus
#
# Purpose:  Determines OA Status counts 
#           Provides the 'eprint_oa_status' datatype.
#
# Authors:  Martin Brändle
# Place:    University of Zurich, Zentrale Informatik, Stampfenbachstr. 73, Zurich, Switzerland
# Date:     2018/02/08
# Modified: -
#

sub new
{
	my( $class, %params ) = @_;
	my $self = $class->SUPER::new( %params );
	my $repo = $self->repository;

	$self->{provides} = [ "oa_status" ];

	$self->{disable} = 0;

	return $self;
}

sub process_record
{
	my ($self, $eprint ) = @_;

	my $epid = $eprint->get_id;
	return unless( defined $epid );

	my $status = $eprint->get_value( "eprint_status" );
	return unless( defined $status ); 
	return unless( $status eq 'archive' );

	my $datestamp = $eprint->get_value( "datestamp" ) || $eprint->get_value( "lastmod" );

	my $date = $self->parse_datestamp( $self->{session}, $datestamp );

	my $year = $date->{year};
	my $month = $date->{month};
	my $day = $date->{day};
	
	my $oa_status = $eprint->get_value( "oa_status" );
	
	if (defined $oa_status)
	{
		$self->{cache}->{"$year$month$day"}->{$epid}->{"$oa_status"}++;
	}
	else
	{
		$self->{cache}->{"$year$month$day"}->{$epid}->{"unknown"}++;	
	}
}

1;
