=head1 NAME

EPrints::Plugin::Event::OpenAccessEvent - Updates Open Access type and DOAJ flag
upon eprint and document changes.

=head1 DESCRIPTION

This plug-in updates the Open Access type and DOAJ flag upon triggering of eprint 
and document changes. It calls the OpenAccess plug-in.

=head1 METHODS

=over 4

=item update_oa_type_document

Updates the OA type and DOAJ flag triggered by a document change.

=item update_oa_type

Updates the OA type and DOAJ flag triggered by a eprint change.

=back

=cut

package EPrints::Plugin::Event::OpenAccessEvent;

use strict;
use warnings;
use base 'EPrints::Plugin::Event';


sub update_oa_type_document
{
	my( $self, $document ) = @_;
	
	return if $document->has_relation( undef, "isVersionOf" );
	my $eprint = $document->get_parent();
	return unless $eprint;
	
	$self->update_oa_type( $eprint );
	
	return;
}

sub update_oa_type
{
	my ($self, $eprint) = @_;
	
	my $repository = $self->repository();
	
	my $plugin = $repository->plugin( 'OpenAccess' );
	return if ( !defined $plugin );
	
	$plugin->{eprint} = $eprint;
	$plugin->{param}->{verbose} = 0;
	$plugin->{param}->{noise} = 1;
	
	my $oa_data = $plugin->get_oa_type();
	
	if ( defined $oa_data && $oa_data->{error}->{value} == 0 )
	{
		my $oa_type = $oa_data->{oa_type}->{value};
		my $is_doaj = $oa_data->{is_doaj}->{value};
		
		if ( !defined $oa_type || $oa_type eq '' )
		{
			$oa_type = $oa_data->{tentative_oa_type}->{value};
		}
		
		$plugin->update_oa_data( $oa_type, $is_doaj );
	}

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

