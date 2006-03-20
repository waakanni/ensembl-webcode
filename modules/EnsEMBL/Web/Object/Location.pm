package EnsEMBL::Web::Object::Location;

use strict;
use warnings;
no warnings "uninitialized";
use Data::Dumper;

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Proxy::Factory;
our @ISA = qw(EnsEMBL::Web::Object);
use POSIX qw(floor ceil);

sub centrepoint      { return ( $_[0]->Obj->{'seq_region_end'} + $_[0]->Obj->{'seq_region_start'} ) / 2; }
sub length           { return $_[0]->Obj->{'seq_region_end'} - $_[0]->Obj->{'seq_region_start'} + 1; }

sub slice            {
  my $self = shift;
  return $self->Obj->{'slice'} ||= $self->database('core',$self->real_species)->get_SliceAdaptor->fetch_by_region(
    $self->seq_region_type, $self->seq_region_name, $self->seq_region_start, $self->seq_region_end, $self->seq_region_strand );
}

sub alternative_object_from_factory {
  my( $self,$type ) =@_;
  my $t_fact = EnsEMBL::Web::Proxy::Factory->new( $type, $self->__data );
  if( $t_fact->can( 'createObjects' ) ) {
    $t_fact->createObjects;
    $self->__data->{lc($type)} = $t_fact->DataObjects;
    $self->__data->{'objects'} = $t_fact->__data->{'objects'};
  }
}

sub get_snp { return $_[0]->__data->{'snp'}[0] if $_[0]->__data->{'snp'}; }

sub attach_slice       { $_[0]->Obj->{'slice'} = $_[1];              }
sub real_species       :lvalue { $_[0]->Obj->{'real_species'};       }
sub raw_feature_strand :lvalue { $_[0]->Obj->{'raw_feature_strand'}; }
sub strand             :lvalue { $_[0]->Obj->{'strand'};             }
sub name               :lvalue { $_[0]->Obj->{'name'};               }
sub type               :lvalue { $_[0]->Obj->{'type'};               }
sub synonym            :lvalue { $_[0]->Obj->{'synonym'};            }
sub seq_region_name    :lvalue { $_[0]->Obj->{'seq_region_name'};    }
sub seq_region_start   :lvalue { $_[0]->Obj->{'seq_region_start'};   }
sub seq_region_end     :lvalue { $_[0]->Obj->{'seq_region_end'};     }
sub seq_region_strand  :lvalue { $_[0]->Obj->{'seq_region_strand'};  }
sub seq_region_type    :lvalue { $_[0]->Obj->{'seq_region_type'};    }
sub seq_region_length  :lvalue { $_[0]->Obj->{'seq_region_length'};  }

sub align_species {
    my $self = shift;
    if (my $add_species = shift) {
	$self->Obj->{'align_species'} = $add_species;
    }
    return $self->Obj->{'align_species'};
}

 
sub misc_set_code { 
  my $self = shift;
  if( @_ ) { 
    $self->Obj->{'misc_set_code'} = shift;
  }
  return $self->Obj->{'misc_set_code'};
}

sub setCentrePoint {
  my $self        = shift;
  my $centrepoint = shift;
  my $length      = shift || $self->length;
  $self->seq_region_start = $centrepoint - ($length-1)/2;
  $self->seq_region_end   = $centrepoint + ($length+1)/2;
}

sub setLength {
  my $self        = shift;
  my $length      = shift;
  $self->seq_region_start = $self->centrepoint - ($length-1)/2;
  $self->seq_region_end   = $self->seq_region_start + ($length-1)/2;
}

sub addContext {
  my $self = shift;
  my $context = shift;
  $self->seq_region_start -= int($context);
  $self->seq_region_end   += int($context);
}

######## LDVIEW CALLS ################################################

=head2 get_default_pop_name

   Arg[1]      : 
   Example     : my $pop_id = $self->DataObj->get_default_pop_name
   Description : returns population id for default population for this species
   Return type : population dbID

=cut

sub get_default_pop_name {
  my $self = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pop_adaptor = $variation_db->get_PopulationAdaptor;
  my $pop = $pop_adaptor->fetch_default_LDPopulation(); 
  return unless $pop;
  return $pop->name;
}

=head2 pop_obj_from_name

  Arg[1]      : Population name
  Example     : my $pop_name = $self->DataObj->pop_obj_from_name($pop_id);
  Description : returns population info for the given population name
  Return type : population object

=cut

sub pop_obj_from_name {
  my $self = shift;
  my $pop_name = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop = $pa->fetch_by_name($pop_name);
  return {} unless $pop;
  my $data = $self->format_pop( [$pop] );
  return $data;
}

