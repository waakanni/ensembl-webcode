package Bio::EnsEMBL::GlyphSet::gsv_variations;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use Data::Dumper;

sub _init {
  my ($self) = @_; 
  my $type = $self->check(); ;
  return unless defined $type;
  return unless $self->strand() == -1;

  my $Config = $self->{'config'}; 
  my $transcript =  $Config->{'transcript'}->{'transcript'};
 
  # Drawing params
  
  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my @res = $self->get_text_width( 0, 'M', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my( $font_w_bp, $font_h_bp) = ($res[2]/$pix_per_bp,$res[3]);
  my $h = $res[3] + 4; 

  # Data stuff
  my $colour_map  = $self->my_config('colours');  
  my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1; 
  my $EXTENT        = $Config->get_parameter( 'context'); 
   
     $EXTENT        = 1e6 if $EXTENT eq 'FULL'; 
  my $seq_region_name = $self->{'container'}->seq_region_name(); 

  # Bumping params
  my $bitmap_length = int($Config->container_width() * $pix_per_bp);
  my $voffset = 0;
  my @bitmap;
  my $max_row = -1;

  foreach my $snpref ( @{$Config->{'snps'}} ) { 
    my $snp = $snpref->[2];
    my $cod_snp =  $Config->{'transcript'}->{'snps'}->{$snp->dbID()};
    next unless $cod_snp;
    next if $snp->end < $transcript->start - $EXTENT - $offset;
    next if $snp->start > $transcript->end + $EXTENT - $offset;
    my $snp_type = lc($cod_snp->display_consequence); 
    my $colour = $colour_map->{$snp_type}->{'default'};
    my $aa_change = $cod_snp->pep_allele_string || '';
   

    my $S =  ( $snpref->[0]+$snpref->[1] )/2;
    my @res = $self->get_text_width( 0, $aa_change, '', 'font'=>$fontname, 'ptsize' => $fontsize );
    my $W = $res[2]/$pix_per_bp;
    my $tglyph = $self->Text({
      'x'         => $S-$W/2,
      'y'         => $h+4,
      'height'    => $font_h_bp,
      'width'     => $res[2]/$pix_per_bp,
      'textwidth' => $res[2],
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'colour'    => 'black',
      'text'      => $aa_change,
      'absolutey' => 1,
    });
    $W += 4/$pix_per_bp;

    my $dbid = $cod_snp->dbID;  
    my $variation_id = $snp->variation_name;
    unless ($aa_change =~/^\w+/) {$aa_change = '-';} 
    my $href = $self->_url
    ({'action'  => 'Variation',
      'v'     => $variation_id,
      'vf'    => $dbid,
      'var_box' => $aa_change,
    });

    my $type      = join ", ", @{$cod_snp->consequence_type || [] }; 
    $type = lc($type);
    my $bglyph = $self->Rect({
      'x'         => $S - $W / 2,
      'y'         => $h + 2,
      'height'    => $h,
      'width'     => $W,
      'colour'    => $colour,
      'absolutey' => 1,
      'href'      => $href,
    });
    my $bump_start = int($bglyph->{'x'} * $pix_per_bp);
       $bump_start = 0 if ($bump_start < 0);
    my $bump_end = $bump_start + int($bglyph->width()*$pix_per_bp) +1;
       $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
    my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );
    $max_row = $row if $row > $max_row;
    $tglyph->y( $voffset + $tglyph->{'y'} + ( $row * (2+$h) ) + 1 );
    $bglyph->y( $voffset + $bglyph->{'y'} + ( $row * (2+$h) ) + 1 );
    $self->push( $bglyph, $tglyph );
  }
}


sub error_track_name { return $_[0]->species_defs->AUTHORITY.' transcripts'; }

1;
