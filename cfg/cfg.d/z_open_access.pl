##############################################################################
#
#  Open Access Plug-in configuration. 
#
##############################################################################

$c->{plugins}{"OpenAccess"}{params}{disable} = 0;
$c->{plugins}{"OpenAccess::JDB"}{params}{disable} = 0;
$c->{plugins}{"OpenAccess::Unpaywall"}{params}{disable} = 0;
$c->{plugins}{"Event::OpenAccessEvent"}{params}{disable} = 0;

$c->{openaccess} = {};

# 
$c->{openaccess}->{plugins} = [ 
	{ 
		name => 'OpenAccess::JDB', 
		source => 'JDB',
		priority => 1 
	},
	{ 
		name => 'OpenAccess::Unpaywall',
		source => 'Unpaywall',
		priority => 2
	}, 
];

#
# Add a trigger that updates the OA type when a document is modified
#
$c->add_dataset_trigger( "document", EP_TRIGGER_AFTER_COMMIT, sub
{
	my ( %args ) = @_;

	my ($doc) = @args{qw( dataobj )};

	return unless defined $doc;
	return if $doc->has_relation( undef, "isVersionOf" );

	my $repository = $doc->repository;
 
	$repository->dataset( "event_queue" )->create_dataobj({
		pluginid => "Event::OpenAccessEvent",
		action => "update_oa_type_document",
		params => [$doc->internal_uri],
	});

	return EP_TRIGGER_OK;
});

#
# Add a trigger that updates the OA type when a document is removed
#
$c->add_dataset_trigger( "document", EP_TRIGGER_REMOVED, sub
{
	my ( %args ) = @_;

	my ($doc) = @args{qw( dataobj )};

	return unless defined $doc;
	# one can't check on relations as above because these have been removed already
	return if ($doc->get_value( "format") ne "application/pdf");

	my $repository = $doc->repository;

	my $eprint = $doc->get_parent();
	
	return unless defined $eprint;
	
	$repository->dataset( "event_queue" )->create_dataobj({
		pluginid => "Event::OpenAccessEvent",
		action => "update_oa_type",
		params => [$eprint->internal_uri],
	});

	return EP_TRIGGER_OK;
});

#
# Add a trigger that updates the OA type when an eprint is moved to the archive
#
$c->add_dataset_trigger( "eprint", EP_TRIGGER_STATUS_CHANGE, sub
{       
	my( %args ) = @_;
	my( $eprint, $old_state, $new_state ) = @args{qw( dataobj old_status new_status )};

	return unless defined $eprint;
	return unless defined $new_state && $new_state eq "archive";

	# if there are any documents, the document trigger above will fire
	my @documents = $eprint->get_all_documents();
	return if (scalar @documents > 0);

	my $repository = $eprint->repository;

	$repository->dataset( "event_queue" )->create_dataobj({
		pluginid => "Event::OpenAccessEvent",
		action => "update_oa_type",
		params => [$eprint->internal_uri],
	});

	return EP_TRIGGER_OK;
});