=head2 pop_name_from_id

  Arg[1]      : Population id
  Example     : my $pop_name = $self->DataObj->pop_name_from_id($pop_id);
  Description : returns population name as string
  Return type : string

=cut

sub pop_name_from_id {
  my $self = shift;
  my $pop_id = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop = $pa->fetch_by_dbID($pop_id);
  return {} unless $pop;
  return $self->pop_name( $pop );
}

=head2 extra_pop

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Arg[2]      : string "super", "sub"
  Example     : $genotype_freq = $self->DataObj->extra_pop($pop, "super");
  Description : gets any super/sub populations
  Return type : String

=cut

sub extra_pop {  ### ALSO IN SNP DATA OBJ
  my ($self, $pop_obj, $type)  = @_;
  return {} unless $pop_obj;
  my $call = "get_all_$type" . "_Populations";
  my @populations = @{ $pop_obj->$call};
  return  $self->format_pop(\@populations);
}

=head2 format_pop

  Arg[1]      : population object
  Example     : my $data = $self->format_pop
  Description : returns population info for the given population obj
  Return type : hashref

=cut

sub format_pop {
  my $self = shift;
  my $pops = shift;
  my %data;
  foreach (@$pops) {
    my $name = $self->pop_name($_);
    $data{$name}{Name}       = $self->pop_name($_);
    $data{$name}{dbID}       = $_->dbID;
    $data{$name}{Size}       = $self->pop_size($_);
    $data{$name}{PopLink}    = $self->pop_links($_);
    $data{$name}{Description}= $self->pop_description($_);
    $data{$name}{PopObject}  = $_;  ## ok maybe this is cheating..
  }
  return \%data;
}


=head2 pop_name

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $self->DataObj->pop_name($pop);
  Description : gets the Population name
  Return type : String

=cut

sub pop_name {
  my ($self, $pop_obj)  = @_;
  return unless $pop_obj;
  return $pop_obj->name;
}

=head2 ld_for_slice

   Arg[1]      :
   Example     : my $container = $self->ld_for_slice;
   Description : returns all LD values on this slice as a
                 Bio::EnsEMBL::Variation::LDFeatureContainer
   ReturnType  :  Bio::EnsEMBL::Variation::LDFeatureContainer

=cut


sub ld_for_slice {
  my $self = shift; 
  my $pop_id = shift;
  my $width = $self->param('w') || "50000";
  my ($seq_region, $start, $seq_type ) = ($self->seq_region_name, $self->seq_region_start, $self->seq_region_type);
  return [] unless $seq_region;

  my $end   = $start + ($width/2);
  $start -= ($width/2);
  my $slice = $self->slice_cache($seq_type, $seq_region, $start, $end, 1);
  return {} unless $slice;
  return  $slice->get_all_LD_values() || {};
}



=head2 pop_links

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $genotype_freq = $self->DataObj->pop_links($pop);
  Description : gets the Population description
  Return type : String

=cut

sub pop_links {
  my ($self, $pop_obj)  = @_;
  return $pop_obj->get_all_synonyms("dbSNP");
}


=head2 pop_size

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $genotype_freq = $self->DataObj->pop_size($pop);
  Description : gets the Population size
  Return type : String

=cut

sub pop_size {
  my ($self, $pop_obj)  = @_;
  return $pop_obj->size;
}


=head2 pop_description

  Arg[1]      : Bio::EnsEMBL::Variation::Population object
  Example     : $genotype_freq = $self->DataObj->pop_description($pop);
  Description : gets the Population description
  Return type : String

=cut

sub pop_description {
  my ($self, $pop_obj)  = @_;
  return $pop_obj->description;
}

=head2 location

    Arg[1]      : (optional) String
                  Name of slice
    Example     : my $location = $self->DataObj->name;
    Description : getter/setter for slice name
    Return type : String for slice name

=cut

sub location { return $_[0]; }

sub generate_query_hash {
  my $self = shift;
  return {
    'c'     => $self->seq_region_name.':'.$self->centrepoint.':'.$self->seq_region_strand,
    'w'     => $self->length,
    'h'     => $self->highlights_string(),
    'pop'   => $self->param('pop'),
 };
}

=head2 get_variation_features

  Arg[1]      : none
  Example     : my @vari_features = $self->get_variation_features;
  Description : gets the Variation features found  on a slice
  Return type : Arrayref of Bio::EnsEMBL::Variation::VariationFeatures

=cut

sub get_variation_features {
   my $self = shift;
   my $slice = $self->slice_cache;
   return unless $slice;
   return $slice->get_all_VariationFeatures || [];
}

sub slice_cache {
  my $self = shift;
  my( $type, $region, $start, $end, $strand ) = @_;
  $type   ||= $self->seq_region_type;
  $region ||= $self->seq_region_name;
  $start  ||= $self->seq_region_start;
  $end    ||= $self->seq_region_end;
  $strand ||= $self->seq_region_strand;

  my $key = join '::', $type, $region, $start, $end, $strand;
  unless ($self->__data->{'slice_cache'}{$key}) {
    $self->__data->{'slice_cache'}{$key} =
      $self->database('core')->get_SliceAdaptor()->fetch_by_region(
        $type, $region, $start, $end, $strand
      );
  }
  return $self->__data->{'slice_cache'}{$key};
}


sub current_pop_name {
  my $self = shift;
  my %pops_on;
  my %pops_off;
  my $script_config = $self->get_scriptconfig();

  # Read in all in scriptconfig stuff
  foreach ($script_config->options) {
    next unless $_ =~ s/opt_pop_//;
    $pops_on{$_}  = 1 if $script_config->get("opt_pop_$_") eq 'on';
    $pops_off{$_} = 1 if $script_config->get("opt_pop_$_") eq 'off';
  }

  # Set options according to bottom
  # if param bottom   #pop_CSHL-HAPMAP:HapMap-JPT:on;
  if ( $self->param('bottom') ) {
    foreach( split /\|/, ($self->param('bottom') ) ) {
      next unless $_ =~ /opt_pop_(.*):(.*)/;
      if ($2 eq 'on') {
	$pops_on{$1} = 1;
	delete $pops_off{$1};
      }
      elsif ($2 eq 'off') {
	$pops_off{$1} = 1;
	delete $pops_on{$1};
      }
    }
    return ( [keys %pops_on], [keys %pops_off] )  if keys %pops_on or keys %pops_off;
  }


  # Get pops switched on via pop arg if no bottom
  if ( my @pops = $self->param('pop') ) {
    # put all pops_on keys in pops_off
    map { $pops_off{$_} = 1 } (keys %pops_on);
    %pops_on = ();
    map { $pops_on{$_} = 1 if $_ } @pops;
  }
  return ( [keys %pops_on], [keys %pops_off] )  if keys %pops_on or keys %pops_off;

  return [] if $self->param('bottom') or $self->param('pop');
  my $default_pop =  $self->get_default_pop_name;
  warn "*****[ERROR]: NO DEFAULT POPULATION DEFINED.\n\n" unless $default_pop;
  return ( [$default_pop], [] );
}


=head2 pops_for_slice

   Arg[1]      :
   Example     : my $data = $self->DataObj->ld_for_slice;
   Description : returns all population IDs with LD data for this slice
   ReturnType  : hashref of population dbIDs
=cut


sub pops_for_slice {
  my $self = shift;
  my $width  = shift || 100000;

  my $ld_container = $self->ld_for_slice($width);
  return [] unless $ld_container;

  my $pop_ids = $ld_container->get_all_populations();
  return {} unless @$pop_ids;

  my @pops;
  foreach (@$pop_ids) {
    my $name = $self->pop_name_from_id($_);
    push @pops, $name;
  }

  my @tmp_sorted =  sort {$a cmp $b} @pops;
  return \@tmp_sorted;
}


sub getVariationsOnSlice {
  my $self = shift;
  my $sliceObj = EnsEMBL::Web::Proxy::Object->new(
        'Slice', $self->slice_cache, $self->__data
       );

  my ($count_snps, $filtered_snps) = $sliceObj->getVariationFeatures;
  return ($count_snps, $filtered_snps);
}


sub get_genotyped_VariationsOnSlice {
  my $self = shift;
  my $sliceObj = EnsEMBL::Web::Proxy::Object->new(
        'Slice', $self->slice_cache, $self->__data
       );

  my ($count_snps, $filtered_snps) = $sliceObj->get_genotyped_VariationFeatures;
  return ($count_snps, $filtered_snps);
}

sub get_source {
  my $self = shift;
  my $default = shift;
  my $vari_adaptor = $self->database('variation')->get_db_adaptor('variation');
  unless ($vari_adaptor) {
    warn "ERROR: Can't get variation adaptor";
    return ();
  }

  if ($default) {
    return  $vari_adaptor->get_VariationAdaptor->get_default_source();
  }
  else {
    return $vari_adaptor->get_VariationAdaptor->get_all_sources();
  }
}

1;
